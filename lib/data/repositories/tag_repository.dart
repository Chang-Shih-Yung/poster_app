import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/poster.dart';
import '../models/tag.dart';
import '../providers/supabase_providers.dart';

/// CRUD-light access to the tag taxonomy. Writes are admin-only (RLS
/// enforced). User-side write goes through [TagSuggestionRepository].
class TagRepository {
  TagRepository(this._client);
  final SupabaseClient _client;

  /// Fetch all categories ordered by position.
  Future<List<TagCategory>> listCategories() async {
    final rows = await _client
        .from('tag_categories')
        .select()
        .order('position', ascending: true);
    return (rows as List)
        .map((r) => TagCategory.fromRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// All canonical (non-deprecated) tags in a category, ordered by
  /// poster_count descending so popular tags float to top of picker.
  /// The 其他 fallback tag floats to the bottom.
  Future<List<Tag>> listByCategory(String categoryId) async {
    final rows = await _client
        .from('tags')
        .select()
        .eq('category_id', categoryId)
        .eq('deprecated', false)
        .order('is_other_fallback', ascending: true)
        .order('poster_count', ascending: false)
        .order('label_zh');
    return (rows as List)
        .map((r) => Tag.fromRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Search across all tags (label_zh / label_en / aliases).
  /// Used by the autocomplete picker.
  ///
  /// Trimming + empty-guard so a lone spacebar key doesn't fire a query.
  Future<List<Tag>> search(String query, {int limit = 12}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    // PostgREST: match label_zh ilike OR label_en ilike OR aliases contains.
    // Sanitize commas+parens from user input (same lesson as R4 audit).
    final safe =
        q.replaceAll(RegExp(r'[,()]'), '').replaceAll('%', r'\%');
    if (safe.isEmpty) return const [];

    final rows = await _client
        .from('tags')
        .select()
        .eq('deprecated', false)
        .or('label_zh.ilike.%$safe%,label_en.ilike.%$safe%,aliases.cs.{$safe}')
        .order('poster_count', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => Tag.fromRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Find similar existing tags by similarity score (pg_trgm).
  /// Returns tags with `similarity` 0.3-1.0. Used for:
  ///   - Admin review card's duplicate hint
  ///   - User-side autocomplete in suggestion form
  Future<List<SimilarTag>> findSimilar({
    required String categoryId,
    required String label,
    int limit = 5,
  }) async {
    final q = label.trim();
    if (q.isEmpty) return const [];
    final rows = await _client.rpc('find_similar_tags', params: {
      'p_category_id': categoryId,
      'p_label': q,
      'p_limit': limit,
    });
    return ((rows as List?) ?? const [])
        .map((r) => SimilarTag.fromRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Browse posters by tag slug. Returns {tag, posters[]}. Empty posters
  /// with null tag if slug not found.
  Future<({Tag? tag, List<Poster> posters})> browseByTag(
    String slug, {
    int limit = 50,
    int offset = 0,
  }) async {
    final result = await _client.rpc('browse_posters_by_tag', params: {
      'p_tag_slug': slug,
      'p_limit': limit,
      'p_offset': offset,
    });
    if (result == null) return (tag: null, posters: const <Poster>[]);
    final map = result as Map<String, dynamic>;
    final tagRow = map['tag'];
    final postersList = (map['posters'] as List?) ?? const [];
    return (
      tag: tagRow != null
          ? Tag.fromRow(tagRow as Map<String, dynamic>)
          : null,
      posters: postersList
          .map((r) => Poster.fromRow(r as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  /// Tags attached to a specific poster (for displaying on detail page).
  Future<List<Tag>> listForPoster(String posterId) async {
    final rows = await _client
        .from('poster_tags')
        .select('tag:tags(*)')
        .eq('poster_id', posterId);
    return (rows as List)
        .map((r) => Tag.fromRow((r as Map<String, dynamic>)['tag']
            as Map<String, dynamic>))
        .toList(growable: false);
  }
}

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepository(ref.watch(supabaseClientProvider));
});

/// Cached categories — rarely change, safe to hold.
final tagCategoriesProvider =
    FutureProvider<List<TagCategory>>((ref) async {
  return ref.watch(tagRepositoryProvider).listCategories();
});

/// Tags by category, cached per-category.
final tagsByCategoryProvider =
    FutureProvider.family<List<Tag>, String>((ref, categoryId) async {
  return ref.watch(tagRepositoryProvider).listByCategory(categoryId);
});

/// Tag search for autocomplete.
final tagSearchProvider =
    FutureProvider.autoDispose.family<List<Tag>, String>((ref, q) async {
  return ref.watch(tagRepositoryProvider).search(q);
});

/// Tags attached to a given poster.
final tagsForPosterProvider =
    FutureProvider.autoDispose.family<List<Tag>, String>((ref, posterId) async {
  return ref.watch(tagRepositoryProvider).listForPoster(posterId);
});

/// Tag browse page: {tag, posters[]}.
final browseByTagProvider = FutureProvider.autoDispose
    .family<({Tag? tag, List<Poster> posters}), String>((ref, slug) async {
  return ref.watch(tagRepositoryProvider).browseByTag(slug);
});

/// Find similar existing tags — family keyed on (categoryId, label).
/// Used by admin suggestion review card + user-side autocomplete.
class SimilarTagsQuery {
  const SimilarTagsQuery({required this.categoryId, required this.label});
  final String categoryId;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is SimilarTagsQuery &&
      other.categoryId == categoryId &&
      other.label == label;

  @override
  int get hashCode => Object.hash(categoryId, label);
}

final similarTagsProvider = FutureProvider.autoDispose
    .family<List<SimilarTag>, SimilarTagsQuery>((ref, query) async {
  if (query.label.trim().isEmpty) return const [];
  return ref.watch(tagRepositoryProvider).findSimilar(
        categoryId: query.categoryId,
        label: query.label,
      );
});
