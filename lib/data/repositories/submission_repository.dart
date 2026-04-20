import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/submission.dart';
import '../providers/supabase_providers.dart';

class SubmissionRepository {
  SubmissionRepository(this._client);
  final SupabaseClient _client;
  static const _bucket = 'posters';

  // ── Image upload (reused from poster_upload_repository) ───────────────────

  Future<String> _uploadBlob({
    required Uint8List bytes,
    required String contentType,
    required String userId,
    required String suffix,
  }) async {
    final ext = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final objectKey = '$userId/${const Uuid().v4()}_$suffix.$ext';
    await _client.storage.from(_bucket).uploadBinary(
          objectKey,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return _client.storage.from(_bucket).getPublicUrl(objectKey);
  }

  /// Upload poster + thumbnail pair, return (posterUrl, thumbUrl).
  Future<({String posterUrl, String thumbUrl})> uploadPosterPair({
    required Uint8List posterBytes,
    required Uint8List thumbBytes,
    required String contentType,
    required String userId,
  }) async {
    final results = await Future.wait([
      _uploadBlob(
        bytes: posterBytes,
        contentType: contentType,
        userId: userId,
        suffix: 'poster',
      ),
      _uploadBlob(
        bytes: thumbBytes,
        contentType: contentType,
        userId: userId,
        suffix: 'thumb',
      ),
    ]);
    return (posterUrl: results[0], thumbUrl: results[1]);
  }

  // ── Submission CRUD ───────────────────────────────────────────────────────

  /// Create a new submission. Writes to submissions table (not posters).
  Future<String> createSubmission(Map<String, dynamic> row) async {
    final result = await _client
        .from('submissions')
        .insert(row)
        .select('id')
        .single();
    return result['id'] as String;
  }

  /// List submissions for the current user (capped — most recent first).
  /// For full history, paginate via `offset`.
  Future<List<Submission>> listMine(
    String userId, {
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await _client
        .from('submissions')
        .select()
        .eq('uploader_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (rows as List)
        .map((r) => Submission.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// List pending submissions (admin only), oldest first (review queue order).
  /// Capped so the initial page load stays bounded even with huge backlogs.
  Future<List<Submission>> listPending({int limit = 100}) async {
    final rows = await _client
        .from('submissions')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: true)
        .limit(limit);
    return (rows as List)
        .map((r) => Submission.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Get a single submission by ID.
  Future<Submission?> getById(String id) async {
    final row =
        await _client.from('submissions').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return Submission.fromRow(row);
  }

  /// Approve a submission via RPC (transaction-wrapped on DB side).
  Future<String> approve(String submissionId, {String? workId}) async {
    final result = await _client.rpc('approve_submission', params: {
      'p_submission_id': submissionId,
      'p_work_id': ?workId,
    });
    return result as String;
  }

  /// Check if a poster with the same title+year already exists (duplicate hint).
  /// Returns the count of matching approved posters, capped at [cap].
  /// Note: `ilike` with an exact string still uses the index; we rely on
  /// the poster-title index for speed. The cap bounds the hint UI.
  Future<int> checkDuplicate({
    required String titleZh,
    int? year,
    int cap = 20,
  }) async {
    var query = _client
        .from('posters')
        .select('id')
        .eq('status', 'approved')
        .isFilter('deleted_at', null)
        .ilike('title', titleZh);
    if (year != null) {
      query = query.eq('year', year);
    }
    final rows = await query.limit(cap);
    return (rows as List).length;
  }

  /// Reject a submission via RPC.
  Future<void> reject(String submissionId, {String? note}) async {
    await _client.rpc('reject_submission', params: {
      'p_submission_id': submissionId,
      'p_note': ?note,
    });
  }
}

final submissionRepositoryProvider = Provider<SubmissionRepository>((ref) {
  return SubmissionRepository(ref.watch(supabaseClientProvider));
});

/// My submissions as a provider.
final mySubmissionsV2Provider =
    FutureProvider.autoDispose<List<Submission>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(submissionRepositoryProvider).listMine(user.id);
});

/// Pending submissions (admin).
final pendingSubmissionsProvider =
    FutureProvider.autoDispose<List<Submission>>((ref) async {
  return ref.watch(submissionRepositoryProvider).listPending();
});
