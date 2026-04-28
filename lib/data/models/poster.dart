import '../../core/constants/enums.dart';

class Poster {
  const Poster({
    required this.id,
    this.title,
    this.posterUrl,
    this.uploaderId,
    required this.status,
    required this.tags,
    required this.createdAt,
    this.year,
    this.director,
    this.thumbnailUrl,
    this.reviewNote,
    this.viewCount = 0,
    // V2 fields
    this.workId,
    this.workKind,
    this.parentGroupId,
    this.isPlaceholder = false,
    this.posterName,
    this.region,
    this.posterReleaseDate,
    this.posterReleaseType,
    this.sizeType,
    this.channelCategory,
    this.channelType,
    this.channelName,
    this.isExclusive = false,
    this.exclusiveName,
    this.materialType,
    this.versionLabel,
    this.imageSizeBytes,
    this.sourceUrl,
    this.sourcePlatform,
    this.sourceNote,
    this.favoriteCount = 0,
    this.approvedAt,
    this.deletedAt,
    // Optional social/denorm fields — present when fetched via RPCs that
    // join users, absent in plain posters.* queries. Never persisted.
    this.uploaderName,
    this.uploaderAvatar,
    // v19 Phase 3 — BlurHash placeholder string (~30 base83 chars).
    // Filled by an Edge Function on upload; nullable for legacy rows
    // until the backfill completes. AppPosterTile renders BlurHash
    // when present, ShimmerPlaceholder when null.
    this.blurhash,
  });

  factory Poster.fromRow(Map<String, dynamic> row) {
    return Poster(
      id: row['id'] as String,
      // 2026-04-28: title / poster_url / uploader_id are nullable in the
      // schema now. title is still sync'd with poster_name via DB
      // trigger; poster_url is null while is_placeholder=true; uploader_id
      // is null only for legacy / system-inserted rows.
      title: row['title'] as String?,
      year: row['year'] as int?,
      director: row['director'] as String?,
      tags: ((row['tags'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      posterUrl: row['poster_url'] as String?,
      thumbnailUrl: row['thumbnail_url'] as String?,
      uploaderId: row['uploader_id'] as String?,
      status: row['status'] as String,
      reviewNote: row['review_note'] as String?,
      viewCount: (row['view_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String),
      // V2 fields — nullable, safe for V1 rows
      workId: row['work_id'] as String?,
      workKind: row['work_kind'] as String?,
      parentGroupId: row['parent_group_id'] as String?,
      isPlaceholder: (row['is_placeholder'] as bool?) ?? false,
      posterName: row['poster_name'] as String?,
      region: row['region'] != null
          ? Region.fromString(row['region'] as String)
          : null,
      posterReleaseDate: row['poster_release_date'] != null
          ? DateTime.tryParse(row['poster_release_date'] as String)
          : null,
      posterReleaseType: row['poster_release_type'] != null
          ? ReleaseType.fromString(row['poster_release_type'] as String)
          : null,
      sizeType: row['size_type'] != null
          ? SizeType.fromString(row['size_type'] as String)
          : null,
      channelCategory: row['channel_category'] != null
          ? ChannelCategory.fromString(row['channel_category'] as String)
          : null,
      channelType: row['channel_type'] as String?,
      channelName: row['channel_name'] as String?,
      isExclusive: (row['is_exclusive'] as bool?) ?? false,
      exclusiveName: row['exclusive_name'] as String?,
      materialType: row['material_type'] as String?,
      versionLabel: row['version_label'] as String?,
      imageSizeBytes: row['image_size_bytes'] as int?,
      sourceUrl: row['source_url'] as String?,
      sourcePlatform: row['source_platform'] as String?,
      sourceNote: row['source_note'] as String?,
      favoriteCount: (row['favorite_count'] as num?)?.toInt() ?? 0,
      approvedAt: row['approved_at'] != null
          ? DateTime.parse(row['approved_at'] as String)
          : null,
      deletedAt: row['deleted_at'] != null
          ? DateTime.parse(row['deleted_at'] as String)
          : null,
      uploaderName: row['uploader_name'] as String?,
      uploaderAvatar: row['uploader_avatar'] as String?,
      blurhash: row['blurhash'] as String?,
    );
  }

  // V1 fields
  final String id;
  /// Legacy column, kept in lock-step with [posterName] via DB trigger.
  /// Nullable since 2026-04-28; readers should fall back to posterName
  /// or `'(未命名)'`.
  final String? title;
  final int? year;
  final String? director;
  final List<String> tags;
  /// Null when [isPlaceholder] is true (no real image uploaded yet).
  /// Public clients should branch on isPlaceholder before rendering.
  final String? posterUrl;
  final String? thumbnailUrl;
  /// Null for legacy or system-inserted rows. Most posters have an
  /// uploader; UI should hide author chrome when this is null.
  final String? uploaderId;
  final String status;
  final String? reviewNote;
  final int viewCount;
  final DateTime createdAt;

  // V2 fields
  final String? workId;
  /// Denormalized from works.work_kind — kept in lock-step by DB triggers
  /// (see migration 20260427160000_sync_posters_work_kind.sql).
  final String? workKind;
  /// v3: leaf poster hangs off a poster_groups node. NULL for legacy v2
  /// posters that haven't been migrated into the tree yet.
  final String? parentGroupId;
  /// v3: TRUE when poster_url is still a work-kind silhouette (admin
  /// hasn't uploaded the real scan). UI uses this to show a placeholder
  /// hint and an upload affordance.
  final bool isPlaceholder;
  final String? posterName;
  final Region? region;
  final DateTime? posterReleaseDate;
  final ReleaseType? posterReleaseType;
  final SizeType? sizeType;
  final ChannelCategory? channelCategory;
  final String? channelType;
  final String? channelName;
  final bool isExclusive;
  final String? exclusiveName;
  final String? materialType;
  final String? versionLabel;
  final int? imageSizeBytes;
  final String? sourceUrl;
  final String? sourcePlatform;
  final String? sourceNote;
  final int favoriteCount;
  final DateTime? approvedAt;
  final DateTime? deletedAt;
  // Social RPC fields (never persisted; only set when fetched via
  // recent_approved_feed / trending_favorites / follow_feed).
  final String? uploaderName;
  final String? uploaderAvatar;
  // BlurHash placeholder (~30 base83 chars). Null until the Edge
  // Function backfills.
  final String? blurhash;
}
