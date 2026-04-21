import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/auth_repository.dart';

/// Shared tab index for the bottom nav.
///   0 = 探索 (home)
///   1 = 我的 (library with favorites default)
/// Plus two "action" tabs that don't change page but push routes:
///   ＋ → /upload
///   ♥ → /notifications
class ShellTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setIndex(int index) => state = index;
}

final shellTabProvider =
    NotifierProvider<ShellTabNotifier, int>(ShellTabNotifier.new);

/// v18 shell — floating glass pill tab bar with **4 slots**:
///   [home] [＋] [heart♥] [avatar]
///
/// - home / avatar swap the IndexedStack child
/// - ＋ pushes /upload (bottom-up slide handled by GoRouter config)
/// - heart pushes /notifications
/// - avatar shows the user's profile pic, gains a ring when active
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: children,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset + 20,
            child: Center(
              child: _GlassPillTabBar(currentIndex: currentIndex),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPillTabBar extends ConsumerWidget {
  const _GlassPillTabBar({required this.currentIndex});
  final int currentIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).asData?.value;
    return Glass(
      blur: 18,
      tint: 0.6,
      borderRadius: BorderRadius.circular(999),
      padding: const EdgeInsets.all(5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconTab(
            iconInactive: LucideIcons.house,
            iconActive: LucideIcons.house,
            activeIsFilled: true,
            label: '探索',
            active: currentIndex == 0,
            onTap: () => _switchTab(context, 0),
          ),
          const SizedBox(width: 2),
          _IconTab(
            iconInactive: LucideIcons.plus,
            iconActive: LucideIcons.plus,
            label: '新增',
            active: false, // action tab, never stays active
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/upload');
            },
          ),
          const SizedBox(width: 2),
          _IconTab(
            iconInactive: LucideIcons.heart,
            // Stroke heart → filled Material favorite for active state
            // (Lucide is stroke-only). We never show active=true here
            // (notification is a push route), but a red dot marks unread.
            iconActive: Icons.favorite,
            label: '通知',
            active: false,
            badgeDot: true, // TODO: wire real unread-count source
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/notifications');
            },
          ),
          const SizedBox(width: 2),
          _AvatarTab(
            profile: profile,
            active: currentIndex == 1,
            onTap: () => _switchTab(context, 1),
          ),
        ],
      ),
    );
  }

  void _switchTab(BuildContext context, int index) {
    if (index == currentIndex) return;
    HapticFeedback.selectionClick();
    _AppShellScope.of(context)?.onTabChanged(index);
  }
}

class _IconTab extends StatelessWidget {
  const _IconTab({
    required this.iconInactive,
    required this.iconActive,
    required this.label,
    required this.active,
    required this.onTap,
    this.activeIsFilled = false,
    this.badgeDot = false,
  });
  final IconData iconInactive;
  final IconData iconActive;
  final String label;
  final bool active;
  final bool activeIsFilled;
  final bool badgeDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
                child: Icon(
                  active ? iconActive : iconInactive,
                  key: ValueKey(active),
                  size: 20,
                  color: Colors.white,
                ),
              ),
              if (badgeDot)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5C5C),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.black.withValues(alpha: 0.85),
                          width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar tab — circular avatar; active state = white ring around it.
class _AvatarTab extends StatelessWidget {
  const _AvatarTab({
    required this.profile,
    required this.active,
    required this.onTap,
  });
  final AppUser? profile;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '我的',
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 30,
              height: 30,
              padding: EdgeInsets.all(active ? 1.5 : 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: profile?.avatarUrl != null
                    ? CachedNetworkImage(
                        imageUrl: profile!.avatarUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => _AvatarFallback(
                            name: profile?.displayName ?? '?'),
                      )
                    : _AvatarFallback(
                        name: profile?.displayName ?? '?'),
              ),
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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: Colors.white,
            ),
      ),
    );
  }
}

class _AppShellScope extends InheritedWidget {
  const _AppShellScope({
    required this.onTabChanged,
    required super.child,
  });
  final void Function(int) onTabChanged;

  static _AppShellScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AppShellScope>();

  @override
  bool updateShouldNotify(_AppShellScope oldWidget) =>
      onTabChanged != oldWidget.onTabChanged;
}

class AppShellWrapper extends ConsumerWidget {
  const AppShellWrapper({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(shellTabProvider);
    return _AppShellScope(
      onTabChanged: (i) => ref.read(shellTabProvider.notifier).setIndex(i),
      child: AppShell(
        currentIndex: index,
        children: children,
      ),
    );
  }
}
