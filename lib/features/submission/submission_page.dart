import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/enums.dart';
import '../../core/constants/region_labels.dart';
import '../../core/services/image_compressor.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/ds/ds.dart';
import '../../core/widgets/sticky_header.dart';
import '../../data/models/work.dart';
import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/submission_repository.dart';
import '../../data/repositories/work_repository.dart';
import 'tag_picker.dart';

/// Two-stage upload flow — pick first, compose second. Mirrors
/// Instagram / Threads / Pinterest where tapping ＋ takes you to a
/// gallery-style picker and only a deliberate 下一步 moves to the
/// caption / metadata step.
enum _UploadStage { pick, compose }

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

  // ── Upload stage machine ──
  //
  // v19 round 11 — two-stage flow matching IG:
  //   _UploadStage.pick      — user picks the image; cancel = pop route,
  //                            下一步 = advance to compose (enabled only
  //                            when an image is picked).
  //   _UploadStage.compose   — caption / tags / AI declaration / 送審.
  //                            Back button returns to pick so the user
  //                            can swap the image without losing form.
  //
  // On web, the "in-app gallery grid" IG-style isn't buildable — the
  // browser's File API only exposes a native file chooser. Step 1 on
  // web renders the empty-preview → tap → system chooser path. On
  // iOS/Android image_picker still triggers the OS sheet. Either way
  // we never auto-fire the picker on page entry; the user taps the
  // preview deliberately, which is the behaviour the design review
  // called for.
  _UploadStage _stage = _UploadStage.pick;
  _PickedImage? _picked;

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

  // ── Image picking (multi) ──────────────────────────────────────────────────

  /// Open the native picker. On iOS/Android this presents multi-select;
  /// on web it opens the browser file dialog. Every picked file is
  /// compressed on-device and appended to [_images]. Progress and
  /// per-file skip reasons are surfaced in the UI (overlay during,
  /// dialog at end).
  ///
  /// Presents a native iOS action sheet: 拍照 / 從相簿選擇 / 取消.
  /// Camera path uses ImagePicker.pickImage(source: camera) so we get
  /// the device capture flow instead of the browser file chooser.
  /// Ask the user how to source the image(s). Returns null if cancelled.
  /// iOS action sheet style; Web falls back to gallery since there's no
  /// meaningful camera tier.
  Future<ImageSource?> _pickSource() async {
    // Cupertino widgets inherit SF Pro by default; CJK chars render
    // as tofu if our bundled NotoSansTC isn't explicitly re-applied
    // (action sheets bypass MaterialApp's theme fallback). Use a
    // DefaultTextStyle wrapper around the sheet so every label
    // resolves to NotoSansTC.
    const font = TextStyle(fontFamily: 'NotoSansTC');
    return await showCupertinoModalPopup<ImageSource>(
      context: context,
      builder: (ctx) => DefaultTextStyle.merge(
        style: font,
        child: CupertinoActionSheet(
          title: const Text('加入海報', style: font),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, ImageSource.camera),
              child: const Text('拍照', style: font),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
              child: const Text('從相簿選擇', style: font),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: font),
          ),
        ),
      ),
    );
  }

  /// Pick a single image (camera or gallery), compress it, stash in
  /// `_picked`. If the user cancels the sheet, returns with `_picked`
  /// unchanged so the caller can decide what to do (initState will
  /// pop the route; the 更換 button will stay on the previous image).
  Future<void> _pickOne() async {
    final picker = ImagePicker();
    final source = await _pickSource();
    if (source == null) return;

    final XFile? file = await picker.pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (file == null) return;

    if (!mounted) return;
    setState(() => _compressing = true);
    try {
      final rawBytes = await file.readAsBytes();
      final result = ImageCompressor.compress(rawBytes);
      if (!mounted) return;
      if (result == null) {
        AppToast.show(context, '圖片格式無法辨識',
            kind: AppToastKind.destructive);
        return;
      }
      if (result.posterBytes.lengthInBytes >
          ImageCompressor.maxPosterBytes) {
        final mb =
            (rawBytes.lengthInBytes / 1024 / 1024).toStringAsFixed(1);
        AppToast.show(context, '圖片太大（$mb MB），請改用小一點的照片',
            kind: AppToastKind.destructive);
        return;
      }
      setState(() {
        _picked = _PickedImage(bytes: rawBytes, compressed: result);
      });
    } finally {
      if (mounted) setState(() => _compressing = false);
    }
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
      AppToast.show(context, '請先登入');
      return;
    }
    if (_picked == null) {
      AppToast.show(context,
          _compressing ? '圖片壓縮中，請稍候' : '請先選一張海報圖片');
      return;
    }
    if (!_aiDeclaration) {
      AppToast.show(context, '請先勾選「此海報非 AI 生成」的聲明');
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
        imageBytes: _picked!.bytes,
        imageSizeBytes: _picked!.compressed.posterBytes.lengthInBytes,
        extraCount: 0,
      ),
    );

    if (confirmed != true || !mounted) return;
    await _doSubmit(user.id, row);
  }

  Future<void> _doSubmit(String userId, Map<String, dynamic> baseRow) async {
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();
    final repo = ref.read(submissionRepositoryProvider);
    try {
      final img = _picked!;
      final urls = await repo.uploadPosterPair(
        posterBytes: img.compressed.posterBytes,
        thumbBytes: img.compressed.thumbBytes,
        contentType: img.compressed.contentType,
        userId: userId,
      );
      final row = Map<String, dynamic>.from(baseRow);
      row['image_url'] = urls.posterUrl;
      row['thumbnail_url'] = urls.thumbUrl;
      row['image_size_bytes'] = img.compressed.posterBytes.lengthInBytes;
      await repo.createSubmission(row);
      if (!mounted) return;
      AppToast.show(context, '已送出審核，感謝投稿！',
          kind: AppToastKind.success);
      _resetForm();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, '送出失敗：$e',
          kind: AppToastKind.destructive);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _resetForm() {
    setState(() {
      _picked = null;
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(currentUserProvider) != null;
    if (!signedIn) {
      return Scaffold(

        body: Center(
          child: Text('請先登入才能上傳',
              style: TextStyle(color: AppTheme.textMute)),
        ),
      );
    }

    final topInset = MediaQuery.paddingOf(context).top;
    final theme = Theme.of(context);

    // v19 round 11 — dispatch on stage. Pick stage shows a large
    // centered preview tile + 下一步 in the header. Compose stage
    // shows the full form with the image pinned at the top and the
    // back button returns to pick (so users can swap the image
    // without losing the form they've typed).
    return Scaffold(

      body: Stack(
        children: [
          if (_stage == _UploadStage.pick)
            _buildPickStage(topInset)
          else
            _buildScrollableForm(topInset, theme),
          if (_stage == _UploadStage.pick)
            StickyHeader(
              title: '新增海報',
              actionLabel: '下一步',
              backText: '取消',
              actionLoading: _compressing,
              actionEnabled: !_compressing && _picked != null,
              onAction: () {
                HapticFeedback.selectionClick();
                setState(() => _stage = _UploadStage.compose);
              },
            )
          else
            // AnimatedBuilder listens to the title controller so only
            // the header (not the whole form tree) rebuilds per keystroke.
            AnimatedBuilder(
              animation: _titleZhController,
              builder: (_, _) => StickyHeader(
                title: '填寫資訊',
                actionLabel: '送審',
                // Back returns to pick — lets the user swap the image
                // without clearing the form fields they've filled in.
                // During submit we make it a no-op instead of null so
                // the StickyHeader default (maybePop) doesn't kick the
                // user out of the page mid-upload.
                onBack: () {
                  if (_submitting) return;
                  HapticFeedback.selectionClick();
                  setState(() => _stage = _UploadStage.pick);
                },
                actionLoading: _submitting || _compressing,
                actionEnabled: !_submitting &&
                    !_compressing &&
                    _picked != null &&
                    _titleZhController.text.trim().isNotEmpty,
                onAction: (_submitting || _compressing) ? null : _showPreview,
              ),
            ),
        ],
      ),
    );
  }

  /// Stage 1 — big centered tap-to-pick tile. Mirrors IG's ＋ entry:
  /// no auto-popup on page entry, the user deliberately taps the
  /// preview to summon the native file chooser. Empty-state shows
  /// the camera icon + hint; once picked, the 2:3 preview fills the
  /// card with a 更換 pill at the bottom-right so re-pick is obvious.
  Widget _buildPickStage(double topInset) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, topInset + 80, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: Stack(
                children: [
                  if (_picked == null)
                    GestureDetector(
                      onTap: _compressing ? null : _pickOne,
                      child: _EmptyPicker(compressing: _compressing),
                    )
                  else
                    GestureDetector(
                      onTap: _compressing ? null : _pickOne,
                      child: _ImagePreview(
                        bytes: _picked!.bytes,
                        compressing: _compressing,
                      ),
                    ),
                  if (_compressing)
                    const Positioned.fill(child: _CompressOverlay()),
                  if (_picked != null && !_compressing)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: GestureDetector(
                        onTap: _pickOne,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius:
                                BorderRadius.circular(AppTheme.rPill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(LucideIcons.repeat2,
                                  size: 14, color: Colors.white),
                              SizedBox(width: 6),
                              AppText.small('更換',
                                  color: Colors.white,
                                  weight: FontWeight.w600),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          AppText.caption(
            _picked == null
                ? '點擊上方以選擇照片'
                : '準備好後按右上角「下一步」填寫資訊',
            tone: AppTextTone.faint,
            textAlign: TextAlign.center,
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
            // ── Compose-stage thumbnail ──
            // Small image strip (70% width, 2:3 aspect) pinned at top so
            // the user keeps visual context of which photo they're
            // composing metadata for. Tapping it returns to the pick
            // stage rather than re-opening the system picker — if they
            // want a different image, the two-stage flow expects a
            // deliberate "上一步" before re-picking.
            if (_picked != null)
              Align(
                alignment: Alignment.center,
                child: FractionallySizedBox(
                  widthFactor: 0.55,
                  child: GestureDetector(
                    onTap: _submitting
                        ? null
                        : () => setState(() => _stage = _UploadStage.pick),
                    child: _ImagePreview(
                      bytes: _picked!.bytes,
                      compressing: false,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // ── Work kind selector (EPIC 18-8) ──
            _WorkKindSelector(
              value: _workKind,
              onChanged: (v) => setState(() => _workKind = v),
            ),
            const SizedBox(height: 16),

            // ── Basic info (all required-ish fields merged into a
            //    single grouped list so the form reads as one block).
            _FormGroup(children: [
              _WorkTitleAutocomplete(
                controller: _titleZhController,
                workRepo: ref.read(workRepositoryProvider),
              ),
              _DarkField(
                controller: _titleEnController,
                label: '英文名',
              ),
              _DarkField(
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
              _DarkField(
                controller: _posterNameController,
                label: '海報名稱',
                hint: '如：正式版、角色版A…',
              ),
              _DarkDropdown<Region>(
                label: '地區',
                value: _region,
                items: Region.values,
                labelOf: (r) => regionLabels[r] ?? r.value,
                onChanged: (v) {
                  if (v != null) setState(() => _region = v);
                },
              ),
              _DarkDropdown<ReleaseType>(
                label: '發行類型',
                value: _releaseType,
                items: ReleaseType.values,
                labelOf: (r) => releaseTypeLabels[r] ?? r.value,
                onChanged: (v) => setState(() => _releaseType = v),
                allowNull: true,
              ),
              _DarkDropdown<SizeType>(
                label: '尺寸',
                value: _sizeType,
                items: SizeType.values,
                labelOf: (s) => sizeTypeLabels[s] ?? s.value,
                onChanged: (v) => setState(() => _sizeType = v),
                allowNull: true,
              ),
            ]),

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
                  AppText.bodyBold('進階資訊', tone: AppTextTone.muted),
                ],
              ),
            ),

            if (_showAdvanced) ...[
              const SizedBox(height: 14),

              // ── Tag picker (EPIC 18-9): faceted taxonomy ──
              // Moved inside 進階 per v18 spec — 進階 is now the single
              // home for all optional / structured metadata. The picker
              // itself was simplified (no per-category search input)
              // so the chip rows feel like direct tappable categories,
              // not search forms.
              _SectionLabel(label: '分類'),
              const SizedBox(height: 8),
              TagPicker(
                selected: _selectedTags,
                onChanged: (m) => setState(() => _selectedTags = m),
              ),

              const SizedBox(height: 16),

              // ── Group C: 通路 / 獨家 ───────────────────
              _SectionLabel(label: '通路'),
              const SizedBox(height: 8),
              _FormGroup(children: [
                _DarkDropdown<ChannelCategory>(
                  label: '通路類型',
                  value: _channelCategory,
                  items: ChannelCategory.values,
                  labelOf: (c) => channelCategoryLabels[c] ?? c.value,
                  onChanged: (v) => setState(() => _channelCategory = v),
                  allowNull: true,
                ),
                _DarkField(
                  controller: _channelTypeController,
                  label: '通路細項',
                  hint: '如：IMAX, 4DX…',
                ),
                _DarkField(
                  controller: _channelNameController,
                  label: '通路名稱',
                  hint: '如：威秀、秀泰…',
                ),
                _SwitchRow(
                  label: '獨家',
                  value: _isExclusive,
                  onChanged: (v) => setState(() => _isExclusive = v),
                ),
                if (_isExclusive)
                  _DarkField(
                    controller: _exclusiveNameController,
                    label: '獨家名稱',
                    hint: '如：影城獨家版…',
                  ),
              ]),

              const SizedBox(height: 16),

              // ── Group D: 材質 / 版本 ───────────────────
              _SectionLabel(label: '材質 / 版本'),
              const SizedBox(height: 8),
              _FormGroup(children: [
                _DarkField(
                  controller: _materialTypeController,
                  label: '材質',
                  hint: '如：紙質、金屬…',
                ),
                _DarkField(
                  controller: _versionLabelController,
                  label: '版本標記',
                  hint: '如：v2, 修正版…',
                ),
              ]),

              const SizedBox(height: 16),

              // ── Group E: 來源 ───────────────────────────
              _SectionLabel(label: '來源'),
              const SizedBox(height: 8),
              _FormGroup(children: [
                _DarkField(
                  controller: _sourceUrlController,
                  label: '來源網址',
                  keyboardType: TextInputType.url,
                ),
                _DarkField(
                  controller: _sourcePlatformController,
                  label: '來源平台',
                  hint: '如：Facebook, X…',
                ),
                _DarkField(
                  controller: _sourceNoteController,
                  label: '備註',
                ),
              ]),
            ],

            const SizedBox(height: 24),

            // ── AI self-declaration (EPIC 18-12): mandatory ──
            _AiDeclarationRow(
              checked: _aiDeclaration,
              onChanged: (v) => setState(() => _aiDeclaration = v),
            ),

            // Inner "預覽並送出" button removed in v18: the top-right
            // 送審 pill already triggers the same preview → confirm →
            // submit flow; having both felt redundant on a mobile
            // modal sheet.
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
    return AppText.label(label, tone: AppTextTone.faint);
  }
}

/// v13 empty picker — 2:3 aspect, diagonal-stripe placeholder, camera
/// icon + 點擊選擇圖片 · 支援多張. Stripe is drawn via canvas.drawRect
/// (rect-based, fully bounded — avoids the framework assertion the
/// previous path-based painter triggered).
class _EmptyPicker extends StatelessWidget {
  const _EmptyPicker({required this.compressing});
  final bool compressing;

  @override
  Widget build(BuildContext context) {
    // v19 round 2: the earlier diagonal-stripe placeholder read as
    // "under-construction hatch-pattern" — too noisy against the
    // otherwise clean submission form. Replaced with a flat iOS-style
    // card: muted surface, single hairline border, centered camera
    // icon + label. Reads as a tappable drop zone without tech debt
    // vibes.
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.r4),
          border: Border.all(color: AppTheme.line1, width: 0.5),
        ),
        child: Center(
          child: compressing
              ? const AppLoader()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceRaised,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(LucideIcons.camera,
                          size: 24, color: AppTheme.textMute),
                    ),
                    const SizedBox(height: 12),
                    const AppText.body(
                      '點擊選擇圖片',
                      weight: FontWeight.w500,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// v13 image preview — just the image, 2:3 aspect, rounded.
/// Compression spinner is owned by the outer `_CompressOverlay` in the
/// parent Stack so we don't double up. Replace / add-more is now handled
/// by the thumb row's ＋ slot, so no inline pill needed.
class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.bytes,
    required this.compressing,
  });
  final Uint8List bytes;
  final bool compressing;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Image.memory(bytes, fit: BoxFit.cover),
      ),
    );
  }
}

/// iOS-style form row — label stacked on top of an un-bordered text
/// field. Designed to live inside a [_FormGroup] (which paints the
/// rounded card bg + hairlines between rows). Mirrors the Threads /
/// iOS Settings grouped-list aesthetic.
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kept as a tight 12/600 label (not AppText.label which is
          // 11/600 letter-spaced) — this row-style inside _FormGroup
          // is a distinct primitive from standalone AppField.
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'InterDisplay',
              fontFamilyFallback: ['NotoSansTC'],
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ).copyWith(color: AppTheme.textMute),
          ),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            style: TextStyle(
              fontFamily: 'InterDisplay',
              fontFamilyFallback: const ['NotoSansTC'],
              fontSize: 15,
              color: AppTheme.text,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppTheme.textFaint, fontSize: 15),
              isDense: true,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }
}

