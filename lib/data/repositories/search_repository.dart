import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../models/poster.dart';
import '../models/work.dart';
import '../providers/supabase_providers.dart';

/// Grouped search result for the unified search page.
class SearchResults {
  const SearchResults({
    required this.works,
    required this.posters,
    required this.users,
  });

  factory SearchResults.fromJson(Map<String, dynamic> json) {
    return SearchResults(
      works: ((json['works'] as List?) ?? const [])
          .map((r) => Work.fromRow(r as Map<String, dynamic>))
          .toList(),
      posters: ((json['posters'] as List?) ?? const [])
          .map((r) => Poster.fromRow(r as Map<String, dynamic>))
          .toList(),
      users: ((json['users'] as List?) ?? const [])
          .map((r) => AppUser.fromRow(r as Map<String, dynamic>))
          .toList(),
    );
  }

  static const empty = SearchResults(works: [], posters: [], users: []);

  final List<Work> works;
  final List<Poster> posters;
  final List<AppUser> users;

  bool get isEmpty => works.isEmpty && posters.isEmpty && users.isEmpty;
  int get totalCount => works.length + posters.length + users.length;
}

class SearchRepository {
  SearchRepository(this._client);
  final SupabaseClient _client;

  Future<SearchResults> search(String query, {int limit = 8}) async {
    final q = query.trim();
    if (q.isEmpty) return SearchResults.empty;

    final result = await _client.rpc('unified_search', params: {
      'p_query': q,
      'p_limit': limit,
    });
    if (result == null) return SearchResults.empty;
    return SearchResults.fromJson(result as Map<String, dynamic>);
  }
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(supabaseClientProvider));
});

final unifiedSearchProvider =
    FutureProvider.autoDispose.family<SearchResults, String>((ref, q) async {
  return ref.watch(searchRepositoryProvider).search(q);
});
