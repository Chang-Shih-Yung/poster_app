import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/providers/supabase_providers.dart';
import '../../features/admin/admin_review_page.dart';
import '../../features/admin/admin_tag_suggestions_page.dart';
import '../../features/auth/signin_page.dart';
import '../../features/home/home_page.dart';
import '../../features/posters/library_page.dart';
import '../../features/posters/poster_detail_page.dart';
import '../../features/posters/tag_browse_page.dart';
import '../../features/posters/work_page.dart';
import '../../features/profile/my_favorites_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/profile/public_profile_page.dart';
import '../../features/search/search_page.dart';
import '../../features/shell/app_shell.dart';
import '../../features/submission/batch_submission_page.dart';
import '../../features/submission/my_submissions_page.dart';
import '../../features/submission/submission_page.dart';
import '../theme/app_theme.dart';

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

      // Sub-pages: back arrow top-left.
      GoRoute(
        path: '/upload',
        builder: (_, _) => const _BackablePage(child: SubmissionPage()),
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
        path: '/me/submissions',
        builder: (_, _) => const _BackablePage(child: MySubmissionsPage()),
      ),
      GoRoute(
        path: '/me/favorites',
        builder: (_, _) => const _BackablePage(child: MyFavoritesPage()),
      ),

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
        builder: (_, _) => const _BackablePage(child: SearchPage()),
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
    return const AppShellWrapper(
      children: [
        HomePage(),
        LibraryPage(),
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

/// Wraps sub-pages: dark scaffold + floating back arrow top-left.
class _BackablePage extends StatelessWidget {
  const _BackablePage({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppTheme.bg,
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
                        LucideIcons.arrowLeft,
                        size: 20,
                        color: AppTheme.textMute,
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
