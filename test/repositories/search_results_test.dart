import 'package:flutter_test/flutter_test.dart';
import 'package:poster_app/data/repositories/search_repository.dart';

void main() {
  group('SearchResults.fromJson', () {
    test('parses full payload with works, posters, users', () {
      final r = SearchResults.fromJson({
        'works': [
          {
            'id': 'w-1',
            'title_zh': '追殺比爾',
            'title_en': 'Kill Bill',
            'movie_release_year': 2003,
            'poster_count': 4,
          }
        ],
        'posters': [
          {
            'id': 'p-1',
            'title': '追殺比爾',
            'year': 2003,
            'tags': <String>[],
            'poster_url': 'https://example.com/p.jpg',
            'uploader_id': 'u-1',
            'status': 'approved',
            'created_at': '2024-01-01T00:00:00Z',
          }
        ],
        'users': [
          {
            'id': 'u-1',
            'display_name': 'Henry',
            'role': 'user',
          }
        ],
      });

      expect(r.works, hasLength(1));
      expect(r.posters, hasLength(1));
      expect(r.users, hasLength(1));
      expect(r.works.first.titleZh, '追殺比爾');
      expect(r.posters.first.title, '追殺比爾');
      expect(r.users.first.displayName, 'Henry');
      expect(r.isEmpty, isFalse);
      expect(r.totalCount, 3);
    });

    test('handles empty arrays', () {
      final r = SearchResults.fromJson({
        'works': <dynamic>[],
        'posters': <dynamic>[],
        'users': <dynamic>[],
      });
      expect(r.isEmpty, isTrue);
      expect(r.totalCount, 0);
    });

    test('handles missing keys gracefully', () {
      final r = SearchResults.fromJson(<String, dynamic>{});
      expect(r.isEmpty, isTrue);
    });

    test('empty sentinel is truly empty', () {
      expect(SearchResults.empty.isEmpty, isTrue);
      expect(SearchResults.empty.totalCount, 0);
    });
  });
}
