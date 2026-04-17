import '../../core/constants/enums.dart';

class Poster {
  const Poster({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.uploaderId,
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
  });

  factory Poster.fromRow(Map<String, dynamic> row) {
    return Poster(
      id: row['id'] as String,
      title: row['title'] as String,
      year: row['year'] as int?,
      director: row['director'] as String?,
      tags: ((row['tags'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      posterUrl: row['poster_url'] as String,
      thumbnailUrl: row['thumbnail_url'] as String?,
      uploaderId: row['uploader_id'] as String,
      status: row['status'] as String,
      reviewNote: row['review_note'] as String?,
      viewCount: (row['view_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String),
      // V2 fields — nullable, safe for V1 rows
      workId: row['work_id'] as String?,
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
    );
  }

  // V1 fields
  final String id;
  final String title;
  final int? year;
  final String? director;
  final List<String> tags;
  final String posterUrl;
  final String? thumbnailUrl;
  final String uploaderId;
  final String status;
  final String? reviewNote;
  final int viewCount;
  final DateTime createdAt;

  // V2 fields
  final String? workId;
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
}
