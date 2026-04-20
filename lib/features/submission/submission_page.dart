import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/enums.dart';
import '../../core/constants/region_labels.dart';
import '../../core/services/image_compressor.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sticky_header.dart';
import '../../data/models/work.dart';
import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/submission_repository.dart';
import '../../data/repositories/work_repository.dart';
import 'tag_picker.dart';

class SubmissionPage extends ConsumerStatefulWidget {
  const SubmissionPage({super.key});

  @override
  ConsumerState<SubmissionPage> createState() => _SubmissionPageState();
}

class _SubmissionPageState extends ConsumerState<SubmissionPage> {
  final _formKey = GlobalKey<FormState>();

  // ── Required ──
  final _titleZhController = TextEditingController();

  // ── Basic info ──
  final _titleEnController = TextEditingController();
  final _yearController = TextEditingController();
  final _posterNameController = TextEditingController();

  // ── Enums ──
  Region _region = Region.tw;
  ReleaseType? _releaseType;
  SizeType? _sizeType;
  ChannelCategory? _channelCategory;

  // ── EPIC 18: work_kind + tags + AI self-declaration ──
  String _workKind = 'movie'; // values match work_kind_enum in SQL
  Map<String, Set<String>> _selectedTags = {};
  bool _aiDeclaration = false;

  // ── Channel detail ──
  final _channelTypeController = TextEditingController();
  final _channelNameController = TextEditingController();
  bool _isExclusive = false;
  final _exclusiveNameController = TextEditingController();

  // ── Material ──
  final _materialTypeController = TextEditingController();
  final _versionLabelController = TextEditingController();

  // ── Source ──
  final _sourceUrlController = TextEditingController();
  final _sourcePlatformController = TextEditingController();
  final _sourceNoteController = TextEditingController();

  // ── Image state ──
  Uint8List? _imageBytes;
  CompressedImages? _compressed;
  bool _compressing = false;
  bool _submitting = false;

  // ── Expandable sections ──
  bool _showAdvanced = false;

  @override
  void dispose() {
    _titleZhController.dispose();
    _titleEnController.dispose();
    _yearController.dispose();
    _posterNameController.dispose();
    _channelTypeController.dispose();
    _channelNameController.dispose();
    _exclusiveNameController.dispose();
    _materialTypeController.dispose();
    _versionLabelController.dispose();
    _sourceUrlController.dispose();
    _sourcePlatformController.dispose();
    _sourceNoteController.dispose();
    super.dispose();
  }

  // ── Image picking ──────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final rawBytes = await file.readAsBytes();

    setState(() {
      _imageBytes = rawBytes;
      _compressed = null;
      _compressing = true;
    });

    final result = ImageCompressor.compress(rawBytes);
    if (!mounted) return;

    if (result == null) {
      _toast('圖片格式無法辨識，請換一張試試');
      setState(() {
        _imageBytes = null;
        _compressing = false;
      });
      return;
    }

    if (result.posterBytes.lengthInBytes > ImageCompressor.maxPosterBytes) {
      _toast('壓縮後仍超過 5 MB，請選擇較小的圖片');
      setState(() {
        _imageBytes = null;
        _compressing = false;
      });
      return;
    }

    setState(() {
      _compressed = result;
      _compressing = false;
    });

