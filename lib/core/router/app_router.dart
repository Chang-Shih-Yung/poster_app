import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/admin_review_page.dart';
import '../../features/favorites/favorites_page.dart';
import '../../features/posters/browse_page.dart';
import '../../features/posters/poster_detail_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/submission/my_submissions_page.dart';
import '../../features/submission/submission_page.dart';

final appRouter = GoRouter(
  initialLocation: '/browse',
  routes: [
    ShellRoute(
      builder: (context, state, child) => _HomeShell(child: child),
      routes: [
        GoRoute(path: '/browse', builder: (_, _) => const BrowsePage()),
        GoRoute(path: '/upload', builder: (_, _) => const SubmissionPage()),
        GoRoute(path: '/favorites', builder: (_, _) => const FavoritesPage()),
        GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
      ],
    ),
    GoRoute(
      path: '/poster/:id',
      builder: (_, state) =>
          PosterDetailPage(posterId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/admin', builder: (_, _) => const AdminReviewPage()),
    GoRoute(
      path: '/me/submissions',
      builder: (_, _) => const MySubmissionsPage(),
    ),
  ],
);

class _HomeShell extends StatelessWidget {
  const _HomeShell({required this.child});

  final Widget child;

  static const _tabs = ['/browse', '/upload', '/favorites', '/profile'];

  int _indexOf(String location) {
    final idx = _tabs.indexWhere(location.startsWith);
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _indexOf(location);
    return Scaffold(
      appBar: AppBar(title: const Text('Poster App')),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: '瀏覽'),
          NavigationDestination(icon: Icon(Icons.upload), label: '上傳'),
          NavigationDestination(icon: Icon(Icons.favorite), label: '收藏'),
          NavigationDestination(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
