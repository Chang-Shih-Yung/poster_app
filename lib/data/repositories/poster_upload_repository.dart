import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../providers/supabase_providers.dart';

class PosterUploadRepository {
  PosterUploadRepository(this._client);

  final SupabaseClient _client;
  static const _bucket = 'posters';

  Future<String> uploadImage({
    required Uint8List bytes,
    required String contentType,
    required String userId,
  }) async {
    final ext = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final objectKey = '$userId/${const Uuid().v4()}.$ext';
    await _client.storage.from(_bucket).uploadBinary(
          objectKey,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return _client.storage.from(_bucket).getPublicUrl(objectKey);
  }

  Future<String> createSubmission({
    required String title,
    int? year,
    String? director,
    required List<String> tags,
    required String posterUrl,
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
          'thumbnail_url': posterUrl,
          'uploader_id': userId,
          'status': 'pending',
        })
        .select('id')
        .single();
    return row['id'] as String;
  }
}

final posterUploadRepositoryProvider =
    Provider<PosterUploadRepository>((ref) {
  return PosterUploadRepository(ref.watch(supabaseClientProvider));
});
