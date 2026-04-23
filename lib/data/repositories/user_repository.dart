import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../providers/supabase_providers.dart';
import 'auth_repository.dart' show currentProfileProvider;
import 'social_repository.dart' show homeSectionsV2Provider;

/// Public profile payload returned by the `user_public_profile` RPC.
/// Separate from [AppUser] because it includes aggregated stats.
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.handle,
    this.submissionCount = 0,
    this.approvedPosterCount = 0,
    this.viewerReported = false,
    this.isPublic = true,
    this.viewerFollowStatus = 'none',
  });

  factory PublicProfile.fromRow(Map<String, dynamic> row) {
    return PublicProfile(
      id: row['id'] as String,
      displayName: (row['display_name'] as String?) ?? '',
      avatarUrl: row['avatar_url'] as String?,
      bio: row['bio'] as String?,
      handle: row['handle'] as String?,
      submissionCount: (row['submission_count'] as int?) ?? 0,
      approvedPosterCount:
          (row['approved_poster_count'] as int?) ?? 0,
      viewerReported: (row['viewer_reported'] as bool?) ?? false,
      isPublic: (row['is_public'] as bool?) ?? true,
      viewerFollowStatus:
          (row['viewer_follow_status'] as String?) ?? 'none',
    );
  }

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String? handle;
  final int submissionCount;
  final int approvedPosterCount;

  /// True when the current auth'd viewer has already submitted an
  /// avatar report for this target — used by the `檢舉頭像` sheet
  /// to render the action as already-done.
  final bool viewerReported;

  /// Mirror of users.is_public on the server. When false, the viewer
  /// only sees this profile's shell (name + handle + bio + counts)
  /// unless they're an accepted follower.
  final bool isPublic;

  /// One of 'none' | 'pending' | 'accepted' | 'self'. Used to gate
  /// private-profile content visibility on the client.
  final String viewerFollowStatus;

  /// True iff the viewer should be shown the target's posters / grids.
  /// Public profiles are always open. Private profiles require an
  /// accepted follow (or being the user themselves).
  bool get viewerCanSeeContent =>
      isPublic ||
      viewerFollowStatus == 'accepted' ||
      viewerFollowStatus == 'self';
}

class UserRepository {
  UserRepository(this._client);
  final SupabaseClient _client;

  /// Search public users by display name. Trims query, returns empty on blank.
  Future<List<AppUser>> search(String query, {int limit = 20}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final rows = await _client.rpc('search_users', params: {
      'p_query': q,
      'p_limit': limit,
    });
    return (rows as List)
        .map((r) => AppUser.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Get a public profile by ID. Returns null if user is private or missing.
  Future<PublicProfile?> getPublicProfile(String userId) async {
    final result =
        await _client.rpc('user_public_profile', params: {'p_user_id': userId});
    if (result == null) return null;
    return PublicProfile.fromRow(result as Map<String, dynamic>);
  }

  /// Update current user's profile fields. Pass only the fields you want
  /// to change; null = leave alone. Empty string = clear bio/etc.
  /// For [handle] specifically: empty string = clear (set to null);
  /// otherwise the DB CHECK constraint enforces shape (lowercase
  /// letter-leading, alnum + underscore, 3-20 chars). On collision
  /// the unique-index throws — caller surfaces the error to the UI.
  Future<void> updateOwnProfile({
    required String userId,
    bool? isPublic,
    String? bio,
    String? displayName,
    String? avatarUrl,
    Gender? gender,
    List<ProfileLink>? links,
    String? handle,
  }) async {
    final row = <String, dynamic>{};
    if (isPublic != null) row['is_public'] = isPublic;
    if (bio != null) row['bio'] = bio;
    if (displayName != null) row['display_name'] = displayName;
    if (avatarUrl != null) row['avatar_url'] = avatarUrl;
    if (gender != null) row['gender'] = gender.value;
    if (links != null) {
      row['links'] = links.map((l) => l.toJson()).toList();
    }
    if (handle != null) {
      row['handle'] = handle.isEmpty ? null : handle.toLowerCase();
    }
    if (row.isEmpty) return;

    await _client.from('users').update(row).eq('id', userId);
  }

  /// Report another user's avatar as inappropriate. Calls the
  /// `report_avatar` RPC; the DB enforces "one report per (reporter,
  /// target)" via UNIQUE — re-tapping is a no-op.
  Future<void> reportAvatar(String targetUserId, {String? reason}) async {
    await _client.rpc('report_avatar', params: {
      'p_target_user_id': targetUserId,
      'p_reason': reason,
    });
  }

  /// Upload an avatar image to the avatars bucket. Returns the public URL.
  /// Old avatar (if any) is left in place — Supabase storage doesn't auto-
  /// clean. We pick a new path each upload (uuid suffix) to bust caches.
  ///
  /// v19: after upload, fire-and-forget the `avatar-moderation` Edge
  /// Function. It runs server-side NSFW classification via Hugging
  /// Face Inference API and writes `users.avatar_status` to
  /// ok / pending_review / rejected. Failing open (on HF outage /
  /// timeout) is intentional — the user-report path already catches
  /// anything the model misses.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final ext = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final objectKey =
        '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from('avatars').uploadBinary(
          objectKey,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    final url = _client.storage.from('avatars').getPublicUrl(objectKey);
    unawaited(_moderateAvatar(userId: userId, imageUrl: url));
    return url;
  }

  Future<void> _moderateAvatar({
    required String userId,
    required String imageUrl,
  }) async {
    try {
      await _client.functions.invoke(
        'avatar-moderation',
        body: {'user_id': userId, 'image_url': imageUrl},
      );
    } catch (_) {
      // Soft-fail — avatar_status defaults to 'ok' on the DB side.
      // The server-side report trigger is the safety net.
    }
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(supabaseClientProvider));
});

final publicProfileProvider =
    FutureProvider.autoDispose.family<PublicProfile?, String>((ref, id) async {
  return ref.watch(userRepositoryProvider).getPublicProfile(id);
});

final userSearchProvider =
    FutureProvider.autoDispose.family<List<AppUser>, String>((ref, query) async {
  return ref.watch(userRepositoryProvider).search(query);
});

/// Invalidate every provider that carries user-facing data for [userId].
///
/// Call this after ANY mutation that changes how a user is displayed across
/// the app: avatar, displayName, bio, gender, links — and in the future,
/// follow/unfollow counts, role badges, etc.
///
/// Why a single helper: native apps (iOS / Android) don't have "F5". The
/// only way to make a screen show fresh data is to invalidate the providers
/// that source it. Profile fields surface in many places (header card,
/// uploader badges on poster cards, active-collectors row, follow feed,
/// public profile page, search results). Centralising this so every future
/// caller does the right thing.
///
/// Strategy:
///   - non-autoDispose providers: always invalidate (the home tab is
///     persistent in the IndexedStack so it actively listens — invalidate
///     triggers refetch immediately).
///   - autoDispose family providers (publicProfileProvider, _postersByUploader,
///     unifiedSearchProvider, browseByTagProvider, _posterByIdProvider...):
///     when the page leaves the tree they auto-tear-down; on next entry
///     they refetch with the latest joined user data. We still invalidate
///     publicProfileProvider(self) because the user might be viewing their
///     own `/user/<self>` route.
void invalidateUserSurfaces(WidgetRef ref, String userId) {
  // Always-watched (persistent in IndexedStack):
  ref.invalidate(currentProfileProvider);
  ref.invalidate(homeSectionsV2Provider);
  // Family — own public profile may be currently shown:
  ref.invalidate(publicProfileProvider(userId));
}
