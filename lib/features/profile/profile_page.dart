import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/app_user.dart';
import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/auth_repository.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const _SignedOutView();

    final profileAsync = ref.watch(currentProfileProvider);
    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('載入失敗：$e')),
      data: (profile) => _SignedInView(email: user.email ?? '', profile: profile),
    );
  }
}

class _SignedOutView extends ConsumerWidget {
  const _SignedOutView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('尚未登入'),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.login),
            label: const Text('以 Google 登入'),
            onPressed: () =>
                ref.read(authRepositoryProvider).signInWithGoogle(),
          ),
        ],
      ),
    );
  }
}

class _SignedInView extends ConsumerWidget {
  const _SignedInView({required this.email, required this.profile});

  final String email;
  final AppUser? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('已登入', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Email: $email'),
          if (profile != null) ...[
            const SizedBox(height: 4),
            Text('名稱: ${profile!.displayName}'),
            Text('角色: ${profile!.role}'),
          ],
          if (profile?.isAdmin == true) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Admin 審核'),
              onPressed: () => context.push('/admin'),
            ),
          ],
          const Spacer(),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('登出'),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
    );
  }
}
