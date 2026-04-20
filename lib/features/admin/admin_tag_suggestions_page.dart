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
        title: const Text('分類建議審核'),
        backgroundColor: AppTheme.bg,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.list),
            tooltip: '分類一覽',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const _TaxonomyOverviewDialog(),
            ),
          ),
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
                child: Text('目前沒有待審核的建議。',
                    style: TextStyle(color: AppTheme.textMute)),
              ),
            );
          }
          final cats = catsAsync.asData?.value ?? const <TagCategory>[];
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length + 1, // +1 for intro card
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              if (i == 0) return const _IntroCard();
              return _SuggestionCard(
                  suggestion: items[i - 1], categories: cats);
            },
          );
        },
      ),
    );
  }
}

/// Intro card: explains the 3 action buttons to non-technical reviewers.
/// Collapsed by default so it doesn't take too much screen real estate.
class _IntroCard extends StatefulWidget {
  const _IntroCard();
  @override
  State<_IntroCard> createState() => _IntroCardState();
}

class _IntroCardState extends State<_IntroCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.chipBg,
        border: Border.all(color: AppTheme.line1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Icon(LucideIcons.lightbulb, size: 16, color: AppTheme.textMute),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '怎麼決定按哪個按鈕？',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                    ),
                  ),
                ),
                Icon(
                  _expanded
                      ? LucideIcons.chevronUp
                      : LucideIcons.chevronDown,
                  size: 16,
                  color: AppTheme.textMute,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 10),
            _IntroLine(
              icon: LucideIcons.check,
              title: '建立新分類',
              detail: '這個建議真的是新的分類，站上目前沒有類似的。直接加入官方分類庫。',
            ),
            const SizedBox(height: 8),
            _IntroLine(
              icon: LucideIcons.gitMerge,
              title: '合併到既有分類',
              detail: '使用者建議的意思我們已經有對應分類了（例如他寫「Miyazaki」但我們已經有「宮崎駿」）。把這個寫法加進既有分類的「別名」，以後別人搜尋也找得到。',
            ),
            const SizedBox(height: 8),
            _IntroLine(
              icon: LucideIcons.x,
              title: '退回此建議',
              detail: '建議不合適（亂填、廣告、沒意義、放錯類別）。可以寫退回原因給使用者。',
            ),
          ],
        ],
      ),
    );
  }
}

