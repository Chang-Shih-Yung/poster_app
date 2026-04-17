import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/shimmer_placeholder.dart';
import '../../data/models/app_user.dart';
import '../../data/models/poster.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/favorite_repository.dart';
import '../../data/repositories/poster_repository.dart';

// ---------------------------------------------------------------------------
// Section display config
// ---------------------------------------------------------------------------

/// Map RPC section keys → display title + icon.
const _sectionMeta = <String, ({String title, IconData icon})>{
  'popular': (title: '熱門', icon: LucideIcons.flame),
  'latest': (title: '最新上架', icon: LucideIcons.sparkles),
  'social': (title: '社群動態', icon: LucideIcons.users),
  // Tag-based sections: unknown keys get a default icon.
};

IconData _iconForKey(String key) =>
    _sectionMeta[key]?.icon ?? LucideIcons.tag;

String _titleForKey(String key) =>
    _sectionMeta[key]?.title ?? key;

// ---------------------------------------------------------------------------
// Home sections provider — single RPC (review #10)
// ---------------------------------------------------------------------------

final _homeSectionsProvider =
    FutureProvider<List<HomeSection>>((ref) async {
  final repo = ref.watch(posterRepositoryProvider);
  return repo.homeSections(limit: 10);
});

/// Social activity feed: separate RPC so it can refresh independently.
final _socialFeedProvider =
    FutureProvider<HomeSection>((ref) async {
  final repo = ref.watch(posterRepositoryProvider);
  final items = await repo.socialActivityFeed(limit: 12);
  return HomeSection(key: 'social', items: items);
});

// ---------------------------------------------------------------------------
// HomePage
// ---------------------------------------------------------------------------

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.asData?.value;
    final favIds = ref.watch(favoriteIdsProvider).asData?.value ?? {};
    final sectionsAsync = ref.watch(_homeSectionsProvider);
    final socialAsync = ref.watch(_socialFeedProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        slivers: [
          // Top bar.
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: _Avatar(profile: profile, size: 32),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '探索',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.push('/search');
                    },
                    child: Icon(LucideIcons.search,
                        size: 22, color: AppTheme.textMute),
                  ),
                ],
              ),
            ),
          ),

          // Sections from single RPC.
          ...sectionsAsync.when(
            loading: () => [
              // Show skeleton for first 3 sections.
              for (int i = 0; i < 3; i++)
                SliverToBoxAdapter(child: _SectionSkeleton()),
            ],
            error: (e, _) => [
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('載入失敗：$e',
                        style: TextStyle(color: AppTheme.textFaint)),
                  ),
                ),
              ),
            ],
            data: (sections) => sections
                .where((s) => s.items.isNotEmpty)
                .map((section) => SliverToBoxAdapter(
                      child: _SectionRow(
                        section: section,
                        favIds: favIds,
                      ),
                    ))
                .toList(),
          ),

          // Social activity feed.
          socialAsync.maybeWhen(
            data: (section) => section.items.isEmpty
                ? const SliverToBoxAdapter(child: SizedBox.shrink())
                : SliverToBoxAdapter(
                    child: _SectionRow(section: section, favIds: favIds),
                  ),
            orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
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

// ---------------------------------------------------------------------------
// Section row
// ---------------------------------------------------------------------------

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.section, required this.favIds});
  final HomeSection section;
  final Set<String> favIds;

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
                Icon(_iconForKey(section.key),
                    size: 16, color: AppTheme.textMute),
                const SizedBox(width: 6),
                Text(
                  _titleForKey(section.key),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text,
                      ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Horizontal scroll.
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: section.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _FeedCard(
                poster: section.items[i],
                isFav: favIds.contains(section.items[i].id),
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
            // Image.
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: poster.thumbnailUrl ?? poster.posterUrl,
                  fit: BoxFit.cover,
                  width: 140,
                  placeholder: (_, _) => const ShimmerPlaceholder(),
                  errorWidget: (_, _, _) =>
                      const ColoredBox(color: AppTheme.surfaceRaised),
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
