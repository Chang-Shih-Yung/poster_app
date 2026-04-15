import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  final auth = ref.watch(authStateChangesProvider);
  return auth.whenOrNull(data: (s) => s.session?.user) ??
      ref.watch(supabaseClientProvider).auth.currentUser;
});

final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});
