import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../providers/supabase_providers.dart';

/// Public profile payload returned by the `user_public_profile` RPC.
/// Separate from [AppUser] because it includes aggregated stats.
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.submissionCount = 0,
    this.approvedPosterCount = 0,
  });

  factory PublicProfile.fromRow(Map<String, dynamic> row) {
    return PublicProfile(
      id: row['id'] as String,
      displayName: (row['display_name'] as String?) ?? '',
      avatarUrl: row['avatar_url'] as String?,
      bio: row['bio'] as String?,
      submissionCount: (row['submission_count'] as int?) ?? 0,
      approvedPosterCount:
          (row['approved_poster_count'] as int?) ?? 0,
    );
  }

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final int submissionCount;
  final int approvedPosterCount;
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
  Future<void> updateOwnProfile({
    required String userId,
    bool? isPublic,
    String? bio,
    String? displayName,
    String? avatarUrl,
    Gender? gender,
    List<ProfileLink>? links,
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
    if (row.isEmpty) return;

    await _client.from('users').update(row).eq('id', userId);
  }

  /// Upload an avatar image to the avatars bucket. Returns the public URL.
  /// Old avatar (if any) is left in place — Supabase storage doesn't auto-
  /// clean. We pick a new path each upload (uuid suffix) to bust caches.
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
    return _client.storage.from('avatars').getPublicUrl(objectKey);
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
