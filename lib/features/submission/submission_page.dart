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

  // ── Image state (multi-upload, v13 2026-04-21) ──
  //
  // Each entry = one picked poster. Big 2:3 preview shows whichever
  // thumb the user tapped (defaults to the first). The thumb row
  // below shows the full queue with a ring around the active one,
  // plus a ＋ slot. On submit, each image becomes its own submission
  // row, sharing the same work metadata.
  final List<_PickedImage> _images = [];
  int _primaryIdx = 0;

  // Compression progress (visible blocking overlay so the user
  // doesn't think the app is hung when picking a 30MB photo).
  bool _compressing = false;
  int _compressDone = 0;
  int _compressTotal = 0;

  bool _submitting = false;

  // v18: previously every keystroke in the title field called setState
  // on the entire submission form (~a dozen widgets incl. image preview
  // + tag picker) just so the 送審 pill could toggle its enabled state.
  // That stuttered on older Android when typing long CJK titles. Now
  // the StickyHeader wraps the pill in an AnimatedBuilder listening to
  // this controller — only the pill rebuilds on keystroke.

  Uint8List? get _primaryImageBytes =>
      _images.isEmpty ? null : _images[_primaryIdx.clamp(0, _images.length - 1)].bytes;
  CompressedImages? get _primaryCompressed =>
      _images.isEmpty ? null : _images[_primaryIdx.clamp(0, _images.length - 1)].compressed;

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

  Future<void> _addImages() async {
    final picker = ImagePicker();
    final source = await _pickSource();
    if (source == null) return;

    List<XFile> files;
    if (source == ImageSource.camera) {
      final shot = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
      files = shot == null ? const <XFile>[] : [shot];
    } else {
      files = await picker.pickMultiImage();
    }
    if (files.isEmpty) return;

    setState(() {
      _compressing = true;
      _compressTotal = files.length;
      _compressDone = 0;
    });

    final added = <_PickedImage>[];
    final tooLarge = <String>[]; // raw filename + raw size for the dialog
    final badFormat = <String>[];
    final duplicates = <String>[];

    // Snapshot fingerprints of already-queued images so we can dedupe
    // both against existing and against the just-picked batch.
    final existingFingerprints = <int>{
      for (final img in _images) _fingerprint(img.bytes),
    };

    for (final file in files) {
      final rawBytes = await file.readAsBytes();
      await Future<void>.delayed(Duration.zero); // yield to repaint

      final fp = _fingerprint(rawBytes);
      if (existingFingerprints.contains(fp)) {
        duplicates.add(file.name);
        if (mounted) setState(() => _compressDone++);
        continue;
      }
      existingFingerprints.add(fp);

      final result = ImageCompressor.compress(rawBytes);
      if (result == null) {
        badFormat.add(file.name);
      } else if (result.posterBytes.lengthInBytes >
          ImageCompressor.maxPosterBytes) {
        final mb = (rawBytes.lengthInBytes / 1024 / 1024).toStringAsFixed(1);
        tooLarge.add('${file.name} ($mb MB)');
      } else {
        added.add(_PickedImage(bytes: rawBytes, compressed: result));
      }
      if (mounted) setState(() => _compressDone++);
    }

    if (!mounted) return;
    setState(() {
      _images.addAll(added);
      // If this was the first batch, leave _primaryIdx at 0; otherwise
      // jump to the first newly-added image so the user can see what
      // they just picked.
      if (added.isNotEmpty && _images.length == added.length) {
        _primaryIdx = 0;
      } else if (added.isNotEmpty) {
        _primaryIdx = _images.length - added.length;
      }
      _compressing = false;
      _compressTotal = 0;
      _compressDone = 0;
    });

    // Single, clear summary instead of N stacked toasts.
    if (tooLarge.isNotEmpty || badFormat.isNotEmpty || duplicates.isNotEmpty) {
      _showSkipSummary(
        added: added.length,
        tooLarge: tooLarge,
        badFormat: badFormat,
        duplicates: duplicates,
      );
    } else if (added.isNotEmpty) {
      _toast(added.length == 1 ? '已加入 1 張' : '已加入 ${added.length} 張');
    }
  }

  /// Cheap content fingerprint — hashes file size and a sample of bytes
  /// (first / mid / last 64). Same image picked twice always collides.
  /// Different images of the same dimension *may* collide (extremely
  /// unlikely with the offsets), but we accept the small false-positive
  /// risk to avoid hashing the entire byte array.
  int _fingerprint(Uint8List b) {
    final n = b.length;
    var h = n;
    void mix(int i) {
      if (i < 0 || i >= n) return;
      h = (h * 31 + b[i]) & 0x7fffffff;
    }
    for (var i = 0; i < 64 && i < n; i++) {
      mix(i);
    }
    final mid = n ~/ 2;
    for (var i = 0; i < 64; i++) {
      mix(mid + i);
    }
    for (var i = 1; i <= 64; i++) {
      mix(n - i);
    }
    return h;
  }

  Future<void> _showSkipSummary({
    required int added,
    required List<String> tooLarge,
    required List<String> badFormat,
    required List<String> duplicates,
  }) async {
    if (!mounted) return;
    Widget section(String label, List<String> names, String? hint) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label（${names.length} 張）',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textMute,
                    fontWeight: FontWeight.w600,
                  )),
          const SizedBox(height: 4),
          ...names.map((n) => Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Text('· $n',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.text,
                        )),
              )),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(hint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textFaint,
                    )),
          ],
        ],
      );
    }

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceRaised,
        title: Text(
          added > 0 ? '已加入 $added 張，部分跳過' : '全部跳過',
          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (duplicates.isNotEmpty)
                section('已存在於這次的清單', duplicates,
                    '同一張照片不能加兩次'),
              if (tooLarge.isNotEmpty) ...[
                if (duplicates.isNotEmpty) const SizedBox(height: 16),
                section('超過 5 MB', tooLarge,
                    '請先用編輯器壓縮再上傳，或選較小的圖片'),
              ],
              if (badFormat.isNotEmpty) ...[
                if (duplicates.isNotEmpty || tooLarge.isNotEmpty)
                  const SizedBox(height: 16),
                section('格式不支援', badFormat, null),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _removeImageAt(int i) {
    setState(() {
      _images.removeAt(i);
      // Keep _primaryIdx valid after removal.
      if (_primaryIdx >= _images.length) {
        _primaryIdx = (_images.length - 1).clamp(0, 1 << 30);
      }
    });
  }

  void _setPrimary(int i) {
    setState(() => _primaryIdx = i);
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
    if (_images.isEmpty) {
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
        imageBytes: _primaryImageBytes!,
        imageSizeBytes: _primaryCompressed!.posterBytes.lengthInBytes,
        extraCount: _images.length - 1,
      ),
    );

    if (confirmed != true || !mounted) return;
    await _doSubmit(user.id, row);
  }

  /// Multi-upload: for each picked image, upload the pair + create a
  /// submission row. All rows share the same work metadata (title,
  /// year, director, tags, AI declaration). If any upload fails we
  /// keep going so partial success doesn't lose uploaded work.
  Future<void> _doSubmit(String userId, Map<String, dynamic> baseRow) async {
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();
    final repo = ref.read(submissionRepositoryProvider);
    var ok = 0;
    final errors = <String>[];
    for (var i = 0; i < _images.length; i++) {
      final img = _images[i];
      try {
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
        ok++;
      } catch (e) {
        errors.add('第 ${i + 1} 張失敗：$e');
      }
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok > 0 && errors.isEmpty) {
      _toast('已送出 $ok 張審核，感謝投稿！');
      _resetForm();
    } else if (ok > 0) {
      _toast('送出 $ok 張成功 / ${errors.length} 張失敗');
      setState(() => _images.removeRange(0, ok));
    } else {
      _toast('全部失敗：${errors.first}');
    }
  }

  void _resetForm() {
    setState(() {
      _images.clear();
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
        
        body: Center(
          child: Text('請先登入才能上傳',
              style: TextStyle(color: AppTheme.textMute)),
        ),
      );
    }

    final topInset = MediaQuery.paddingOf(context).top;
    final theme = Theme.of(context);

    return Scaffold(
      
      body: Stack(
        children: [
          _buildScrollableForm(topInset, theme),
          // v18 sticky header — X (no bg circle) + 上傳海報 + 送審 pill.
          // The pill lights up only when a title + at least one image
          // are present, matching the prototype's canSubmit gate.
          // AnimatedBuilder listens to the title controller so only
          // the header (not the whole form tree) rebuilds per keystroke.
          AnimatedBuilder(
            animation: _titleZhController,
            builder: (_, _) => StickyHeader(
              title: '上傳海報',
              actionLabel: '送審',
              backText: '取消',
              actionLoading: _submitting || _compressing,
              actionEnabled: !_submitting &&
                  !_compressing &&
                  _images.isNotEmpty &&
                  _titleZhController.text.trim().isNotEmpty,
              onAction: (_submitting || _compressing) ? null : _showPreview,
            ),
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
            // ── Image picker ── (v13: big 2:3 preview + thumb row)
            // Big area:
            //   - empty: tappable, opens picker
            //   - has images: NOT tappable (avoids "tap → re-pick"
            //     confusion with ＋ slot below). Adding more goes via
            //     ＋ slot in thumb row only.
            // Stack overlays an unmissable compression spinner.
            Stack(
              children: [
                _images.isEmpty
                    ? GestureDetector(
                        onTap: _submitting || _compressing ? null : _addImages,
                        child: _EmptyPicker(compressing: _compressing),
                      )
                    : _ImagePreview(
                        bytes: _primaryImageBytes!,
                        compressing: _compressing,
                      ),
                if (_compressing)
                  Positioned.fill(
                    child: _CompressOverlay(
                      done: _compressDone,
                      total: _compressTotal,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Thumb row — each picked image + a trailing ＋ slot.
            _ThumbRow(
              images: _images,
              activeIdx: _primaryIdx,
              onRemove: _submitting ? null : _removeImageAt,
              onSelect: _submitting ? null : _setPrimary,
              onAdd: _submitting ? null : _addImages,
            ),
            // Hint when there's at least one image, so the multi-upload
            // affordance is unmissable.
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '點縮圖切換預覽，按 ＋ 加更多張（共用同一筆作品資料）',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textFaint,
                      fontSize: 11,
                    ),
              ),
            ],

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
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textFaint,
            letterSpacing: 0.5,
          ),
    );
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
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.ink2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.line2),
          ),
          child: CustomPaint(
            painter: _DiagonalStripePainter(),
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
        ),
      ),
    );
  }
}

