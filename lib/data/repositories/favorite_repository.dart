import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/favorite.dart';
import '../models/poster.dart';
import '../providers/supabase_providers.dart';

class FavoriteRepository {
  FavoriteRepository(this._client);
  final SupabaseClient _client;

  Future<List<Favorite>> list(String userId) async {
    final rows = await _client
        .from('favorites')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Favorite.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<Set<String>> listIds(String userId) async {
    final rows = await _client
        .from('favorites')
        .select('poster_id')
        .eq('user_id', userId);
    return (rows as List)
        .map((r) => (r as Map<String, dynamic>)['poster_id'] as String)
        .toSet();
  }

  Future<void> add(String userId, Poster poster) async {
    await _client.from('favorites').upsert({
      'user_id': userId,
      'poster_id': poster.id,
      'poster_title': poster.title,
      'poster_thumbnail_url': poster.thumbnailUrl ?? poster.posterUrl,
    });
  }

  Future<void> remove(String userId, String posterId) async {
    await _client
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('poster_id', posterId);
  }
}

final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  return FavoriteRepository(ref.watch(supabaseClientProvider));
});

final favoritesProvider = FutureProvider<List<Favorite>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(favoriteRepositoryProvider).list(user.id);
});

final favoriteIdsProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return <String>{};
  return ref.watch(favoriteRepositoryProvider).listIds(user.id);
});
