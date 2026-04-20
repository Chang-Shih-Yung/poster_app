import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/tag.dart';
import '../providers/supabase_providers.dart';

/// User-facing: submit new-tag suggestions.
/// Admin-facing: list queue + approve/reject/merge via RPCs.
class TagSuggestionRepository {
  TagSuggestionRepository(this._client);
  final SupabaseClient _client;

  /// Create a new suggestion. Caller must be authenticated.
  Future<TagSuggestion> create({
    required String categoryId,
    required String labelZh,
    String? labelEn,
    String? reason,
    String? linkedSubmissionId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('sign-in required to suggest a tag');
    }
    final row = <String, dynamic>{
      'suggested_by': user.id,
      'suggested_label_zh': labelZh.trim(),
      'category_id': categoryId,
      if (labelEn != null && labelEn.trim().isNotEmpty)
        'suggested_label_en': labelEn.trim(),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      if (linkedSubmissionId != null) 'linked_submission_id': linkedSubmissionId,
    };
    final result = await _client
        .from('tag_suggestions')
        .insert(row)
        .select()
        .single();
    return TagSuggestion.fromRow(result);
  }

  /// List suggestions for caller (or all if admin — RLS handles it).
  Future<List<TagSuggestion>> listMine({int limit = 50}) async {
    final rows = await _client
        .from('tag_suggestions')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => TagSuggestion.fromRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Admin: list pending suggestions, oldest first (queue order).
  Future<List<TagSuggestion>> listPending({int limit = 100}) async {
    final rows = await _client
        .from('tag_suggestions')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: true)
        .limit(limit);
    return (rows as List)
        .map((r) => TagSuggestion.fromRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Admin: approve a suggestion → creates canonical tag + optionally
  /// attaches to the linked submission's poster.
  Future<String> approve(String suggestionId) async {
    final result = await _client.rpc(
      'approve_tag_suggestion',
      params: {'p_suggestion_id': suggestionId},
    );
    return result as String;
  }

  /// Admin: reject.
  Future<void> reject(String suggestionId, {String? note}) async {
    await _client.rpc('reject_tag_suggestion', params: {
      'p_suggestion_id': suggestionId,
      if (note != null && note.isNotEmpty) 'p_note': note,
    });
  }

  /// Admin: merge into an existing tag (adds suggested label as alias).
  Future<void> merge({
    required String suggestionId,
    required String targetTagId,
  }) async {
    await _client.rpc('merge_tag_suggestion', params: {
      'p_suggestion_id': suggestionId,
      'p_target_tag_id': targetTagId,
    });
  }
}

final tagSuggestionRepositoryProvider =
    Provider<TagSuggestionRepository>((ref) {
  return TagSuggestionRepository(ref.watch(supabaseClientProvider));
});

final pendingTagSuggestionsProvider =
    FutureProvider.autoDispose<List<TagSuggestion>>((ref) async {
  return ref.watch(tagSuggestionRepositoryProvider).listPending();
});

final myTagSuggestionsProvider =
    FutureProvider.autoDispose<List<TagSuggestion>>((ref) async {
  return ref.watch(tagSuggestionRepositoryProvider).listMine();
});
