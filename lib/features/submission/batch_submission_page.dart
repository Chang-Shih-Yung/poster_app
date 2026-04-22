import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/enums.dart';
import '../../core/constants/region_labels.dart';
import '../../core/services/image_compressor.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/submission_repository.dart';
import 'tag_picker.dart';

/// /upload/batch — shared work info + N poster cards.
///
/// Each card has its own image, posterName, sizeType. Work info
/// (title, year, region) is shared across all cards in the batch.
/// All cards get the same batch_id on submit so admin can review together.
class BatchSubmissionPage extends ConsumerStatefulWidget {
  const BatchSubmissionPage({super.key});

  @override
  ConsumerState<BatchSubmissionPage> createState() =>
      _BatchSubmissionPageState();
}

class _BatchSubmissionPageState extends ConsumerState<BatchSubmissionPage> {
  final _formKey = GlobalKey<FormState>();

  // Shared work info.
  final _titleZhController = TextEditingController();
  final _titleEnController = TextEditingController();
  final _yearController = TextEditingController();
  Region _region = Region.tw;

  // EPIC 18: shared across all cards in this batch.
  // Batch UX is primarily for multiple versions of the same movie
  // (e.g. teaser + final + IMAX). Default to 'movie', users wanting
  // other kinds use single submission flow.
  final String _workKind = 'movie';
  Map<String, Set<String>> _selectedTags = {};
  bool _aiDeclaration = false;

  // One card per poster in this batch.
  final List<_CardState> _cards = [_CardState()];

  bool _submitting = false;

  @override
  void dispose() {
    _titleZhController.dispose();
    _titleEnController.dispose();
    _yearController.dispose();
    for (final c in _cards) {
      c.dispose();
    }
    super.dispose();
  }

  void _addCard() {
    HapticFeedback.selectionClick();
    setState(() => _cards.add(_CardState()));
  }

  void _removeCard(int i) {
    HapticFeedback.selectionClick();
    setState(() {
      _cards[i].dispose();
      _cards.removeAt(i);
    });
  }

