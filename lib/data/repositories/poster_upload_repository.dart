import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../providers/supabase_providers.dart';

class PosterUploadRepository {
  PosterUploadRepository(this._client);

  final SupabaseClient _client;
  static const _bucket = 'posters';

  /// Upload a single image blob and return its public URL.
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

  /// Legacy single-image upload (kept for backwards compat).
  Future<String> uploadImage({
    required Uint8List bytes,
    required String contentType,
    required String userId,
  }) =>
      _uploadBlob(
        bytes: bytes,
        contentType: contentType,
        userId: userId,
        suffix: 'poster',
      );

  /// Upload poster + thumbnail pair, return (posterUrl, thumbUrl).
  Future<({String posterUrl, String thumbUrl})> uploadPosterPair({
    required Uint8List posterBytes,
    required Uint8List thumbBytes,
    required String contentType,
    required String userId,
  }) async {
    // Upload both concurrently.
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

  Future<String> createSubmission({
    required String title,
    int? year,
    String? director,
    required List<String> tags,
    required String posterUrl,
    required String thumbnailUrl,
    required String userId,
  }) async {
    final row = await _client
        .from('posters')
        .insert({
          'title': title,
          'year': year,
          'director': director,
          'tags': tags,
          'poster_url': posterUrl,
          'thumbnail_url': thumbnailUrl,
          'uploader_id': userId,
          'status': 'pending',
        })
        .select('id')
        .single();
    final posterId = row['id'] as String;
    // Fire-and-forget: have the poster-blurhash Edge Function compute
    // the ~30-byte BlurHash and write it back to posters.blurhash.
    // We don't await — the upload flow finishes instantly; the hash
    // arrives asynchronously (seconds), and AppPosterTile gracefully
    // falls back to ShimmerPlaceholder when blurhash is still null.
    unawaited(_requestBlurhash(posterId: posterId, imageUrl: thumbnailUrl));
    return posterId;
  }

  Future<void> _requestBlurhash({
    required String posterId,
    required String imageUrl,
  }) async {
    try {
      await _client.functions.invoke(
        'poster-blurhash',
        body: {'poster_id': posterId, 'image_url': imageUrl},
      );
    } catch (_) {
      // Soft-fail — the hash is a nice-to-have; missing it means the
      // tile shows a flat ShimmerPlaceholder instead of the pixel-
      // correct blur. Don't block the submission flow.
    }
  }
}

final posterUploadRepositoryProvider =
    Provider<PosterUploadRepository>((ref) {
  return PosterUploadRepository(ref.watch(supabaseClientProvider));
});
