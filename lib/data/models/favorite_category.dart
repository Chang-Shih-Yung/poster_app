class FavoriteCategory {
  const FavoriteCategory({
    required this.id,
    required this.userId,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
  });

  factory FavoriteCategory.fromRow(Map<String, dynamic> row) {
    return FavoriteCategory(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      name: row['name'] as String,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  final String id;
  final String userId;
  final String name;
  final int sortOrder;
  final DateTime createdAt;
}
