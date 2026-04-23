import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_notifier.dart';
import '../../core/widgets/ds/ds.dart';
import '../../core/widgets/shimmer_placeholder.dart';
import '../../core/widgets/two_bar_icon.dart';
import '../../data/models/app_user.dart';
import '../../data/models/home_section.dart';
import '../../data/models/poster.dart';
import '../../data/models/social.dart';
import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/favorite_repository.dart';
import '../../data/repositories/social_repository.dart';
import '../profile/follow_pill.dart';
import '../shell/app_shell.dart';

// ---------------------------------------------------------------------------
// Section display config
// ---------------------------------------------------------------------------

/// Map lucide icon name (from DB) → IconData.
/// Short whitelist — we only wire icons that seeded rows use today.
/// Unknown icons fall back to LucideIcons.tag.
IconData _iconFromName(String? name) {
  switch (name) {
    case 'flame':
      return LucideIcons.flame;
    case 'user-check':
      return LucideIcons.userCheck;
    case 'trending-up':
      return LucideIcons.trendingUp;
    case 'users':
      return LucideIcons.users;
    case 'sparkle':
    case 'sparkles':
      return LucideIcons.sparkles;
    case 'star':
      return LucideIcons.star;
    case 'medal':
      return LucideIcons.medal;
    case 'flag':
      return LucideIcons.flag;
    case 'palette':
      return LucideIcons.palette;
    case 'award':
      return LucideIcons.award;
    case 'film':
      return LucideIcons.film;
    default:
      return LucideIcons.tag;
  }
}

// ---------------------------------------------------------------------------
// HomePage
// ---------------------------------------------------------------------------

