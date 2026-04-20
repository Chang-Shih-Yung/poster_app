/// A facet of the taxonomy (國別 / 年代 / 媒材 / 設計師 …).
class TagCategory {
  const TagCategory({
    required this.id,
    required this.slug,
    required this.titleZh,
    required this.titleEn,
    required this.position,
    required this.kind,
    this.descriptionZh,
    this.descriptionEn,
    this.icon,
    this.isRequired = false,
    this.allowOther = true,
    this.allowsSuggestion = true,
  });

  factory TagCategory.fromRow(Map<String, dynamic> row) {
    return TagCategory(
      id: row['id'] as String,
      slug: row['slug'] as String,
      titleZh: row['title_zh'] as String,
      titleEn: row['title_en'] as String,
      descriptionZh: row['description_zh'] as String?,
      descriptionEn: row['description_en'] as String?,
      position: (row['position'] as num?)?.toInt() ?? 0,
      icon: row['icon'] as String?,
      kind: row['kind'] as String? ?? 'free_tag',
      isRequired: (row['is_required'] as bool?) ?? false,
      allowOther: (row['allow_other'] as bool?) ?? true,
      allowsSuggestion: (row['allows_suggestion'] as bool?) ?? true,
    );
  }

  final String id;
  final String slug;
  final String titleZh;
  final String titleEn;
  final String? descriptionZh;
  final String? descriptionEn;
  final int position;
  final String? icon;
  /// 'enum' | 'controlled_vocab' | 'free_tag'
  final String kind;
  final bool isRequired;
  final bool allowOther;
  final bool allowsSuggestion;
}

/// A canonical tag belonging to one category.
class Tag {
  const Tag({
    required this.id,
    required this.slug,
    required this.categoryId,
    required this.labelZh,
    required this.labelEn,
    this.aliases = const [],
    this.posterCount = 0,
    this.isCanonical = true,
    this.isOtherFallback = false,
    this.deprecated = false,
    this.description,
  });

  factory Tag.fromRow(Map<String, dynamic> row) {
    return Tag(
      id: row['id'] as String,
      slug: row['slug'] as String,
      categoryId: row['category_id'] as String,
      labelZh: row['label_zh'] as String,
      labelEn: row['label_en'] as String,
      description: row['description'] as String?,
      aliases: ((row['aliases'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      posterCount: (row['poster_count'] as num?)?.toInt() ?? 0,
      isCanonical: (row['is_canonical'] as bool?) ?? true,
      isOtherFallback: (row['is_other_fallback'] as bool?) ?? false,
      deprecated: (row['deprecated'] as bool?) ?? false,
    );
  }

  final String id;
  final String slug;
  final String categoryId;
  final String labelZh;
  final String labelEn;
  final String? description;
  final List<String> aliases;
  final int posterCount;
  final bool isCanonical;
  /// True when this is the synthetic "其他 Other" fallback tag for a
  /// required category. Usually hidden from search suggestions except when
  /// no other match exists.
  final bool isOtherFallback;
  final bool deprecated;
}

/// Result of `find_similar_tags` RPC — an existing tag with a fuzzy-match
/// similarity score (0.3-1.0) against a user-typed label. Used for
/// duplicate-detection hints in admin review and user suggestion forms.
class SimilarTag {
  const SimilarTag({
    required this.tagId,
    required this.slug,
    required this.labelZh,
    required this.labelEn,
    required this.similarity,
    this.aliases = const [],
    this.posterCount = 0,
    this.categorySlug,
    this.categoryTitleZh,
  });

  factory SimilarTag.fromRow(Map<String, dynamic> row) {
    return SimilarTag(
      tagId: row['tag_id'] as String,
      slug: row['slug'] as String,
      labelZh: row['label_zh'] as String,
      labelEn: (row['label_en'] as String?) ?? '',
      aliases: ((row['aliases'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      posterCount: (row['poster_count'] as num?)?.toInt() ?? 0,
      similarity: (row['similarity'] as num?)?.toDouble() ?? 0.0,
      categorySlug: row['category_slug'] as String?,
      categoryTitleZh: row['category_title_zh'] as String?,
    );
  }

  final String tagId;
  final String slug;
  final String labelZh;
  final String labelEn;
  final List<String> aliases;
  final int posterCount;
  final double similarity;
  // When cross-category search is used (admin view), these tell admin
  // which category the matched tag actually lives in — e.g. user put
  // "院線" under 編輯精選, match is "院線首刷" under 版本.
  final String? categorySlug;
  final String? categoryTitleZh;

  /// Percentage (0-100) for UI display.
  int get similarityPercent => (similarity * 100).round();

  /// Auto-merge happens silently at this threshold (matches SQL).
  static const double autoMergeThreshold = 0.95;

  /// Show user "did you mean?" suggestion at this threshold.
  static const double strongHintThreshold = 0.75;

  /// Show admin "may be duplicate" hint at this threshold.
  static const double weakHintThreshold = 0.50;
}

/// A user-submitted new-tag suggestion awaiting admin review.
class TagSuggestion {
  const TagSuggestion({
    required this.id,
    required this.suggestedLabelZh,
    required this.categoryId,
    required this.status,
    required this.createdAt,
    this.suggestedBy,
    this.suggestedSlug,
    this.suggestedLabelEn,
    this.reason,
    this.linkedSubmissionId,
    this.mergedIntoTagId,
    this.reviewedBy,
    this.reviewedAt,
    this.adminNote,
  });

  factory TagSuggestion.fromRow(Map<String, dynamic> row) {
    return TagSuggestion(
      id: row['id'] as String,
      suggestedBy: row['suggested_by'] as String?,
      suggestedSlug: row['suggested_slug'] as String?,
      suggestedLabelZh: row['suggested_label_zh'] as String,
      suggestedLabelEn: row['suggested_label_en'] as String?,
      categoryId: row['category_id'] as String,
      reason: row['reason'] as String?,
      linkedSubmissionId: row['linked_submission_id'] as String?,
      status: row['status'] as String? ?? 'pending',
      mergedIntoTagId: row['merged_into_tag_id'] as String?,
      reviewedBy: row['reviewed_by'] as String?,
      reviewedAt: row['reviewed_at'] != null
          ? DateTime.parse(row['reviewed_at'] as String)
          : null,
      adminNote: row['admin_note'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  final String id;
  final String? suggestedBy;
  final String? suggestedSlug;
  final String suggestedLabelZh;
  final String? suggestedLabelEn;
  final String categoryId;
  final String? reason;
  final String? linkedSubmissionId;
  final String status; // pending | approved | rejected | merged
  final String? mergedIntoTagId;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? adminNote;
  final DateTime createdAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isMerged => status == 'merged';
}
