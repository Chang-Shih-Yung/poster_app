import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/services/image_compressor.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sticky_header.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_repository.dart';

/// /profile/edit — IG-style profile editor.
///   - avatar (upload + preview)
///   - display name
///   - bio (200 chars)
///   - gender dropdown
///   - links (named external URLs, add/remove)
class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  Gender? _gender;
  List<ProfileLink> _links = [];
  String? _avatarUrl;
  Uint8List? _newAvatarBytes;
  String? _newAvatarContentType;
  bool _saving = false;
  bool _initialised = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _hydrateFrom(AppUser p) {
    if (_initialised) return;
    _nameCtrl.text = p.displayName;
    _bioCtrl.text = p.bio ?? '';
    _gender = p.gender;
    _links = List.from(p.links);
    _avatarUrl = p.avatarUrl;
    _initialised = true;
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (file == null) return;
    final raw = await file.readAsBytes();
    final compressed = ImageCompressor.compress(raw);
    if (compressed == null) {
      _toast('圖片格式無法辨識');
      return;
    }
    setState(() {
      _newAvatarBytes = compressed.thumbBytes; // smaller variant for avatar
      _newAvatarContentType = compressed.contentType;
    });
  }

  Future<void> _save(AppUser profile) async {
    if (_saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final repo = ref.read(userRepositoryProvider);
    try {
      String? newAvatarUrl;
      if (_newAvatarBytes != null) {
        newAvatarUrl = await repo.uploadAvatar(
          userId: profile.id,
          bytes: _newAvatarBytes!,
          contentType: _newAvatarContentType ?? 'image/jpeg',
        );
      }
      await repo.updateOwnProfile(
        userId: profile.id,
        displayName: _nameCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        gender: _gender,
        links: _links,
        avatarUrl: newAvatarUrl,
      );
      // Single helper invalidates every provider that surfaces this user's
      // displayName / avatar / bio / gender / links across the app. See
      // user_repository.dart → invalidateUserSurfaces for the rationale.
      invalidateUserSurfaces(ref, profile.id);
      if (mounted) {
        _toast('已儲存');
        context.pop();
      }
    } catch (e) {
      _toast('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: profileAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Center(
          child: Text('載入失敗：$e',
              style: TextStyle(color: AppTheme.textMute)),
        ),
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Text('請先登入',
                  style: TextStyle(color: AppTheme.textMute)),
            );
          }
          _hydrateFrom(profile);

          return Stack(
            children: [
              // Scrollable form (push down for sticky header height).
              SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    20, topInset + 70, 20, bottomInset + 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Centered avatar + 更換相片 caption (v13 spec).
                    Center(
                      child: Column(
                        children: [
                          _AvatarPicker(
                            url: _avatarUrl,
                            newBytes: _newAvatarBytes,
                            onPick: _pickAvatar,
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: _pickAvatar,
                            child: Text(
                              '更換相片',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textMute,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _Label('暱稱'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameCtrl,
                      maxLength: 30,
                      decoration: _v13InputDeco('你想被叫什麼名字？'),
                    ),
                    const SizedBox(height: 16),
                    _Label('簡介'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _bioCtrl,
                      maxLength: 200,
                      maxLines: 4,
                      decoration: _v13InputDeco('介紹一下你自己、你收藏的風格…'),
                    ),
                    const SizedBox(height: 16),
                    _Label('性別（選填）'),
                    const SizedBox(height: 6),
                    _GenderPicker(
                      value: _gender,
                      onChanged: (g) => setState(() => _gender = g),
                    ),
                    const SizedBox(height: 24),
                    _Label('個人連結'),
                    const SizedBox(height: 6),
                    _LinksEditor(
                      value: _links,
                      onChanged: (l) => setState(() => _links = l),
                    ),
                  ],
                ),
              ),
              // v13 sticky black header — back arrow + title + save pill.
              StickyHeader(
                title: '編輯個人檔案',
                actionLabel: '儲存',
                actionLoading: _saving,
                onAction: _saving ? null : () => _save(profile),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// v13 input decoration — exact prototype spec:
///   bg = rgba(255,255,255,0.06), border 1px line1, radius 12px,
///   12px padding, no counter (we hide maxLength counter manually
///   if it causes vertical drift, which it doesn't in current spec).
InputDecoration _v13InputDeco(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0x0FFFFFFF), // 0.06
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
      borderSide: BorderSide(color: AppTheme.line2, width: 1),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.textMute,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
            ));
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.url,
    required this.newBytes,
    required this.onPick,
  });
  final String? url;
  final Uint8List? newBytes;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    Widget inner;
    if (newBytes != null) {
      inner = Image.memory(newBytes!, fit: BoxFit.cover);
    } else if (url != null && url!.isNotEmpty) {
      inner = CachedNetworkImage(
        imageUrl: url!,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => Icon(LucideIcons.user,
            size: 48, color: AppTheme.textFaint),
      );
    } else {
      inner = Icon(LucideIcons.user, size: 48, color: AppTheme.textFaint);
    }
    return GestureDetector(
      onTap: onPick,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          ClipOval(
            child: SizedBox(width: 96, height: 96, child: inner),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.text,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.bg, width: 2),
            ),
            child: Icon(LucideIcons.camera, size: 14, color: AppTheme.bg),
          ),
        ],
      ),
    );
  }
}

