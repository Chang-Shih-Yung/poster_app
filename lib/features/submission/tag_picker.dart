import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/tag.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/repositories/tag_suggestion_repository.dart';

/// Multi-facet tag picker used in submission flows.
///
/// Given a list of [TagCategory], renders one picker per category:
/// a collapsible chip row where the user can select canonical tags.
/// Within each category:
///   - Inline search with alias fallback (TagRepository.search)
///   - Top tags shown as chips
///   - "建議新增 tag" opens a small form → TagSuggestionRepository
///   - Required categories show a subtle hint if nothing picked
///
/// Value is a `Map<categorySlug, Set<tagId>>`.
class TagPicker extends ConsumerStatefulWidget {
  const TagPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.onlyRequired = false,
  });

  final Map<String, Set<String>> selected;
  final ValueChanged<Map<String, Set<String>>> onChanged;
  /// If true, hide non-required categories. Used in "quick" submission mode.
  final bool onlyRequired;

  @override
  ConsumerState<TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends ConsumerState<TagPicker> {
  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(tagCategoriesProvider);
    return catsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('分類載入失敗：$e',
            style: TextStyle(color: AppTheme.textMute)),
      ),
      data: (cats) {
        final visible = widget.onlyRequired
            ? cats.where((c) => c.isRequired).toList()
            : cats;
        if (visible.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final c in visible)
              _CategorySection(
                category: c,
                selectedIds: widget.selected[c.slug] ?? <String>{},
                onToggle: (tagId, picked) {
                  final next = Map<String, Set<String>>.from(widget.selected);
                  final s = Set<String>.from(next[c.slug] ?? <String>{});
                  if (picked) {
                    s.add(tagId);
                  } else {
                    s.remove(tagId);
                  }
                  if (s.isEmpty) {
                    next.remove(c.slug);
                  } else {
                    next[c.slug] = s;
                  }
                  widget.onChanged(next);
                },
              ),
          ],
        );
      },
    );
  }
}

class _CategorySection extends ConsumerStatefulWidget {
  const _CategorySection({
    required this.category,
    required this.selectedIds,
    required this.onToggle,
  });
  final TagCategory category;
  final Set<String> selectedIds;
  final void Function(String tagId, bool picked) onToggle;

  @override
  ConsumerState<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends ConsumerState<_CategorySection> {
  // v18 — per-category search input was removed; each category now
  // shows its tags as direct tappable chips (+ a 建議新增 link at the
  // end). Keeping the field felt like a nested form inside a form.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagsAsync = ref.watch(tagsByCategoryProvider(widget.category.id));

    // Auto-expand if any tags already selected (user is actively editing).
    final shouldExpand = _expanded || widget.selectedIds.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line1),
      ),
      child: Column(
        children: [
          // Header row — tap to expand.
          InkWell(
            onTap: () => setState(() => _expanded = !shouldExpand),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.category.titleZh,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (widget.category.isRequired) ...[
                              const SizedBox(width: 4),
                              Text('*',
                                  style: TextStyle(color: Colors.amber[400])),
                            ],
                            if (widget.selectedIds.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.chipBgStrong,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${widget.selectedIds.length}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (widget.category.descriptionZh != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.category.descriptionZh!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: AppTheme.textFaint),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    shouldExpand
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 18,
                    color: AppTheme.textMute,
                  ),
                ],
              ),
            ),
          ),
          if (shouldExpand)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: tagsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (e, _) => Text('載入失敗：$e',
                    style: TextStyle(color: AppTheme.textMute)),
                data: (tags) {
                  final visible =
                      tags.where((t) => !t.deprecated).toList(growable: false);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tag chips — direct tap, no nested search field.
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final t in visible)
                            _TagChip(
                              tag: t,
                              selected: widget.selectedIds.contains(t.id),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                widget.onToggle(
                                  t.id,
                                  !widget.selectedIds.contains(t.id),
                                );
                              },
                            ),
                        ],
                      ),
                      if (visible.isEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          '此類別尚無 tag。',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textFaint),
                        ),
                      ],
                      if (widget.category.allowsSuggestion) ...[
                        const SizedBox(height: 12),
                        _SuggestLink(category: widget.category),
                      ],
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.tag,
    required this.selected,
    required this.onTap,
  });
  final Tag tag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppTheme.text : AppTheme.chipBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppTheme.text : AppTheme.line1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tag.isOtherFallback) ...[
                Icon(LucideIcons.circleAlert,
                    size: 12,
                    color: selected ? AppTheme.bg : AppTheme.textFaint),
                const SizedBox(width: 4),
              ],
              Text(
                tag.labelZh,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? AppTheme.bg : AppTheme.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (tag.posterCount > 0 && !selected) ...[
                const SizedBox(width: 5),
                Text(
                  '${tag.posterCount}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textFaint,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Don't see what you want? Suggest a new tag" link that opens a form.
class _SuggestLink extends ConsumerWidget {
  const _SuggestLink({required this.category});
  final TagCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _openForm(context, ref),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.plus, size: 12, color: AppTheme.textMute),
          const SizedBox(width: 4),
          Text(
            '找不到適合的？建議新增「${category.titleZh}」分類',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppTheme.textMute),
          ),
        ],
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _SuggestDialog(category: category),
    );
  }
}

