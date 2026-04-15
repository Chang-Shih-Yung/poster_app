import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/poster.dart';
import '../../data/repositories/poster_repository.dart';

final _posterByIdProvider =
    FutureProvider.family<Poster?, String>((ref, id) async {
  final repo = ref.watch(posterRepositoryProvider);
  final p = await repo.getById(id);
  if (p != null && p.status == 'approved') {
    unawaited(repo.incrementViewCount(id));
  }
  return p;
});

void unawaited(Future<void> f) {}

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

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.poster});
  final Poster poster;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: CachedNetworkImage(
              imageUrl: poster.posterUrl,
              fit: BoxFit.contain,
              placeholder: (_, _) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (_, _, _) => const Icon(Icons.broken_image),
            ),
          ),
          const SizedBox(height: 16),
          Text(poster.title,
              style: Theme.of(context).textTheme.headlineSmall),
          if (poster.year != null || poster.director != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (poster.year != null) '${poster.year}',
                if (poster.director != null) poster.director!,
              ].join(' · '),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (poster.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: poster.tags
                  .map((t) => Chip(label: Text(t)))
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 12),
          Text('瀏覽數：${poster.viewCount}',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
