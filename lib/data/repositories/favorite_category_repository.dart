import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/favorite_category.dart';
import '../providers/supabase_providers.dart';

class FavoriteCategoryRepository {
  FavoriteCategoryRepository(this._client);
  final SupabaseClient _client;

  Future<List<FavoriteCategory>> list(String userId) async {
    final rows = await _client
        .from('favorite_categories')
        .select()
        .eq('user_id', userId)
        .order('sort_order')
        .order('created_at');
    return (rows as List)
        .map((r) => FavoriteCategory.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<FavoriteCategory> create(String userId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('分類名稱不能為空');
    }
    final row = await _client
        .from('favorite_categories')
        .insert({'user_id': userId, 'name': trimmed})
        .select()
        .single();
    return FavoriteCategory.fromRow(row);
  }

  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('分類名稱不能為空');
    }
    await _client
        .from('favorite_categories')
        .update({'name': trimmed})
        .eq('id', id);
  }

  Future<void> delete(String id) async {
    // favorites.category_id ON DELETE SET NULL → those favorites become "預設"
    await _client.from('favorite_categories').delete().eq('id', id);
  }

  Future<void> reorder(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await _client
          .from('favorite_categories')
          .update({'sort_order': i})
          .eq('id', orderedIds[i]);
    }
  }

  Future<void> moveFavorite({
    required String userId,
    required String posterId,
    required String? categoryId,
  }) async {
    await _client
        .from('favorites')
        .update({'category_id': categoryId})
        .eq('user_id', userId)
        .eq('poster_id', posterId);
  }
}

final favoriteCategoryRepositoryProvider =
    Provider<FavoriteCategoryRepository>((ref) {
  return FavoriteCategoryRepository(ref.watch(supabaseClientProvider));
});

final favoriteCategoriesProvider =
    FutureProvider<List<FavoriteCategory>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(favoriteCategoryRepositoryProvider).list(user.id);
});
