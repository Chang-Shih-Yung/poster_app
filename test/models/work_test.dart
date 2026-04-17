import 'package:flutter_test/flutter_test.dart';
import 'package:poster_app/data/models/work.dart';

void main() {
  group('Work.fromRow', () {
    test('parses full row', () {
      final row = {
        'id': 'abc-123',
        'work_key': 'inception-2010-07-16',
        'title_zh': '全面啟動',
        'title_en': 'Inception',
        'movie_release_date': '2010-07-16',
        'movie_release_year': 2010,
        'poster_count': 3,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-02T00:00:00Z',
      };

      final work = Work.fromRow(row);

      expect(work.id, 'abc-123');
      expect(work.workKey, 'inception-2010-07-16');
      expect(work.titleZh, '全面啟動');
      expect(work.titleEn, 'Inception');
      expect(work.movieReleaseYear, 2010);
      expect(work.posterCount, 3);
      expect(work.displayTitle, '全面啟動');
    });

    test('handles nullable fields', () {
      final row = {
        'id': 'abc-123',
        'work_key': null,
        'title_zh': '測試',
        'title_en': null,
        'movie_release_date': null,
        'movie_release_year': null,
        'poster_count': 0,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': null,
      };

      final work = Work.fromRow(row);

      expect(work.workKey, isNull);
      expect(work.titleEn, isNull);
      expect(work.movieReleaseDate, isNull);
      expect(work.movieReleaseYear, isNull);
      expect(work.posterCount, 0);
    });

    test('displayTitle prefers titleZh', () {
      final work = Work.fromRow({
        'id': '1',
        'work_key': null,
        'title_zh': '中文',
        'title_en': 'English',
        'movie_release_date': null,
        'movie_release_year': null,
        'poster_count': 0,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': null,
      });
      expect(work.displayTitle, '中文');
    });
  });

  group('Work.toInsertRow', () {
    test('includes all provided fields', () {
      final work = Work(
        id: 'ignored',
        titleZh: '全面啟動',
        titleEn: 'Inception',
        workKey: 'inception-2010',
        movieReleaseYear: 2010,
      );

      final row = work.toInsertRow();

      expect(row['title_zh'], '全面啟動');
      expect(row['title_en'], 'Inception');
      expect(row['work_key'], 'inception-2010');
      expect(row['movie_release_year'], 2010);
      expect(row.containsKey('id'), false);
    });

    test('omits null fields', () {
      final work = Work(id: 'x', titleZh: '測試');
      final row = work.toInsertRow();

      expect(row.containsKey('title_en'), false);
      expect(row.containsKey('work_key'), false);
      expect(row.containsKey('movie_release_year'), false);
    });
  });
}
