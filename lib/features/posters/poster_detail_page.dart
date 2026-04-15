import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/poster.dart';
import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/favorite_repository.dart';
import '../../data/repositories/poster_repository.dart';

final _posterByIdProvider =
    FutureProvider.family<Poster?, String>((ref, id) async {
  final repo = ref.watch(posterRepositoryProvider);
  final p = await repo.getById(id);
  if (p != null && p.status == 'approved') {
    // Fire and forget — view count is non-critical.
    repo.incrementViewCount(id);
  }
  return p;
});

class PosterDetailPage extends ConsumerWidget {
  const PosterDetailPage({super.key, required this.posterId});
  final String posterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_posterByIdProvider(posterId));
    return Scaffold(
      appBar: AppBar(title: const Text('海報')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('載入失敗：$e')),
        data: (p) {
          if (p == null) {
            return const Center(child: Text('找不到這張海報'));
          }
          return _DetailBody(poster: p);
        },
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.poster});
  final Poster poster;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final favIdsAsync = ref.watch(favoriteIdsProvider);
    final favIds = favIdsAsync.asData?.value;
    final isFav = favIds?.contains(poster.id) ?? false;
    final favIdsReady = favIds != null;

    Future<void> toggleFav() async {
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請先到「我的」tab 登入')),
        );
        return;
      }
      final repo = ref.read(favoriteRepositoryProvider);
      try {
        if (isFav) {
          await repo.remove(user.id, poster.id);
        } else {
          await repo.add(user.id, poster);
        }
        ref.invalidate(favoriteIdsProvider);
        ref.invalidate(favoritesProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('失敗：$e')));
        }
      }
    }

    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: CachedNetworkImage(
                imageUrl: poster.posterUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => ColoredBox(
                  color: theme.colorScheme.surfaceContainerHigh,
                ),
                errorWidget: (_, _, _) => ColoredBox(
                  color: theme.colorScheme.surfaceContainerHigh,
                  child: const Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  poster.title,
                  style: theme.textTheme.displaySmall?.copyWith(height: 1.1),
                ),
              ),
              const SizedBox(width: 8),
              _FavButton(
                ready: favIdsReady,
                isFav: isFav,
                onTap: favIdsReady ? toggleFav : null,
              ),
            ],
          ),
          if (poster.year != null || poster.director != null) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (poster.year != null) '${poster.year}',
                if (poster.director != null) poster.director!,
              ].join('   ·   '),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
          ],
          if (poster.tags.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: poster.tags
                  .map((t) => Chip(label: Text(t)))
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.visibility_outlined,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                '${poster.viewCount} 次瀏覽',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FavButton extends StatelessWidget {
  const _FavButton({
    required this.ready,
    required this.isFav,
    required this.onTap,
  });
  final bool ready;
  final bool isFav;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: isFav
          ? scheme.primary.withValues(alpha: 0.18)
          : scheme.surfaceContainerHigh,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ready
              ? Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? scheme.primary : scheme.onSurfaceVariant,
                  size: 24,
                )
              : SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
        ),
      ),
    );
  }
}
