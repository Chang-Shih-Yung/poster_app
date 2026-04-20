import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/poster.dart';
import '../providers/supabase_providers.dart';

enum PosterSort { latest, popular }

class PosterFilter {
  const PosterFilter({
    this.sortBy = PosterSort.latest,
    this.search,
    this.tags = const [],
    this.director,
    this.yearMin,
    this.yearMax,
    this.favoritesOf,
    this.uploadedBy,
  });

  final PosterSort sortBy;
  final String? search;
  final List<String> tags;
  final String? director;
  final int? yearMin;
  final int? yearMax;

  /// When set, only return posters favorited by this user ID.
  final String? favoritesOf;

  /// When set, only return posters uploaded by this user ID
  /// (used by 我的 → 投稿 segmented tab).
  final String? uploadedBy;

  bool get hasAdvanced =>
      tags.isNotEmpty ||
      (director != null && director!.trim().isNotEmpty) ||
      yearMin != null ||
      yearMax != null;

  int get advancedCount =>
      (tags.isNotEmpty ? 1 : 0) +
      ((director != null && director!.trim().isNotEmpty) ? 1 : 0) +
      (yearMin != null ? 1 : 0) +
      (yearMax != null ? 1 : 0);

  PosterFilter copyWith({
    PosterSort? sortBy,
    String? search,
    List<String>? tags,
    String? director,
    int? yearMin,
    int? yearMax,
    String? favoritesOf,
    String? uploadedBy,
    bool clearSearch = false,
    bool clearDirector = false,
    bool clearYearMin = false,
    bool clearYearMax = false,
    bool clearFavoritesOf = false,
    bool clearUploadedBy = false,
  }) {
    return PosterFilter(
      sortBy: sortBy ?? this.sortBy,
      search: clearSearch ? null : (search ?? this.search),
      tags: tags ?? this.tags,
      director: clearDirector ? null : (director ?? this.director),
      yearMin: clearYearMin ? null : (yearMin ?? this.yearMin),
      yearMax: clearYearMax ? null : (yearMax ?? this.yearMax),
      favoritesOf:
          clearFavoritesOf ? null : (favoritesOf ?? this.favoritesOf),
      uploadedBy:
          clearUploadedBy ? null : (uploadedBy ?? this.uploadedBy),
    );
  }
}

class PosterPage {
  const PosterPage({required this.items, required this.hasMore});
  final List<Poster> items;
  final bool hasMore;
}

class PosterRepository {
  PosterRepository(this._client);

  final SupabaseClient _client;
  static const _pageSize = 20;
  static const _popularWindowDays = 30;

  Future<PosterPage> listApproved({
    PosterFilter filter = const PosterFilter(),
    int offset = 0,
  }) async {
    // Favorites filter: use RPC instead of IN clause (review #11).
    if (filter.favoritesOf != null) {
      final rows = await _client.rpc('list_favorites_with_posters', params: {
        'p_user_id': filter.favoritesOf,
        'p_offset': offset,
        'p_limit': _pageSize,
      });
      final items = (rows as List)
          .map((r) => Poster.fromRow(r as Map<String, dynamic>))
          .toList();
      return PosterPage(items: items, hasMore: items.length == _pageSize);
    }

    var query = _client
        .from('posters')
        .select()
        .eq('status', 'approved')
        .isFilter('deleted_at', null);

    if (filter.sortBy == PosterSort.popular) {
      final cutoff = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: _popularWindowDays));
      query = query.gte('created_at', cutoff.toIso8601String());
    }

    final search = filter.search?.trim();
    if (search != null && search.isNotEmpty) {
      // Sanitize: PostgREST `or` uses commas + parens as separators.
      // Strip them to prevent query-injection via user-typed search strings.
      final safe =
          search.replaceAll(RegExp(r'[,()]'), '').replaceAll('%', r'\%');
      if (safe.isNotEmpty) {
        query = query.or(
          'title.ilike.%$safe%,director.ilike.%$safe%,tags.cs.{$safe}',
        );
      }
    }

    if (filter.tags.isNotEmpty) {
      query = query.contains('tags', filter.tags);
    }

    if (filter.uploadedBy != null) {
      query = query.eq('uploader_id', filter.uploadedBy!);
    }

    final director = filter.director?.trim();
    if (director != null && director.isNotEmpty) {
      query = query.ilike('director', '%$director%');
    }

    if (filter.yearMin != null) {
      query = query.gte('year', filter.yearMin!);
    }
    if (filter.yearMax != null) {
      query = query.lte('year', filter.yearMax!);
    }

    final ordered = filter.sortBy == PosterSort.popular
        ? query
            .order('view_count', ascending: false)
            .order('created_at', ascending: false)
        : query.order('created_at', ascending: false);

    final rows = await ordered.range(offset, offset + _pageSize - 1);

    final items = (rows as List)
        .map((r) => Poster.fromRow(r as Map<String, dynamic>))
        .toList();

    return PosterPage(items: items, hasMore: items.length == _pageSize);
  }

  /// Top tags via SQL RPC (review #8). Replaces client-side 500-row fetch.
  Future<List<String>> topTags({int limit = 20}) async {
    final rows = await _client.rpc('top_tags', params: {'p_limit': limit});
    return (rows as List)
        .map((r) => (r as Map<String, dynamic>)['tag'] as String)
        .toList();
  }


  Future<Poster?> getById(String id) async {
    final row = await _client
        .from('posters')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Poster.fromRow(row);
  }

  /// List approved posters by a given uploader, newest first.
  /// Used by public profile pages (/user/:id).
  Future<List<Poster>> listByUploader(String uploaderId,
      {int limit = 60}) async {
    final rows = await _client
        .from('posters')
        .select()
        .eq('uploader_id', uploaderId)
        .eq('status', 'approved')
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => Poster.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// List all approved posters for a given work, newest first.
  Future<List<Poster>> listByWorkId(String workId) async {
    final rows = await _client
        .from('posters')
        .select()
        .eq('work_id', workId)
        .eq('status', 'approved')
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Poster.fromRow(r as Map<String, dynamic>))
        .toList();
  }
}

final posterRepositoryProvider = Provider<PosterRepository>((ref) {
  return PosterRepository(ref.watch(supabaseClientProvider));
});

final postersByWorkIdProvider =
    FutureProvider.autoDispose.family<List<Poster>, String>((ref, workId) async {
  return ref.watch(posterRepositoryProvider).listByWorkId(workId);
});

final topTagsProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(posterRepositoryProvider).topTags();
});
