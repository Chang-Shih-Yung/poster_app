import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ds/ds.dart';
import '../shell/app_shell.dart';

/// IG-style side drawer for the home (探索) tab.
///
/// Three nav rows (matching the reference screenshot the user sent):
///   · 收藏       → pushes a flat grid of the user's favorited posters
///                  (routes through the existing 我的 tab, which already
///                  defaults to "favorites").
///   · 為你推薦   → pushes a flat grid page of personalized picks.
///   · 追蹤中     → pushes a list of users the viewer follows.
///
/// Plus a 日 / 夜 toggle at the bottom (ties to [themeModeProvider] so
/// the app's AppTheme tokens flip on demand).
class HomeDrawer extends ConsumerWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Drawer(
      // `AppTheme.bg` is theme-aware via a static getter, but as a
      // param it's captured once. Using Theme.of keeps the drawer's
      // bg live-swapping when mode flips.
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(top: topInset + 16, bottom: bottomInset + 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header — 動態消息 title only (no X close; modern iOS
              // drawers dismiss by swipe-back or tapping the barrier).
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: const AppText.title('動態消息',
                    weight: FontWeight.w700),
              ),

              const SizedBox(height: 4),

              // Three primary nav rows in a rounded pill list.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.chipBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.line1),
                  ),
                  child: Column(
                    children: [
                      _DrawerRow(
                        icon: LucideIcons.heart,
                        label: '收藏',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop();
                          GoRouter.of(context).push('/home/collection/favorites');
                        },
                      ),
                      _DrawerDivider(),
                      _DrawerRow(
                        icon: LucideIcons.sparkles,
                        label: '為你推薦',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop();
                          GoRouter.of(context).push('/home/collection/for-you');
                        },
                      ),
                      _DrawerDivider(),
                      _DrawerRow(
                        icon: LucideIcons.users,
                        label: '追蹤中',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop();
                          GoRouter.of(context).push('/home/collection/following');
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Exposes a hook for HomePage's hamburger button to open the drawer
/// without HomePage having to know about AppShell internals.
void openHomeDrawerFrom(BuildContext context) => openHomeDrawer(context);

// ─── internals ─────────────────────────────────────────────────────────

class _DrawerRow extends StatelessWidget {
  const _DrawerRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.text),
            const SizedBox(width: 14),
            Expanded(
              child: AppText.body(
                label,
                weight: FontWeight.w500,
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 16, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }
}

class _DrawerDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: AppTheme.line1,
    );
  }
}

