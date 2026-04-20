import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/tag.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/repositories/tag_suggestion_repository.dart';

/// /admin/tag-suggestions — review queue for user-submitted tag suggestions.
/// Three actions per row: approve / merge into existing / reject.
/// Low-frequency operations (edit existing tag, deprecate) intentionally
/// not built — use Supabase Studio.
class AdminTagSuggestionsPage extends ConsumerWidget {
  const AdminTagSuggestionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingTagSuggestionsProvider);
    final catsAsync = ref.watch(tagCategoriesProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Tag 建議審核'),
        backgroundColor: AppTheme.bg,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(pendingTagSuggestionsProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) =>
            Center(child: Text('載入失敗：$e', style: TextStyle(color: AppTheme.textMute))),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('目前沒有待審核的 tag 建議。',
                    style: TextStyle(color: AppTheme.textMute)),
              ),
            );
          }
          final cats = catsAsync.asData?.value ?? const <TagCategory>[];
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) =>
                _SuggestionCard(suggestion: items[i], categories: cats),
          );
        },
      ),
    );
  }
}

class _SuggestionCard extends ConsumerStatefulWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.categories,
  });
  final TagSuggestion suggestion;
  final List<TagCategory> categories;

  @override
  ConsumerState<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends ConsumerState<_SuggestionCard> {
  bool _busy = false;

  TagCategory? get _category {
    for (final c in widget.categories) {
      if (c.id == widget.suggestion.categoryId) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.suggestion;
    final cat = _category;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        border: Border.all(color: AppTheme.line1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category + time.
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.chipBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  cat?.titleZh ?? '未知類別',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: AppTheme.textMute),
                ),
              ),
              const Spacer(),
              Text(
                _relativeTime(s.createdAt),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: AppTheme.textFaint),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Labels.
          Text(s.suggestedLabelZh,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          if (s.suggestedLabelEn != null &&
              s.suggestedLabelEn != s.suggestedLabelZh)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(s.suggestedLabelEn!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppTheme.textMute)),
            ),
          if (s.reason != null && s.reason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                s.reason!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppTheme.textMute),
              ),
            ),
          ],
          if (s.linkedSubmissionId != null) ...[
            const SizedBox(height: 8),
            Text(
              '來自 submission: ${s.linkedSubmissionId!.substring(0, 8)}…',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: AppTheme.textFaint),
            ),
          ],

          const SizedBox(height: 14),

          // Actions.
          Row(
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _approve,
                icon: const Icon(LucideIcons.check, size: 14),
                label: const Text('批准（建 tag）'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _merge,
                icon: const Icon(LucideIcons.gitMerge, size: 14),
                label: const Text('合併到既有'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _reject,
                icon: const Icon(LucideIcons.x, size: 14),
                label: const Text('退回'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '剛剛';
    if (d.inHours < 1) return '${d.inMinutes} 分鐘前';
    if (d.inDays < 1) return '${d.inHours} 小時前';
    return '${d.inDays} 天前';
  }

  Future<void> _approve() async {
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      await ref
          .read(tagSuggestionRepositoryProvider)
          .approve(widget.suggestion.id);
      if (!mounted) return;
      _toast('已批准，canonical tag 建立');
      ref.invalidate(pendingTagSuggestionsProvider);
      ref.invalidate(tagCategoriesProvider);
    } catch (e) {
      _toast('批准失敗：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('退回原因（選填）'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: '讓使用者知道為什麼不批准'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('退回'),
            ),
          ],
        );
      },
    );
    if (note == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(tagSuggestionRepositoryProvider).reject(
            widget.suggestion.id,
            note: note.isEmpty ? null : note,
          );
      if (!mounted) return;
      _toast('已退回');
      ref.invalidate(pendingTagSuggestionsProvider);
    } catch (e) {
      _toast('退回失敗：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _merge() async {
    final cat = _category;
    if (cat == null) {
      _toast('找不到對應的 category');
      return;
    }
    final target = await showDialog<Tag>(
      context: context,
      builder: (_) => _MergePicker(categoryId: cat.id),
    );
    if (target == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(tagSuggestionRepositoryProvider).merge(
            suggestionId: widget.suggestion.id,
            targetTagId: target.id,
          );
      if (!mounted) return;
      _toast('已合併到「${target.labelZh}」並加為別名');
      ref.invalidate(pendingTagSuggestionsProvider);
      ref.invalidate(tagCategoriesProvider);
    } catch (e) {
      _toast('合併失敗：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// Dialog picker: search existing tags within a category to merge into.
class _MergePicker extends ConsumerStatefulWidget {
  const _MergePicker({required this.categoryId});
  final String categoryId;

  @override
  ConsumerState<_MergePicker> createState() => _MergePickerState();
}

class _MergePickerState extends ConsumerState<_MergePicker> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsByCategoryProvider(widget.categoryId));
    return AlertDialog(
      title: const Text('合併到哪個既有 tag？'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: '搜尋既有 tag…'),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: tagsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Text('載入失敗：$e'),
                data: (tags) {
                  final filtered = _query.isEmpty
                      ? tags.where((t) => !t.isOtherFallback).toList()
                      : tags.where((t) {
                          if (t.isOtherFallback) return false;
                          if (t.labelZh.toLowerCase().contains(_query)) {
                            return true;
                          }
                          if (t.labelEn.toLowerCase().contains(_query)) {
                            return true;
                          }
                          return t.aliases
                              .any((a) => a.toLowerCase().contains(_query));
                        }).toList();
                  if (filtered.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('沒有符合的 tag'),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final t = filtered[i];
                      return ListTile(
                        dense: true,
                        title: Text(t.labelZh),
                        subtitle: Text(
                          [t.labelEn, '${t.posterCount} 張'].join(' · '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () => Navigator.pop(context, t),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