    final rawKB = (rawBytes.lengthInBytes / 1024).round();
    final posterKB = (result.posterBytes.lengthInBytes / 1024).round();
    _toast('已壓縮 $rawKB → $posterKB KB');
  }

  // ── Row builder ────────────────────────────────────────────────────────────

  Map<String, dynamic> _buildRow(String userId) {
    // Flatten selected tag IDs from all categories into a single array.
    final allTagIds =
        _selectedTags.values.expand((s) => s).toList(growable: false);

    final row = <String, dynamic>{
      'work_title_zh': _titleZhController.text.trim(),
      'uploader_id': userId,
      'region': _region.value,
      'is_exclusive': _isExclusive,
      'work_kind': _workKind,
      'tag_ids': allTagIds,
      'ai_self_declaration': _aiDeclaration,
    };

    final titleEn = _titleEnController.text.trim();
    if (titleEn.isNotEmpty) row['work_title_en'] = titleEn;

    final year = int.tryParse(_yearController.text.trim());
    if (year != null) row['movie_release_year'] = year;

    final posterName = _posterNameController.text.trim();
    if (posterName.isNotEmpty) row['poster_name'] = posterName;

    if (_releaseType != null) row['poster_release_type'] = _releaseType!.value;
    if (_sizeType != null) row['size_type'] = _sizeType!.value;
    if (_channelCategory != null) {
      row['channel_category'] = _channelCategory!.value;
    }

    final channelType = _channelTypeController.text.trim();
    if (channelType.isNotEmpty) row['channel_type'] = channelType;

    final channelName = _channelNameController.text.trim();
    if (channelName.isNotEmpty) row['channel_name'] = channelName;

    if (_isExclusive) {
      final exName = _exclusiveNameController.text.trim();
      if (exName.isNotEmpty) row['exclusive_name'] = exName;
    }

    final materialType = _materialTypeController.text.trim();
    if (materialType.isNotEmpty) row['material_type'] = materialType;

    final versionLabel = _versionLabelController.text.trim();
    if (versionLabel.isNotEmpty) row['version_label'] = versionLabel;

    final sourceUrl = _sourceUrlController.text.trim();
    if (sourceUrl.isNotEmpty) row['source_url'] = sourceUrl;

    final sourcePlatform = _sourcePlatformController.text.trim();
    if (sourcePlatform.isNotEmpty) row['source_platform'] = sourcePlatform;

    final sourceNote = _sourceNoteController.text.trim();
    if (sourceNote.isNotEmpty) row['source_note'] = sourceNote;

    return row;
  }

  // ── Preview → Confirm → Submit ────────────────────────────────────────────

  Future<void> _showPreview() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _toast('請先登入');
      return;
    }
    if (_compressed == null) {
      _toast(_compressing ? '圖片壓縮中，請稍候' : '請先選一張海報圖片');
      return;
    }
    if (!_aiDeclaration) {
      _toast('請先勾選「此海報非 AI 生成」的聲明');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final row = _buildRow(user.id);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        row: row,
        imageBytes: _imageBytes!,
        imageSizeBytes: _compressed!.posterBytes.lengthInBytes,
      ),
    );

    if (confirmed != true || !mounted) return;
    await _doSubmit(user.id, row);
  }

  Future<void> _doSubmit(String userId, Map<String, dynamic> row) async {
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();
    try {
      final repo = ref.read(submissionRepositoryProvider);

      final urls = await repo.uploadPosterPair(
        posterBytes: _compressed!.posterBytes,
        thumbBytes: _compressed!.thumbBytes,
        contentType: _compressed!.contentType,
        userId: userId,
      );

      row['image_url'] = urls.posterUrl;
      row['thumbnail_url'] = urls.thumbUrl;
      row['image_size_bytes'] = _compressed!.posterBytes.lengthInBytes;

      await repo.createSubmission(row);

      if (!mounted) return;
      _toast('已送出審核，感謝投稿！');
      _resetForm();
    } catch (e) {
      _toast('上傳失敗：$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _resetForm() {
    setState(() {
      _imageBytes = null;
      _compressed = null;
      _showAdvanced = false;
      _region = Region.tw;
      _releaseType = null;
      _sizeType = null;
      _channelCategory = null;
      _isExclusive = false;
    });
    _formKey.currentState!.reset();
    for (final c in [
      _titleZhController,
      _titleEnController,
      _yearController,
      _posterNameController,
      _channelTypeController,
      _channelNameController,
      _exclusiveNameController,
      _materialTypeController,
      _versionLabelController,
      _sourceUrlController,
      _sourcePlatformController,
      _sourceNoteController,
    ]) {
      c.clear();
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(currentUserProvider) != null;
    if (!signedIn) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(
          child: Text('請先登入才能上傳',
              style: TextStyle(color: AppTheme.textMute)),
        ),
      );
    }

    final topInset = MediaQuery.paddingOf(context).top;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          _buildScrollableForm(topInset, theme),
          // v13 sticky header — back arrow + 上傳海報 title + 送出 pill.
          StickyHeader(
            title: '上傳海報',
            actionLabel: '送出',
            actionLoading: _submitting || _compressing,
            onAction: (_submitting || _compressing) ? null : _showPreview,
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableForm(double topInset, ThemeData theme) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, topInset + 70, 20, 40), // header height = 60 + buffer
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Batch mode link.
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.push('/upload/batch'),
                icon: const Icon(LucideIcons.layers, size: 14),
                label: const Text('同一部電影有多張？改用批次'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textMute,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // ── Image picker ──
            GestureDetector(
              onTap: _submitting ? null : _pickImage,
              child: _imageBytes == null
                  ? _EmptyPicker(compressing: _compressing)
                  : _ImagePreview(
                      bytes: _imageBytes!,
                      compressing: _compressing,
                      onReplace: _submitting ? null : _pickImage,
                    ),
            ),

            const SizedBox(height: 24),

            // ── Work kind selector (EPIC 18-8) ──
            _WorkKindSelector(
              value: _workKind,
              onChanged: (v) => setState(() => _workKind = v),
            ),
            const SizedBox(height: 16),

            // ── Required: 作品中文名（auto-suggest） ──
            _WorkTitleAutocomplete(
              controller: _titleZhController,
              workRepo: ref.read(workRepositoryProvider),
            ),
            const SizedBox(height: 12),

            // ── Basic row: 英文名 + 年份 ──
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _DarkField(
                    controller: _titleEnController,
                    label: '英文名',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DarkField(
                    controller: _yearController,
                    label: '上映年份',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 1900 || n > 2100) return '格式錯誤';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Poster name ──
            _DarkField(
              controller: _posterNameController,
              label: '海報名稱',
              hint: '如：正式版、角色版A…',
            ),
            const SizedBox(height: 12),

            // ── Region dropdown ──
            _DarkDropdown<Region>(
              label: '地區',
              value: _region,
              items: Region.values,
              labelOf: (r) => regionLabels[r] ?? r.value,
              onChanged: (v) {
                if (v != null) setState(() => _region = v);
              },
            ),
            const SizedBox(height: 12),

            // ── Release type + Size ──
            Row(
              children: [
                Expanded(
                  child: _DarkDropdown<ReleaseType>(
                    label: '發行類型',
                    value: _releaseType,
                    items: ReleaseType.values,
                    labelOf: (r) => releaseTypeLabels[r] ?? r.value,
                    onChanged: (v) => setState(() => _releaseType = v),
                    allowNull: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DarkDropdown<SizeType>(
                    label: '尺寸',
                    value: _sizeType,
                    items: SizeType.values,
                    labelOf: (s) => sizeTypeLabels[s] ?? s.value,
                    onChanged: (v) => setState(() => _sizeType = v),
                    allowNull: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Expand/collapse advanced ──
            GestureDetector(
              onTap: () => setState(() => _showAdvanced = !_showAdvanced),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Icon(
                    _showAdvanced
                        ? LucideIcons.chevronDown
                        : LucideIcons.chevronRight,
                    size: 16,
                    color: AppTheme.textMute,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '進階資訊',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.textMute,
                    ),
                  ),
                ],
              ),
            ),

            if (_showAdvanced) ...[
              const SizedBox(height: 14),

              // ── Channel section ──
              _SectionLabel(label: '通路'),
              const SizedBox(height: 8),
              _DarkDropdown<ChannelCategory>(
                label: '通路類型',
                value: _channelCategory,
                items: ChannelCategory.values,
                labelOf: (c) => channelCategoryLabels[c] ?? c.value,
                onChanged: (v) => setState(() => _channelCategory = v),
                allowNull: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DarkField(
                      controller: _channelTypeController,
                      label: '通路細項',
                      hint: '如：IMAX, 4DX…',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DarkField(
                      controller: _channelNameController,
                      label: '通路名稱',
                      hint: '如：威秀、秀泰…',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Exclusive toggle ──
              Row(
                children: [
                  Text(
                    '獨家',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMute,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: _isExclusive,
                    onChanged: (v) => setState(() => _isExclusive = v),
                    activeTrackColor: AppTheme.text,
                  ),
                ],
              ),
              if (_isExclusive) ...[
                const SizedBox(height: 8),
                _DarkField(
                  controller: _exclusiveNameController,
                  label: '獨家名稱',
                  hint: '如：影城獨家版…',
                ),
              ],

              const SizedBox(height: 16),

              // ── Material section ──
              _SectionLabel(label: '材質 / 版本'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DarkField(
                      controller: _materialTypeController,
                      label: '材質',
                      hint: '如：紙質、金屬…',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DarkField(
                      controller: _versionLabelController,
                      label: '版本標記',
                      hint: '如：v2, 修正版…',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Source section ──
              _SectionLabel(label: '來源'),
              const SizedBox(height: 8),
              _DarkField(
                controller: _sourceUrlController,
                label: '來源網址',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DarkField(
                      controller: _sourcePlatformController,
                      label: '來源平台',
                      hint: '如：Facebook, X…',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DarkField(
                      controller: _sourceNoteController,
                      label: '備註',
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // ── Tag picker (EPIC 18-9): faceted taxonomy ──
            _SectionLabel(label: '分類'),
            const SizedBox(height: 8),
            TagPicker(
              selected: _selectedTags,
              onChanged: (m) => setState(() => _selectedTags = m),
            ),

            const SizedBox(height: 24),

            // ── AI self-declaration (EPIC 18-12): mandatory ──
            _AiDeclarationRow(
              checked: _aiDeclaration,
              onChanged: (v) => setState(() => _aiDeclaration = v),
            ),

            const SizedBox(height: 20),

            // ── Submit button ──
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: (_submitting || _compressing) ? null : _showPreview,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.text,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppTheme.line2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: (_submitting || _compressing)
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.textMute,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _compressing ? '壓縮中…' : '上傳中…',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppTheme.textMute,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        '預覽並送出',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textFaint,
            letterSpacing: 0.5,
          ),
    );
  }
}

/// Empty state: tap to pick.
/// v13 empty picker — 2:3 aspect ratio, soft dark fill, camera icon
/// centred + 點擊選擇圖片 · 支援多張. Earlier version used a custom
/// diagonal-stripe painter but it caused a framework assertion on web
/// (likely from path bounds vs the Stack-positioned StickyHeader); the
/// flat fill reads almost identically and is bulletproof.
class _EmptyPicker extends StatelessWidget {
  const _EmptyPicker({required this.compressing});
  final bool compressing;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x0AFFFFFF), // ≈ rgba(255,255,255,0.04)
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.line2),
        ),
        child: Center(
          child: compressing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.textMute,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.camera,
                        size: 32, color: AppTheme.textMute),
                    const SizedBox(height: 10),
                    Text(
                      '點擊選擇圖片 · 支援多張',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textMute,
                            fontSize: 13,
                          ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Image preview with replace overlay.
class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.bytes,
    required this.compressing,
    required this.onReplace,
  });
  final Uint8List bytes;
  final bool compressing;
  final VoidCallback? onReplace;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
          if (compressing)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.textMute,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('壓縮中…',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppTheme.textMute)),
                    ],
                  ),
                ),
              ),
            ),
          if (!compressing)
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: onReplace,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.refreshCw,
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.8)),
                      const SizedBox(width: 5),
                      Text(
                        '更換',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dark-themed form field.
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
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.text,
          ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AppTheme.textMute, fontSize: 14),
        hintStyle: TextStyle(color: AppTheme.textFaint, fontSize: 14),
        filled: true,
        fillColor: AppTheme.surfaceRaised,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.line1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.line1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.textMute),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935)),
        ),
      ),
    );
  }
}

