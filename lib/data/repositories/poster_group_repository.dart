import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/poster_group.dart';
import '../providers/supabase_providers.dart';

/// Reads the recursive `poster_groups` tree for a work. The admin manages
/// this hierarchy via /tree; the Flutter app currently only consumes it.
class PosterGroupRepository {
  PosterGroupRepository(this._client);
  final SupabaseClient _client;

  /// Every group attached to a work, returned flat. Caller can build the
  /// tree via parentGroupId. Sorted by (parent, displayOrder, name) so a
  /// stable pre-order traversal yields a sensible UI ordering.
  Future<List<PosterGroup>> listForWork(String workId) async {
    final rows = await _client
        .from('poster_groups')
        .select()
        .eq('work_id', workId)
        .order('display_order')
        .order('name');
    return (rows as List)
        .map((r) => PosterGroup.fromRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }
}

final posterGroupRepositoryProvider =
    Provider<PosterGroupRepository>((ref) {
  return PosterGroupRepository(ref.watch(supabaseClientProvider));
});

/// Live list of groups for one work — re-evaluates when the work's
/// realtime channel fires (see realtimeProviders).
final posterGroupsForWorkProvider =
    FutureProvider.autoDispose.family<List<PosterGroup>, String>(
  (ref, workId) async {
    return ref
        .watch(posterGroupRepositoryProvider)
        .listForWork(workId);
  },
);
