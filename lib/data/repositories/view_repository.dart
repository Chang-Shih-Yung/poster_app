import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/supabase_providers.dart';

/// Tracks poster views with session-level dedup (review #12).
/// DB also deduplicates per day via composite PK, but we avoid
/// unnecessary network requests by tracking locally.
class ViewRepository {
  ViewRepository(this._client);
  final SupabaseClient _client;

  /// Poster IDs already viewed this session — skip RPC for these.
  final Set<String> _viewedThisSession = {};

  /// Record a view. Returns true if the RPC was actually called.
  /// Errors are caught so a flaky network / RPC bug doesn't crash detail
  /// page loads, but we log them to the console — silent catches hide bugs
  /// (e.g. v2's initial bigint→bool mismatch in increment_view_with_dedup
  /// went unnoticed for weeks because this catch swallowed the raise).
  Future<bool> recordView(String posterId) async {
    if (_viewedThisSession.contains(posterId)) return false;

    _viewedThisSession.add(posterId);
    try {
      await _client.rpc(
        'increment_view_with_dedup',
        params: {'p_poster_id': posterId},
      );
      return true;
    } catch (e, st) {
      // Keep the posterId in the set so we don't spam retries, but surface
      // the error. Dart `print` goes to Flutter console / Sentry breadcrumb.
      // ignore: avoid_print
      print('view_repository: increment_view_with_dedup failed — $e\n$st');
      return false;
    }
  }

  /// Check if a poster was already viewed this session.
  bool wasViewedThisSession(String posterId) =>
      _viewedThisSession.contains(posterId);
}

final viewRepositoryProvider = Provider<ViewRepository>((ref) {
  return ViewRepository(ref.watch(supabaseClientProvider));
});
