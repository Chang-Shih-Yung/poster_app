/// Recursive grouping node between a Work and its leaf Posters.
///
/// The shape of the tree is editor-defined per work — most works follow
/// the convention `release_era` → `variant` → leaf poster, but the table
/// allows any depth. A NULL parentGroupId means the group is a top-level
/// child of the work.
class PosterGroup {
  const PosterGroup({
    required this.id,
    required this.workId,
    required this.name,
    this.parentGroupId,
    this.groupType,
    this.displayOrder = 0,
    this.coverUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory PosterGroup.fromRow(Map<String, dynamic> row) {
    return PosterGroup(
      id: row['id'] as String,
      workId: row['work_id'] as String,
      parentGroupId: row['parent_group_id'] as String?,
      name: row['name'] as String,
      groupType: row['group_type'] as String?,
      displayOrder: (row['display_order'] as int?) ?? 0,
      coverUrl: row['cover_url'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
    );
  }

  final String id;
  final String workId;
  final String? parentGroupId;
  final String name;

  /// 'release_era' | 'variant' | custom — informational, not enforced.
  final String? groupType;
  final int displayOrder;
  final String? coverUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