// Density toggle removed in v18 — horizontal-scroll cards only.

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // HomePage is a const widget sitting inside an IndexedStack — the
    // Element reuses across theme flips, which means without an
    // explicit watch its subtree keeps the stale AppTheme.* values
    // until something else rebuilds it (e.g. user tapping a tab).
    // This watch makes it rebuild the same frame the user picks
    // 白天 / 夜晚 / 系統預設, so the 我的 tab is already the new
    // colour when they pop back from Profile.
    ref.watch(themeModeProvider);
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final favIds = ref.watch(favoriteIdsProvider).asData?.value ?? {};
    final sectionsAsync = ref.watch(homeSectionsV2Provider);
    final myId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      
      body: CustomScrollView(
        slivers: [
          // v18 top chrome: hamburger + search icon on a glass pill.
          // Floating behaviour (`floating: true, snap: true, pinned:
          // false`) lets the bar slide off-screen on scroll-down and
          // snap back on the first scroll-up tick — matches the
          // IG / Threads / X header pattern the user asked for.
          SliverAppBar(
            pinned: false,
            floating: true,
            snap: true,
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 48,
            titleSpacing: 0,
            // `primary: true` reserves the status-bar space; the
            // flexibleSpace widget then paints the full (topInset +
            // 48) area, with our bar content nudged down by topInset.
            flexibleSpace: _HomeGlassHeaderBar(
              topInset: topInset,
              onMenuTap: () {
                HapticFeedback.selectionClick();
                openHomeDrawer(context);
              },
              onSearchTap: () {
                HapticFeedback.selectionClick();
                context.push('/search');
              },
            ),
          ),

          // ── EPIC 14: config-driven sections ──────────────────────────────
          // One provider → ordered list → dispatch per sourceType. Order is
          // determined by `home_sections_config.position` in DB. Admin can
          // reorder / add / remove sections without code changes.
          ...sectionsAsync.when(
            loading: () => [
              for (var i = 0; i < 3; i++)
                SliverToBoxAdapter(child: _SectionSkeleton()),
            ],
            error: (e, _) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text('載入失敗：$e',
                        style: TextStyle(color: AppTheme.textFaint)),
                  ),
                ),
              ),
            ],
            data: (sections) {
              // v18: drop the hardcoded editorial tag sections (經典 /
              // 日版 / 台版 / 手繪 / 大師 / 收藏必備) that were seeded in
              // home_sections_config. They felt like a permanent store
              // shelf; the home page should read as "what's moving
              // now", driven by trending / follow / recent_approved.
              // The DB rows stay put so admin / migrations aren't
              // disturbed — we just filter them on the client.
              sections = sections
                  .where((s) => s.sourceType != 'tag_slug')
                  .toList(growable: false);

              final slivers = <Widget>[];

              // ── Editorial hero ────────────────────────────────────
              // v18 prototype opens with a 16:10 full-bleed card built
              // from the top trending item. Pulls from the first
              // trending_favorites section; falls back to the first
              // popular section if trending is empty.
              final hero = _pickHero(sections);
              if (hero != null) {
                slivers.add(SliverToBoxAdapter(
                  child: _HeroCard(poster: hero),
                ));
              }

              // Skip re-rendering the poster we already promoted to the
              // hero so it doesn't appear twice in a row.
              final heroId = hero?.id;
              for (final s in sections) {
                if (s.isEmpty) continue;
                slivers.add(SliverToBoxAdapter(
                  child: _DynamicSectionRow(
                    section: s,
                    favIds: favIds,
                    skipPosterId: heroId,
                    skipUserId: myId,
                  ),
                ));
              }
              return slivers;
            },
          ),

          // Bottom padding.
          SliverToBoxAdapter(
            child: SizedBox(height: bottomInset + 80),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// v13 sticky glass top header for explore page
// ═══════════════════════════════════════════════════════════════════════════

class _HomeGlassHeaderBar extends StatelessWidget {
  const _HomeGlassHeaderBar({
    required this.topInset,
    required this.onMenuTap,
    required this.onSearchTap,
  });
  final double topInset;
  final VoidCallback onMenuTap;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      // v18 tweak: the top chrome is now a solid opaque strip. The
      // glass/blur read as haze when it crossed posters; a flat
      // scaffold-colour bar is cleaner and also lets us drop a
      // whole BackdropFilter from the tree.
      decoration: BoxDecoration(
        color: AppTheme.bg,
        border: Border(
          bottom: BorderSide(color: AppTheme.line1, width: 0.5),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, topInset + 4, 14, 4),
        child: Row(
          children: [
            // Hamburger — opens the IG-style drawer (收藏 / 為你推薦 /
            // 追蹤中). No bg circle per v18 spec.
            Semantics(
              label: '選單',
              button: true,
              child: GestureDetector(
                onTap: onMenuTap,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: TwoBarIcon(size: 22, color: AppTheme.text),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Semantics(
              label: '搜尋',
              button: true,
              child: GestureDetector(
                onTap: onSearchTap,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Icon(LucideIcons.search,
                        size: 22, color: AppTheme.text),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EPIC 14: _DynamicSectionRow — dispatches per sourceType
// ═══════════════════════════════════════════════════════════════════════════
//
// Each home section comes from DB config. sourceType tells us which card
// widget to render:
//   popular / tag_slug / recent_approved → _SectionRow (plain poster cards)
//   trending_favorites                   → _TrendingRow
//   active_collectors                    → _CollectorsRow
//   follow_feed                          → _FollowFeedRow

class _DynamicSectionRow extends StatelessWidget {
  const _DynamicSectionRow({
    required this.section,
    required this.favIds,
    this.skipPosterId,
    this.skipUserId,
  });
  final HomeSectionV2 section;
  final Set<String> favIds;

  /// If set, skip any poster with this ID (used to avoid duplicating
  /// the hero in the row below it).
  final String? skipPosterId;

  /// If set, skip any user with this ID — keeps the viewer out of
  /// "people to follow" lists, which are nonsensical when the user
  /// shows up as a recommendation for themselves.
  final String? skipUserId;

  @override
  Widget build(BuildContext context) {
    switch (section.sourceType) {
      case 'trending_favorites':
        // v19 round 4: cap at TOP 10 + override title. The DB
        // section can return more, but the visual rank list reads
        // as "top something" — anything past 10 is just clutter.
        final items = section
            .asTrending()
            .where((t) => t.poster.id != skipPosterId)
            .take(10)
            .toList(growable: false);
        return _TrendingRow(
          items: items,
          favIds: favIds,
          title: '本週 TOP 10',
          icon: _iconFromName(section.icon),
        );
      case 'active_collectors':
        // Override DB title (活躍收藏家) to the v18 friendlier
        // "推薦朋友" — the section now leads with a follow-toggle
        // pill, so framing it as "people you might want to follow"
        // reads truer than "who's been busy this week".
        // Filter the viewer out — recommending yourself is silly.
        final items = section
            .asCollectors()
            .where((c) => c.userId != skipUserId)
            .toList(growable: false);
        if (items.isEmpty) return const SizedBox.shrink();
        return _CollectorsRow(
          items: items,
          title: '推薦朋友',
          icon: _iconFromName(section.icon),
        );
      case 'follow_feed':
        return _FollowFeedRow(
          activities: section.asFollowFeed(),
          favIds: favIds,
          title: section.titleZh,
          icon: _iconFromName(section.icon),
        );
      case 'popular':
      case 'tag_slug':
      case 'recent_approved':
      case 'for_you':
      case 'for_you_cf':
        final items = section
            .asPosters()
            .where((p) => p.id != skipPosterId)
            .toList(growable: false);
        return _SectionRow(
          items: items,
          favIds: favIds,
          title: section.titleZh,
          icon: _iconFromName(section.icon),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Pick a poster to feature in the editorial hero. Prefers the first
/// trending_favorites item; falls back to the first popular / recent_approved.
Poster? _pickHero(List<HomeSectionV2> sections) {
  for (final s in sections) {
    if (s.sourceType == 'trending_favorites' && !s.isEmpty) {
      final t = s.asTrending();
      if (t.isNotEmpty) return t.first.poster;
    }
  }
  for (final s in sections) {
    if ((s.sourceType == 'popular' ||
            s.sourceType == 'recent_approved' ||
            s.sourceType == 'tag_slug') &&
        !s.isEmpty) {
      final p = s.asPosters();
      if (p.isNotEmpty) return p.first;
    }
  }
  return null;
}

// ─── Editorial hero card ────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.poster});
  final Poster poster;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: GestureDetector(
        onTap: () => context.push('/poster/${poster.id}'),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: poster.thumbnailUrl ?? poster.posterUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const ShimmerPlaceholder(),
                  errorWidget: (_, _, _) =>
                      ColoredBox(color: AppTheme.surfaceRaised),
                ),
                // Hero gradient — fades into AppTheme.bg at the hem
                // so the title overlay sits on solid dark. Stops are
                // soft top dim → transparent middle → opaque bg.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x1A121212),
                        Color(0x33121212),
                        Color(0xF2121212),
                      ],
                      stops: [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
                // 本週之選 pill
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '本週之選',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Title / meta
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (poster.tags.isNotEmpty)
                        AppText.label(
                          poster.tags.first.toUpperCase(),
                          color: Colors.white.withValues(alpha: 0.7),
                          weight: FontWeight.w500,
                        ),
                      const SizedBox(height: 4),
                      AppText.headline(
                        poster.title,
                        color: Colors.white,
                        weight: FontWeight.w700,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (poster.year != null || poster.director != null) ...[
                        const SizedBox(height: 4),
                        AppText.caption(
                          [
                            if (poster.year != null) '${poster.year}',
                            if (poster.director != null) poster.director!,
                          ].join(' · '),
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section row
// ---------------------------------------------------------------------------

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.items,
    required this.favIds,
    required this.title,
    required this.icon,
  });
  final List<Poster> items;
  final Set<String> favIds;
  final String title;
  // Legacy; home icons were per-section (trending / recent / etc).
  // Kept for call-site compatibility but no longer rendered — the
  // AppSectionHeader layout lets the title carry the whole eyebrow.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSectionHeader(title: title),
          const SizedBox(height: 12),
          // v18: horizontal-scroll only (density toggle removed).
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _FeedCard(
                poster: items[i],
                isFav: favIds.contains(items[i].id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Section skeleton
// ---------------------------------------------------------------------------

class _SectionSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: AppSkeleton(width: 80, height: 16, radius: 4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, _) => const AppSkeleton(width: 140),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feed card (Spotify style: image + meta below)
// ---------------------------------------------------------------------------

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.poster, required this.isFav});
  final Poster poster;
  final bool isFav;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/poster/${poster.id}'),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image + uploader avatar overlay.
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: poster.thumbnailUrl ?? poster.posterUrl,
                      fit: BoxFit.cover,
                      width: 140,
                      placeholder: (_, _) => const ShimmerPlaceholder(),
                      errorWidget: (_, _, _) =>
                          ColoredBox(color: AppTheme.surfaceRaised),
                    ),
                    // Uploader avatar overlay (bottom-right, 18px). Tappable
                    // to jump to their profile. Only shown when RPC returned
                    // uploader metadata (trending / recent_approved / etc.).
                    if (poster.uploaderName != null)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: _UploaderBadge(
                          name: poster.uploaderName!,
                          avatarUrl: poster.uploaderAvatar,
                          userId: poster.uploaderId,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Meta.
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText.bodyBold(
                          poster.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (poster.director != null) ...[
                          const SizedBox(height: 1),
                          AppText.small(
                            poster.director!,
                            tone: AppTextTone.faint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 1),
                    child: Icon(
                      LucideIcons.heart,
                      size: 14,
                      color: isFav
                          ? AppTheme.favoriteActive
                          : AppTheme.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar (same pattern as library)
// ---------------------------------------------------------------------------

// ignore: unused_element
class _Avatar extends StatelessWidget {
  // ignore: unused_element_parameter
  const _Avatar({required this.profile, this.size = 32});
  final AppUser? profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = profile?.avatarUrl;
    final name = profile?.displayName ?? '';
    final letter = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => _fallback(context, letter),
              )
            : _fallback(context, letter),
      ),
    );
  }

  Widget _fallback(BuildContext context, String letter) {
    return Container(
      color: AppTheme.chipBgStrong,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          fontFamily: 'InterDisplay',
          fontFamilyFallback: ['NotoSansTC'],
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Uploader badge — small avatar chip shown on poster cards in social feeds.
// Tappable to jump to the uploader's public profile.
// ---------------------------------------------------------------------------

class _UploaderBadge extends StatelessWidget {
  const _UploaderBadge({
    required this.name,
    required this.userId,
    this.avatarUrl,
  });

  final String name;
  final String userId;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return GestureDetector(
      // Stop tap from bubbling to the card's onTap (which would open /poster/...).
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/user/$userId'),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Subtle dark ring so the avatar stays legible over any poster.
          border: Border.all(color: Colors.black.withValues(alpha: 0.5), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipOval(
          child: avatarUrl != null && avatarUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: avatarUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => _fallback(context, letter),
                )
              : _fallback(context, letter),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context, String letter) {
    return Container(
      color: AppTheme.chipBgStrong,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          fontFamily: 'InterDisplay',
          fontFamilyFallback: ['NotoSansTC'],
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EPIC 11 widgets — trending / collectors / follow feed
// ═══════════════════════════════════════════════════════════════════════════

// ─── 本週最多人收藏 ─────────────────────────────────────────────────────────

class _TrendingRow extends StatelessWidget {
  const _TrendingRow({
    required this.items,
    required this.favIds,
    required this.title,
    required this.icon,
  });
  final List<TrendingPoster> items;
  final Set<String> favIds;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSectionHeader(title: title),
          const SizedBox(height: 12),
          SizedBox(
            // 90w poster × 2:3 = 135h, + label below
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) => _RankedCard(
                rank: i + 1,
                item: items[i],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// v18 prototype "RankedCard" — 260-wide horizontal row combining a
/// giant hollow rank numeral with a compact 90w / 2:3 poster and three
/// lines of meta (title · year · director + ♥ / views).
class _RankedCard extends StatelessWidget {
  const _RankedCard({required this.rank, required this.item});
  final int rank;
  final TrendingPoster item;

  @override
  Widget build(BuildContext context) {
    final p = item.poster;
    return GestureDetector(
      onTap: () => context.push('/poster/${p.id}'),
      child: SizedBox(
        width: 250,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Solid white rank numeral.
            SizedBox(
              width: 52,
              child: Text(
                rank.toString().padLeft(2, '0'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 44,
                  height: 0.9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: AppTheme.text,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Poster thumb.
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 86,
                height: 129,
                child: CachedNetworkImage(
                  imageUrl: p.thumbnailUrl ?? p.posterUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const ShimmerPlaceholder(),
                  errorWidget: (_, _, _) =>
                      ColoredBox(color: AppTheme.surfaceRaised),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Meta column.
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppText.bodyBold(
                    p.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  AppText.small(
                    [
                      if (p.year != null) '${p.year}',
                      if (p.director != null) p.director!,
                    ].join(' · '),
                    tone: AppTextTone.muted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  AppText.small('♥ ${item.recentFavCount}',
                      tone: AppTextTone.faint),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 活躍收藏家 ────────────────────────────────────────────────────────────

class _CollectorsRow extends StatelessWidget {
  const _CollectorsRow({
    required this.items,
    required this.title,
    required this.icon,
  });
  final List<CollectorPreview> items;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSectionHeader(title: title),
          const SizedBox(height: 12),
          SizedBox(
            // Taller row: avatar 68 + name + follow pill (compact) +
            // a bit of breathing room.
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) => _CollectorCard(collector: items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

/// v18 prototype collector card — compact circular avatar with a
/// conic-gradient ring, name + activity count below. Matches the
/// IG "story ring" pattern.
class _CollectorCard extends StatelessWidget {
  const _CollectorCard({required this.collector});
  final CollectorPreview collector;

  @override
  Widget build(BuildContext context) {
    final name = collector.displayName.isEmpty ? '無名使用者' : collector.displayName;
    final letter = name.characters.first.toUpperCase();
    return GestureDetector(
      onTap: () => context.push('/user/${collector.userId}'),
      child: SizedBox(
        width: 88,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Conic-gradient ring around the avatar. 2px band, 68px total.
            // Uses theme-aware tokens so day mode renders a visible ring
            // (earlier pure-white ring disappeared on the beige scaffold).
            Container(
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    AppTheme.text,
                    AppTheme.text.withValues(alpha: 0.6),
                    AppTheme.line2,
                    AppTheme.text,
                  ],
                  stops: const [0.0, 0.5, 0.8, 1.0],
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.bg,
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: (collector.avatarUrl != null &&
                          collector.avatarUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: collector.avatarUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) =>
                              _avatarFallback(context, letter),
                        )
                      : _avatarFallback(context, letter),
                ),
              ),
            ),
            const SizedBox(height: 8),
            AppText.small(
              name,
              weight: FontWeight.w600,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            // v18: activity count replaced by a direct follow toggle.
            // FollowPill handles "me / self-follow / already following"
            // internally; hides when viewing yourself.
            FollowPill(targetUserId: collector.userId, compact: true),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(BuildContext context, String letter) {
    return Container(
      color: AppTheme.chipBgStrong,
      alignment: Alignment.center,
      child: AppText.bodyBold(letter),
    );
  }
}

// ─── 追蹤的人最近在收 ──────────────────────────────────────────────────────

class _FollowFeedRow extends StatelessWidget {
  const _FollowFeedRow({
    required this.activities,
    required this.favIds,
    required this.title,
    required this.icon,
  });
  final List<FollowActivity> activities;
  final Set<String> favIds;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSectionHeader(title: title),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: activities.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final a = activities[i];
                // Reuse _FeedCard, but inject uploader metadata from the
                // ACTOR (the person we follow), not the original uploader.
                final posterWithActor = Poster(
                  id: a.poster.id,
                  title: a.poster.title,
                  posterUrl: a.poster.posterUrl,
                  uploaderId: a.actorId,
                  status: a.poster.status,
                  tags: a.poster.tags,
                  createdAt: a.poster.createdAt,
                  year: a.poster.year,
                  director: a.poster.director,
                  thumbnailUrl: a.poster.thumbnailUrl,
                  uploaderName: a.actorName,
                  uploaderAvatar: a.actorAvatar,
                );
                return _FeedCard(
                  poster: posterWithActor,
                  isFav: favIds.contains(a.poster.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
