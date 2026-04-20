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
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _expanded = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

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
                  final filtered = _filterTags(tags, _query);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search field.
                      TextField(
                        controller: _searchCtrl,
                        onChanged: _onSearchChanged,
                        style: theme.textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: '搜尋 ${widget.category.titleZh}…',
                          prefixIcon: Icon(LucideIcons.search,
                              size: 16, color: AppTheme.textMute),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Tag chips (selectable).
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final t in filtered)
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
                      if (filtered.isEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          _query.isEmpty ? '此類別尚無 tag。' : '找不到符合「$_query」的 tag。',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textFaint),
                        ),
                      ],
                      if (widget.category.allowsSuggestion) ...[
                        const SizedBox(height: 12),
                        _SuggestLink(
                          category: widget.category,
                          prefill: _query,
                        ),
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

  /// Filter tags by query + float "其他" to bottom + exclude deprecated.
  List<Tag> _filterTags(List<Tag> tags, String q) {
    final query = q.toLowerCase();
    final visible = tags.where((t) => !t.deprecated).toList();

    if (query.isEmpty) return visible;

    return visible.where((t) {
      if (t.labelZh.toLowerCase().contains(query)) return true;
      if (t.labelEn.toLowerCase().contains(query)) return true;
      return t.aliases.any((a) => a.toLowerCase().contains(query));
    }).toList();
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
  const _SuggestLink({required this.category, this.prefill});
  final TagCategory category;
  final String? prefill;

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
    final labelZhCtrl = TextEditingController(text: prefill ?? '');
    final labelEnCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('建議新增「${category.titleZh}」分類'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelZhCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: '中文名 *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: labelEnCtrl,
                decoration: const InputDecoration(labelText: '英文名（選填）'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                decoration:
                    const InputDecoration(labelText: '為什麼需要這個分類？（選填）'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('送出建議'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final zh = labelZhCtrl.text.trim();
    if (zh.isEmpty) return;

    try {
      await ref.read(tagSuggestionRepositoryProvider).create(
            categoryId: category.id,
            labelZh: zh,
            labelEn: labelEnCtrl.text.trim().isEmpty
                ? null
                : labelEnCtrl.text.trim(),
            reason: reasonCtrl.text.trim().isEmpty
                ? null
                : reasonCtrl.text.trim(),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已送出建議，管理員審核後會加入分類庫')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('建議失敗：$e')),
        );
      }
    }
  }
}
