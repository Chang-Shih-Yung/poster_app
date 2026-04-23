import 'poster.dart';

/// Compact user ref used inside social payloads. Smaller than AppUser —
/// intentionally so the trending / collectors RPCs stay cheap.
class MiniUser {
  const MiniUser({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory MiniUser.fromRow(Map<String, dynamic> row) {
    return MiniUser(
      id: row['id'] as String,
      name: (row['name'] as String?) ?? '',
      avatarUrl: row['avatar'] as String?,
    );
  }

  final String id;
  final String name;
  final String? avatarUrl;
}

/// One row of `trending_favorites(days, limit)`.
/// A Poster plus recent-favorite metadata for the "+N 人收藏" UI.
class TrendingPoster {
  const TrendingPoster({
    required this.poster,
    required this.recentFavCount,
    required this.collectors,
  });

  factory TrendingPoster.fromRow(Map<String, dynamic> row) {
    final collectorsRaw = (row['collectors'] as List?) ?? const [];
    return TrendingPoster(
      poster: Poster.fromRow(row),
      recentFavCount: (row['recent_fav_count'] as num?)?.toInt() ?? 0,
      collectors: collectorsRaw
          .map((c) => MiniUser.fromRow(c as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final Poster poster;
  final int recentFavCount;
  final List<MiniUser> collectors;
}

/// One row of `active_collectors(days, limit)`.
/// A user card with their recent favorited posters (thumbs only, compact).
class CollectorPreview {
  const CollectorPreview({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.submissionCount = 0,
    this.activityCount = 0,
    this.recentPosters = const [],
  });

  factory CollectorPreview.fromRow(Map<String, dynamic> row) {
    final postersRaw = (row['recent_posters'] as List?) ?? const [];
    return CollectorPreview(
      userId: row['id'] as String,
      displayName: (row['display_name'] as String?) ?? '',
      avatarUrl: row['avatar_url'] as String?,
      bio: row['bio'] as String?,
      submissionCount: (row['submission_count'] as num?)?.toInt() ?? 0,
      activityCount: (row['activity_count'] as num?)?.toInt() ?? 0,
      recentPosters: postersRaw
          .map((r) => PosterThumb.fromRow(r as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final int submissionCount;
  final int activityCount;
  final List<PosterThumb> recentPosters;
}

/// Minimal poster thumb (id + url) used inside CollectorPreview.
class PosterThumb {
  const PosterThumb({required this.id, this.thumbnailUrl, this.posterUrl});

  factory PosterThumb.fromRow(Map<String, dynamic> row) {
    return PosterThumb(
      id: row['id'] as String,
      thumbnailUrl: row['thumbnail_url'] as String?,
      posterUrl: row['poster_url'] as String?,
    );
  }

  final String id;
  final String? thumbnailUrl;
  final String? posterUrl;

  String get displayUrl => thumbnailUrl ?? posterUrl ?? '';
}

/// One row of `follow_feed(limit)`. A Poster plus actor metadata (who did what).
class FollowActivity {
  const FollowActivity({
    required this.poster,
    required this.actorId,
    required this.actorName,
    this.actorAvatar,
    required this.actionType,
    required this.actionAt,
  });

  factory FollowActivity.fromRow(Map<String, dynamic> row) {
    return FollowActivity(
      poster: Poster.fromRow(row),
      actorId: row['actor_id'] as String,
      actorName: (row['actor_name'] as String?) ?? '',
      actorAvatar: row['actor_avatar'] as String?,
      actionType: (row['action_type'] as String?) ?? 'favorite',
      actionAt: DateTime.parse(row['action_at'] as String),
    );
  }

  final Poster poster;
  final String actorId;
  final String actorName;
  final String? actorAvatar;
  final String actionType;
  final DateTime actionAt;
}

/// v19 round 10: IG-style follow states. Private accounts require a
/// request-approval round-trip; accepted means the edge is live.
enum FollowStatus {
  /// No outbound edge from the viewer to this target.
  none,

  /// Viewer requested to follow a private account; target hasn't
  /// approved yet.
  pending,

  /// Follow edge is live; viewer sees the target's private content.
  accepted,

  /// The target IS the viewer — can't follow yourself.
  self;

  static FollowStatus fromRaw(String? s) {
    switch (s) {
      case 'pending':
        return FollowStatus.pending;
      case 'accepted':
        return FollowStatus.accepted;
      case 'self':
        return FollowStatus.self;
      default:
        return FollowStatus.none;
    }
  }
}

/// Result of `user_relationship_stats(p_user_id)`.
class UserRelationshipStats {
  const UserRelationshipStats({
    required this.followerCount,
    required this.followingCount,
    required this.viewerStatus,
    required this.isFollowingMe,
  });

  factory UserRelationshipStats.fromRow(Map<String, dynamic> row) {
    // Legacy `is_following` flag (the pre-v10 RPC returned
    // `am_i_following`; the post-v10 RPC returns `is_following`).
    // If neither is present but we have viewer_follow_status, derive.
    final rawStatus = row['viewer_follow_status'] as String?;
    final derived = FollowStatus.fromRaw(rawStatus);
    return UserRelationshipStats(
      followerCount: (row['follower_count'] as num?)?.toInt() ?? 0,
      followingCount: (row['following_count'] as num?)?.toInt() ?? 0,
      viewerStatus: derived != FollowStatus.none
          ? derived
          : ((row['is_following'] as bool?) ??
                  (row['am_i_following'] as bool?) ??
                  false)
              ? FollowStatus.accepted
              : FollowStatus.none,
      isFollowingMe: (row['is_following_me'] as bool?) ?? false,
    );
  }

  static const empty = UserRelationshipStats(
    followerCount: 0,
    followingCount: 0,
    viewerStatus: FollowStatus.none,
    isFollowingMe: false,
  );

  final int followerCount;
  final int followingCount;
  final FollowStatus viewerStatus;
  final bool isFollowingMe;

  /// Back-compat shim: true iff the viewer has an accepted follow
  /// edge. Callers that only cared about "is this follow live"
  /// keep working without changes.
  bool get amIFollowing => viewerStatus == FollowStatus.accepted;

  /// Pending request from viewer to target — pill shows
  /// "等待確認" / "取消請求".
  bool get viewerHasPendingRequest => viewerStatus == FollowStatus.pending;
}
