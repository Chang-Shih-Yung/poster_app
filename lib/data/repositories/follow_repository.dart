import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/social.dart';
import '../providers/supabase_providers.dart';

/// Lightweight user record returned by [FollowRepository.listFollowing]
/// and [FollowRepository.listFollowers]. Only the fields the 粉絲 /
/// 追蹤中 list UI actually renders.
class FollowedProfile {
  const FollowedProfile({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.bio,
  });
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? bio;

  factory FollowedProfile.fromEmbeddedUsers({
    required Map<String, dynamic> embedded,
    required String fallbackId,
  }) {
    return FollowedProfile(
      userId: (embedded['id'] ?? fallbackId).toString(),
      displayName: (embedded['display_name'] ?? '').toString(),
      avatarUrl: embedded['avatar_url']?.toString(),
      bio: embedded['bio']?.toString(),
    );
  }
}

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

  /// Accounts that [viewerId] is following. Follow graph is public under
  /// the current RLS so any signed-in viewer can read any other user's
  /// outgoing edges.
  Future<List<FollowedProfile>> listFollowing(String viewerId) =>
      _listRelated(viewerId: viewerId, followers: false);

  /// Accounts that follow [viewerId] (粉絲).
  Future<List<FollowedProfile>> listFollowers(String viewerId) =>
      _listRelated(viewerId: viewerId, followers: true);

  /// Shared query for both directions. Uses **column-name** FK hints
  /// (`users!followee_id`) rather than constraint-name hints
  /// (`users!follows_followee_id_fkey`) so a future `ALTER TABLE …
  /// RENAME CONSTRAINT` can't silently turn this into "empty list".
  Future<List<FollowedProfile>> _listRelated({
    required String viewerId,
    required bool followers,
  }) async {
    // When listing FOLLOWERS we want the follower side of each edge:
    //   filter: followee_id = viewerId
    //   embed: users keyed off follower_id
    // When listing FOLLOWING it's the opposite.
    final embedCol = followers ? 'follower_id' : 'followee_id';
    final filterCol = followers ? 'followee_id' : 'follower_id';
    final embed =
        'users!$embedCol(id, display_name, avatar_url, bio)';

    final rows = await _client
        .from('follows')
        .select('$embedCol, created_at, $embed')
        .eq(filterCol, viewerId)
        .order('created_at', ascending: false);

    return ((rows as List?) ?? const [])
        .map((r) {
          final row = r as Map<String, dynamic>;
          final embedded = row['users'] as Map<String, dynamic>?;
          if (embedded == null) return null;
          return FollowedProfile.fromEmbeddedUsers(
            embedded: embedded,
            fallbackId: row[embedCol].toString(),
          );
        })
        .whereType<FollowedProfile>()
        .toList(growable: false);
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
