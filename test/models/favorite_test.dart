import 'package:flutter_test/flutter_test.dart';
import 'package:poster_app/data/models/favorite.dart';

void main() {
  group('Favorite.fromRow (V2 — no denorm columns)', () {
    test('parses row without poster_title/poster_thumbnail_url', () {
      final row = {
        'poster_id': 'p-1',
        'category_id': 'cat-1',
        'created_at': '2026-04-16T10:00:00Z',
      };

      final fav = Favorite.fromRow(row);

      expect(fav.posterId, 'p-1');
      expect(fav.categoryId, 'cat-1');
      expect(fav.createdAt.year, 2026);
    });

    test('handles null category_id', () {
      final row = {
        'poster_id': 'p-2',
        'category_id': null,
        'created_at': '2026-04-16T10:00:00Z',
      };

      final fav = Favorite.fromRow(row);
      expect(fav.categoryId, isNull);
    });
  });
}
