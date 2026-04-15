class Favorite {
  const Favorite({
    required this.posterId,
    required this.title,
    required this.createdAt,
    this.thumbnailUrl,
  });

  factory Favorite.fromRow(Map<String, dynamic> row) {
    return Favorite(
      posterId: row['poster_id'] as String,
      title: row['poster_title'] as String,
      thumbnailUrl: row['poster_thumbnail_url'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  final String posterId;
  final String title;
  final String? thumbnailUrl;
  final DateTime createdAt;
}