class _IntroLine extends StatelessWidget {
  const _IntroLine({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: AppTheme.textMute),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textMute,
                height: 1.45,
              ),
              children: [
                TextSpan(
                  text: title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.text,
                  ),
                ),
                const TextSpan(text: ' — '),
                TextSpan(text: detail),
              ],
            ),
          ),
        ),
      ],
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
          // Category chip (clickable to change) + time.
          Row(
            children: [
              InkWell(
                onTap: _busy ? null : _changeCategory,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.chipBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.line1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cat?.titleZh ?? '未知類別',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: AppTheme.textMute),
                      ),
                      const SizedBox(width: 4),
                      Icon(LucideIcons.chevronDown,
                          size: 10, color: AppTheme.textFaint),
                    ],
                  ),
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

          // ─── Similarity hint: "看起來這可能已經存在" ─────────────────────
          _SimilarityHint(
            categoryId: s.categoryId,
            label: s.suggestedLabelZh,
            busy: _busy,
            onMergeToExisting: (tagId, labelZh) async {
              // One-click merge into the surfaced match.
              setState(() => _busy = true);
              try {
                await ref.read(tagSuggestionRepositoryProvider).merge(
                      suggestionId: s.id,
                      targetTagId: tagId,
                    );
                if (!mounted) return;
                _toast('已合併到「$labelZh」');
                ref.invalidate(pendingTagSuggestionsProvider);
                ref.invalidate(tagCategoriesProvider);
              } catch (e) {
                _toast('合併失敗：$e');
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
          ),

          const SizedBox(height: 14),

          // Actions.
          Row(
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _approve,
                icon: const Icon(LucideIcons.check, size: 14),
                label: const Text('建立新分類'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _merge,
                icon: const Icon(LucideIcons.gitMerge, size: 14),
                label: const Text('合併到既有分類'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _reject,
                icon: const Icon(LucideIcons.x, size: 14),
                label: const Text('退回此建議'),
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
      _toast('已加入官方分類庫');
      ref.invalidate(pendingTagSuggestionsProvider);
      ref.invalidate(tagCategoriesProvider);
    } catch (e) {
      _toast('批准失敗：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Reassign this suggestion to a different category before approving.
  /// Fixes legacy-migrated suggestions that were all dumped into 編輯精選.
  Future<void> _changeCategory() async {
    final cats = widget.categories;
    final picked = await showDialog<TagCategory>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('改到哪個類別？'),
        children: [
          for (final c in cats)
            if (c.id != widget.suggestion.categoryId)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, c),
                child: Row(
                  children: [
                    Text(c.titleZh),
                    const SizedBox(width: 8),
                    if (c.descriptionZh != null)
                      Flexible(
                        child: Text(
                          c.descriptionZh!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppTheme.textFaint),
                        ),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(tagSuggestionRepositoryProvider).changeCategory(
            suggestionId: widget.suggestion.id,
            newCategoryId: picked.id,
          );
      if (!mounted) return;
      _toast('已改為「${picked.titleZh}」');
      ref.invalidate(pendingTagSuggestionsProvider);
    } catch (e) {
      _toast('改類別失敗：$e');
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
      builder: (_) => _MergePicker(
        categoryId: cat.id,
        suggestionLabel: widget.suggestion.suggestedLabelZh,
      ),
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

/// Dialog picker: pick an existing canonical tag to merge a suggestion into.
///
/// Pre-populates with cross-category similarity matches at the top
/// (system's best guesses for the merge target), then a manual search
/// across all tags.
class _MergePicker extends ConsumerStatefulWidget {
  const _MergePicker({
    required this.categoryId,
    required this.suggestionLabel,
  });
  final String categoryId;
  final String suggestionLabel;

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
    final theme = Theme.of(context);
    // System recommendations: cross-category similarity matches.
    final suggestionsAsync = ref.watch(similarTagsProvider(
      SimilarTagsQuery(
        categoryId: widget.categoryId,
        label: widget.suggestionLabel,
        crossCategory: true,
      ),
    ));
    // Manual search across ALL canonical tags (not just suggestion's
    // category). Admin often needs to pick a target in a different facet
    // — e.g. legacy-migrated "諾蘭" is in 編輯精選 but belongs in 設計師.
    final tagsAsync = ref.watch(allCanonicalTagsProvider);
    final catsAsync = ref.watch(tagCategoriesProvider);
    final cats = catsAsync.asData?.value ?? const <TagCategory>[];
    String? categoryTitle(String categoryId) {
      for (final c in cats) {
        if (c.id == categoryId) return c.titleZh;
      }
      return null;
    }

    return AlertDialog(
      title: const Text('合併到哪一個既有分類？'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── System recommendations ────────────────────────────────
            suggestionsAsync.maybeWhen(
              data: (matches) {
                if (matches.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.chipBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.info,
                            size: 13, color: AppTheme.textFaint),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '系統在全站分類中找不到相似的既有分類，請自行搜尋挑選。',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: AppTheme.textFaint),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final top = matches.take(3).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '系統推薦（最相近的 ${top.length} 個）',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.amber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final m in top)
                      _RecommendedMatchTile(
                        match: m,
                        onTap: () {
                          // Must fetch the full Tag to return — callers
                          // expect a Tag, not a SimilarTag.
                          final fullTag =
                              tagsAsync.asData?.value.firstWhere(
                            (t) => t.id == m.tagId,
                            orElse: () => Tag(
                              id: m.tagId,
                              slug: m.slug,
                              categoryId: widget.categoryId,
                              labelZh: m.labelZh,
                              labelEn: m.labelEn,
                            ),
                          );
                          Navigator.pop(context, fullTag);
                        },
                      ),
                    const SizedBox(height: 12),
                    Divider(color: AppTheme.line1, height: 1),
                    const SizedBox(height: 10),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            // ─── Manual search ─────────────────────────────────────────
            TextField(
              controller: _searchCtrl,
              decoration:
                  const InputDecoration(hintText: '或自行搜尋既有分類…'),
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
                      child: Text('沒有符合的分類'),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final t = filtered[i];
                      final catName = categoryTitle(t.categoryId);
                      return ListTile(
                        dense: true,
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                t.labelZh,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (catName != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.chipBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  catName,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppTheme.textMute,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
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

/// Shows a one-line hint above the action buttons when the suggestion looks
/// like a duplicate of an existing tag. Reduces admin cognitive load: they
/// don't need to memorize the ~165 canonical tags — the system surfaces
/// likely matches inline with a one-click merge.
class _SimilarityHint extends ConsumerWidget {
  const _SimilarityHint({
    required this.categoryId,
    required this.label,
    required this.busy,
    required this.onMergeToExisting,
  });

  final String categoryId;
  final String label;
  final bool busy;
  final Future<void> Function(String tagId, String labelZh) onMergeToExisting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Admin review: cross-category search so legacy-mis-categorised
    // suggestions (e.g. 院線 filed under 編輯精選 but matches 院線首刷
    // under 版本) still surface.
    final async = ref.watch(similarTagsProvider(
      SimilarTagsQuery(
        categoryId: categoryId,
        label: label,
        crossCategory: true,
      ),
    ));
    return async.maybeWhen(
      data: (matches) {
        if (matches.isEmpty) return const SizedBox.shrink();
        // Only show hint if best match is above admin-weak threshold.
        final best = matches.first;
        if (best.similarity < SimilarTag.weakHintThreshold) {
          return const SizedBox.shrink();
        }
        // Show top 3 above threshold.
        final shown = matches
            .where((m) => m.similarity >= SimilarTag.weakHintThreshold)
            .take(3)
            .toList();

        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.08),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.triangleAlert,
                      size: 13, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text(
                    '看起來這個分類可能已經存在：',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.amber,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final m in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _MatchRow(
                    match: m,
                    busy: busy,
                    onTap: () => onMergeToExisting(m.tagId, m.labelZh),
                  ),
                ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({
    required this.match,
    required this.busy,
    required this.onTap,
  });
  final SimilarTag match;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Colour the similarity badge by strength.
    final pct = match.similarityPercent;
    final Color badge;
    if (match.similarity >= SimilarTag.autoMergeThreshold) {
      badge = Colors.green;
    } else if (match.similarity >= SimilarTag.strongHintThreshold) {
      badge = Colors.amber;
    } else {
      badge = AppTheme.textMute;
    }
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top line: labels + similarity badge + poster count
              Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    match.labelZh,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                    ),
                  ),
                  if (match.labelEn.isNotEmpty &&
                      match.labelEn != match.labelZh)
                    Text(
                      match.labelEn,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: AppTheme.textMute),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: badge.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '相似度 $pct%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: badge,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  if (match.posterCount > 0)
                    Text(
                      '${match.posterCount} 張',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.textFaint, fontSize: 10),
                    ),
                ],
              ),
              // Category hint (cross-category results)
              if (match.categoryTitleZh != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '在「${match.categoryTitleZh}」分類下',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.textFaint,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: busy ? null : onTap,
          icon: const Icon(LucideIcons.gitMerge, size: 12),
          label: const Text('一鍵合併', style: TextStyle(fontSize: 12)),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: const Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}

/// One row in the "系統推薦" top section of the merge picker.
class _RecommendedMatchTile extends StatelessWidget {
  const _RecommendedMatchTile({required this.match, required this.onTap});
  final SimilarTag match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = match.similarityPercent;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: AppTheme.chipBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          match.labelZh,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$pct%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.amber,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (match.categoryTitleZh != null)
                      Text(
                        '在「${match.categoryTitleZh}」分類 · ${match.posterCount} 張',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: AppTheme.textFaint),
                      ),
                  ],
                ),
              ),
              Icon(LucideIcons.gitMerge,
                  size: 14, color: AppTheme.textMute),
            ],
          ),
        ),
      ),
    );
  }
}

/// 分類一覽 — admin 可以在做決策前看完整 taxonomy。
/// 10 個 category 摺疊展開，每個裡面是 canonical tags (含別名 + 海報數)。
class _TaxonomyOverviewDialog extends ConsumerWidget {
  const _TaxonomyOverviewDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final catsAsync = ref.watch(tagCategoriesProvider);
    final tagsAsync = ref.watch(allCanonicalTagsProvider);

    return Dialog(
      backgroundColor: AppTheme.bg,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.list, size: 16, color: AppTheme.textMute),
                const SizedBox(width: 6),
                Text(
                  '分類一覽',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '目前官方有 10 大類別，下面是所有 canonical 分類與其別名。審稿前可以先看一下。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppTheme.textMute),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: catsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Text('載入失敗：$e'),
                data: (cats) => tagsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (e, _) => Text('載入失敗：$e'),
                  data: (allTags) {
                    // Group tags by category
                    final byCategory = <String, List<Tag>>{};
                    for (final t in allTags) {
                      byCategory.putIfAbsent(t.categoryId, () => []).add(t);
                    }
                    return ListView.builder(
                      itemCount: cats.length,
                      itemBuilder: (_, i) {
                        final c = cats[i];
                        final tags = byCategory[c.id] ?? const [];
                        return _CategoryBlock(category: c, tags: tags);
                      },
                    );
                  },
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('關閉'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBlock extends StatefulWidget {
  const _CategoryBlock({required this.category, required this.tags});
  final TagCategory category;
  final List<Tag> tags;

  @override
  State<_CategoryBlock> createState() => _CategoryBlockState();
}

class _CategoryBlockState extends State<_CategoryBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    _expanded
                        ? LucideIcons.chevronDown
                        : LucideIcons.chevronRight,
                    size: 14,
                    color: AppTheme.textMute,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.category.titleZh,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.tags.length} 個分類',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: AppTheme.textFaint),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded && widget.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 4, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final t in widget.tags)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMute,
                          ),
                          children: [
                            TextSpan(
                              text: t.labelZh,
                              style: TextStyle(
                                color: AppTheme.text,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (t.labelEn.isNotEmpty && t.labelEn != t.labelZh)
                              TextSpan(text: ' · ${t.labelEn}'),
                            if (t.aliases.isNotEmpty)
                              TextSpan(
                                text: ' · 別名：${t.aliases.join(" / ")}',
                                style: TextStyle(color: AppTheme.textFaint),
                              ),
                            TextSpan(text: '  （${t.posterCount} 張）'),
                          ],
                        ),
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
