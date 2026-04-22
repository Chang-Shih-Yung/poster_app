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
import '../../data/models/work.dart';
import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/poster_repository.dart';
import '../../data/repositories/search_repository.dart';
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
    final theme = Theme.of(context);

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
                Text(
                  '搜尋',
                  style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
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

        // Section eyebrow
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              '為你推薦',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textMute,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),

        // ── Recommended posters (flat 2-col masonry) ──
        postersAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: AppLoader()),
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text('載入失敗：$e',
                    style: TextStyle(color: AppTheme.textMute)),
              ),
            ),
          ),
          data: (posters) {
            if (posters.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Center(
                    child: Text('暫無推薦，輸入關鍵字搜尋海報、作品、使用者',
                        style: TextStyle(color: AppTheme.textFaint)),
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset + 32),
              sliver: SliverToBoxAdapter(
                child: _LandingMasonry(posters: posters),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 2-col deterministic-aspect masonry for the search landing's poster
/// grid. Tap a card → /poster/:id. Same algorithm as the 我的 tab so
/// the visual rhythm matches.
class _LandingMasonry extends StatelessWidget {
  const _LandingMasonry({required this.posters});
  final List<Poster> posters;

  static double _ratioForId(String id) {
    const ratios = <double>[0.67, 0.67, 0.75, 1.0, 1.33, 0.56];
    var h = 0;
    for (final r in id.runes) {
      h = (h * 31 + r) & 0x7fffffff;
    }
    return ratios[h % ratios.length];
  }

  @override
  Widget build(BuildContext context) {
    final colA = <Poster>[];
    final colB = <Poster>[];
    var hA = 0.0;
    var hB = 0.0;
    for (final p in posters) {
      final h = 1 / _ratioForId(p.id);
      if (hA <= hB) {
        colA.add(p);
        hA += h + 0.05;
      } else {
        colB.add(p);
        hB += h + 0.05;
      }
    }
    Widget col(List<Poster> items) => Column(
          children: items
              .map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _LandingCard(
                      poster: p,
                      aspectRatio: _ratioForId(p.id),
                    ),
                  ))
              .toList(),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: col(colA)),
        const SizedBox(width: 8),
        Expanded(child: col(colB)),
      ],
    );
  }
}

class _LandingCard extends StatelessWidget {
  const _LandingCard({required this.poster, required this.aspectRatio});
  final Poster poster;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return AppPosterTile(
      imageUrl: poster.thumbnailUrl ?? poster.posterUrl,
      posterId: poster.id,
      title: poster.title,
      subtitle: [
        if (poster.year != null) '${poster.year}',
        if (poster.director != null) poster.director!,
      ].join(' · '),
      aspectRatio: aspectRatio,
    );
  }
}

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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textFaint),
          const SizedBox(width: 6),
          Text(
            '$label · $count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.textFaint,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w600,
            ),
          ),
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
    final theme = Theme.of(context);
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
                    Text(work.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall),
                    Text(
                      [
                        if (work.movieReleaseYear != null)
                          '${work.movieReleaseYear}',
                        '${work.posterCount} 張海報',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppTheme.textMute),
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
    final theme = Theme.of(context);
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
                    Text(poster.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall),
                    Text(
                      [
                        if (poster.posterName != null) poster.posterName!,
                        if (poster.year != null) '${poster.year}',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppTheme.textMute),
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
    final theme = Theme.of(context);
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
                    Text(
                        user.displayName.isEmpty
                            ? '無名使用者'
                            : user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall),
                    if (user.bio != null && user.bio!.isNotEmpty)
                      Text(user.bio!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textMute)),
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
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}