/// Dark-themed dropdown field.
class _DarkDropdown<T> extends StatelessWidget {
  const _DarkDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.allowNull = false,
  });
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;
  final bool allowNull;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      onChanged: onChanged,
      isExpanded: true,
      dropdownColor: AppTheme.surfaceRaised,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.text,
          ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.textMute, fontSize: 14),
        filled: true,
        fillColor: AppTheme.surfaceRaised,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.line1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.line1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.textMute),
        ),
      ),
      items: [
        if (allowNull)
          DropdownMenuItem<T>(
            value: null,
            child: Text('未指定',
                style: TextStyle(color: AppTheme.textFaint)),
          ),
        ...items.map((item) => DropdownMenuItem<T>(
              value: item,
              child: Text(labelOf(item)),
            )),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Work title autocomplete
// ---------------------------------------------------------------------------

class _WorkTitleAutocomplete extends StatefulWidget {
  const _WorkTitleAutocomplete({
    required this.controller,
    required this.workRepo,
  });
  final TextEditingController controller;
  final WorkRepository workRepo;

  @override
  State<_WorkTitleAutocomplete> createState() => _WorkTitleAutocompleteState();
}

class _WorkTitleAutocompleteState extends State<_WorkTitleAutocomplete> {
  List<Work> _suggestions = [];
  bool _showSuggestions = false;
  Timer? _debounce;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Debounce keystrokes (250ms) before querying the DB, and guard against
  /// stale responses via _requestId so a slow earlier query can't clobber
  /// the suggestions for a later keystroke.
  void _onChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final id = ++_requestId;
      try {
        final results =
            await widget.workRepo.search(titleZh: trimmed, limit: 5);
        if (!mounted || id != _requestId) return;
        setState(() {
          _suggestions = results;
          _showSuggestions = results.isNotEmpty;
        });
      } catch (e) {
        // Don't crash the form on a transient search hiccup, but surface it.
        // ignore: avoid_print
        print('work autocomplete search failed: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: widget.controller,
          validator: (v) => (v == null || v.trim().isEmpty) ? '必填' : null,
          onChanged: _onChanged,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.text,
              ),
          decoration: InputDecoration(
            labelText: '作品中文名 *',
            hintText: '輸入 2 字以上自動建議',
            labelStyle: TextStyle(color: AppTheme.textMute, fontSize: 14),
            hintStyle: TextStyle(color: AppTheme.textFaint, fontSize: 14),
            filled: true,
            fillColor: AppTheme.surfaceRaised,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.line1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.line1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.textMute),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE53935)),
            ),
          ),
        ),
        if (_showSuggestions)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.line1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _suggestions.map((w) {
                return InkWell(
                  onTap: () {
                    widget.controller.text = w.displayTitle;
                    widget.controller.selection = TextSelection.collapsed(
                        offset: w.displayTitle.length);
                    setState(() => _showSuggestions = false);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${w.displayTitle}${w.movieReleaseYear != null ? " (${w.movieReleaseYear})" : ""}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          '${w.posterCount} 張',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppTheme.textFaint),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Confirmation sheet (preview before submit)
// ---------------------------------------------------------------------------

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.row,
    required this.imageBytes,
    required this.imageSizeBytes,
  });
  final Map<String, dynamic> row;
  final Uint8List imageBytes;
  final int imageSizeBytes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppTheme.line1)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle.
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.line2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text('確認投稿',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),

            // Image preview.
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(imageBytes,
                  height: 180, fit: BoxFit.cover),
            ),
            const SizedBox(height: 12),

            // Summary rows.
            _SummaryRow(
                label: '作品', value: row['work_title_zh'] as String),
            if (row['work_title_en'] != null)
              _SummaryRow(label: '英文名', value: row['work_title_en']),
            if (row['movie_release_year'] != null)
              _SummaryRow(
                  label: '年份', value: '${row["movie_release_year"]}'),
            _SummaryRow(
              label: '地區',
              value: regionLabels[Region.fromString(row['region'])] ??
                  row['region'],
            ),
            if (row['poster_name'] != null)
              _SummaryRow(label: '海報名稱', value: row['poster_name']),
            if (row['poster_release_type'] != null)
              _SummaryRow(
                label: '發行類型',
                value: releaseTypeLabels[
                        ReleaseType.fromString(row['poster_release_type'])] ??
                    row['poster_release_type'],
              ),
            if (row['size_type'] != null)
              _SummaryRow(
                label: '尺寸',
                value: sizeTypeLabels[
                        SizeType.fromString(row['size_type'])] ??
                    row['size_type'],
              ),
            if (row['channel_category'] != null)
              _SummaryRow(
                label: '通路',
                value: channelCategoryLabels[ChannelCategory.fromString(
                        row['channel_category'])] ??
                    row['channel_category'],
              ),
            if (row['is_exclusive'] == true)
              _SummaryRow(
                  label: '獨家',
                  value: row['exclusive_name'] ?? '是'),
            _SummaryRow(
              label: '檔案大小',
              value: '${(imageSizeBytes / 1024).round()} KB',
            ),

            const SizedBox(height: 20),

            // Buttons.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('返回修改'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.text,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('確認送出'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textMute),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EPIC 18-8: Work kind selector — first step of submission
