import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/social.dart';
import '../providers/supabase_providers.dart';

/// Thin wrapper around the follow-related RPCs.
/// Keeps the Dart surface small: toggle + stats + paging helpers.
class FollowRepository {
  FollowRepository(this._client);
  final SupabaseClient _client;

  /// Toggle follow / unfollow the given user. Returns true if now following.
  /// Throws if the caller tries to follow themselves — DB check catches it
  /// too, but the RPC returns a readable error first.
  Future<bool> toggle(String userId) async {
    final result =
        await _client.rpc('toggle_follow', params: {'p_user_id': userId});
    return (result as bool?) ?? false;
  }

  /// Fetch counts + directional flags for a profile.
  Future<UserRelationshipStats> stats(String userId) async {
    final result = await _client
        .rpc('user_relationship_stats', params: {'p_user_id': userId});
    if (result == null) return UserRelationshipStats.empty;
    return UserRelationshipStats.fromRow(result as Map<String, dynamic>);
  }
}

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return FollowRepository(ref.watch(supabaseClientProvider));
});

/// Stats provider — auto-disposes so re-opening a profile refetches.
final userRelationshipStatsProvider = FutureProvider.autoDispose
    .family<UserRelationshipStats, String>((ref, userId) async {
  return ref.watch(followRepositoryProvider).stats(userId);
});
