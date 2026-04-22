import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart'
    show
        CupertinoActionSheet,
        CupertinoActionSheetAction,
        CupertinoSwitch,
        showCupertinoModalPopup;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_notifier.dart';
import '../../core/widgets/app_loader.dart';
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
      padding: EdgeInsets.fromLTRB(20, topInset + 56, 20, 120),
      children: [
        _IdentityCard(email: email, profile: profile),
        if (profile?.isAdmin == true) ...[
          const SizedBox(height: 28),
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
        _SectionLabel(label: '外觀'),
        const SizedBox(height: 10),
        const _ThemeModeRow(),
        const SizedBox(height: 20),
        _SectionLabel(label: '個人檔案設定'),
        const SizedBox(height: 10),
        // 編輯個人檔案 row removed — the inline 編輯 pill on the
        // identity card at the top already does the same thing, and
        // having both felt like duplication on a thin settings page.
        _PrivacyToggle(profile: profile),
        const SizedBox(height: 28),
        // 切換帳號 (accent text) — Supabase keeps only one session per
        // client, so functionally this is the same as signing out and
        // signing back in. We surface it separately because users
        // coming from IG/Threads expect the affordance; it keeps the
        // sign-in screen's Google button primed for a different
        // account without the mental overhead of "did I really just
        // log out for good?".
        _TextActionRow(
          label: '切換帳號',
          color: AppTheme.accent2,
          onTap: () => _signOutAndGo(context, ref, switchAccount: true),
        ),
        const SizedBox(height: 4),
        _TextActionRow(
          label: '登出',
          color: AppTheme.danger,
          onTap: () => _signOutAndGo(context, ref, switchAccount: false),
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

/// Borderless text-link row — used for 登出 / 切換帳號. No icon, no
/// card chrome; just a coloured label that fills the row so it reads
/// as a commitment (vs an ordinary settings list item).
class _TextActionRow extends StatelessWidget {
  const _TextActionRow({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
          ),
        ),
      ),
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
  });
  final IconData icon;
  final String label;
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
              Icon(LucideIcons.chevronRight,
                  size: 16, color: AppTheme.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Theme row — tap the row to open a CupertinoActionSheet with
/// 白天 / 夜晚 / 系統預設. Replaces the segmented pill (which looked
/// like a browser form control). Matches the iOS Settings pattern.
class _ThemeModeRow extends ConsumerWidget {
  const _ThemeModeRow();

  String _labelFor(AppThemeMode m) => switch (m) {
        AppThemeMode.day => '白天',
        AppThemeMode.night => '夜晚',
        AppThemeMode.system => '系統預設',
      };

  IconData _iconFor(AppThemeMode m) => switch (m) {
        AppThemeMode.day => LucideIcons.sun,
        AppThemeMode.night => LucideIcons.moon,
        AppThemeMode.system => LucideIcons.sunMoon,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Material(
      color: AppTheme.surfaceRaised,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _openSheet(context, ref),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.line1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(_iconFor(mode), size: 20, color: AppTheme.text),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '主題',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              Text(
                _labelFor(mode),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMute,
                    ),
              ),
              const SizedBox(width: 6),
              Icon(LucideIcons.chevronRight,
                  size: 16, color: AppTheme.textFaint),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    // NotoSansTC override — Cupertino widgets default to SF Pro and
    // tofu CJK on first paint without this.
    const font = TextStyle(fontFamily: 'NotoSansTC');
    final current = ref.read(themeModeProvider);
    final picked = await showCupertinoModalPopup<AppThemeMode>(
      context: context,
      builder: (ctx) => DefaultTextStyle.merge(
        style: font,
        child: CupertinoActionSheet(
          title: const Text('主題', style: font),
          actions: [
            for (final m in AppThemeMode.values)
              CupertinoActionSheetAction(
                onPressed: () => Navigator.of(ctx).pop(m),
                isDefaultAction: m == current,
                child: Text(_labelFor(m), style: font),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消', style: font),
          ),
        ),
      ),
    );
    if (picked != null) {
      await ref.read(themeModeProvider.notifier).setMode(picked);
    }
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

