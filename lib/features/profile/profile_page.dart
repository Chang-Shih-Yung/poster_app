import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/ds/ds.dart';
import '../../data/models/app_user.dart';
import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/auth_repository.dart';
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
      // Reaches here only transiently — between signOut() firing and
      // the router's auth listener redirecting to /signin. A loader
      // reads as "switching..." rather than the alarming "請先登入"
      // on an otherwise-blank page the user saw for half a second.
      return const Scaffold(body: AppLoader.centered());
    }

    final profileAsync = ref.watch(currentProfileProvider);
    return profileAsync.when(
      loading: () => const AppLoader.centered(),
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
    final topInset = MediaQuery.paddingOf(context).top;

    // "你的內容" section (我的收藏 / 我的投稿) removed — both
    // destinations are already reachable from the 我的 tab's stats
    // row (粉絲 / 追蹤中 / 已通過) and the home drawer's 收藏 entry.
    // Keeping them here felt duplicative once those wiring up.
    return ListView(
      padding: EdgeInsets.only(top: topInset + 56, bottom: 120),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _IdentityCard(email: email, profile: profile),
        ),
        if (profile?.isAdmin == true) ...[
          const SizedBox(height: 28),
          _SectionLabel(label: '管理'),
          const SizedBox(height: 4),
          AppSettingsRow(
            icon: LucideIcons.shieldCheck,
            label: 'Admin 審核',
            onTap: () => context.push('/admin'),
          ),
          AppSettingsRow(
            icon: LucideIcons.tag,
            label: '分類建議審核',
            onTap: () => context.push('/admin/tag-suggestions'),
          ),
        ],
        const SizedBox(height: 20),
        _SectionLabel(label: '個人檔案設定'),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _PrivacyToggle(profile: profile),
        ),
        const SizedBox(height: 28),
        // Two text-link actions. Monochrome design: 切換帳號 is neutral
        // white text, 登出 is destructive red. Same AppButton.text
        // variant, distinguished by the `destructive` flag.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppButton.text(
              label: '切換帳號',
              onPressed: () =>
                  _signOutAndGo(context, ref, switchAccount: true),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppButton.text(
              label: '登出',
              destructive: true,
              onPressed: () =>
                  _signOutAndGo(context, ref, switchAccount: false),
            ),
          ),
        ),
      ],
    );
  }

  /// Two paths out of the signed-in profile page.
  ///
  /// **Switch account** ([switchAccount] = true): do NOT call
  /// `signOut()`. Just navigate to `/signin?switch=1` — the sign-in
  /// page picks up the flag and immediately fires Google OAuth with
  /// `prompt=select_account`, so the user sees the account chooser.
  /// When they pick a different Google account, Supabase atomically
  /// replaces the session; the auth listener (in app_router) detects
  /// the user id change and invalidates every user-scoped cache.
  /// Picking the same account is a no-op, which is the right
  /// behaviour for "I changed my mind".
  ///
  /// **Sign out** ([switchAccount] = false): navigate first so
  /// ProfilePage dismounts before the session drops (otherwise the
  /// rebuild-with-null-user shows a loader flash). Then await
  /// `signOut()` and invalidate caches defensively — the auth
  /// listener will do the same, but this pair of calls makes the
  /// cleanup deterministic.
  Future<void> _signOutAndGo(
    BuildContext context,
    WidgetRef ref, {
    required bool switchAccount,
  }) async {
    HapticFeedback.selectionClick();
    final router = GoRouter.of(context);

    if (switchAccount) {
      router.go('/signin?switch=1');
      return;
    }

    // Logout — await signOut, then navigate. Cache invalidation is
    // NOT duplicated here; _AuthListenable (in app_router) watches
    // the auth stream and invalidates every user-scoped provider
    // whenever the user id changes. Doing it here AND there was
    // causing a race when both fired against family providers
    // (publicProfileProvider / userRelationshipStatsProvider) with
    // active watchers mid-rebuild — visible as an uncaught error in
    // the console even though logout ultimately worked. One owner
    // of this cleanup is enough.
    await ref.read(authRepositoryProvider).signOut();
    router.go('/signin');
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
                      child: AppText.bodyBold(
                        name,
                        size: 17,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (profile?.isAdmin == true) ...[
                      const SizedBox(width: 6),
                      const AppBadge(label: 'ADMIN'),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                AppText.caption(
                  bio?.isNotEmpty == true ? bio! : email,
                  tone: AppTextTone.muted,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // 編輯 pill removed per v18 spec — editing profile now
          // lives only via the library (我的) → 編輯檔案 affordance.
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
      child: AppText.title(letter),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    // Aligned to the 20px gutter used by AppSettingsRow / other body
    // content, so the eyebrow sits flush with the rows below it.
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'NotoSansTC',
          fontSize: 10,
          color: AppTheme.textMute,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w600,
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
                const AppText.body('公開個人檔案', weight: FontWeight.w500),
                const SizedBox(height: 2),
                AppText.caption(
                  isPublic ? '其他使用者可以看到你的收藏與投稿' : '只有你自己看得到',
                  tone: AppTextTone.muted,
                ),
              ],
            ),
          ),
          // Explicit CupertinoSwitch — `Switch.adaptive` was falling
          // back to the Material visual on Android web (which renders
          // as the user's "原生的破東西" complaint). Forcing Cupertino
          // gives the iOS pill-shaped toggle on every platform.
          CupertinoSwitch(
            value: isPublic,
            activeTrackColor: AppTheme.accent2,
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

