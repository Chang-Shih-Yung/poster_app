import 'package:flutter_test/flutter_test.dart';
import 'package:poster_app/core/constants/enums.dart';
import 'package:poster_app/data/models/submission.dart';

void main() {
  group('Submission.fromRow', () {
    test('parses full row', () {
      final row = {
        'id': 'sub-1',
        'batch_id': 'batch-1',
        'work_title_zh': '全面啟動',
        'work_title_en': 'Inception',
        'movie_release_year': 2010,
        'poster_name': '台灣院線版',
        'region': 'TW',
        'poster_release_date': '2010-07-30',
        'poster_release_type': 'theatrical',
        'size_type': 'B2',
        'channel_category': 'cinema',
        'channel_type': '影城通路',
        'channel_name': '威秀影城',
        'is_exclusive': true,
        'exclusive_name': 'IMAX 限定',
        'material_type': '紙質',
        'version_label': 'A版',
        'image_url': 'https://example.com/poster.jpg',
        'thumbnail_url': 'https://example.com/thumb.jpg',
        'image_size_bytes': 1024000,
        'source_url': 'https://fb.com/post',
        'source_platform': 'Facebook',
        'source_note': '官方發布',
        'uploader_id': 'user-1',
        'status': 'pending',
        'reviewer_id': null,
        'review_note': null,
        'reviewed_at': null,
        'matched_work_id': null,
        'created_poster_id': null,
        'created_at': '2026-04-16T10:00:00Z',
      };

      final sub = Submission.fromRow(row);

      expect(sub.id, 'sub-1');
      expect(sub.batchId, 'batch-1');
      expect(sub.workTitleZh, '全面啟動');
      expect(sub.workTitleEn, 'Inception');
      expect(sub.region, Region.tw);
      expect(sub.posterReleaseType, ReleaseType.theatrical);
      expect(sub.sizeType, SizeType.b2);
      expect(sub.channelCategory, ChannelCategory.cinema);
      expect(sub.isExclusive, true);
      expect(sub.exclusiveName, 'IMAX 限定');
      expect(sub.status, SubmissionStatus.pending);
      expect(sub.isPending, true);
      expect(sub.isApproved, false);
    });

    test('handles minimal row (nullable fields)', () {
      final row = {
        'id': 'sub-2',
        'batch_id': null,
        'work_title_zh': '測試',
        'work_title_en': null,
        'movie_release_year': null,
        'poster_name': null,
        'region': null,
        'poster_release_date': null,
        'poster_release_type': null,
        'size_type': null,
        'channel_category': null,
        'channel_type': null,
        'channel_name': null,
        'is_exclusive': false,
        'exclusive_name': null,
        'material_type': null,
        'version_label': null,
        'image_url': 'https://example.com/img.jpg',
        'thumbnail_url': null,
        'image_size_bytes': null,
        'source_url': null,
        'source_platform': null,
        'source_note': null,
        'uploader_id': 'user-2',
        'status': 'approved',
        'reviewer_id': 'admin-1',
        'review_note': null,
        'reviewed_at': '2026-04-16T12:00:00Z',
        'matched_work_id': 'work-1',
        'created_poster_id': 'poster-1',
        'created_at': '2026-04-16T10:00:00Z',
      };

      final sub = Submission.fromRow(row);

      expect(sub.batchId, isNull);
      expect(sub.region, Region.other); // null maps to other via fromString
      expect(sub.posterReleaseType, isNull);
      expect(sub.isApproved, true);
      expect(sub.matchedWorkId, 'work-1');
      expect(sub.createdPosterId, 'poster-1');
    });
  });

  group('Submission.toInsertRow', () {
    test('includes required and provided optional fields', () {
      final sub = Submission(
        id: 'ignored',
        workTitleZh: '全面啟動',
        workTitleEn: 'Inception',
        movieReleaseYear: 2010,
        region: Region.jp,
        imageUrl: 'https://example.com/img.jpg',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        uploaderId: 'user-1',
        status: SubmissionStatus.pending,
        createdAt: DateTime.now(),
        channelCategory: ChannelCategory.cinema,
        channelName: '威秀',
      );

      final row = sub.toInsertRow();

      expect(row['work_title_zh'], '全面啟動');
      expect(row['work_title_en'], 'Inception');
      expect(row['movie_release_year'], 2010);
      expect(row['region'], 'JP');
      expect(row['channel_category'], 'cinema');
      expect(row['channel_name'], '威秀');
      expect(row['image_url'], 'https://example.com/img.jpg');
      expect(row['uploader_id'], 'user-1');
      // Should not include id, status, reviewer fields
      expect(row.containsKey('id'), false);
      expect(row.containsKey('status'), false);
    });

    test('omits null optional fields', () {
      final sub = Submission(
        id: 'x',
        workTitleZh: '測試',
        imageUrl: 'https://example.com/img.jpg',
        uploaderId: 'user-1',
        status: SubmissionStatus.pending,
        createdAt: DateTime.now(),
      );

      final row = sub.toInsertRow();

      expect(row.containsKey('work_title_en'), false);
      expect(row.containsKey('movie_release_year'), false);
      expect(row.containsKey('poster_name'), false);
      expect(row.containsKey('channel_category'), false);
    });
  });
}
