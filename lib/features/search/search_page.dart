import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/ds/ds.dart';
import '../../data/models/app_user.dart';
import '../../data/models/poster.dart';
import '../../data/models/tag.dart';
import '../../data/models/work.dart';
import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/poster_repository.dart';
import '../../data/repositories/search_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../profile/follow_pill.dart';

/// /search — unified search across works, posters, users.
/// Debounces input by 250ms to avoid hammering the RPC.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  String _effectiveQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    // Rebuild immediately so the clear-X suffix icon tracks keystrokes;
    // debounce only the actual search RPC so we don't hammer the DB.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _effectiveQuery = v.trim());
    });
  }

  /// Tag chip tapped on the landing — fill the field and trigger
  /// search immediately (no debounce, since the tap IS intent).
  void _searchForTag(String tag) {
    _controller.text = tag;
    _controller.selection =
        TextSelection.collapsed(offset: tag.length);
    _debounce?.cancel();
    setState(() => _effectiveQuery = tag);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      
      body: Column(
        children: [
          // Top bar: chevron-back + 搜尋 title. Matches the chrome on
          // 我的投稿 / 粉絲 / 追蹤中 etc. so all push screens share one
          // header pattern.
          Padding(
            padding: EdgeInsets.fromLTRB(4, topInset + 8, 16, 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go('/');
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(LucideIcons.chevronLeft,
                        size: 24, color: AppTheme.text),
                  ),
                ),
                const SizedBox(width: 4),
                const AppText.title('搜尋'),
              ],
            ),
          ),
          // Search field — Spotify-style white pill: pure white bg,
          // dark text, rounded full-pill, no border. The white surface
          // pops on the dark page bg the way Spotify's search input
          // does on its black scaffold.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            // ClipRRect — Container's borderRadius only paints the bg
            // edge; the TextField inside still rendered as a square
            // box, leaking past the rounded fill. ClipRRect actually
            // CLIPS children to the pill shape so the input renders
            // round at every rest/focus state.
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.rPill),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(AppTheme.rPill),
                ),
                child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onChanged,
                style: const TextStyle(
                  fontFamily: 'NotoSansTC',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF121212),
                ),
                cursorColor: const Color(0xFF121212),
                decoration: InputDecoration(
                  hintText: '搜尋作品、海報、使用者…',
                  hintStyle: const TextStyle(
                    fontFamily: 'NotoSansTC',
                    color: Color(0xFF6B6B6B),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: const Icon(LucideIcons.search,
                      size: 18, color: Color(0xFF6B6B6B)),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(LucideIcons.x,
                              size: 16, color: Color(0xFF6B6B6B)),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _effectiveQuery = '');
                          },
                        ),
                  filled: true,
                  fillColor: const Color(0xFFFFFFFF),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                ),
                ),
              ),
            ),
          ),

          Expanded(
            child: _effectiveQuery.isEmpty
                ? _SearchLanding(
                    onTagTap: _searchForTag,
                    bottomInset: bottomInset,
                  )
                : _ResultsView(
                    query: _effectiveQuery,
                    bottomInset: bottomInset,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Search landing — replaces the old empty state.
//
// Top: horizontal-scroll row of top-20 tag chips (from `top_tags` RPC).
//      Tap a chip → it fills the search field and triggers search.
// Below: flat 2-col masonry of recommended posters from for_you_feed_v1
//      (taste-ranked when user has ≥3 favorites; trending fallback when
//      cold-start or signed out).
// ─────────────────────────────────────────────────────────────────────

/// Calls `for_you_feed_v1` and parses each row through Poster.fromRow.
/// Caps at 24 posters so the landing renders fast.
final searchLandingPostersProvider =
    FutureProvider.autoDispose<List<Poster>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client.rpc('for_you_feed_v1', params: {'p_limit': 24});
  if (rows == null) return const [];
  return (rows as List)
      .map((r) => Poster.fromRow(r as Map<String, dynamic>))
      .toList(growable: false);
});

class _SearchLanding extends ConsumerWidget {
  const _SearchLanding({
    required this.onTagTap,
    required this.bottomInset,
  });
  final ValueChanged<String> onTagTap;
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(topTagsProvider);
    final postersAsync = ref.watch(searchLandingPostersProvider);

