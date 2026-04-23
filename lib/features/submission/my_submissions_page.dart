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
import '../../core/widgets/ds/ds.dart';
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
            child: const AppText.title('我的投稿', weight: FontWeight.w700),
          ),
          Expanded(
            child: async.when(
              loading: () => const AppLoader.centered(),
              error: (e, _) => AppEmptyState(title: '載入失敗：$e'),
              data: (items) {
                if (items.isEmpty) {
                  return AppEmptyState(
                    icon: LucideIcons.upload,
                    title: '還沒投稿過',
                    subtitle: '把你收藏中最特別的那一張寄出，讓更多人看到。',
                    actionLabel: '寄出第一張',
                    onAction: () {
                      HapticFeedback.selectionClick();
                      context.push('/upload');
                    },
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
                  AppText.bodyBold(
                    submission.workTitleZh,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (submission.movieReleaseYear != null) ...[
                    const SizedBox(height: 2),
                    AppText.caption(
                      '${submission.movieReleaseYear}  ${regionLabels[submission.region] ?? ''}',
                      tone: AppTextTone.muted,
                    ),
                  ],
                  const SizedBox(height: 6),
                  _StatusChip(status: submission.status),
                  if (submission.isRejected &&
                      submission.reviewNote != null) ...[
                    const SizedBox(height: 6),
                    AppText.caption(
                      '備註：${submission.reviewNote}',
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
      SubmissionStatus.approved =>
        ('已上架', AppTheme.success, Icons.check_circle),
      SubmissionStatus.rejected =>
        ('已退回', AppTheme.favoriteActive, Icons.cancel),
      SubmissionStatus.duplicate =>
        ('重複', AppTheme.danger, Icons.copy),
      SubmissionStatus.pending =>
        ('審核中', AppTheme.danger, Icons.hourglass_top),
    };
    return AppBadge(
      label: label,
      icon: icon,
      variant: AppBadgeVariant.accent,
      color: color,
    );
  }
}
