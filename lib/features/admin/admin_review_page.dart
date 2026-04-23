import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/region_labels.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/ds/ds.dart';
import '../../data/models/submission.dart';
import '../../data/models/work.dart';
import '../../data/repositories/submission_repository.dart';
import '../../data/repositories/work_repository.dart';

class AdminReviewPage extends ConsumerWidget {
  const AdminReviewPage({super.key});

  /// Group submissions by batchId. Items without batchId are standalone.
  List<_ReviewGroup> _groupByBatch(List<Submission> items) {
    final Map<String, List<Submission>> batched = {};
    final List<Submission> standalone = [];

    for (final s in items) {
      if (s.batchId != null) {
        batched.putIfAbsent(s.batchId!, () => []).add(s);
      } else {
        standalone.add(s);
      }
    }

    final groups = <_ReviewGroup>[];
    for (final entry in batched.entries) {
      groups.add(_ReviewGroup(
        batchId: entry.key,
        items: entry.value,
      ));
    }
    for (final s in standalone) {
      groups.add(_ReviewGroup(batchId: null, items: [s]));
    }

    // Sort by earliest created_at in group.
    groups.sort((a, b) =>
        a.items.first.createdAt.compareTo(b.items.first.createdAt));
    return groups;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingSubmissionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin 審核'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(pendingSubmissionsProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const AppLoader.centered(),
        error: (e, _) => Center(child: Text('載入失敗：$e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('目前沒有待審核的投稿。'));
          }
          final groups = _groupByBatch(items);
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: groups.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final g = groups[i];
              if (g.isBatch) {
                return _BatchGroup(group: g);
              }
              return _PendingCard(submission: g.items.first);
            },
          );
        },
      ),
    );
  }
}

/// A group of submissions, either a batch or a single item.
class _ReviewGroup {
  const _ReviewGroup({this.batchId, required this.items});
  final String? batchId;
  final List<Submission> items;

  bool get isBatch => batchId != null && items.length > 1;
}

