import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/tag.dart';
import '../providers/supabase_providers.dart';

/// Result of `submit_tag_suggestion` RPC.
/// Either the server auto-merged into an existing tag (silent success) or
/// the suggestion was queued for admin review.
sealed class SuggestionOutcome {
  const SuggestionOutcome();
  factory SuggestionOutcome.fromJson(Map<String, dynamic> json) {
    if (json['auto_merged'] == true) {
      return SuggestionAutoMerged(
        tagId: json['tag_id'] as String,
        tagLabelZh: json['tag_label_zh'] as String,
        similarity: (json['similarity'] as num?)?.toDouble() ?? 0.0,
      );
    }
    return SuggestionQueued(
      suggestionId: json['suggestion_id'] as String,
    );
  }
}

class SuggestionAutoMerged extends SuggestionOutcome {
  const SuggestionAutoMerged({
    required this.tagId,
    required this.tagLabelZh,
    required this.similarity,
  });
  final String tagId;
  final String tagLabelZh;
  final double similarity;
}

class SuggestionQueued extends SuggestionOutcome {
  const SuggestionQueued({required this.suggestionId});
  final String suggestionId;
}


/// User-facing: submit new-tag suggestions.
/// Admin-facing: list queue + approve/reject/merge via RPCs.
class TagSuggestionRepository {
  TagSuggestionRepository(this._client);
  final SupabaseClient _client;

  /// Submit a new-tag suggestion via the `submit_tag_suggestion` gateway.
  ///
  /// Server auto-merges when similarity ≥ 0.95 (e.g. user types "Miyazaki"
  /// and we already have "宮崎駿" with alias "miyazaki"). Silent merge →
  /// admin queue stays clean.
  ///
  /// Returns [SuggestionOutcome] so the UI can tell the user whether their
  /// suggestion was added to the queue or silently merged into an existing
  /// tag.
  Future<SuggestionOutcome> submit({
    required String categoryId,
    required String labelZh,
    String? labelEn,
    String? reason,
    String? linkedSubmissionId,
  }) async {
    final result = await _client.rpc('submit_tag_suggestion', params: {
      'p_category_id': categoryId,
      'p_label_zh': labelZh.trim(),
      if (labelEn != null && labelEn.trim().isNotEmpty)
        'p_label_en': labelEn.trim(),
      if (reason != null && reason.trim().isNotEmpty) 'p_reason': reason.trim(),
      if (linkedSubmissionId != null)
        'p_linked_submission_id': linkedSubmissionId,
    });
    return SuggestionOutcome.fromJson(result as Map<String, dynamic>);
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

  /// Admin: change the category of a pending suggestion (fixes legacy
  /// migration's "everything goes to 編輯精選" problem).
  Future<void> changeCategory({
    required String suggestionId,
    required String newCategoryId,
  }) async {
    await _client.rpc('change_suggestion_category', params: {
      'p_suggestion_id': suggestionId,
      'p_new_category_id': newCategoryId,
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
