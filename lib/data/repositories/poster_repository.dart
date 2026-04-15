import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/poster.dart';
import '../providers/supabase_providers.dart';

class PosterPage {
  const PosterPage({required this.items, required this.nextCursor});
  final List<Poster> items;
  final DateTime? nextCursor;
}

class PosterRepository {
  PosterRepository(this._client);

  final SupabaseClient _client;
  static const _pageSize = 20;

  Future<PosterPage> listApproved({
    DateTime? cursor,
    String? search,
    String? tag,
  }) async {
    var query = _client
        .from('posters')
        .select()
        .eq('status', 'approved')
        .isFilter('deleted_at', null);

    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim();
      query = query.or(
        'title.ilike.%$s%,director.ilike.%$s%,tags.cs.{$s}',
      );
    }
    if (tag != null && tag.trim().isNotEmpty) {
      query = query.contains('tags', [tag]);
    }
    if (cursor != null) {
      query = query.lt('created_at', cursor.toIso8601String());
    }

    final rows = await query
        .order('created_at', ascending: false)
        .limit(_pageSize);

    final items = (rows as List)
        .map((r) => Poster.fromRow(r as Map<String, dynamic>))
        .toList();

    return PosterPage(
      items: items,
      nextCursor:
          items.length == _pageSize ? items.last.createdAt : null,
    );
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