// ═══════════════════════════════════════════════════════════════════════════

class _WorkKindSelector extends StatelessWidget {
  const _WorkKindSelector({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  static const _kinds = <_KindOption>[
    _KindOption('movie',        '電影',       LucideIcons.film),
    _KindOption('concert',      '演唱會',     LucideIcons.music),
    _KindOption('theatre',      '戲劇',       LucideIcons.theater),
    _KindOption('exhibition',   '展覽',       LucideIcons.image),
    _KindOption('event',        '活動',       LucideIcons.calendar),
    _KindOption('original_art', '原創作品',   LucideIcons.palette),
    _KindOption('advertisement', '商業廣告',  LucideIcons.megaphone),
    _KindOption('other',        '其他',       LucideIcons.circle),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '這張海報是關於什麼？*',
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppTheme.textMute,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final k in _kinds)
              _KindChip(
                option: k,
                selected: value == k.slug,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(k.slug);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _KindOption {
  const _KindOption(this.slug, this.label, this.icon);
  final String slug;
  final String label;
  final IconData icon;
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });
  final _KindOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.text : AppTheme.chipBg,
            border: Border.all(
              color: selected ? AppTheme.text : AppTheme.line1,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                option.icon,
                size: 14,
                color: selected ? AppTheme.bg : AppTheme.text,
              ),
              const SizedBox(width: 6),
              Text(
                option.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected ? AppTheme.bg : AppTheme.text,
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

// ═══════════════════════════════════════════════════════════════════════════
// EPIC 18-12: AI self-declaration checkbox (MANDATORY)
// ═══════════════════════════════════════════════════════════════════════════

class _AiDeclarationRow extends StatelessWidget {
  const _AiDeclarationRow({required this.checked, required this.onChanged});
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: checked ? AppTheme.text : AppTheme.line1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox visual (manual, matches dark theme).
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: checked ? AppTheme.text : Colors.transparent,
                border: Border.all(
                  color: checked ? AppTheme.text : AppTheme.line2,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: checked
                  ? Icon(LucideIcons.check, size: 14, color: AppTheme.bg)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '我確認此海報「非 AI 生成」*',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'POSTER. 禁止收錄 AI 生成海報。違者將永久停權。'
                    '送出即代表你同意此條款。',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppTheme.textMute),
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
