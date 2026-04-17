import 'package:flutter_test/flutter_test.dart';

import 'package:poster_app/core/constants/enums.dart';
import 'package:poster_app/data/models/submission.dart';

/// Tests that Submission.toInsertRow produces correct V2 rows
/// matching what the rewritten SubmissionPage would send.
void main() {
  group('Submission.toInsertRow for V2 submission form', () {
    test('minimal required fields only', () {
      final s = Submission(
        id: 'test',
        workTitleZh: '乘風破浪',
        imageUrl: 'https://example.com/poster.jpg',
        uploaderId: 'user-1',
        status: SubmissionStatus.pending,
        createdAt: DateTime(2026, 4, 16),
        region: Region.tw,
      );
      final row = s.toInsertRow();
      expect(row['work_title_zh'], '乘風破浪');
      expect(row['image_url'], 'https://example.com/poster.jpg');
      expect(row['uploader_id'], 'user-1');
      expect(row['region'], 'TW');
      expect(row['is_exclusive'], false);
      // Optional fields should be absent.
      expect(row.containsKey('work_title_en'), false);
      expect(row.containsKey('movie_release_year'), false);
      expect(row.containsKey('poster_name'), false);
      expect(row.containsKey('channel_category'), false);
      expect(row.containsKey('source_url'), false);
    });

    test('full V2 fields', () {
      final s = Submission(
        id: 'test-2',
        workTitleZh: '乘風破浪',
        workTitleEn: 'Ride the Wave',
        movieReleaseYear: 2024,
        posterName: '正式版',
        region: Region.kr,
        posterReleaseType: ReleaseType.theatrical,
        sizeType: SizeType.b2,
        channelCategory: ChannelCategory.cinema,
        channelType: 'IMAX',
        channelName: '威秀影城',
        isExclusive: true,
        exclusiveName: 'IMAX 獨家版',
        materialType: '紙質',
        versionLabel: 'v2',
        imageUrl: 'https://example.com/poster.jpg',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        imageSizeBytes: 1234567,
        sourceUrl: 'https://facebook.com/post/123',
        sourcePlatform: 'Facebook',
        sourceNote: '官方粉專',
        uploaderId: 'user-2',
        status: SubmissionStatus.pending,
        createdAt: DateTime(2026, 4, 16),
      );
      final row = s.toInsertRow();
      expect(row['work_title_zh'], '乘風破浪');
      expect(row['work_title_en'], 'Ride the Wave');
      expect(row['movie_release_year'], 2024);
      expect(row['poster_name'], '正式版');
      expect(row['region'], 'KR');
      expect(row['poster_release_type'], 'theatrical');
      expect(row['size_type'], 'B2');
      expect(row['channel_category'], 'cinema');
      expect(row['channel_type'], 'IMAX');
      expect(row['channel_name'], '威秀影城');
      expect(row['is_exclusive'], true);
      expect(row['exclusive_name'], 'IMAX 獨家版');
      expect(row['material_type'], '紙質');
      expect(row['version_label'], 'v2');
      expect(row['image_url'], 'https://example.com/poster.jpg');
      expect(row['thumbnail_url'], 'https://example.com/thumb.jpg');
      expect(row['image_size_bytes'], 1234567);
      expect(row['source_url'], 'https://facebook.com/post/123');
      expect(row['source_platform'], 'Facebook');
      expect(row['source_note'], '官方粉專');
      expect(row['uploader_id'], 'user-2');
    });

    test('region defaults to OTHER when null string parsed', () {
      expect(Region.fromString(null), Region.other);
      expect(Region.fromString('UNKNOWN'), Region.other);
      expect(Region.fromString('TW'), Region.tw);
    });

    test('channel category roundtrip', () {
      for (final cat in ChannelCategory.values) {
        expect(ChannelCategory.fromString(cat.value), cat);
      }
    });
  });
}
