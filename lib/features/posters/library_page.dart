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
import '../../core/widgets/glass.dart';
import '../../data/models/app_user.dart';
import '../../data/models/poster.dart';
import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/favorite_repository.dart';
import '../../data/repositories/poster_repository.dart';
import '../../data/repositories/submission_repository.dart';

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

/// v13 Me-tab chrome (top → bottom):
///   1. title row (+ upload + ☰ menu — no text title)
///   2. profile row (avatar + name + bio + 編輯 pill)
///   3. segmented tabs (收藏 / 投稿)
///
/// Tag filter pills + L/M/S toggle removed (2026-04-20):
///   - L/M/S: only masonry (M) makes sense for the IG-like 我的 view
///   - Tag pills: list_favorites_with_posters RPC doesn't accept a tag
///     filter, so filter chips were silently no-op when 收藏 was active.
///     Cleaner to remove them than to fix server-side for a feature
///     that isn't in v13 spec anyway.
const _titleRowHeight = 44.0;
const _profileRowHeight = 80.0;  // 64 avatar + 16 padding
const _segTabsHeight = 48.0;
double _chromeHeight(double safeTop) =>
    safeTop + 8 + _titleRowHeight + _profileRowHeight + _segTabsHeight;

/// 我的 segmented sub-tab — drives the filter passed to the poster
/// repository. 收藏 → favoritesOf=user.id. 投稿 → uploadedBy=user.id.
enum _MeTab { favorites, submissions }

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

  // v13 我的: only the segmented sub-tab drives filtering. Tag chips
  // and density toggle removed.
  _MeTab _meTab = _MeTab.favorites;

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
    // Build initial filter from default pills (favorites=true, no tags).
    // Must run after first frame so we can read currentUserProvider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _rebuildFilterFromPills();
    });
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

  /// Advanced filter sheet — kept for future "更多篩選" entry point but
  /// not currently surfaced in v13 chrome (Me tab only has ⚙ in title row).
  // ignore: unused_element
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

  /// Legacy density cycle — replaced by _DensityToggle (3-icon segmented).
  /// Kept for any external callers.
  // ignore: unused_element
  void _cycleDensity() {
    final notifier = ref.read(browseDensityProvider.notifier);
    notifier.cycle();
    HapticFeedback.selectionClick();
    final next = ref.read(browseDensityProvider);
    SharedPreferences.getInstance()
        .then((p) => p.setString(_prefsKeyDensity, next.key));
  }

  void _onSegChange(_MeTab tab) {
    if (_meTab == tab) return;
    HapticFeedback.selectionClick();
    setState(() => _meTab = tab);
    _rebuildFilterFromPills();
  }

  void _rebuildFilterFromPills() {
    final user = ref.read(currentUserProvider);
    final uid = user?.id;
    _applyFilter(PosterFilter(
      favoritesOf: _meTab == _MeTab.favorites ? uid : null,
      uploadedBy: _meTab == _MeTab.submissions ? uid : null,
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
      if (_meTab == _MeTab.favorites) {
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
    // v13 我的 chrome (3 rows):
    //   1. title row: + (upload) on left, ☰ (menu) on right — no text title
    //   2. profile row: avatar 64 + name + bio + 編輯 pill
    //   3. segmented sub-tabs: 收藏 N / 投稿 N
    //
    // tag pills + L/M/S row removed per user feedback (2026-04-20).
    final favCount = ref.watch(favoriteIdsProvider).asData?.value.length ?? 0;
    final mySubsAsync = ref.watch(mySubmissionsV2Provider);
    final subCount = mySubsAsync.asData?.value.length ?? 0;
    final user = ref.read(currentUserProvider);

    final inner = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: topInset + 8),

          // ── 1. title row: + upload (left), ☰ menu (right) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: _titleRowHeight,
              child: Row(
                children: [
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
                  const Spacer(),
                  _ChromeIconButton(
                    icon: LucideIcons.menu,
                    semanticLabel: '選單',
                    onTap: () => context.push('/profile'),
                  ),
                ],
              ),
            ),
          ),

          // ── 2. profile row ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: _profileRowHeight,
              child: _MeProfileRow(profile: profile, fallbackEmail: user?.email ?? ''),
            ),
          ),

          // ── 3. segmented sub-tabs (收藏 / 投稿) ──
          SizedBox(
            height: _segTabsHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _SegTab(
                      label: '收藏 $favCount',
                      active: _meTab == _MeTab.favorites,
                      onTap: () => _onSegChange(_MeTab.favorites),
                    ),
                  ),
                  Expanded(
                    child: _SegTab(
                      label: '投稿 $subCount',
                      active: _meTab == _MeTab.submissions,
                      onTap: () => _onSegChange(_MeTab.submissions),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

    // v13: a single glass strip wraps the chrome. In L mode keep the
    // dark gradient on top so chrome reads against bright posters.
    final glass = Glass(
      blur: 20,
      tint: 0.5,
      // Full-width strip — no rounded corners on top/sides.
      borderRadius: BorderRadius.zero,
      // Custom border: no top/left/right edges, only bottom hairline.
      border: Border(
        bottom: BorderSide(color: AppTheme.line1, width: 0.5),
      ),
      shadow: false,
      highlight: false,
      child: inner,
    );

    if (density == BrowseDensity.large) {
      return Stack(
        children: [
          // Dark gradient behind glass for legibility over full-bleed image.
          IgnorePointer(
            child: Container(
              height: _chromeHeight(topInset) + 8,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB3000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
          glass,
        ],
      );
    }
    return glass;
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
        child: _meTab == _MeTab.favorites
            ? const _EmptyFavoritesState()
            : const _EmptyState(),
      );
    }
    // v13: only masonry. L (full-bleed page-view) and S (list) widgets
    // are still in library_density_views.dart for future re-use.
    return _MediumGrid(
      controller: _scrollController,
      items: displayItems,
      trailingLoader: _loading,
      topPadding: topPad,
      bottomPadding: bottomPad,
      favIds: favIds,
      onToggleFavorite: _toggleFavorite,
    );
  }
}
