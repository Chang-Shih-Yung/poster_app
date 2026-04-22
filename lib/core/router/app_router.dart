import 'package:flutter/cupertino.dart' show CupertinoPage;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/providers/supabase_providers.dart';
import '../../features/admin/admin_review_page.dart';
import '../../features/admin/admin_tag_suggestions_page.dart';
import '../../features/auth/signin_page.dart';
import '../../features/home/home_collection_page.dart';
import '../../features/home/home_page.dart';
import '../../features/notifications/notifications_page.dart';
import '../../features/posters/library_page.dart';
import '../../features/posters/poster_detail_page.dart';
import '../../features/posters/tag_browse_page.dart';
import '../../features/posters/work_page.dart';
import '../../features/profile/profile_edit_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/profile/public_profile_page.dart';
import '../../features/search/search_page.dart';
import '../../features/shell/app_shell.dart';
import '../../features/submission/batch_submission_page.dart';
import '../../features/submission/my_submissions_page.dart';
import '../../features/submission/submission_page.dart';
import '../theme/app_theme.dart';
import '../theme/theme_mode_notifier.dart';

/// Fires whenever auth state changes so GoRouter re-evaluates redirects.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(
      authStateChangesProvider,
      (_, _) => notifyListeners(),
      fireImmediately: false,
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final signedIn = ref.read(isSignedInProvider);
      final loc = state.matchedLocation;
      final onSignin = loc == '/signin';
      if (!signedIn && !onSignin) return '/signin';
      if (signedIn && onSignin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/signin', builder: (_, _) => const SigninPage()),

      // Main shell: bottom nav with 探索 + 我的.
      GoRoute(
        path: '/',
        pageBuilder: (_, _) => const NoTransitionPage(
          child: _MainShell(),
        ),
      ),

      // Keep old paths as aliases.
      GoRoute(path: '/library', redirect: (_, _) => '/'),
      GoRoute(path: '/browse', redirect: (_, _) => '/'),

      // Sub-pages: floating back arrow top-left for pages without their
      // own header. v13 pages with sticky black headers (/upload,
      // /profile/edit) skip the floating back so we don't double up.
      GoRoute(
        path: '/upload',
        pageBuilder: (_, state) => _SheetPage(
          key: state.pageKey,
          child: const _SheetShell(child: SubmissionPage()),
        ),
      ),
      // /notifications is now rendered inside the shell as tab index
      // 2 (so the bottom nav stays visible). The heart icon on the
      // bottom nav switches tabs directly. This path is kept so
      // deep links still land in the right place — and we schedule
      // the tab switch in a post-frame callback so the redirect
      // itself stays a pure function (mutating provider state
      // during route evaluation is fragile + fires on every
      // refreshListenable tick).
      GoRoute(
        path: '/notifications',
        redirect: (_, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(shellTabProvider.notifier).setIndex(2);
          });
          return '/';
        },
      ),
      GoRoute(
        path: '/home/collection/:mode',
        // Right → left iOS push (via CupertinoPage). Flutter's
        // CupertinoPageRoute plumbs the left-edge swipe-back gesture
        // automatically, which is what the user expects from 粉絲 /
        // 追蹤中 / 收藏 / 為你推薦 push screens. HomeCollectionPage
        // renders its own chevron-left top bar so we don't wrap in
        // _BackablePage (would double up the back chrome).
        pageBuilder: (_, state) {
          final mode =
              parseHomeCollectionMode(state.pathParameters['mode'] ?? '');
          return CupertinoPage<void>(
            key: state.pageKey,
            child: HomeCollectionPage(mode: mode),
          );
        },
      ),
      GoRoute(
        path: '/upload/batch',
        builder: (_, _) => const _BackablePage(child: BatchSubmissionPage()),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const _BackablePage(child: ProfilePage()),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const ProfileEditPage(),
      ),
      GoRoute(
        path: '/me/submissions',
        builder: (_, _) => const _BackablePage(child: MySubmissionsPage()),
      ),
      // /me/favorites route removed — 我的收藏 now routes to the 我的
      // bottom tab (LibraryPage with pillFavorites=true default).

      // Detail: slide-up modal transition.
      GoRoute(
        path: '/poster/:id',
        pageBuilder: (_, state) => _SlideUpPage(
          key: state.pageKey,
          child: PosterDetailPage(posterId: state.pathParameters['id']!),
        ),
      ),

      GoRoute(
        path: '/work/:id',
        builder: (_, state) => _BackablePage(
          child: WorkPage(workId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/tags/:slug',
        builder: (_, state) => _BackablePage(
          child: TagBrowsePage(slug: state.pathParameters['slug']!),
        ),
      ),
      GoRoute(
        path: '/user/:id',
        builder: (_, state) => _BackablePage(
          child: PublicProfilePage(userId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/search',
        // SearchPage owns its own top bar (chevron + 搜尋 title) so we
        // don't wrap it in _BackablePage — would double up the back chrome.
        builder: (_, _) => const SearchPage(),
      ),

      GoRoute(path: '/admin', builder: (_, _) => const AdminReviewPage()),
      GoRoute(
        path: '/admin/tag-suggestions',
        builder: (_, _) => const AdminTagSuggestionsPage(),
      ),
    ],
  );
});

