import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/poster.dart';
import '../../data/providers/supabase_providers.dart';

final _pendingPostersProvider = FutureProvider<List<Poster>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('posters')
      .select()
      .eq('status', 'pending')
      .isFilter('deleted_at', null)
      .order('created_at', ascending: false);
  return (rows as List)
      .map((r) => Poster.fromRow(r as Map<String, dynamic>))
      .toList();
});

class AdminReviewPage extends ConsumerWidget {
  const AdminReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_pendingPostersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin 審核'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_pendingPostersProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('載入失敗：$e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('目前沒有待審核的海報。'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _PendingCard(poster: items[i]),
          );
        },
      ),
    );
  }
}

class _PendingCard extends ConsumerStatefulWidget {
  const _PendingCard({required this.poster});
  final Poster poster;

  @override
  ConsumerState<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends ConsumerState<_PendingCard> {
  bool _busy = false;

  Future<void> _review(String status) async {
    String? note;
    if (status == 'rejected') {
      note = await _askNote();
      if (note == null) return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(supabaseClientProvider).rpc('review_poster', params: {
        'poster_id': widget.poster.id,
        'new_status': status,
        'note': note,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'approved' ? '已核准' : '已退件'),
        ),
      );
      ref.invalidate(_pendingPostersProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('失敗：$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askNote() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退件原因'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例如：圖片模糊、重複投稿'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('退件'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.poster;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              height: 120,
              child: CachedNetworkImage(
                imageUrl: p.thumbnailUrl ?? p.posterUrl,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const Icon(Icons.broken_image),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  if (p.year != null || p.director != null)
                    Text(
                      [
                        if (p.year != null) '${p.year}',
                        if (p.director != null) p.director!,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (p.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: p.tags
                            .map((t) => Chip(
                                  label: Text(t, style: const TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ))
                            .toList(growable: false),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('核准'),
                        onPressed: _busy ? null : () => _review('approved'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('退件'),
                        onPressed: _busy ? null : () => _review('rejected'),
                      ),
                    ],
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
