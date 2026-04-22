import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/enums.dart';
import '../../core/constants/region_labels.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_loader.dart';
import '../../data/models/submission.dart';
import '../../data/repositories/submission_repository.dart';

class MySubmissionsPage extends ConsumerWidget {
  const MySubmissionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mySubmissionsV2Provider);
    final topInset = MediaQuery.paddingOf(context).top;
    // No AppBar — the enclosing `_BackablePage` already provides a
    // floating chevron-left. A second Material AppBar was surfacing a
    // duplicate back button. Render a minimal inline title row instead.
    return Padding(
      padding: EdgeInsets.only(top: topInset + 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 6, 20, 12),
            child: Text(
              '我的投稿',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const AppLoader.centered(),
              error: (e, _) => Center(child: Text('載入失敗：$e')),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.upload,
                              size: 36, color: AppTheme.textFaint),
                          const SizedBox(height: 12),
                          Text(
                            '還沒投稿過',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '把你收藏中最特別的那一張寄出，讓更多人看到。',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.textMute),
                          ),
                          const SizedBox(height: 18),
                          Material(
                            color: AppTheme.text,
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                context.push('/upload');
                              },
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 22, vertical: 10),
                                child: Text(
                                  '寄出第一張',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        color: AppTheme.bg,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        letterSpacing: 0,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(mySubmissionsV2Provider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) =>
                        _SubmissionTile(submission: items[i]),
                  ),
                );
              },
            ),
          ),
        ],
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