/// Switch row designed for use inside a [_FormGroup]. Label left,
/// Switch.adaptive right — matches the iOS Settings pattern.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      child: Row(
        children: [
          Expanded(child: AppText.body(label)),
          CupertinoSwitch(
            value: value,
            activeTrackColor: AppTheme.accent2,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Rounded-card wrapper around a stack of form rows, with 0.5px
/// hairlines injected between rows. iOS Settings grouped-list
/// pattern. Accepts any widget as a row (text field, dropdown row,
/// switch row, etc.) so consumers can mix & match.
class _FormGroup extends StatelessWidget {
  const _FormGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Container(height: 0.5, color: AppTheme.line1),
              ),
          ],
        ],
      ),
    );
  }
}

/// iOS-style dropdown — renders as a tappable row (label left, current
/// value right, chevron) and opens a [CupertinoActionSheet] with one
/// button per option when tapped. Replaces `DropdownButtonFormField`
/// which looks Material everywhere.
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
    final displayText = value == null ? '未指定' : labelOf(value as T);
    return Material(
      color: AppTheme.surfaceRaised,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openSheet(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Match _DarkField's in-group label weight/size (12/600).
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'InterDisplay',
                        fontFamilyFallback: const ['NotoSansTC'],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMute,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AppText.body(
                      displayText,
                      tone: value == null
                          ? AppTextTone.faint
                          : AppTextTone.primary,
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight,
                  size: 16, color: AppTheme.textFaint),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    HapticFeedback.selectionClick();
    // NotoSansTC override — Cupertino widgets default to SF Pro and
    // tofu on first paint for CJK. See _pickSource in submission_page
    // for the same treatment.
    const font = TextStyle(fontFamily: 'NotoSansTC');
    final picked = await showCupertinoModalPopup<_PickResult<T>>(
      context: context,
      builder: (ctx) => DefaultTextStyle.merge(
        style: font,
        child: CupertinoActionSheet(
          title: Text(label, style: font),
          actions: [
            if (allowNull)
              CupertinoActionSheetAction(
                onPressed: () =>
                    Navigator.of(ctx).pop(_PickResult<T>.none()),
                isDestructiveAction: value == null,
                child: const Text('未指定', style: font),
              ),
            ...items.map((item) => CupertinoActionSheetAction(
                  onPressed: () =>
                      Navigator.of(ctx).pop(_PickResult<T>(item)),
                  isDefaultAction: value == item,
                  child: Text(labelOf(item), style: font),
                )),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消', style: font),
          ),
        ),
      ),
    );
    if (picked != null) onChanged(picked.value);
  }
}

