import 'package:flutter_test/flutter_test.dart';
import 'package:poster_app/core/constants/enums.dart';
import 'package:poster_app/data/models/poster.dart';

void main() {
  group('Poster.fromRow', () {
    test('parses V1 row (no V2 fields)', () {
      final row = {
        'id': 'p-1',
        'title': '全面啟動',
        'year': 2010,
        'director': 'Christopher Nolan',
        'tags': ['科幻', '經典'],
        'poster_url': 'https://example.com/poster.jpg',
        'thumbnail_url': 'https://example.com/thumb.jpg',
        'uploader_id': 'user-1',
        'status': 'approved',
        'review_note': null,
        'view_count': 42,
        'created_at': '2026-01-01T00:00:00Z',
        // V2 fields absent
      };

      final poster = Poster.fromRow(row);

      expect(poster.id, 'p-1');
      expect(poster.title, '全面啟動');
      expect(poster.year, 2010);
      expect(poster.director, 'Christopher Nolan');
      expect(poster.tags, ['科幻', '經典']);
      expect(poster.viewCount, 42);
      // V2 fields should be null/default
      expect(poster.workId, isNull);
      expect(poster.region, isNull);
      expect(poster.isExclusive, false);
      expect(poster.favoriteCount, 0);
    });

    test('parses full V2 row', () {
      final row = {
        'id': 'p-2',
        'title': '全面啟動',
        'year': 2010,
        'director': 'Christopher Nolan',
        'tags': ['科幻'],
        'poster_url': 'https://example.com/poster.jpg',
        'thumbnail_url': 'https://example.com/thumb.jpg',
        'uploader_id': 'user-1',
        'status': 'approved',
        'review_note': null,
        'view_count': 100,
        'created_at': '2026-01-01T00:00:00Z',
        // V2 fields
        'work_id': 'work-1',
        'poster_name': '台灣院線版',
        'region': 'TW',
        'poster_release_date': '2010-07-30',
        'poster_release_type': 'theatrical',
        'size_type': 'B2',
        'channel_category': 'cinema',
        'channel_type': '影城',
        'channel_name': '威秀',
        'is_exclusive': true,
        'exclusive_name': 'IMAX',
        'material_type': '紙質',
        'version_label': 'A版',
        'image_size_bytes': 2048000,
        'source_url': 'https://fb.com/post',
        'source_platform': 'Facebook',
        'source_note': '官方',
        'favorite_count': 15,
        'approved_at': '2026-01-02T00:00:00Z',
        'deleted_at': null,
      };

      final poster = Poster.fromRow(row);

      expect(poster.workId, 'work-1');
      expect(poster.posterName, '台灣院線版');
      expect(poster.region, Region.tw);
      expect(poster.posterReleaseType, ReleaseType.theatrical);
      expect(poster.sizeType, SizeType.b2);
      expect(poster.channelCategory, ChannelCategory.cinema);
      expect(poster.isExclusive, true);
      expect(poster.exclusiveName, 'IMAX');
      expect(poster.favoriteCount, 15);
      expect(poster.approvedAt, isNotNull);
      expect(poster.deletedAt, isNull);
    });

    test('handles empty tags list', () {
      final row = {
        'id': 'p-3',
        'title': 'test',
        'year': null,
        'director': null,
        'tags': null,
        'poster_url': 'https://example.com/img.jpg',
        'thumbnail_url': null,
        'uploader_id': 'u-1',
        'status': 'pending',
        'review_note': null,
        'view_count': null,
        'created_at': '2026-01-01T00:00:00Z',
      };

      final poster = Poster.fromRow(row);
      expect(poster.tags, isEmpty);
      expect(poster.viewCount, 0);
    });
  });
}
