import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/poster.dart';
import '../models/social.dart';
import '../providers/supabase_providers.dart';

/// Home-page social sections: trending favorites, active collectors,
/// follow feed, recent approved posters. Each RPC is its own method so
/// Riverpod can refresh them independently.
class SocialRepository {
  SocialRepository(this._client);
  final SupabaseClient _client;

  /// `trending_favorites(days, limit)` — posters that gained the most
  /// favorites in the last N days. Includes up-to-3 collector avatars.
  Future<List<TrendingPoster>> trendingFavorites({
    int days = 7,
    int limit = 10,
  }) async {
    final result = await _client.rpc('trending_favorites', params: {
      'p_days': days,
      'p_limit': limit,
    });
    final rows = (result as List?) ?? const [];
    return rows
        .map((r) => TrendingPoster.fromRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `active_collectors(days, limit)` — public users with recent activity,
  /// with up-to-3 recently-favorited poster thumbs for the preview row.
  Future<List<CollectorPreview>> activeCollectors({
    int days = 7,
    int limit = 12,
  }) async {
    final result = await _client.rpc('active_collectors', params: {
      'p_days': days,
      'p_limit': limit,
    });
    final rows = (result as List?) ?? const [];
    return rows
        .map((r) => CollectorPreview.fromRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `follow_feed(limit)` — posters people I follow have recently favorited.
  /// Returns empty list if caller is not authenticated (RPC enforces).
  Future<List<FollowActivity>> followFeed({int limit = 20}) async {
    final result =
        await _client.rpc('follow_feed', params: {'p_limit': limit});
    final rows = (result as List?) ?? const [];
    return rows
        .map((r) => FollowActivity.fromRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `recent_approved_feed(limit)` — was social_activity_feed, renamed.
  /// Returns Poster objects (with uploader_name/avatar fields on each row).
  Future<List<Poster>> recentApprovedFeed({int limit = 12}) async {
    final result = await _client
        .rpc('recent_approved_feed', params: {'p_limit': limit});
    final rows = (result as List?) ?? const [];
    return rows
        .map((r) => Poster.fromRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }
}

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository(ref.watch(supabaseClientProvider));
});

// ── Riverpod providers for each section ─────────────────────────────────────

final trendingFavoritesProvider =
    FutureProvider.autoDispose<List<TrendingPoster>>((ref) async {
  return ref.watch(socialRepositoryProvider).trendingFavorites();
});

final activeCollectorsProvider =
    FutureProvider.autoDispose<List<CollectorPreview>>((ref) async {
  return ref.watch(socialRepositoryProvider).activeCollectors();
});

final followFeedProvider =
    FutureProvider.autoDispose<List<FollowActivity>>((ref) async {
  return ref.watch(socialRepositoryProvider).followFeed();
});

final recentApprovedFeedProvider =
    FutureProvider.autoDispose<List<Poster>>((ref) async {
  return ref.watch(socialRepositoryProvider).recentApprovedFeed();
});
