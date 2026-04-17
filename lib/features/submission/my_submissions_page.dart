import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../core/constants/region_labels.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/submission.dart';
import '../../data/repositories/submission_repository.dart';

class MySubmissionsPage extends ConsumerWidget {
  const MySubmissionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mySubmissionsV2Provider);
    return Scaffold(
      appBar: AppBar(title: const Text('我的投稿')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('載入失敗：$e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('你還沒投稿過海報。'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(mySubmissionsV2Provider),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _SubmissionTile(submission: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  const _SubmissionTile({required this.submission});
  final Submission submission;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: CachedNetworkImage(
                imageUrl: submission.thumbnailUrl ?? submission.imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) =>
                    const ColoredBox(color: Colors.black12),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    submission.workTitleZh,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (submission.movieReleaseYear != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${submission.movieReleaseYear}  ${regionLabels[submission.region] ?? ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMute,
                          ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  _StatusChip(status: submission.status),
                  if (submission.isRejected &&
                      submission.reviewNote != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '備註：${submission.reviewNote}',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final SubmissionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      SubmissionStatus.approved => ('已上架', Colors.green, Icons.check_circle),
      SubmissionStatus.rejected => ('已退回', Colors.red, Icons.cancel),
      SubmissionStatus.duplicate => ('重複', Colors.orange, Icons.copy),
      SubmissionStatus.pending => ('審核中', Colors.orange, Icons.hourglass_top),
    };
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
