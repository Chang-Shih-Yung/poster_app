/// A user's favorite. V2: denorm columns removed, use JOIN for poster data.
class Favorite {
  const Favorite({
    required this.posterId,
    required this.createdAt,
    this.categoryId,
  });

  factory Favorite.fromRow(Map<String, dynamic> row) {
    return Favorite(
      posterId: row['poster_id'] as String,
      categoryId: row['category_id'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  final String posterId;
  final String? categoryId;
  final DateTime createdAt;
}