    return CustomScrollView(
      slivers: [
        // ── Tag chip row ──
        SliverToBoxAdapter(
          child: tagsAsync.when(
            // Skeleton: 5 muted placeholder chips so the row has shape
            // before data arrives. A blank 50-high box read as "is
            // something broken?" — this makes the pending state
            // obvious without a spinner.
            loading: () => SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                itemCount: 5,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, _) => Container(
                  width: 72,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceRaised,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (tags) {
              if (tags.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  itemCount: tags.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => Center(
                    child: AppChip(
                      label: tags[i],
                      size: AppChipSize.small,
                      onTap: () => onTagTap(tags[i]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // ── 為你推薦 — horizontal scroll (Spotify search "made for you") ──
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(0, 16, 0, 12),
            child: AppSectionHeader(title: '為你推薦'),
          ),
        ),
        postersAsync.when(
          loading: () => SliverToBoxAdapter(
            child: SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: 4,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, _) => SizedBox(
                  width: 120,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.r3),
                    ),
                  ),
                ),
              ),
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('載入失敗：$e',
                  style: TextStyle(color: AppTheme.textMute)),
            ),
          ),
          data: (posters) {
            if (posters.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
            final items = posters.take(12).toList(growable: false);
            return SliverToBoxAdapter(
              child: SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final p = items[i];
                    return AppPosterTile(
                      imageUrl: p.thumbnailUrl ?? p.posterUrl,
      fullImageUrl: p.posterUrl,
      blurhash: p.blurhash,
                      posterId: p.id,
                      title: p.title,
                      width: 120,
                      height: 180,
                    );
                  },
                ),
              ),
            );
          },
        ),

        // ── 瀏覽分類 — Spotify "瀏覽全部" pattern ──
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(0, 32, 0, 12),
            child: AppSectionHeader(title: '瀏覽分類'),
          ),
        ),
        SliverToBoxAdapter(
          child: _BrowseCategories(bottomInset: bottomInset),
        ),
      ],
    );
  }
}

/// Spotify "瀏覽全部" — vertical stack of large category cards.
/// Each card surface uses the editorial palette so the page reads
/// at a glance even in monochrome (the colours are shipped per
/// position; the content inside stays text-only).
class _BrowseCategories extends ConsumerWidget {
  const _BrowseCategories({required this.bottomInset});
  final double bottomInset;

  // Stable rotation of muted dark accents so adjacent cards differ
  // visually without competing with the poster art the user lands
  // on after tapping. All bound to AppTheme tokens — no rogue hex.
  Color _bgFor(int i) {
    const palette = [
      Color(0xFF1F2A36),
      Color(0xFF2B1F36),
      Color(0xFF362B1F),
      Color(0xFF1F362A),
      Color(0xFF2A1F36),
      Color(0xFF362024),
    ];
    return palette[i % palette.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catsAsync = ref.watch(tagCategoriesProvider);
    return catsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: AppLoader.centered(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text('載入分類失敗：$e',
            style: TextStyle(color: AppTheme.textMute)),
      ),
      data: (cats) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 40),
          child: Column(
            children: [
              for (var i = 0; i < cats.length; i++) ...[
                _CategoryCard(
                  title: _shortCatName(cats[i].titleZh),
                  background: _bgFor(i),
                  onTap: () => _openCategorySheet(context, cats[i]),
                ),
                if (i < cats.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _shortCatName(String full) =>
      full.startsWith('編輯') ? full.substring(2) : full;

  void _openCategorySheet(BuildContext context, TagCategory cat) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.r6),
        ),
      ),
      builder: (ctx) => _CategoryTagSheet(category: cat),
    );
  }
}

/// Bottom sheet listing all canonical tags in a single category.
/// Tap a chip → `/tags/<slug>`. Stop-gap until a dedicated category
/// landing page lands; works fine because tag pages already render
/// the flat poster grid the user wants.
class _CategoryTagSheet extends ConsumerWidget {
  const _CategoryTagSheet({required this.category});
  final TagCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(allCanonicalTagsProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: category.titleZh.startsWith('編輯')
                ? category.titleZh.substring(2)
                : category.titleZh,
            horizontalPadding: 0,
          ),
          const SizedBox(height: 14),
          tagsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: AppLoader.centered(),
            ),
            error: (e, _) => Text('載入失敗：$e',
                style: TextStyle(color: AppTheme.textMute)),
            data: (allTags) {
              final mine = allTags
                  .where((t) => t.categoryId == category.id)
                  .toList(growable: false);
              if (mine.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('這個分類還沒有 tag',
                      style: TextStyle(color: AppTheme.textMute)),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in mine)
                    AppChip(
                      label: t.labelZh,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/tags/${t.slug}');
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.background,
    required this.onTap,
  });
  final String title;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.r4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.r4),
        child: Container(
          height: 96,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppTheme.r4),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'InterDisplay',
              fontFamilyFallback: ['NotoSansTC'],
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// _LandingMasonry / _LandingCard deleted in v19 round 4 —
// replaced by the horizontal-scroll AppPosterTile row inside
// _SearchLanding. The vertical masonry felt like an infinite
// scroll wall; horizontal + the "瀏覽分類" cards below match
// Spotify's search landing.