/// Diagonal-stripe pattern using `canvas.drawRect` only (rectangles
/// have well-defined bounds, unlike the previous path-fill which
/// extended beyond canvas and triggered an assertion). Each stripe is
/// rotated 45° via canvas.transform.
class _DiagonalStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    // Translate to centre, rotate 45°, draw vertical stripes that
    // cover the rotated bounding box.
    final centre = Offset(size.width / 2, size.height / 2);
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(0.785398); // π/4
    final diag = (size.width + size.height); // covers rotated bbox
    final paint = Paint()..color = const Color(0x0FFFFFFF); // 0.06
    const band = 12.0;
    for (var x = -diag; x < diag; x += band * 2) {
      canvas.drawRect(Rect.fromLTWH(x, -diag, band, diag * 2), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DiagonalStripePainter old) => false;
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.textMute,
              fontSize: 12,
              letterSpacing: 0,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.text,
              fontSize: 15,
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
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.text,
                    fontSize: 15,
                  ),
            ),
          ),
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
    final theme = Theme.of(context);
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
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.textMute,
                        fontSize: 12,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: value == null
                            ? AppTheme.textFaint
                            : AppTheme.text,
                        fontSize: 15,
                      ),
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
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textMute,
                      fontSize: 12,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              TextFormField(
                controller: widget.controller,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '必填' : null,
                onChanged: _onChanged,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.text,
                      fontSize: 15,
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

            Text(
              extraCount > 0 ? '確認投稿 ${extraCount + 1} 張' : '確認投稿',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (extraCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '將為每張海報建立一筆投稿，共用下方的作品資料',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMute,
                ),
              ),
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

/// Horizontal row of 48×64 thumbs — one per picked image + a trailing
/// ＋ slot that opens the multi-picker again. Native-feeling multi-
/// upload UI: main 2:3 preview above, thumb row here for overview
/// and quick remove.
class _ThumbRow extends StatelessWidget {
  const _ThumbRow({
    required this.images,
    required this.activeIdx,
    required this.onRemove,
    required this.onSelect,
    required this.onAdd,
  });
  final List<_PickedImage> images;
  final int activeIdx;
  final ValueChanged<int>? onRemove;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 4dp extra so the close × bubble (top: -4) doesn't get clipped
      // by the row bounds.
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(top: 4),
        itemCount: images.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == images.length) return _AddSlot(onTap: onAdd);
          return _ThumbTile(
            image: images[i],
            active: i == activeIdx,
            onSelect: onSelect == null ? null : () => onSelect!(i),
            onRemove: onRemove == null ? null : () => onRemove!(i),
          );
        },
      ),
    );
  }
}