/// New-tag suggestion form with live duplicate detection.
///
/// As the user types 中文名, we debounce-query find_similar_tags and
/// surface top matches right under the field with a "這個就是你要的" chip.
/// If they pick one, no suggestion is created — the tag is applied directly.
/// If they ignore hints and submit, the server gateway may still auto-merge
/// at similarity ≥ 0.95 (e.g. "Miyazaki" → "宮崎駿" via alias).
class _SuggestDialog extends ConsumerStatefulWidget {
  const _SuggestDialog({required this.category});
  final TagCategory category;

  @override
  ConsumerState<_SuggestDialog> createState() => _SuggestDialogState();
}

class _SuggestDialogState extends ConsumerState<_SuggestDialog> {
  final _labelZhCtrl = TextEditingController();
  final _labelEnCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  Timer? _debounce;
  String _currentQuery = '';
  bool _submitting = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _labelZhCtrl.dispose();
    _labelEnCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _onLabelChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _currentQuery = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final similarAsync = _currentQuery.isEmpty
        ? null
        : ref.watch(similarTagsProvider(
            SimilarTagsQuery(
              categoryId: widget.category.id,
              label: _currentQuery,
            ),
          ));

    // Filter to strong hints only (≥ 0.75) for user-facing UX.
    final strongMatches = similarAsync?.asData?.value
            .where((m) => m.similarity >= SimilarTag.strongHintThreshold)
            .take(3)
            .toList() ??
        const [];

    return AlertDialog(
      title: Text('建議新增「${widget.category.titleZh}」分類'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _labelZhCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: '中文名 *'),
              onChanged: _onLabelChanged,
            ),
            // Live duplicate hint.
            if (strongMatches.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '你是不是想用這個？',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.amber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final m in strongMatches)
                          _UseExistingChip(
                            match: m,
                            onTap: () => _useExistingTag(m),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _labelEnCtrl,
              decoration: const InputDecoration(labelText: '英文名（選填）'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonCtrl,
              decoration:
                  const InputDecoration(labelText: '為什麼需要這個分類？（選填）'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('送出建議'),
        ),
      ],
    );
  }

  /// User clicked a surfaced match → skip suggestion, jump straight to
  /// "this tag already exists, done".
  void _useExistingTag(SimilarTag match) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已使用既有分類「${match.labelZh}」'),
      ),
    );
    // Note: does NOT auto-attach to the current poster since this dialog
    // doesn't know which poster is being edited. User should pick the tag
    // from the category list themselves.
  }

  Future<void> _submit() async {
    final zh = _labelZhCtrl.text.trim();
    if (zh.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final result = await ref.read(tagSuggestionRepositoryProvider).submit(
            categoryId: widget.category.id,
            labelZh: zh,
            labelEn: _labelEnCtrl.text.trim().isEmpty
                ? null
                : _labelEnCtrl.text.trim(),
            reason: _reasonCtrl.text.trim().isEmpty
                ? null
                : _reasonCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      final msg = switch (result) {
        SuggestionAutoMerged(:final tagLabelZh) =>
          '已自動對應到既有分類「$tagLabelZh」',
        SuggestionQueued() => '已送出建議，管理員審核後會加入分類庫',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('建議失敗：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _UseExistingChip extends StatelessWidget {
  const _UseExistingChip({required this.match, required this.onTap});
  final SimilarTag match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.chipBgStrong,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.check,
                  size: 12, color: Colors.amber),
              const SizedBox(width: 5),
              Text(
                match.labelZh,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

