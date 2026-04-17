/// A movie/film entity. One work → many posters.
class Work {
  const Work({
    required this.id,
    required this.titleZh,
    this.titleEn,
    this.workKey,
    this.movieReleaseDate,
    this.movieReleaseYear,
    this.posterCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Work.fromRow(Map<String, dynamic> row) {
    return Work(
      id: row['id'] as String,
      workKey: row['work_key'] as String?,
      titleZh: row['title_zh'] as String,
      titleEn: row['title_en'] as String?,
      movieReleaseDate: row['movie_release_date'] != null
          ? DateTime.tryParse(row['movie_release_date'] as String)
          : null,
      movieReleaseYear: row['movie_release_year'] as int?,
      posterCount: (row['poster_count'] as int?) ?? 0,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
    );
  }

  final String id;
  final String? workKey;
  final String titleZh;
  final String? titleEn;
  final DateTime? movieReleaseDate;
  final int? movieReleaseYear;
  final int posterCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// For display: prefer Chinese title, fallback to English.
  String get displayTitle => titleZh.isNotEmpty ? titleZh : (titleEn ?? '');

  Map<String, dynamic> toInsertRow() => {
        'title_zh': titleZh,
        if (titleEn != null) 'title_en': titleEn,
        if (workKey != null) 'work_key': workKey,
        if (movieReleaseDate != null)
          'movie_release_date': movieReleaseDate!.toIso8601String().split('T').first,
        if (movieReleaseYear != null) 'movie_release_year': movieReleaseYear,
      };
}
