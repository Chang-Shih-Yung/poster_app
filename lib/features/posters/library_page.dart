import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_user.dart';
import '../../data/models/poster.dart';
import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/favorite_repository.dart';
import '../../data/repositories/poster_repository.dart';

part 'library_density_views.dart';
part 'library_chrome_widgets.dart';
part 'library_filter_sheet.dart';

// ---------------------------------------------------------------------------
// Density
// ---------------------------------------------------------------------------

/// Density modes: L = full-bleed hero, M = 2-col grid, S = list.
enum BrowseDensity { large, medium, small }

extension BrowseDensityExt on BrowseDensity {
  String get key => switch (this) {
        BrowseDensity.large => 'L',
        BrowseDensity.medium => 'M',
        BrowseDensity.small => 'S',
      };
  IconData get icon => switch (this) {
        BrowseDensity.large => LucideIcons.square,
        BrowseDensity.medium => LucideIcons.layoutGrid,
        BrowseDensity.small => LucideIcons.list,
      };
  BrowseDensity get next => switch (this) {
        BrowseDensity.large => BrowseDensity.medium,
        BrowseDensity.medium => BrowseDensity.small,
        BrowseDensity.small => BrowseDensity.large,
      };
}

class BrowseDensityNotifier extends Notifier<BrowseDensity> {
  @override
  BrowseDensity build() => BrowseDensity.medium;

  void set(BrowseDensity d) => state = d;
  void cycle() => state = state.next;
}

final browseDensityProvider =
    NotifierProvider<BrowseDensityNotifier, BrowseDensity>(
        BrowseDensityNotifier.new);

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _prefsKeyDensity = 'browse.density';
const _prefsKeySearchHistory = 'browse.search_history';
const _searchHistoryMax = 5;

/// Height of the top chrome (top bar + pills + sort row) so content knows
/// how much room to reserve.
const _topBarHeight = 44.0;
const _filterPillsHeight = 36.0; // 28px pill + 8px gap
const _sortRowHeight = 40.0; // 32px row + 8px gap
double _chromeHeight(double safeTop) =>
    safeTop + 8 + _topBarHeight + _filterPillsHeight + _sortRowHeight;

