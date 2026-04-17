import '../../core/constants/enums.dart';

/// A user-submitted poster pending admin review.
class Submission {
  const Submission({
    required this.id,
    required this.workTitleZh,
    required this.imageUrl,
    required this.uploaderId,
    required this.status,
    required this.createdAt,
    this.batchId,
    this.workTitleEn,
    this.movieReleaseYear,
    this.posterName,
    this.region = Region.tw,
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
    this.thumbnailUrl,
    this.imageSizeBytes,
    this.sourceUrl,
    this.sourcePlatform,
    this.sourceNote,
    this.reviewerId,
    this.reviewNote,
    this.reviewedAt,
    this.matchedWorkId,
    this.createdPosterId,
  });

  factory Submission.fromRow(Map<String, dynamic> row) {
    return Submission(
      id: row['id'] as String,
      batchId: row['batch_id'] as String?,
      workTitleZh: row['work_title_zh'] as String,
      workTitleEn: row['work_title_en'] as String?,
      movieReleaseYear: row['movie_release_year'] as int?,
      posterName: row['poster_name'] as String?,
      region: Region.fromString(row['region'] as String?),
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
      imageUrl: row['image_url'] as String,
      thumbnailUrl: row['thumbnail_url'] as String?,
      imageSizeBytes: row['image_size_bytes'] as int?,
      sourceUrl: row['source_url'] as String?,
      sourcePlatform: row['source_platform'] as String?,
      sourceNote: row['source_note'] as String?,
      uploaderId: row['uploader_id'] as String,
      status: SubmissionStatus.fromString(row['status'] as String?),
      reviewerId: row['reviewer_id'] as String?,
      reviewNote: row['review_note'] as String?,
      reviewedAt: row['reviewed_at'] != null
          ? DateTime.parse(row['reviewed_at'] as String)
          : null,
      matchedWorkId: row['matched_work_id'] as String?,
      createdPosterId: row['created_poster_id'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  final String id;
  final String? batchId;
  final String workTitleZh;
  final String? workTitleEn;
  final int? movieReleaseYear;
  final String? posterName;
  final Region region;
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
  final String imageUrl;
  final String? thumbnailUrl;
  final int? imageSizeBytes;
  final String? sourceUrl;
  final String? sourcePlatform;
  final String? sourceNote;
  final String uploaderId;
  final SubmissionStatus status;
  final String? reviewerId;
  final String? reviewNote;
  final DateTime? reviewedAt;
  final String? matchedWorkId;
  final String? createdPosterId;
  final DateTime createdAt;

  bool get isPending => status == SubmissionStatus.pending;
  bool get isApproved => status == SubmissionStatus.approved;
  bool get isRejected => status == SubmissionStatus.rejected;

  /// Build the row for inserting into submissions table.
  Map<String, dynamic> toInsertRow() => {
        'work_title_zh': workTitleZh,
        if (workTitleEn != null) 'work_title_en': workTitleEn,
        if (movieReleaseYear != null) 'movie_release_year': movieReleaseYear,
        if (posterName != null) 'poster_name': posterName,
        'region': region.value,
        if (posterReleaseDate != null)
          'poster_release_date':
              posterReleaseDate!.toIso8601String().split('T').first,
        if (posterReleaseType != null)
          'poster_release_type': posterReleaseType!.value,
        if (sizeType != null) 'size_type': sizeType!.value,
        if (channelCategory != null)
          'channel_category': channelCategory!.value,
        if (channelType != null) 'channel_type': channelType,
        if (channelName != null) 'channel_name': channelName,
        'is_exclusive': isExclusive,
        if (exclusiveName != null) 'exclusive_name': exclusiveName,
        if (materialType != null) 'material_type': materialType,
        if (versionLabel != null) 'version_label': versionLabel,
        'image_url': imageUrl,
        if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
        if (imageSizeBytes != null) 'image_size_bytes': imageSizeBytes,
        if (sourceUrl != null) 'source_url': sourceUrl,
        if (sourcePlatform != null) 'source_platform': sourcePlatform,
        if (sourceNote != null) 'source_note': sourceNote,
        'uploader_id': uploaderId,
        if (batchId != null) 'batch_id': batchId,
      };
}
