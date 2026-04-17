import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Compressed image result with poster + thumbnail bytes.
class CompressedImages {
  const CompressedImages({
    required this.posterBytes,
    required this.thumbBytes,
    required this.contentType,
  });

  /// Full-size poster (max 1200px wide, JPEG quality 82).
  final Uint8List posterBytes;

  /// Thumbnail (max 400px wide, JPEG quality 72).
  final Uint8List thumbBytes;

  /// Always 'image/jpeg' after compression.
  final String contentType;
}

/// Client-side image compression.
///
/// Takes raw picked bytes, decodes, resizes to two sizes, encodes as JPEG.
/// Runs synchronously (pure Dart `image` package). For images under 4000px
/// this typically takes < 1s on modern devices.
class ImageCompressor {
  static const _posterMaxWidth = 1200;
  static const _posterQuality = 82;
  static const _thumbMaxWidth = 400;
  static const _thumbQuality = 72;

  /// Max allowed file size for the poster image after compression (5 MB).
  static const maxPosterBytes = 5 * 1024 * 1024;

  /// Compress [rawBytes] into poster + thumbnail pair.
  ///
  /// Returns null if the image cannot be decoded.
  static CompressedImages? compress(Uint8List rawBytes) {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return null;

    // Poster: resize if wider than max, encode as JPEG.
    final poster = decoded.width > _posterMaxWidth
        ? img.copyResize(decoded, width: _posterMaxWidth)
        : decoded;
    final posterBytes =
        Uint8List.fromList(img.encodeJpg(poster, quality: _posterQuality));

    // Thumbnail: always resize to thumb width.
    final thumb = img.copyResize(decoded, width: _thumbMaxWidth);
    final thumbBytes =
        Uint8List.fromList(img.encodeJpg(thumb, quality: _thumbQuality));

    return CompressedImages(
      posterBytes: posterBytes,
      thumbBytes: thumbBytes,
      contentType: 'image/jpeg',
    );
  }
}
