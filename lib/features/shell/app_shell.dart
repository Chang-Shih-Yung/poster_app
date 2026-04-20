import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass.dart';

/// Shared tab index for the bottom nav. Exposed so any route can jump
/// the shell to a specific tab without lifting state via nav args.
///   0 = 探索 (home)
///   1 = 我的 (library with favorites default)
class ShellTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setIndex(int index) => state = index;
}

final shellTabProvider =
    NotifierProvider<ShellTabNotifier, int>(ShellTabNotifier.new);

/// v13 shell — content is full-bleed under the device safe area, and a
/// **floating glass pill island** hovers at the bottom centre with two
/// circular icons (home + heart). No more full-width bottom bar.
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
      // extendBody so the glass pill floats over the content edge.
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
            // 28dp from bottom safe area — matches v13 prototype.
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

class _GlassPillTabBar extends StatelessWidget {
  const _GlassPillTabBar({required this.currentIndex});
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Glass(
      blur: 18,
      tint: 0.6,
      borderRadius: BorderRadius.circular(999),
      padding: const EdgeInsets.all(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillIcon(
            icon: LucideIcons.house,
            active: currentIndex == 0,
            label: '探索',
            onTap: () => _onTap(context, 0),
          ),
          const SizedBox(width: 4),
          _PillIcon(
            // When active, swap stroke heart → filled heart for the
            // "saved/loved" visual. Lucide is stroke-only so we use
            // Material's favorite icon for the filled state.
            icon: currentIndex == 1
                ? Icons.favorite
                : LucideIcons.heart,
            active: currentIndex == 1,
            label: '我的',
            onTap: () => _onTap(context, 1),
          ),
        ],
      ),
    );
  }

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    HapticFeedback.selectionClick();
    _AppShellScope.of(context)?.onTabChanged(index);
  }
}

class _PillIcon extends StatelessWidget {
  const _PillIcon({
    required this.icon,
    required this.active,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final bool active;
  final String label;
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: AppTheme.easeStandard,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              icon,
              size: 18,
              color: active ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// InheritedWidget to pass tab-change callback down.
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

/// Stateful shell wrapper. Tab index is backed by [shellTabProvider]
/// so external pages can jump tabs by reading the provider.
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
