import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';

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

/// Shell with bottom navigation: 探索 (home) / 我的 (library).
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
      body: IndexedStack(
        index: currentIndex,
        children: children,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.line1, width: 0.5)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 8),
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                _NavItem(
                  icon: LucideIcons.compass,
                  label: '探索',
                  active: currentIndex == 0,
                  onTap: () => _onTap(context, 0),
                ),
                _NavItem(
                  icon: LucideIcons.libraryBig,
                  label: '我的',
                  active: currentIndex == 1,
                  onTap: () => _onTap(context, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    HapticFeedback.selectionClick();
    // Navigate via the shell callback.
    _AppShellScope.of(context)?.onTabChanged(index);
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: active ? AppTheme.text : AppTheme.textFaint,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: active ? AppTheme.text : AppTheme.textFaint,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 10,
                  ),
            ),
          ],
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

/// Stateful shell wrapper.
/// Tab index is now backed by [shellTabProvider] so external pages
/// (e.g. profile → 我的收藏) can jump tabs by reading the provider.
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
