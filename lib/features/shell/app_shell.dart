import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_notifier.dart';
import '../../core/widgets/glass.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/auth_repository.dart';
import '../home/home_drawer.dart';

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
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Opens the IG-style home drawer (愛心/為你推薦/追蹤中 + 日夜切換).
  /// Called by HomePage's hamburger button via [_AppShellScope.openDrawer].
  void openDrawer() => _scaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      // Theme-aware drawer scrim — dark fade on night, near-white
      // pale fade on day. Default black-at-54% read as a blackout
      // curtain on the new white day scaffold.
      drawerScrimColor: AppTheme.scrim,
      // Drawer only makes sense on the Explore (home) tab, but it's
      // cheap to keep it mounted here — the drawer widget itself is
      // stateless and the hamburger affordance only appears on home.
      drawer: const HomeDrawer(),
      drawerEdgeDragWidth: widget.currentIndex == 0 ? 24 : 0,
      body: Stack(
        children: [
          IndexedStack(
            index: widget.currentIndex,
            children: widget.children,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset + 20,
            child: Center(
              child: _GlassPillTabBar(currentIndex: widget.currentIndex),
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
      // Denser glass for the floating dock — darker + blurrier so the
      // pill reads as a physical object over any bright background
      // (day mode white scaffold especially). Matches the reference
      // travel app's floating dock.
      blur: 22,
      tint: 0.82,
      borderRadius: BorderRadius.circular(999),
      padding: const EdgeInsets.all(5),
      // Kill the 1px inset top highlight — on the floating pill it
      // reads as a stray divider "above the icons", which the user
      // flagged as an artifact. The pill border alone is enough to
      // separate it from the background.
      highlight: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconTab(
            iconInactive: LucideIcons.house,
            // Material filled variant for the active state — Lucide is
            // stroke-only so the active state needs a different glyph
            // to register as "selected".
            iconActive: Icons.home_rounded,
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
            // Filled Material favorite when the tab is active — same
            // pattern as the house tab.
            iconActive: Icons.favorite,
            label: '通知',
            active: currentIndex == 2,
            badgeDot: currentIndex != 2, // hide dot while actively viewing
            onTap: () => _switchTab(context, 2),
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
    this.badgeDot = false,
  });
  final IconData iconInactive;
  final IconData iconActive;
  final String label;
  final bool active;
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
                      color: AppTheme.unreadDot,
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
    final trimmed = name.trim();
    // Right after sign-in the profile hasn't loaded, so name may be
    // empty or a stub "?". Instead of rendering a glaring question
    // mark on the nav bar, fall back to a flat muted silhouette —
    // same IG/Threads "empty avatar" pattern the rest of the UI
    // just got aligned to.
    if (trimmed.isEmpty || trimmed == '?') {
      return Container(color: AppTheme.chipBgStrong);
    }
    final letter = trimmed.characters.first.toUpperCase();
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
    required this.onOpenDrawer,
    required super.child,
  });
  final void Function(int) onTabChanged;
  final VoidCallback onOpenDrawer;

  static _AppShellScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AppShellScope>();

  @override
  bool updateShouldNotify(_AppShellScope oldWidget) =>
      onTabChanged != oldWidget.onTabChanged ||
      onOpenDrawer != oldWidget.onOpenDrawer;
}

/// Called by HomePage's hamburger button.
void openHomeDrawer(BuildContext context) {
  _AppShellScope.of(context)?.onOpenDrawer();
}

class AppShellWrapper extends ConsumerStatefulWidget {
  const AppShellWrapper({super.key, required this.children});
  final List<Widget> children;

  @override
  ConsumerState<AppShellWrapper> createState() => _AppShellWrapperState();
}

class _AppShellWrapperState extends ConsumerState<AppShellWrapper> {
  final GlobalKey<_AppShellState> _shellKey = GlobalKey<_AppShellState>();

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(shellTabProvider);
    // Watch theme mode so every IndexedStack child rebuilds top-down
    // when the user flips day/night — without this, widgets that
    // read `AppTheme.bg` directly (not via Theme.of) stay stale
    // until their parent rebuilds for some other reason.
    ref.watch(themeModeProvider);
    return _AppShellScope(
      onTabChanged: (i) => ref.read(shellTabProvider.notifier).setIndex(i),
      onOpenDrawer: () => _shellKey.currentState?.openDrawer(),
      child: AppShell(
        key: _shellKey,
        currentIndex: index,
        children: widget.children,
      ),
    );
  }
}
