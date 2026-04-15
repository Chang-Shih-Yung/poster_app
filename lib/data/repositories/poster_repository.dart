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
  });

  final PosterSort sortBy;
  final String? search;
  final List<String> tags;
  final String? director;
  final int? yearMin;
  final int? yearMax;

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
      query = query.or(
        'title.ilike.%$search%,director.ilike.%$search%,tags.cs.{$search}',
      );
    }

    if (filter.tags.isNotEmpty) {
      query = query.contains('tags', filter.tags);
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

  Future<List<Poster>> listMine(String userId, {String? statusFilter}) async {
    var query = _client
        .from('posters')
        .select()
        .eq('uploader_id', userId)
        .isFilter('deleted_at', null);
    if (statusFilter != null) {
      query = query.eq('status', statusFilter);
    }
    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Poster.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> topTags({int limit = 20}) async {
    final rows = await _client
        .from('posters')
        .select('tags')
        .eq('status', 'approved')
        .isFilter('deleted_at', null)
        .limit(500);
    final counts = <String, int>{};
    for (final r in rows as List) {
      final tags = (r as Map<String, dynamic>)['tags'] as List? ?? const [];
      for (final t in tags) {
        final s = t.toString();
        counts[s] = (counts[s] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
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

  Future<void> incrementViewCount(String id) async {
    await _client.rpc('increment_poster_view_count', params: {'poster_id': id});
  }
}

final posterRepositoryProvider = Provider<PosterRepository>((ref) {
  return PosterRepository(ref.watch(supabaseClientProvider));
});

final topTagsProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(posterRepositoryProvider).topTags();
});

final mySubmissionsProvider =
    FutureProvider.autoDispose<List<Poster>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(posterRepositoryProvider).listMine(user.id);
});
