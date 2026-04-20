import 'poster.dart';
import 'social.dart';

/// One home-page section as returned by `home_sections_v2` RPC.
///
/// Sections come from DB config rows (`home_sections_config`). Each has
/// a `sourceType` that tells the client which card widget to render:
///   - popular / tag_slug / recent_approved  → `List<Poster>`
///   - trending_favorites                    → `List<TrendingPoster>`
///   - active_collectors                     → `List<CollectorPreview>`
///   - follow_feed                           → `List<FollowActivity>`
class HomeSectionV2 {
  const HomeSectionV2({
    required this.slug,
    required this.titleZh,
    required this.titleEn,
    required this.sourceType,
    required this.rawItems,
    this.icon,
    this.sourceParams = const {},
  });

  factory HomeSectionV2.fromRow(Map<String, dynamic> row) {
    return HomeSectionV2(
      slug: row['slug'] as String,
      titleZh: row['title_zh'] as String,
      titleEn: row['title_en'] as String,
      icon: row['icon'] as String?,
      sourceType: row['source_type'] as String,
      sourceParams:
          (row['source_params'] as Map<String, dynamic>?) ?? const {},
      rawItems: (row['items'] as List?)
              ?.cast<Map<String, dynamic>>()
              .toList(growable: false) ??
          const [],
    );
  }

  final String slug;
  final String titleZh;
  final String titleEn;
  final String? icon;
  final String sourceType;
  final Map<String, dynamic> sourceParams;

  /// Raw items — client dispatches based on [sourceType] to parse into
  /// the appropriate model.
  final List<Map<String, dynamic>> rawItems;

  /// Parse rawItems as `List<Poster>`. Used by sections whose source_type
  /// returns plain poster rows (popular / tag_slug / recent_approved).
  List<Poster> asPosters() =>
      rawItems.map(Poster.fromRow).toList(growable: false);

  /// Parse rawItems as `List<TrendingPoster>` — for trending_favorites.
  List<TrendingPoster> asTrending() =>
      rawItems.map(TrendingPoster.fromRow).toList(growable: false);

  /// Parse rawItems as `List<CollectorPreview>` — for active_collectors.
  List<CollectorPreview> asCollectors() =>
      rawItems.map(CollectorPreview.fromRow).toList(growable: false);

  /// Parse rawItems as `List<FollowActivity>` — for follow_feed.
  List<FollowActivity> asFollowFeed() =>
      rawItems.map(FollowActivity.fromRow).toList(growable: false);

  /// Client-side filter: hide section if its items are empty.
  /// Server already did visibility filtering; this catches the case
  /// where a visible section returned 0 rows (e.g. new tag with no
  /// posters yet).
  bool get isEmpty => rawItems.isEmpty;
}
