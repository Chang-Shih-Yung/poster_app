import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/favorite_repository.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Center(child: Text('請先到「我的」tab 登入'));
    }

    final async = ref.watch(favoritesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('載入失敗：$e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('還沒有收藏任何海報'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(favoritesProvider),
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.66,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final f = items[i];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.push('/poster/${f.posterId}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: f.thumbnailUrl == null
                            ? const ColoredBox(color: Colors.black12)
                            : CachedNetworkImage(
                                imageUrl: f.thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) =>
                                    const ColoredBox(color: Colors.black12),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          f.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