class _ResultsView extends ConsumerWidget {
  const _ResultsView({required this.query, required this.bottomInset});
  final String query;
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(unifiedSearchProvider(query));
    return async.when(
      loading: () => const AppLoader.centered(),
      error: (e, _) => Center(
        child: Text('搜尋失敗：$e',
            style: TextStyle(color: AppTheme.textMute)),
      ),
      data: (r) {
        if (r.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('找不到「$query」的相關結果',
                  style: TextStyle(color: AppTheme.textMute)),
            ),
          );
        }
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 32),
          children: [
            if (r.works.isNotEmpty) ...[
              _SectionHeader(icon: LucideIcons.film, label: '作品', count: r.works.length),
              ...r.works.map((w) => _WorkTile(work: w)),
              const SizedBox(height: 16),
            ],
            if (r.posters.isNotEmpty) ...[
              _SectionHeader(
                  icon: LucideIcons.image, label: '海報', count: r.posters.length),
              ...r.posters.map((p) => _PosterTile(poster: p)),
              const SizedBox(height: 16),
            ],
            if (r.users.isNotEmpty) ...[
              _SectionHeader(
                  icon: LucideIcons.users, label: '使用者', count: r.users.length),
              ...r.users.map((u) => _UserTile(user: u)),
            ],
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.count,
  });
  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textFaint),
          const SizedBox(width: 6),
          AppText.label('$label · $count', tone: AppTextTone.faint),
        ],
      ),
    );
  }
}

class _WorkTile extends StatelessWidget {
  const _WorkTile({required this.work});
  final Work work;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/work/${work.id}'),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.chipBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(LucideIcons.film,
                    size: 18, color: AppTheme.textMute),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.bodyBold(work.displayTitle,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    AppText.caption(
                      [
                        if (work.movieReleaseYear != null)
                          '${work.movieReleaseYear}',
                        '${work.posterCount} 張海報',
                      ].join(' · '),
                      tone: AppTextTone.muted,
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight,
                  size: 14, color: AppTheme.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterTile extends StatelessWidget {
  const _PosterTile({required this.poster});
  final Poster poster;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/poster/${poster.id}'),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 40,
                  height: 56,
                  child: CachedNetworkImage(
                    imageUrl: poster.thumbnailUrl ?? poster.posterUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 200,
                    fadeInDuration: const Duration(milliseconds: 180),
                    errorWidget: (_, _, _) => Container(
                      color: AppTheme.surfaceRaised,
                      child: Icon(LucideIcons.image,
                          size: 16, color: AppTheme.textFaint),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.bodyBold(poster.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    AppText.caption(
                      [
                        if (poster.posterName != null) poster.posterName!,
                        if (poster.year != null) '${poster.year}',
                      ].join(' · '),
                      tone: AppTextTone.muted,
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight,
                  size: 14, color: AppTheme.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/user/${user.id}'),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: user.avatarUrl != null
                      ? CachedNetworkImage(
                          imageUrl: user.avatarUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) =>
                              _UserAvatarFallback(name: user.displayName),
                        )
                      : _UserAvatarFallback(name: user.displayName),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.bodyBold(
                        user.displayName.isEmpty
                            ? '無名使用者'
                            : user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (user.bio != null && user.bio!.isNotEmpty)
                      AppText.caption(user.bio!,
                          tone: AppTextTone.muted,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // Replace the chevron with a follow pill: more actionable,
              // still leaves whole row tappable for navigation.
              FollowPill(targetUserId: user.id, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserAvatarFallback extends StatelessWidget {
  const _UserAvatarFallback({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final letter =
        name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return Container(
      color: AppTheme.chipBgStrong,
      alignment: Alignment.center,
      child: Text(letter,
          style: const TextStyle(
            fontFamily: 'InterDisplay',
            fontFamilyFallback: ['NotoSansTC'],
            fontWeight: FontWeight.w600,
          )),
    );
  }
}