/// Main shell with bottom nav.
class _MainShell extends StatelessWidget {
  const _MainShell();

  @override
  Widget build(BuildContext context) {
    // tab 0 (探索) → HomePage     — sectioned recommendation feed (trending,
    //                                 collectors, for_you, follow_feed...)
    // tab 1 (我的) → LibraryPage  — filter chrome + L/M/S + masonry, defaults
    //                                 to my favorites (_pillFavorites=true)
    // tab 2 (通知) → NotificationsPage — heart icon on the bottom nav.
    //                                     Kept as a shell child instead of a
    //                                     push route so the nav stays visible
    //                                     while you browse notifications.
    return const AppShellWrapper(
      children: [
        HomePage(),
        LibraryPage(),
        NotificationsPage(),
      ],
    );
  }
}

/// Slide-up page transition for detail modal.
class _SlideUpPage extends CustomTransitionPage<void> {
  _SlideUpPage({required super.child, required super.key})
      : super(
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final tween = Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        );
}

/// iOS-style partial modal sheet — slides up from the bottom, leaves
/// a narrow gap at the top showing the dimmed content underneath.
/// Used for the upload flow so it reads as a modal overlay instead of
/// a full page push.
class _SheetPage extends CustomTransitionPage<void> {
  _SheetPage({required super.child, required super.key})
      : super(
          opaque: false,
          barrierDismissible: false,
          // Theme-aware barrier. Day mode gets a pale haze
          // (`AppTheme.scrim` = black 18%) instead of a blackout
          // curtain so the underlying white scaffold shows through
          // as fade-not-dim. Night mode still dims to charcoal.
          barrierColor: AppTheme.scrim,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            final slide = animation.drive(
              Tween(begin: const Offset(0, 1), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeOutCubic)),
            );
            return SlideTransition(position: slide, child: child);
          },
        );
}

/// Visual shell for the upload sheet: leaves a visible gap at the
/// top (so the viewer can tell it's a modal, not a full page) and
/// rounds the top corners. No drag handle — modern iOS sheets have
/// dropped them, the rounded top + gap already signals "sheet".
///
/// Swipe-down dismiss: a [GestureDetector] on the top 40px of the
/// sheet captures vertical drags. A drag of more than 80px down pops
/// the route. Matches iOS modal-sheet conventions; the rest of the
/// sheet scrolls normally so form content is unaffected.
class _SheetShell extends StatefulWidget {
  const _SheetShell({required this.child});
  final Widget child;

  @override
  State<_SheetShell> createState() => _SheetShellState();
}

class _SheetShellState extends State<_SheetShell> {
  double _dragY = 0;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    // ~safe-area top + 32: leaves enough dimmed barrier showing so
    // the sheet doesn't melt into the underlying ink canvas.
    final gap = topInset + 32 + _dragY.clamp(0.0, 400.0);
    return Padding(
      padding: EdgeInsets.only(top: gap),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: Stack(
          children: [
            widget.child,
            // Top 40px grab strip — gesture only, invisible. Drag the
            // title/cancel bar down to dismiss.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 40,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: (details) {
                  if (details.primaryDelta == null) return;
                  setState(() {
                    _dragY = (_dragY + details.primaryDelta!).clamp(0.0, 400.0);
                  });
                },
                onVerticalDragEnd: (details) {
                  final flung =
                      (details.primaryVelocity ?? 0) > 700 || _dragY > 80;
                  if (flung) {
                    Navigator.of(context).maybePop();
                  } else {
                    setState(() => _dragY = 0);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps sub-pages: dark scaffold + floating back arrow top-left.
/// Watches the theme mode so every push route rebuilds top-down when
/// the user toggles day/night — otherwise the pushed widget tree is
/// cached by the Navigator and any `AppTheme.bg`-using child stays
/// stale until the user navigates.
class _BackablePage extends ConsumerWidget {
  const _BackablePage({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeModeProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      
      body: Stack(
        children: [
          Positioned.fill(child: child),
          // Floating back button.
          Positioned(
            top: topInset + 12,
            left: 16,
            child: Semantics(
              label: '返回',
              button: true,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go('/');
                    }
                  },
                  borderRadius: BorderRadius.circular(999),
                  splashColor: Colors.white.withValues(alpha: 0.08),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Icon(
                        LucideIcons.chevronLeft,
                        size: 24,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