  bool get _allCardsReady =>
      _cards.isNotEmpty &&
      _cards.every((c) => c.compressed != null && !c.compressing);

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _toast('請先登入');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_cards.isEmpty) {
      _toast('請至少新增一張海報');
      return;
    }
    if (!_allCardsReady) {
      _toast('有圖片還在壓縮，請稍候');
      return;
    }
    if (!_aiDeclaration) {
      _toast('請先勾選「此批海報皆非 AI 生成」的聲明');
      return;
    }

    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    final batchId = const Uuid().v4();
    final repo = ref.read(submissionRepositoryProvider);
    final titleZh = _titleZhController.text.trim();
    final titleEn = _titleEnController.text.trim();
    final year = int.tryParse(_yearController.text.trim());

    try {
      // Upload all images concurrently, then insert all rows.
      final uploads = await Future.wait(
        _cards.map((c) => repo.uploadPosterPair(
              posterBytes: c.compressed!.posterBytes,
              thumbBytes: c.compressed!.thumbBytes,
              contentType: c.compressed!.contentType,
              userId: user.id,
            )),
      );

      // Build rows.
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < _cards.length; i++) {
        final c = _cards[i];
        final urls = uploads[i];
        final allTagIds =
            _selectedTags.values.expand((s) => s).toList(growable: false);
        final row = <String, dynamic>{
          'batch_id': batchId,
          'uploader_id': user.id,
          'work_title_zh': titleZh,
          'region': _region.value,
          'is_exclusive': false,
          'work_kind': _workKind,
          'tag_ids': allTagIds,
          'ai_self_declaration': _aiDeclaration,
          'image_url': urls.posterUrl,
          'thumbnail_url': urls.thumbUrl,
          'image_size_bytes': c.compressed!.posterBytes.lengthInBytes,
        };
        if (titleEn.isNotEmpty) row['work_title_en'] = titleEn;
        if (year != null) row['movie_release_year'] = year;
        final pname = c.posterNameController.text.trim();
        if (pname.isNotEmpty) row['poster_name'] = pname;
        if (c.sizeType != null) row['size_type'] = c.sizeType!.value;
        rows.add(row);
      }

      // Concurrent inserts — independent rows, no ordering requirement.
      await Future.wait(rows.map(repo.createSubmission));

      if (!mounted) return;
      _toast('已送出 ${_cards.length} 張海報，感謝投稿！');
      Navigator.of(context).pop();
    } catch (e) {
      _toast('上傳失敗：$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.surfaceRaised,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final theme = Theme.of(context);

    final signedIn = ref.watch(currentUserProvider) != null;
    if (!signedIn) {
      return Center(
        child: Text('請先登入才能上傳',
            style: TextStyle(color: AppTheme.textMute)),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, topInset + 64, 20, 40),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('批量投稿',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              '同一部電影的多張海報，共用基本資料 → 一次送審',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppTheme.textMute),
            ),
            const SizedBox(height: 24),

            // ── Shared work info ─────────────────────────────────────────
            Text('共用資料',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.textMute,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 10),
            _DarkField(
              controller: _titleZhController,
              label: '電影中文名稱 *',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '必填' : null,
            ),
            const SizedBox(height: 10),
            _DarkField(
              controller: _titleEnController,
              label: '電影英文名稱',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DarkField(
                    controller: _yearController,
                    label: '上映年份',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<Region>(
                    initialValue: _region,
                    items: Region.values
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(regionLabels[r] ?? r.value),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _region = v ?? Region.tw),
                    decoration: const InputDecoration(labelText: '地區'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Cards ────────────────────────────────────────────────────
            Text('海報（${_cards.length}）',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.textMute,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 10),

            for (var i = 0; i < _cards.length; i++) ...[
              _PosterCardEditor(
                index: i,
                card: _cards[i],
                canRemove: _cards.length > 1,
                onRemove: () => _removeCard(i),
                onChange: () => setState(() {}),
              ),
              const SizedBox(height: 12),
            ],

            OutlinedButton.icon(
              onPressed: _submitting ? null : _addCard,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('新增一張海報'),
            ),

            const SizedBox(height: 28),
            // Shared tags across the whole batch.
            Text('分類（整批共用）',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.textMute,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 8),
            TagPicker(
              selected: _selectedTags,
              onChanged: (m) => setState(() => _selectedTags = m),
            ),
            const SizedBox(height: 20),

            // AI self-declaration.
            InkWell(
              onTap: () => setState(() => _aiDeclaration = !_aiDeclaration),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceRaised,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _aiDeclaration ? AppTheme.text : AppTheme.line1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: _aiDeclaration
                            ? AppTheme.text
                            : Colors.transparent,
                        border: Border.all(
                          color: _aiDeclaration
                              ? AppTheme.text
                              : AppTheme.line2,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: _aiDeclaration
                          ? Icon(LucideIcons.check, size: 14, color: AppTheme.bg)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '我確認此批海報皆非 AI 生成。POSTER. 禁止收錄 AI 海報，違者永久停權。',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppTheme.textMute),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting || !_allCardsReady ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _submitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          // Spinner matches the FilledButton foreground
                          // (AppTheme.bg) so it's visible against the
                          // inverted-pill fill in both day and night.
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.bg,
                          ),
                        )
                      : Text('送出 ${_cards.length} 張'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Per-card state ─────────────────────────────────────────────────────────

class _CardState {
  final posterNameController = TextEditingController();
  SizeType? sizeType;
  Uint8List? imageBytes;
  CompressedImages? compressed;
  bool compressing = false;

  void dispose() {
    posterNameController.dispose();
  }
}

class _PosterCardEditor extends StatelessWidget {
  const _PosterCardEditor({
    required this.index,
    required this.card,
    required this.canRemove,
    required this.onRemove,
    required this.onChange,
  });
  final int index;
  final _CardState card;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChange;

  Future<void> _pick(BuildContext context) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();

    card.imageBytes = bytes;
    card.compressed = null;
    card.compressing = true;
    onChange();

    final result = ImageCompressor.compress(bytes);
    if (result == null) {
      card.imageBytes = null;
      card.compressing = false;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('圖片格式無法辨識，請換一張')),
        );
      }
      onChange();
      return;
    }
    if (result.posterBytes.lengthInBytes > ImageCompressor.maxPosterBytes) {
      card.imageBytes = null;
      card.compressing = false;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('壓縮後仍超過 5 MB，請換張小的')),
        );
      }
      onChange();
      return;
    }
    card.compressed = result;
    card.compressing = false;
    onChange();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = card.imageBytes != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        border: Border.all(color: AppTheme.line1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${index + 1}',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: AppTheme.textMute)),
              const Spacer(),
              if (canRemove)
                IconButton(
                  icon: Icon(LucideIcons.trash2,
                      size: 16, color: AppTheme.textMute),
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Image picker tile.
          GestureDetector(
            onTap: () => _pick(context),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.bg,
                border: Border.all(
                  color: hasImage ? AppTheme.line2 : AppTheme.line1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: hasImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(card.imageBytes!, fit: BoxFit.cover),
                          if (card.compressing)
                            Container(
                              color: Colors.black.withValues(alpha: 0.4),
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            ),
                        ],
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.imagePlus,
                              color: AppTheme.textFaint),
                          const SizedBox(height: 4),
                          Text('點擊選圖',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.textFaint)),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          _DarkField(
            controller: card.posterNameController,
            label: '版本 / 名稱（選填）',
            hint: '例如：台灣院線正式版',
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<SizeType?>(
            initialValue: card.sizeType,
            items: [
              const DropdownMenuItem(value: null, child: Text('尺寸（選填）')),
              ...SizeType.values.map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(sizeTypeLabels[s] ?? s.value),
                ),
              ),
            ],
            onChanged: (v) {
              card.sizeType = v;
              onChange();
            },
            decoration: const InputDecoration(labelText: '尺寸'),
          ),
        ],
      ),
    );
  }
}

// ─── Dark form field (reused pattern from submission_page) ─────────────────

class _DarkField extends StatelessWidget {
  const _DarkField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.validator,
  });
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: AppTheme.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }
}