// ---------------------------------------------------------------------------
// LibraryPage
// ---------------------------------------------------------------------------

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _scrollController = ScrollController();
  late final PageController _heroPageController;

  final List<Poster> _items = [];
  bool _loading = false;
  bool _end = false;
  bool _firstLoad = true;
  PosterFilter _filter = const PosterFilter();
  List<String> _searchHistory = const [];

  int _heroPage = 0;
  int _requestSeq = 0;

  // Pill state: multi-select tags + independent favorites toggle.
  Set<String> _pillTags = {};
  bool _pillFavorites = false;

  @override
  void initState() {
    super.initState();
    _heroPageController = PageController();
    _heroPageController.addListener(() {
      final p = _heroPageController.page ?? 0;
      final idx = p.round();
      if (idx != _heroPage) setState(() => _heroPage = idx);
      // Trigger pagination when approaching the end in L mode.
      if (idx >= _items.length - 3 && !_loading && !_end) {
        _loadMore();
      }
    });
    _loadPrefs();
    _loadMore();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _heroPageController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final d = prefs.getString(_prefsKeyDensity);
    final hist = prefs.getStringList(_prefsKeySearchHistory) ?? const [];
    if (!mounted) return;
    final density = switch (d) {
      'L' => BrowseDensity.large,
      'S' => BrowseDensity.small,
      _ => BrowseDensity.medium,
    };
    ref.read(browseDensityProvider.notifier).set(density);
    setState(() => _searchHistory = hist);
  }

  Future<void> _pushHistory(String term) async {
    if (term.isEmpty) return;
    final next = [term, ..._searchHistory.where((e) => e != term)]
        .take(_searchHistoryMax)
        .toList();
    setState(() => _searchHistory = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKeySearchHistory, next);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _end) return;
    final seq = ++_requestSeq;
    final offset = _items.length;
    final capturedFilter = _filter;
    setState(() => _loading = true);
    try {
      final page = await ref.read(posterRepositoryProvider).listApproved(
            filter: capturedFilter,
            offset: offset,
          );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        final existing = _items.map((p) => p.id).toSet();
        _items.addAll(page.items.where((p) => !existing.contains(p.id)));
        _end = !page.hasMore;
        _firstLoad = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('載入失敗：$e')));
      }
    } finally {
      if (mounted && seq == _requestSeq) setState(() => _loading = false);
    }
  }

  Future<void> _applyFilter(PosterFilter next) async {
    _requestSeq++;
    setState(() {
      _items.clear();
      _end = false;
      _loading = false;
      _firstLoad = true;
      _filter = next;
      _heroPage = 0;
    });
    if (_heroPageController.hasClients) {
      _heroPageController.jumpToPage(0);
    }
    await _loadMore();
  }

  Future<void> _openFilterSheet() async {
    HapticFeedback.selectionClick();
    final result = await showModalBottomSheet<PosterFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      useSafeArea: true,
      builder: (_) => _BlurredFilterSheet(
        initial: _filter,
        history: _searchHistory,
        onClearHistory: () async {
          setState(() => _searchHistory = const []);
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_prefsKeySearchHistory);
        },
      ),
    );
    if (result != null) {
      if (result.search != null && result.search!.isNotEmpty) {
        await _pushHistory(result.search!);
      }
      await _applyFilter(result);
    }
  }

  void _cycleDensity() {
    final notifier = ref.read(browseDensityProvider.notifier);
    notifier.cycle();
    HapticFeedback.selectionClick();
    final next = ref.read(browseDensityProvider);
    SharedPreferences.getInstance()
        .then((p) => p.setString(_prefsKeyDensity, next.key));
  }

  // Pill tap handlers.
  void _onPillAll() {
    if (_pillTags.isEmpty && !_pillFavorites) return;
    setState(() {
      _pillTags = {};
      _pillFavorites = false;
    });
    _applyFilter(const PosterFilter());
  }

  void _onPillTag(String tag) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_pillTags.contains(tag)) {
        _pillTags = Set.of(_pillTags)..remove(tag);
      } else {
        _pillTags = Set.of(_pillTags)..add(tag);
      }
    });
    _rebuildFilterFromPills();
  }

  void _onPillFavorites() {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      HapticFeedback.selectionClick();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請先登入才能檢視收藏')),
        );
      }
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _pillFavorites = !_pillFavorites);
    _rebuildFilterFromPills();
  }

  void _rebuildFilterFromPills() {
    final user = ref.read(currentUserProvider);
    _applyFilter(PosterFilter(
      tags: _pillTags.toList(),
      favoritesOf: _pillFavorites ? user?.id : null,
    ));
  }

  /// Long-press favorite handler for M/S mode.
  Future<void> _toggleFavorite(Poster poster) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      HapticFeedback.selectionClick();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請先登入才能收藏')),
        );
      }
      return;
    }

    final favIds = ref.read(favoriteIdsProvider).asData?.value;
    final alreadyFav = favIds?.contains(poster.id) ?? false;
    HapticFeedback.mediumImpact();

    try {
      if (alreadyFav) {
        await ref.read(favoriteRepositoryProvider).remove(user.id, poster.id);
      } else {
        await ref.read(favoriteRepositoryProvider).add(user.id, poster);
      }
      ref.invalidate(favoriteIdsProvider);

      // If viewing favorites, refresh the list so removed items disappear.
      if (_pillFavorites) {
        _rebuildFilterFromPills();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(alreadyFav
                ? '已取消收藏：${poster.title}'
                : '已加入最愛：${poster.title}'),
            duration: const Duration(seconds: 1),
            backgroundColor: AppTheme.surfaceRaised,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${alreadyFav ? '取消' : '加入'}失敗：$e')),
        );
      }
    }
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final density = ref.watch(browseDensityProvider);
    final topInset = MediaQuery.paddingOf(context).top;
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.asData?.value;
    final user = ref.watch(currentUserProvider);

    // Server-side filtering handles all modes (including favorites).
    final displayItems = _items;
    final favIds = ref.watch(favoriteIdsProvider).asData?.value ?? {};

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // Content fills the scaffold.
          Positioned.fill(
            child: _buildContent(density, displayItems, favIds),
          ),

          // Top chrome: always visible.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopChrome(context, topInset, density, profile, user),
          ),
        ],
      ),
    );
  }

  Widget _buildTopChrome(
    BuildContext context,
    double topInset,
    BrowseDensity density,
    AppUser? profile,
    dynamic user,
  ) {
    final topTagsAsync = ref.watch(topTagsProvider);
    final tags = topTagsAsync.asData?.value ?? const [];

    // In L mode, add a gradient backdrop for legibility.
    return Container(
      decoration: density == BrowseDensity.large
          ? const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xE0000000),
                  Color(0x80000000),
                  Colors.transparent,
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: topInset + 8),

          // Top bar: avatar + title + search + plus.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: _topBarHeight,
              child: Row(
                children: [
                  // Avatar.
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: _Avatar(profile: profile, size: 32),
                  ),
                  const SizedBox(width: 12),
                  // Title.
                  Text(
                    '我的',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                  ),
                  const Spacer(),
                  // Search icon.
                  _ChromeIconButton(
                    icon: LucideIcons.search,
                    semanticLabel: '搜尋',
                    onTap: _openFilterSheet,
                  ),
                  const SizedBox(width: 4),
                  // Upload icon.
                  _ChromeIconButton(
                    icon: LucideIcons.plus,
                    semanticLabel: '上傳海報',
                    onTap: () {
                      final u = ref.read(currentUserProvider);
                      if (u == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('請先登入才能上傳')),
                        );
                        return;
                      }
                      context.push('/upload');
                    },
                  ),
                ],
              ),
            ),
          ),

          // Filter pills.
          SizedBox(
            height: _filterPillsHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shrinkWrap: true,
                children: [
                  Center(
                    child: _FilterPill(
                      label: '全部',
                      selected:
                          _pillTags.isEmpty && !_pillFavorites,
                      onTap: _onPillAll,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...tags.map((t) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Center(
                          child: _FilterPill(
                            label: t,
                            selected: _pillTags.contains(t),
                            onTap: () => _onPillTag(t),
                          ),
                        ),
                      )),
                  Center(
                    child: _FilterPill(
                      label: '收藏',
                      selected: _pillFavorites,
                      onTap: _onPillFavorites,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sort + density row.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: _sortRowHeight,
              child: Row(
                children: [
                  Text(
                    '最近',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppTheme.textMute,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const Spacer(),
                  Semantics(
                    label: '切換顯示密度',
                    button: true,
                    child: GestureDetector(
                      onTap: _cycleDensity,
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: 44,
                        height: 40,
                        child: Center(
                          child: Icon(density.icon,
                              size: 18, color: AppTheme.textMute),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
      BrowseDensity density, List<Poster> displayItems, Set<String> favIds) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final topPad = _chromeHeight(topInset);
    final bottomPad = bottomInset + 20;

    if (_firstLoad && _loading) {
      return Padding(
        padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
        child: LibraryDensitySkeleton(density: density),
      );
    }
    if (displayItems.isEmpty && !_loading) {
      return Padding(
        padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
        child: _pillFavorites
            ? const _EmptyFavoritesState()
            : const _EmptyState(),
      );
    }
    final child = switch (density) {
      BrowseDensity.large => _FullBleedFeed(
          pageController: _heroPageController,
          items: displayItems,
          heroIndex: _heroPage,
          topPadding: topPad,
          favIds: favIds,
          onToggleFavorite: _toggleFavorite,
        ),
      BrowseDensity.medium => _MediumGrid(
          controller: _scrollController,
          items: displayItems,
          trailingLoader: _loading,
          topPadding: topPad,
          bottomPadding: bottomPad,
          favIds: favIds,
          onToggleFavorite: _toggleFavorite,
        ),
      BrowseDensity.small => _SmallList(
          controller: _scrollController,
          items: displayItems,
          trailingLoader: _loading,
          topPadding: topPad,
          bottomPadding: bottomPad,
          favIds: favIds,
          onToggleFavorite: _toggleFavorite,
        ),
    };
    return AnimatedSwitcher(
      duration: AppTheme.motionMed,
      switchInCurve: AppTheme.easeStandard,
      child: KeyedSubtree(
        key: ValueKey(density),
        child: child,
      ),
    );
  }
}