/// Visual group for batched submissions.
class _BatchGroup extends StatelessWidget {
  const _BatchGroup({required this.group});
  final _ReviewGroup group;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Batch header.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.chipBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.layers, size: 16, color: AppTheme.textMute),
                const SizedBox(width: 6),
                AppText.body(
                  '批次投稿（${group.items.length} 張）',
                  tone: AppTextTone.muted,
                ),
              ],
            ),
          ),
          ...group.items.map((s) => _PendingCard(submission: s)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pending card with approve / reject
// ---------------------------------------------------------------------------

/// Provider that checks for duplicate posters matching a submission's title+year.
final _duplicateCountProvider =
    FutureProvider.autoDispose.family<int, ({String titleZh, int? year})>(
  (ref, args) async {
    final repo = ref.watch(submissionRepositoryProvider);
    return repo.checkDuplicate(titleZh: args.titleZh, year: args.year);
  },
);

class _PendingCard extends ConsumerStatefulWidget {
  const _PendingCard({required this.submission});
  final Submission submission;

  @override
  ConsumerState<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends ConsumerState<_PendingCard> {
  bool _busy = false;

  // ── Approve flow ─────────────────────────────────────────────────────────

  Future<void> _approve() async {
    // Show work-matching dialog before approving.
    final workId = await _showWorkMatchDialog();
    // null means user cancelled the dialog.
    if (workId == null && !mounted) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(submissionRepositoryProvider);
      await repo.approve(
        widget.submission.id,
        workId: workId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已核准')),
      );
      ref.invalidate(pendingSubmissionsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('失敗：$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Work-matching dialog: search for existing works, or skip (creates new).
  /// Returns a workId string, empty string to skip, or null if cancelled.
  Future<String?> _showWorkMatchDialog() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _WorkMatchDialog(
        titleZh: widget.submission.workTitleZh,
        year: widget.submission.movieReleaseYear,
      ),
    );
  }

  // ── Reject flow ──────────────────────────────────────────────────────────

  Future<void> _reject() async {
    final note = await _askNote();
    if (note == null) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(submissionRepositoryProvider);
      await repo.reject(widget.submission.id, note: note.isEmpty ? null : note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已退件')),
      );
      ref.invalidate(pendingSubmissionsProvider);
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
          AppButton.text(
            label: '取消',
            onPressed: () => Navigator.pop(ctx),
          ),
          AppButton.primary(
            label: '退件',
            destructive: true,
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;
    final regionText = regionLabels[s.region] ?? s.region.value;

    // Duplicate detection.
    final dupAsync = ref.watch(_duplicateCountProvider(
      (titleZh: s.workTitleZh, year: s.movieReleaseYear),
    ));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Duplicate warning banner.
          dupAsync.whenOrNull(
                data: (count) => count > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        color: Colors.amber.withValues(alpha: 0.15),
                        child: Row(
                          children: [
                            Icon(LucideIcons.triangleAlert,
                                size: 14, color: Colors.amber),
                            const SizedBox(width: 6),
                            AppText.small(
                              '疑似重複：已有 $count 張同名海報',
                              color: Colors.amber,
                            ),
                          ],
                        ),
                      )
                    : null,
              ) ??
              const SizedBox.shrink(),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail.
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 80,
                    height: 120,
                    child: CachedNetworkImage(
                      imageUrl: s.thumbnailUrl ?? s.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) =>
                          const Icon(Icons.broken_image),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title.
                      AppText.title(s.workTitleZh),
                      if (s.workTitleEn != null)
                        AppText.caption(s.workTitleEn!,
                            tone: AppTextTone.muted),

                      // Meta line: year + region.
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: AppText.caption(
                          [
                            if (s.movieReleaseYear != null)
                              '${s.movieReleaseYear}',
                            regionText,
                            if (s.posterName != null) s.posterName!,
                          ].join(' · '),
                        ),
                      ),

                      // V2 detail chips.
                      if (s.posterReleaseType != null ||
                          s.sizeType != null ||
                          s.channelCategory != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              if (s.posterReleaseType != null)
                                _MiniChip(
                                    label: releaseTypeLabels[
                                            s.posterReleaseType] ??
                                        ''),
                              if (s.sizeType != null)
                                _MiniChip(
                                    label:
                                        sizeTypeLabels[s.sizeType] ?? ''),
                              if (s.channelCategory != null)
                                _MiniChip(
                                    label: channelCategoryLabels[
                                            s.channelCategory] ??
                                        ''),
                              if (s.isExclusive)
                                _MiniChip(
                                    label:
                                        '獨家${s.exclusiveName != null ? "：${s.exclusiveName}" : ""}'),
                            ],
                          ),
                        ),

                      const SizedBox(height: 10),

                      // Action buttons.
                      Row(
                        children: [
                          AppButton.primary(
                            label: '核准',
                            icon: Icons.check,
                            size: AppButtonSize.small,
                            onPressed: _busy ? null : _approve,
                          ),
                          const SizedBox(width: 8),
                          AppButton.outline(
                            label: '退件',
                            icon: Icons.close,
                            size: AppButtonSize.small,
                            destructive: true,
                            onPressed: _busy ? null : _reject,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.chipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: AppText.small(label, tone: AppTextTone.muted),
    );
  }
}

// ---------------------------------------------------------------------------
// Work matching dialog
// ---------------------------------------------------------------------------

class _WorkMatchDialog extends ConsumerStatefulWidget {
  const _WorkMatchDialog({required this.titleZh, this.year});
  final String titleZh;
  final int? year;

  @override
  ConsumerState<_WorkMatchDialog> createState() => _WorkMatchDialogState();
}

class _WorkMatchDialogState extends ConsumerState<_WorkMatchDialog> {
  final _searchController = TextEditingController();
  List<Work>? _results;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.titleZh;
    // Auto-search on open.
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _searching = true);
    try {
      final repo = ref.read(workRepositoryProvider);
      final works = await repo.search(titleZh: query, year: widget.year);
      if (mounted) setState(() => _results = works);
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    return AlertDialog(
      title: const Text('配對作品'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search field.
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '搜尋作品名稱…',
                suffixIcon: IconButton(
                  icon: const Icon(LucideIcons.search, size: 18),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 12),

            // Results.
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(16),
                child: AppLoader(),
              )
            else if (_results != null && _results!.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: AppText.caption('找不到符合的作品',
                    tone: AppTextTone.muted),
              )
            else if (_results != null)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results!.length,
                  itemBuilder: (_, i) {
                    final w = _results![i];
                    return ListTile(
                      dense: true,
                      title: Text(w.displayTitle),
                      subtitle: AppText.caption(
                        [
                          if (w.movieReleaseYear != null)
                            '${w.movieReleaseYear}',
                          '${w.posterCount} 張海報',
                        ].join(' · '),
                      ),
                      trailing:
                          const Icon(LucideIcons.chevronRight, size: 16),
                      onTap: () => Navigator.pop(context, w.id),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        AppButton.text(
          label: '取消',
          onPressed: () => Navigator.pop(context),
        ),
        AppButton.outline(
          label: '跳過（建立新作品）',
          onPressed: () => Navigator.pop(context, ''),
        ),
      ],
    );
  }
}