class _ThumbTile extends StatelessWidget {
  const _ThumbTile({
    required this.image,
    required this.active,
    required this.onSelect,
    required this.onRemove,
  });
  final _PickedImage image;
  final bool active;
  final VoidCallback? onSelect;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        height: 68,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Tile.
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: AppTheme.motionFast,
                width: 48,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0x0FFFFFFF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active ? Colors.white : AppTheme.line1,
                    width: active ? 2 : 1,
                  ),
                ),
                child: Image.memory(image.bytes, fit: BoxFit.cover),
              ),
            ),
            // Close × bubble.
            if (onRemove != null)
              Positioned(
                top: -4,
                right: -4,
                child: GestureDetector(
                  onTap: onRemove,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xE6000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        size: 12, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compression progress overlay — sits on top of the picker area
/// during _addImages so the user has unmissable feedback that work
/// is happening (otherwise compressing a 30MB photo on web feels
/// like the app froze).
class _CompressOverlay extends StatelessWidget {
  const _CompressOverlay({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : done / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        // Almost-opaque so any underlying empty placeholder (when
        // compressing the very first image) is fully hidden.
        color: const Color(0xEB0D1116), // ink at ~92% alpha
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                value: total == 0 ? null : pct,
                strokeWidth: 3,
                color: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              total > 0 ? '壓縮中… $done / $total' : '壓縮中…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '請稍候，超過 5MB 的會自動跳過',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSlot extends StatelessWidget {
  const _AddSlot({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 48,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.line2),
        ),
        child: Icon(LucideIcons.plus, size: 18, color: AppTheme.textMute),
      ),
    );
  }
}