class _GenderPicker extends StatelessWidget {
  const _GenderPicker({required this.value, required this.onChanged});
  final Gender? value;
  final ValueChanged<Gender?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final g in Gender.values)
          _GenderChip(
            label: g.labelZh,
            selected: value == g,
            onTap: () => onChanged(value == g ? null : g),
          ),
      ],
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.text : AppTheme.chipBg,
            border: Border.all(
              color: selected ? AppTheme.text : AppTheme.line1,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? AppTheme.bg : AppTheme.text,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}

class _LinksEditor extends StatefulWidget {
  const _LinksEditor({required this.value, required this.onChanged});
  final List<ProfileLink> value;
  final ValueChanged<List<ProfileLink>> onChanged;

  @override
  State<_LinksEditor> createState() => _LinksEditorState();
}

class _LinksEditorState extends State<_LinksEditor> {
  void _addRow() {
    final next = List<ProfileLink>.from(widget.value)
      ..add(const ProfileLink(label: '', url: ''));
    widget.onChanged(next);
  }

  void _updateRow(int i, ProfileLink l) {
    final next = List<ProfileLink>.from(widget.value)..[i] = l;
    widget.onChanged(next);
  }

  void _removeRow(int i) {
    final next = List<ProfileLink>.from(widget.value)..removeAt(i);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.value.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _LinkRow(
              link: widget.value[i],
              onChanged: (l) => _updateRow(i, l),
              onRemove: () => _removeRow(i),
            ),
          ),
        OutlinedButton.icon(
          onPressed: widget.value.length >= 5 ? null : _addRow,
          icon: const Icon(LucideIcons.plus, size: 14),
          label: Text(widget.value.length >= 5 ? '最多 5 個連結' : '新增連結'),
        ),
      ],
    );
  }
}

class _LinkRow extends StatefulWidget {
  const _LinkRow({
    required this.link,
    required this.onChanged,
    required this.onRemove,
  });
  final ProfileLink link;
  final ValueChanged<ProfileLink> onChanged;
  final VoidCallback onRemove;

  @override
  State<_LinkRow> createState() => _LinkRowState();
}

class _LinkRowState extends State<_LinkRow> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.link.label);
    _urlCtrl = TextEditingController(text: widget.link.url);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: TextField(
            controller: _labelCtrl,
            decoration: _v13InputDeco('IG / 網站'),
            onChanged: (v) => widget.onChanged(
              ProfileLink(label: v, url: _urlCtrl.text),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _urlCtrl,
            decoration: _v13InputDeco('https://...'),
            keyboardType: TextInputType.url,
            onChanged: (v) => widget.onChanged(
              ProfileLink(label: _labelCtrl.text, url: v),
            ),
          ),
        ),
        IconButton(
          icon: Icon(LucideIcons.x, size: 16, color: AppTheme.textMute),
          onPressed: widget.onRemove,
        ),
      ],
    );
  }
}
