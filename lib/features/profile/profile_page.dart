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
import '../shell/app_shell.dart';

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
          onTap: () {
            // 我的收藏 = 我的 tab filtered by favorites (default).
            // Jump to tab 1 + pop profile page so the shell is visible.
            ref.read(shellTabProvider.notifier).setIndex(1);
            context.pop();
          },
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
        _CardRow(
          icon: LucideIcons.userPen,
          label: '編輯個人檔案',
          onTap: () => context.push('/profile/edit'),
        ),
        const SizedBox(height: 8),
        _PrivacyToggle(profile: profile),
        const SizedBox(height: 28),
        _GhostPill(
          label: '登出',
          icon: LucideIcons.logOut,
          onTap: () async {
            HapticFeedback.selectionClick();
            // Pop the profile page first so we don't briefly render
            // signed-out content with auth-required widgets still mounted.
            // Then await Supabase signOut and force-navigate to /signin
            // (the GoRouter redirect would also fire, but we don't want
            // to depend on the auth-stream race winning before any
            // already-loaded provider tries to refetch with no session).
            final router = GoRouter.of(context);
            await ref.read(authRepositoryProvider).signOut();
            // Drop any cached user-scoped data so the next sign-in
            // doesn't briefly flash the previous account's profile.
            ref.invalidate(currentProfileProvider);
            router.go('/signin');
          },
        ),
      ],
    );
  }
}

/// v13 identity row — IG-style: 64×64 avatar + name/bio + inline 編輯 pill.
/// No card chrome (lets the cool ink background read as primary), only
/// a hairline at the bottom to mark the section break.
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
    final bio = profile?.bio?.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 64×64 avatar with subtle line border (v13 spec).
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.line2),
            ),
            child: ClipOval(
              child: avatar != null
                  ? CachedNetworkImage(
                      imageUrl: avatar,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _AvatarFallback(name: name),
                    )
                  : _AvatarFallback(name: name),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (profile?.isAdmin == true) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.chipBgStrong,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'ADMIN',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  bio?.isNotEmpty == true ? bio! : email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMute,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Inline 編輯 pill — direct affordance, no need to scroll.
          const _EditPill(),
        ],
      ),
    );
  }
}

/// v13 inline 編輯 pill — opens /profile/edit. Sits on the right side
/// of the identity row.
class _EditPill extends StatelessWidget {
  const _EditPill();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.chipBg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          GoRouter.of(context).push('/profile/edit');
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.line2),
          ),
          alignment: Alignment.center,
          child: Text(
            '編輯',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  letterSpacing: 0,
                ),
          ),
        ),
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

// _BioRow removed — profile editing is now done via the dedicated
// /profile/edit page (see profile_edit_page.dart).

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
