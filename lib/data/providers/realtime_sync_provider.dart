import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/poster_group_repository.dart';
import '../repositories/poster_repository.dart';
import '../repositories/work_repository.dart';
import 'supabase_providers.dart';

/// Subscribes to Postgres change events on works / posters / poster_groups
/// and invalidates the corresponding Riverpod providers, so any UI that
/// watches them re-fetches the moment the admin makes a change.
///
/// Wire this up by calling `ref.watch(realtimeSyncProvider)` once at app
/// startup (e.g. inside the root widget). Keep it non-autoDispose so the
/// channel stays open for the whole session.
///
/// Requires the catalogue tables to be members of the `supabase_realtime`
/// publication (see migration 20260427190000_realtime_publication.sql).
final realtimeSyncProvider = Provider<void>((ref) {
  final client = ref.watch(supabaseClientProvider);

  // One channel, three table subscriptions. Cheaper than one channel per
  // table and the WebSocket frame already carries the table name so the
  // server-side fan-out is identical.
  final channel = client.channel('catalogue-sync')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'works',
      callback: (_) {
        // Family providers: invalidating the parent invalidates every
        // active key (e.g. workByIdProvider('uuid-1') and ('uuid-2')
        // both refetch on the next watch).
        ref.invalidate(workByIdProvider);
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'posters',
      callback: (_) {
        ref.invalidate(postersByWorkIdProvider);
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'poster_groups',
      callback: (_) {
        ref.invalidate(posterGroupsForWorkProvider);
      },
    )
    ..subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });
});
