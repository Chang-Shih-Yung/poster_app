import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/poster.dart';
import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/favorite_repository.dart';
import '../../data/repositories/poster_repository.dart';

/// Provider that fetches the user's favorited posters (full Poster objects).
final myFavoritePostersProvider =
    FutureProvider.autoDispose<List<Poster>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final page = await ref.watch(posterRepositoryProvider).listApproved(
        filter: PosterFilter(favoritesOf: user.id),
      );
  return page.items;
});

class MyFavoritesPage extends ConsumerWidget {
  const MyFavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myFavoritePostersProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('載入失敗：$e',
            style: TextStyle(color: AppTheme.textMute)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.heart, size: 48, color: AppTheme.textFaint),
                const SizedBox(height: 12),
                Text(
                  '還沒有收藏',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppTheme.textMute),
                ),
                const SizedBox(height: 4),
                Text(
                  '在圖庫中按愛心收藏海報',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.textFaint),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          color: AppTheme.text,
          backgroundColor: AppTheme.surfaceRaised,
          onRefresh: () async {
            ref.invalidate(myFavoritePostersProvider);
            ref.invalidate(favoriteIdsProvider);
          },
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 80, 16, 40),
            // Responsive cell width — 2 cols on phone, more on wide viewports.
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 2 / 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => _FavCard(poster: items[i]),
          ),
        );
      },
    );
  }
}

class _FavCard extends StatelessWidget {
  const _FavCard({required this.poster});
  final Poster poster;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/poster/${poster.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: poster.thumbnailUrl ?? poster.posterUrl,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) =>
                  Container(color: AppTheme.surfaceRaised),
            ),
            // Bottom gradient + title.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
                child: Text(
                  poster.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
