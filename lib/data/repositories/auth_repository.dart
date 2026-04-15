import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../providers/supabase_providers.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Future<void> signInWithGoogle() async {
    final redirectTo = kIsWeb
        ? null
        : 'io.supabase.posterapp://login-callback/';
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<AppUser?> fetchProfile(String userId) async {
    final row = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return AppUser.fromRow(row);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final currentProfileProvider = FutureProvider<AppUser?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(authRepositoryProvider).fetchProfile(user.id);
});