/// Triple-state result so we can tell "user picked 未指定" (null) from
/// "user cancelled" (no emission). CupertinoActionSheet itself returns
/// `null` on cancel, which would collide with "null is a valid choice"
/// if we simply returned `T?` directly.
class _PickResult<T> {
  const _PickResult(this.value);
  const _PickResult.none() : value = null;
  final T? value;
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
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '作品中文名 *',
                style: TextStyle(
                  fontFamily: 'InterDisplay',
                  fontFamilyFallback: const ['NotoSansTC'],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMute,
                ),
              ),
              TextFormField(
                controller: widget.controller,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '必填' : null,
                onChanged: _onChanged,
                style: TextStyle(
                  fontFamily: 'InterDisplay',
                  fontFamilyFallback: const ['NotoSansTC'],
                  fontSize: 15,
                  color: AppTheme.text,
                ),
                decoration: InputDecoration(
                  hintText: '輸入 2 字以上自動建議',
                  hintStyle:
                      TextStyle(color: AppTheme.textFaint, fontSize: 15),
                  isDense: true,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
        if (_showSuggestions)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Container(height: 0.5, color: AppTheme.line1),
              ),
              ..._suggestions.map((w) {
                return InkWell(
                  onTap: () {
                    widget.controller.text = w.displayTitle;
                    widget.controller.selection = TextSelection.collapsed(
                        offset: w.displayTitle.length);
                    setState(() => _showSuggestions = false);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppText.body(
                            '${w.displayTitle}${w.movieReleaseYear != null ? " (${w.movieReleaseYear})" : ""}',
                          ),
                        ),
                        AppText.small('${w.posterCount} 張',
                            tone: AppTextTone.faint),
                      ],
                    ),
                  ),
                );
              }),
            ],
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
    this.extraCount = 0,
  });
  final Map<String, dynamic> row;
  final Uint8List imageBytes;
  final int imageSizeBytes;

  /// Count of additional images in the queue (for the "另外 N 張" badge).
  final int extraCount;

  @override
  Widget build(BuildContext context) {
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

            AppText.title(
              extraCount > 0 ? '確認投稿 ${extraCount + 1} 張' : '確認投稿',
            ),
            if (extraCount > 0) ...[
              const SizedBox(height: 4),
              AppText.caption('將為每張海報建立一筆投稿，共用下方的作品資料',
                  tone: AppTextTone.muted),
            ],
            const SizedBox(height: 16),

            // Image preview (first image — others submit silently).
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
                  child: AppButton.outline(
                    label: '返回修改',
                    fullWidth: true,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: AppButton.primary(
                    label: '確認送出',
                    fullWidth: true,
                    onPressed: () => Navigator.pop(context, true),
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
            child: AppText.caption(label, tone: AppTextTone.muted),
          ),
          Expanded(child: AppText.body(value)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText.label('這張海報是關於什麼？*', tone: AppTextTone.muted),
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
              AppText.body(
                option.label,
                color: selected ? AppTheme.bg : AppTheme.text,
                weight: FontWeight.w500,
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
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.bodyBold('我確認此海報「非 AI 生成」*'),
                  SizedBox(height: 4),
                  AppText.caption(
                    'POSTER. 禁止收錄 AI 生成海報。違者將永久停權。'
                    '送出即代表你同意此條款。',
                    tone: AppTextTone.muted,
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

// ─────────────────────────────────────────────────────────────────────
// v13 multi-upload support
// ─────────────────────────────────────────────────────────────────────

/// One picked image + its compression result (shared metadata between
/// thumb-row rendering and the final batched submit).
class _PickedImage {
  const _PickedImage({required this.bytes, required this.compressed});
  final Uint8List bytes;
  final CompressedImages compressed;
}

/// Compression progress overlay — sits on top of the picker area
/// while the single picked image is being down-scaled. Indeterminate
/// spinner only; v19 round 10 dropped multi-upload so there's no
/// "3 / 5" progress to show any more.
class _CompressOverlay extends StatelessWidget {
  const _CompressOverlay();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        color: const Color(0xEB0D1116),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            AppText.bodyBold('壓縮中…', color: Colors.white),
            const SizedBox(height: 4),
            AppText.small(
              '超過 5 MB 的會自動拒絕',
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

