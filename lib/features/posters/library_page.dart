import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_notifier.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/ds/ds.dart';
import '../../data/models/app_user.dart';
import '../../data/models/poster.dart';
import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/favorite_repository.dart';
import '../../data/repositories/follow_repository.dart';
import '../../data/repositories/poster_repository.dart';
import '../../data/repositories/user_repository.dart';

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
const _profileRowHeight = 96.0;  // 72 avatar + 24 padding
const _statsRowHeight = 44.0;    // 4 stats + 編輯檔案 pill
const _segTabsHeight = 48.0;
double _chromeHeight(double safeTop) =>
    safeTop +
    8 +
    _titleRowHeight +
    _profileRowHeight +
    _statsRowHeight +
    _segTabsHeight;

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
    // 我的 page is treated as one integrated surface — the top
    // chrome stays pinned and never hides on scroll (reverted the
    // floating behaviour: it made the page feel chopped up).
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
    // Watch theme mode so LibraryPage rebuilds when user toggles
    // 白天/夜晚 — without this, the const widget stays cached in the
    // IndexedStack and the bg lags a frame behind when you pop back
    // from Profile.
    ref.watch(themeModeProvider);
    final density = ref.watch(browseDensityProvider);
    final topInset = MediaQuery.paddingOf(context).top;
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.asData?.value;
    final user = ref.watch(currentUserProvider);

    // Server-side filtering handles all modes (including favorites).
    final displayItems = _items;
    final favIds = ref.watch(favoriteIdsProvider).asData?.value ?? {};

    // 我的 page scrolls as ONE integrated surface: chrome (avatar +
    // stats + segmented tabs) is embedded as the first child of the
    // masonry scroll view and scrolls away with the posters. Only
    // the L (hero) + S (list) density modes still overlay chrome on
    // top, because their content is not a simple scroll column.
    final chrome = _buildTopChrome(context, topInset, density, profile, user);
    final useInlineChrome = density == BrowseDensity.medium;

    return Scaffold(
      
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildContent(
              density,
              displayItems,
              favIds,
              inlineHeader: useInlineChrome ? chrome : null,
            ),
          ),
          if (!useInlineChrome)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: chrome,
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
    final user = ref.read(currentUserProvider);
    // "投稿 N" and "已通過 N" must match what the submissions grid
    // actually shows — approved posters where uploader_id = me. The
    // old source (mySubmissionsV2Provider → submissions table) counts
    // pending/rejected rows in the review queue, which has no 1:1
    // relationship with the posters table after approval (rows may be
    // removed or stale). Use the same count the public profile RPC
    // exposes so all three — grid, tab label, and 已通過 stat —
    // agree on a single source of truth.
    final subCount = user == null
        ? 0
        : (ref
                .watch(publicProfileProvider(user.id))
                .asData
                ?.value
                ?.approvedPosterCount ??
            0);

    final inner = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: topInset + 8),

          // ── 1. title row: ☰ menu only (right) ──
          // v18: no ＋ button here — upload is in the bottom nav now.
          // No page title text — it's not a desktop.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: _titleRowHeight,
              child: Row(
                children: [
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

          // ── 2. profile row: avatar + name + @handle + bio ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: _profileRowHeight,
              child: _MeProfileRow(
                profile: profile,
                fallbackEmail: user?.email ?? '',
              ),
            ),
          ),

          // ── 3. stats + edit pill ──
          // 追蹤者 · 追蹤中 · 已通過 · 投稿 with thin dividers,
          // plus a "編輯檔案" pill on the right.
          SizedBox(
            height: _statsRowHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
              child: _MeStatsRow(
                userId: user?.id,
                favCount: favCount,
                subCount: subCount,
              ),
            ),
          ),

          // ── 4. segmented sub-tabs (收藏 / 投稿) ──
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

    // v18: solid opaque strip (was a blurred Glass). The blur +
    // tint read as haze over full-bleed L-mode posters and added a
    // BackdropFilter on every scroll frame. Flat scaffold-colour
    // with a hairline bottom is cleaner + cheaper.
    final glass = Container(
      decoration: BoxDecoration(
        color: AppTheme.bg,
        border: Border(
          bottom: BorderSide(color: AppTheme.line1, width: 0.5),
        ),
      ),
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
      BrowseDensity density, List<Poster> displayItems, Set<String> favIds,
      {Widget? inlineHeader}) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // When the chrome is inlined (M mode), topPad only needs a
    // 14px gap between the segmented tabs and the first row —
    // the chrome carries its own safe-area inset. When the chrome
    // is pinned via Positioned (L/S modes), topPad reserves room
    // for the entire chrome.
    final topPad = inlineHeader != null ? 14.0 : _chromeHeight(topInset) + 14;
    // bottomInset + (~nav pill height 58 + floating offset 20 +
    // breathing room) so cards don't hug the nav pill.
    final bottomPad = bottomInset + 110;

    if (_firstLoad && _loading) {
      return Padding(
        padding: EdgeInsets.only(
            top: inlineHeader != null ? topInset : topPad, bottom: bottomPad),
        child: LibraryDensitySkeleton(density: density),
      );
    }
    if (displayItems.isEmpty && !_loading) {
      return Padding(
        padding: EdgeInsets.only(
            top: inlineHeader != null ? topInset : topPad, bottom: bottomPad),
        child: _meTab == _MeTab.favorites
            ? const _EmptyFavoritesState()
            : const _EmptyState(),
      );
    }
    // v18 我的: always Pinterest masonry. Heart overlay shows only on
    // 投稿 tab (submissions) — 收藏 tab is by-definition-favorited so
    // showing a heart on every card is redundant.
    return _MediumGrid(
      controller: _scrollController,
      items: displayItems,
      trailingLoader: _loading,
      topPadding: topPad,
      bottomPadding: bottomPad,
      favIds: favIds,
      showFav: _meTab == _MeTab.submissions,
      onToggleFavorite: _toggleFavorite,
      header: inlineHeader,
    );
  }
}
