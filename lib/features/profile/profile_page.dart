import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_user.dart';
import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/favorite_repository.dart';
import '../../data/repositories/submission_repository.dart';
import '../../data/repositories/user_repository.dart';

/// Profile page — v11 simplified.
///
/// Only accessible when signed in (via library avatar).
/// Identity card + submissions row + admin row + sign-out.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      // Shouldn't happen in v11 (profile only reachable when signed in),
      // but handle gracefully.
      return const Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(child: Text('請先登入')),
      );
    }

    final profileAsync = ref.watch(currentProfileProvider);
    return profileAsync.when(
      loading: () => Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.textMute,
          ),
        ),
      ),
      error: (e, _) => Center(
        child: Text('載入失敗：$e',
            style: TextStyle(color: AppTheme.textMute)),
      ),
      data: (profile) =>
          _SignedInView(email: user.email ?? '', profile: profile),
    );
  }
}

class _SignedInView extends ConsumerWidget {
  const _SignedInView({required this.email, required this.profile});

  final String email;
  final AppUser? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionsAsync = ref.watch(mySubmissionsV2Provider);
    final favCount = ref.watch(favoriteIdsProvider).asData?.value.length;
    final topInset = MediaQuery.paddingOf(context).top;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, topInset + 56, 20, 120),
      children: [
        _IdentityCard(email: email, profile: profile),
        const SizedBox(height: 20),
        _SectionLabel(label: '你的內容'),
        const SizedBox(height: 10),
        _CardRow(
          icon: LucideIcons.heart,
          label: '我的收藏',
          trailing: favCount?.toString(),
          onTap: () => context.push('/me/favorites'),
        ),
        const SizedBox(height: 8),
        _CardRow(
          icon: LucideIcons.upload,
          label: '我的投稿',
          trailing: submissionsAsync.asData?.value.length.toString(),
          onTap: () => context.push('/me/submissions'),
        ),
        if (profile?.isAdmin == true) ...[
          const SizedBox(height: 20),
          _SectionLabel(label: '管理'),
          const SizedBox(height: 10),
          _CardRow(
            icon: LucideIcons.shieldCheck,
            label: 'Admin 審核',
            onTap: () => context.push('/admin'),
          ),
          const SizedBox(height: 8),
          _CardRow(
            icon: LucideIcons.tag,
            label: '分類建議審核',
            onTap: () => context.push('/admin/tag-suggestions'),
          ),
        ],
        const SizedBox(height: 20),
        _SectionLabel(label: '個人檔案設定'),
        const SizedBox(height: 10),
        _PrivacyToggle(profile: profile),
        const SizedBox(height: 8),
        _BioRow(profile: profile),
        const SizedBox(height: 28),
        _GhostPill(
          label: '登出',
          icon: LucideIcons.logOut,
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(authRepositoryProvider).signOut();
          },
        ),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.email, required this.profile});
  final String email;
  final AppUser? profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = profile?.displayName.trim() ?? '';
    final name = displayName.isNotEmpty ? displayName : email.split('@').first;
    final avatar = profile?.avatarUrl;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.line1),
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 56,
              height: 56,
              child: avatar != null
                  ? CachedNetworkImage(
                      imageUrl: avatar,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _AvatarFallback(name: name),
                    )
                  : _AvatarFallback(name: name),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMute,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (profile?.isAdmin == true) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.chipBgStrong,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'ADMIN',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return Container(
      color: AppTheme.chipBgStrong,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.textMute,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppTheme.surfaceRaised,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.line1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.text),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) ...[
                Text(
                  trailing!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMute,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(LucideIcons.chevronRight,
                  size: 16, color: AppTheme.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyToggle extends ConsumerStatefulWidget {
  const _PrivacyToggle({required this.profile});
  final AppUser? profile;

  @override
  ConsumerState<_PrivacyToggle> createState() => _PrivacyToggleState();
}

class _PrivacyToggleState extends ConsumerState<_PrivacyToggle> {
  bool? _optimistic;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPublic = _optimistic ?? widget.profile?.isPublic ?? true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        border: Border.all(color: AppTheme.line1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            isPublic ? LucideIcons.globe : LucideIcons.lock,
            size: 20,
            color: AppTheme.text,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '公開個人檔案',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPublic ? '其他使用者可以看到你的收藏與投稿' : '只有你自己看得到',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppTheme.textMute),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isPublic,
            onChanged: _saving || widget.profile == null
                ? null
                : (v) => _toggle(v),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(bool next) async {
    final profile = widget.profile;
    if (profile == null) return;

    setState(() {
      _optimistic = next;
      _saving = true;
    });
    HapticFeedback.selectionClick();
    try {
      await ref
          .read(userRepositoryProvider)
          .updateOwnProfile(userId: profile.id, isPublic: next);
      ref.invalidate(currentProfileProvider);
    } catch (e) {
      setState(() => _optimistic = !next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失敗：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _BioRow extends ConsumerWidget {
  const _BioRow({required this.profile});
  final AppUser? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bio = profile?.bio?.trim() ?? '';
    return _CardRow(
      icon: LucideIcons.pencilLine,
      label: bio.isEmpty ? '寫一段自介' : '自介：$bio',
      onTap: () => _editBio(context, ref),
    );
  }

  Future<void> _editBio(BuildContext context, WidgetRef ref) async {
    final profile = this.profile;
    if (profile == null) return;

    final controller = TextEditingController(text: profile.bio ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('編輯自介'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '介紹一下你自己、你收藏的風格…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('儲存'),
          ),
        ],
      ),
    );
    if (result == null) return;

    try {
      await ref
          .read(userRepositoryProvider)
          .updateOwnProfile(userId: profile.id, bio: result);
      ref.invalidate(currentProfileProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失敗：$e')),
        );
      }
    }
  }
}

class _GhostPill extends StatelessWidget {
  const _GhostPill({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
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
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.line2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppTheme.textMute),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.textMute,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
