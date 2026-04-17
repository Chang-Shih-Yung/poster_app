import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/work.dart';
import '../providers/supabase_providers.dart';

class WorkRepository {
  WorkRepository(this._client);
  final SupabaseClient _client;

  /// Search works by Chinese title + optional year.
  /// Used by admin when matching a submission to an existing work.
  Future<List<Work>> search({
    required String titleZh,
    int? year,
    int limit = 10,
  }) async {
    var query = _client
        .from('works')
        .select()
        .ilike('title_zh', '%${titleZh.trim()}%');

    if (year != null) {
      query = query.eq('movie_release_year', year);
    }

    final rows = await query.order('poster_count', ascending: false).limit(limit);
    return (rows as List)
        .map((r) => Work.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Get a single work by ID.
  Future<Work?> getById(String id) async {
    final row = await _client.from('works').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return Work.fromRow(row);
  }

  /// Create a new work (admin only, used in approve flow).
  Future<Work> create(Work work) async {
    final row = await _client
        .from('works')
        .insert(work.toInsertRow())
        .select()
        .single();
    return Work.fromRow(row);
  }
}

final workRepositoryProvider = Provider<WorkRepository>((ref) {
  return WorkRepository(ref.watch(supabaseClientProvider));
});

final workByIdProvider =
    FutureProvider.autoDispose.family<Work?, String>((ref, id) async {
  return ref.watch(workRepositoryProvider).getById(id);
});
