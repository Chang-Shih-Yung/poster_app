import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/shimmer_placeholder.dart';
import '../../data/models/app_user.dart';
import '../../data/models/home_section.dart';
import '../../data/models/poster.dart';
import '../../data/models/social.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/favorite_repository.dart';
import '../../data/repositories/social_repository.dart';

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

/// Density modes for the 探索 (HomePage) feed.
///   M (medium): horizontal-scroll cards per section (default).
///   S (small):  each section becomes a vertical list of compact rows
///               with a 40×56 thumb + title + meta + heart.
enum HomeDensity { medium, small }

class HomeDensityNotifier extends Notifier<HomeDensity> {
  static const _prefsKey = 'home.density';
  @override
  HomeDensity build() {
    // Hydrate async — UI starts in M, switches when prefs load.
    SharedPreferences.getInstance().then((p) {
      final v = p.getString(_prefsKey);
      if (v == 'S') state = HomeDensity.small;
    });
    return HomeDensity.medium;
  }

  void toggle() {
    state = state == HomeDensity.medium
        ? HomeDensity.small
        : HomeDensity.medium;
    SharedPreferences.getInstance().then((p) =>
        p.setString(_prefsKey, state == HomeDensity.medium ? 'M' : 'S'));
  }
}

final homeDensityProvider =
    NotifierProvider<HomeDensityNotifier, HomeDensity>(
        HomeDensityNotifier.new);

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.asData?.value;
    final favIds = ref.watch(favoriteIdsProvider).asData?.value ?? {};
    final sectionsAsync = ref.watch(homeSectionsV2Provider);
    final density = ref.watch(homeDensityProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        slivers: [
          // v13 sticky glass top chrome.
          SliverPersistentHeader(
            pinned: true,
            delegate: _HomeGlassHeader(
              topInset: topInset,
              profile: profile,
              density: density,
              onProfileTap: () => context.push('/profile'),
              onSearchTap: () {
                HapticFeedback.selectionClick();
                context.push('/search');
              },
              onUploadTap: () {
                HapticFeedback.selectionClick();
                context.push('/upload');
              },
              onDensityToggle: () {
                HapticFeedback.selectionClick();
                ref.read(homeDensityProvider.notifier).toggle();
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
              final slivers = <Widget>[];
              for (final s in sections) {
                // Server already applied visibility gate. Empty items → hide.
                if (s.isEmpty) continue;
                slivers.add(SliverToBoxAdapter(
                  child: _DynamicSectionRow(
                    section: s,
                    favIds: favIds,
                    density: density,
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

class _HomeGlassHeader extends SliverPersistentHeaderDelegate {
  _HomeGlassHeader({
    required this.topInset,
    required this.profile,
    required this.density,
    required this.onProfileTap,
    required this.onSearchTap,
    required this.onUploadTap,
    required this.onDensityToggle,
  });
  final double topInset;
  final AppUser? profile;
  final HomeDensity density;
  final VoidCallback onProfileTap;
  final VoidCallback onSearchTap;
  final VoidCallback onUploadTap;
  final VoidCallback onDensityToggle;

  static const double _bar = 56;

  @override
  double get minExtent => topInset + _bar;
  @override
  double get maxExtent => topInset + _bar;

  @override
  Widget build(BuildContext ctx, double shrink, bool overlaps) {
    return SizedBox.expand(
      child: Glass(
        blur: 20,
        tint: 0.5,
        borderRadius: BorderRadius.zero,
        border: Border(bottom: BorderSide(color: AppTheme.line1, width: 0.5)),
        shadow: false,
        highlight: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, topInset + 8, 16, 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: onProfileTap,
                child: _Avatar(profile: profile, size: 32),
              ),
              const SizedBox(width: 12),
              Text(
                '探索',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
              ),
              const Spacer(),
              // v13: density toggle as a single circular GlassButton
              // that morphs between grid / list icons (iOS Photos-style
              // — shows current state, tap to flip). Uses
              // AnimatedSwitcher for a soft fade between icons.
              _DensityMorphButton(
                density: density,
                onTap: onDensityToggle,
              ),
              const SizedBox(width: 6),
              GlassButton(
                icon: LucideIcons.search,
                size: 34,
                color: Colors.white.withValues(alpha: 0.85),
                onTap: onSearchTap,
                semanticsLabel: '搜尋',
              ),
              const SizedBox(width: 6),
              GlassButton(
                icon: LucideIcons.plus,
                size: 34,
                color: Colors.white.withValues(alpha: 0.85),
                onTap: onUploadTap,
                semanticsLabel: '上傳',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_HomeGlassHeader old) =>
      old.topInset != topInset ||
      old.profile?.avatarUrl != profile?.avatarUrl ||
      old.density != density;
}

/// v13 density morph button — single circular GlassButton showing the
/// current density's icon (grid for M, list for S). Tap to flip.
/// AnimatedSwitcher fades between icons so the change feels native
/// instead of a hard swap. iOS Photos-style.
class _DensityMorphButton extends StatelessWidget {
  const _DensityMorphButton({required this.density, required this.onTap});
  final HomeDensity density;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = density == HomeDensity.medium
        ? LucideIcons.layoutGrid
        : LucideIcons.list;
    return Semantics(
      button: true,
      label: density == HomeDensity.medium ? '網格檢視' : '列表檢視',
      child: GestureDetector(
        onTap: onTap,
        child: Glass(
          blur: 18,
          tint: 0.5,
          borderRadius: BorderRadius.circular(999),
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Center(
              child: AnimatedSwitcher(
                duration: AppTheme.motionFast,
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: Icon(
                  icon,
                  key: ValueKey(density),
                  size: 17,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
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
    required this.density,
  });
  final HomeSectionV2 section;
  final Set<String> favIds;
  final HomeDensity density;

  @override
  Widget build(BuildContext context) {
    switch (section.sourceType) {
      case 'trending_favorites':
        return _TrendingRow(
          items: section.asTrending(),
          favIds: favIds,
          title: section.titleZh,
          icon: _iconFromName(section.icon),
        );
      case 'active_collectors':
        return _CollectorsRow(
          items: section.asCollectors(),
          title: section.titleZh,
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
        return _SectionRow(
          items: section.asPosters(),
          favIds: favIds,
          title: section.titleZh,
          icon: _iconFromName(section.icon),
          density: density,
        );
      default:
        return const SizedBox.shrink();
    }
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
    required this.density,
  });
  final List<Poster> items;
  final Set<String> favIds;
  final String title;
  final IconData icon;
  final HomeDensity density;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section header.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.textMute),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text,
                      ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // M = horizontal scroll of cards. S = vertical compact list.
          if (density == HomeDensity.medium)
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
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: items
                    .map((p) => _CompactRow(
                          poster: p,
                          isFav: favIds.contains(p.id),
                        ))
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact row for S mode — 40×56 thumb + title + meta + heart.
/// Renders one Poster as a horizontal row with subtle hairline divider.
class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.poster, required this.isFav});
  final Poster poster;
  final bool isFav;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push('/poster/${poster.id}'),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.line1)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
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
                  placeholder: (_, _) =>
                      const ColoredBox(color: AppTheme.surfaceRaised),
                  errorWidget: (_, _, _) =>
                      const ColoredBox(color: AppTheme.surfaceRaised),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    poster.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (poster.year != null) '${poster.year}',
                      if (poster.director != null) poster.director!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMute,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isFav)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.favorite, size: 14, color: Colors.white),
              ),
          ],
        ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: 80,
              height: 16,
              decoration: BoxDecoration(
                color: AppTheme.surfaceRaised,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, _) => Container(
                width: 140,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceRaised,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
    final theme = Theme.of(context);

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
                          const ColoredBox(color: AppTheme.surfaceRaised),
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
                        Text(
                          poster.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.text,
                          ),
                        ),
                        if (poster.director != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            poster.director!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.textFaint,
                            ),
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
                          ? const Color(0xFFE53935)
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

class _Avatar extends StatelessWidget {
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
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 10,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.textMute),
                const SizedBox(width: 6),
                Text(title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.text,
                        )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _TrendingCard(
                item: items[i],
                isFav: favIds.contains(items[i].poster.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  const _TrendingCard({required this.item, required this.isFav});
  final TrendingPoster item;
  final bool isFav;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = item.poster;
    return GestureDetector(
      onTap: () => context.push('/poster/${p.id}'),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: p.thumbnailUrl ?? p.posterUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const ShimmerPlaceholder(),
                      errorWidget: (_, _, _) =>
                          const ColoredBox(color: AppTheme.surfaceRaised),
                    ),
                    // Bottom-right: collector avatar stack + "+N 人收藏"
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: _AvatarStack(
                        users: item.collectors,
                        extraCount: item.recentFavCount - item.collectors.length,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.text,
                            )),
                        const SizedBox(height: 1),
                        Text(
                          '本週 ${item.recentFavCount} 次收藏',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 1),
                    child: Icon(
                      LucideIcons.heart,
                      size: 14,
                      color:
                          isFav ? const Color(0xFFE53935) : AppTheme.textFaint,
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

/// Small overlapping-avatar stack with a "+N" suffix when the total fav
/// count exceeds the 3 preview avatars. 20px avatars, -8px overlap.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.users, this.extraCount = 0});
  final List<MiniUser> users;
  final int extraCount;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const SizedBox.shrink();
    const size = 20.0;
    const overlap = 8.0;
    final totalWidth = (users.length - 1) * (size - overlap) + size;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: totalWidth,
            height: size,
            child: Stack(
              children: [
                for (var i = 0; i < users.length; i++)
                  Positioned(
                    left: i * (size - overlap),
                    child: _MiniAvatar(user: users[i], size: size),
                  ),
              ],
            ),
          ),
          if (extraCount > 0) ...[
            const SizedBox(width: 5),
            Text('+$extraCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ],
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.user, required this.size});
  final MiniUser user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter =
        user.name.isNotEmpty ? user.name.characters.first.toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: ClipOval(
        child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: user.avatarUrl!,
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
      child: Text(letter,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          )),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.textMute),
                const SizedBox(width: 6),
                Text(title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.text,
                        )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _CollectorCard(collector: items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectorCard extends StatelessWidget {
  const _CollectorCard({required this.collector});
  final CollectorPreview collector;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = collector.displayName.isEmpty ? '無名使用者' : collector.displayName;
    final letter = name.characters.first.toUpperCase();
    return GestureDetector(
      onTap: () => context.push('/user/${collector.userId}'),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceRaised,
          border: Border.all(color: AppTheme.line1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar.
            ClipOval(
              child: SizedBox(
                width: 48,
                height: 48,
                child: collector.avatarUrl != null &&
                        collector.avatarUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: collector.avatarUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            _avatarFallback(context, letter),
                      )
                    : _avatarFallback(context, letter),
              ),
            ),
            const SizedBox(height: 8),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.text,
                )),
            const SizedBox(height: 2),
            Text(
              '${collector.activityCount} 次活動',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: AppTheme.textFaint),
            ),
            const SizedBox(height: 10),
            // Mini thumb row — up to 3 recently-favorited poster thumbnails.
            SizedBox(
              height: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i < collector.recentPosters.length)
                      _MiniThumb(url: collector.recentPosters[i].displayUrl)
                    else
                      _MiniThumbEmpty(),
                    if (i < 2) const SizedBox(width: 4),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(BuildContext context, String letter) {
    return Container(
      color: AppTheme.chipBgStrong,
      alignment: Alignment.center,
      child: Text(letter,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

class _MiniThumb extends StatelessWidget {
  const _MiniThumb({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 32,
        height: 48,
        child: url.isEmpty
            ? Container(color: AppTheme.chipBg)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => const ShimmerPlaceholder(),
                errorWidget: (_, _, _) => Container(color: AppTheme.chipBg),
              ),
      ),
    );
  }
}

class _MiniThumbEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.chipBg,
        borderRadius: BorderRadius.circular(4),
      ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.textMute),
                const SizedBox(width: 6),
                Text(title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.text,
                        )),
              ],
            ),
          ),
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
