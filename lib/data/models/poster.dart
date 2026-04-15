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
    );
  }

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
}
