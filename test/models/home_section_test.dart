import 'package:flutter_test/flutter_test.dart';
import 'package:poster_app/data/models/home_section.dart';

void main() {
  group('HomeSectionV2.fromRow', () {
    test('parses config + items payload', () {
      final s = HomeSectionV2.fromRow({
        'slug': 'popular',
        'title_zh': '熱門',
        'title_en': 'Popular',
        'icon': 'flame',
        'source_type': 'popular',
        'source_params': {'days': 30, 'limit': 10},
        'items': <Map<String, dynamic>>[
          {
            'id': 'p-1',
            'title': '追殺比爾',
            'poster_url': 'https://x/p.jpg',
            'uploader_id': 'u-1',
            'status': 'approved',
            'tags': <String>[],
            'created_at': '2024-01-01T00:00:00Z',
          }
        ],
      });
      expect(s.slug, 'popular');
      expect(s.titleZh, '熱門');
      expect(s.titleEn, 'Popular');
      expect(s.icon, 'flame');
      expect(s.sourceType, 'popular');
      expect(s.sourceParams['days'], 30);
      expect(s.rawItems, hasLength(1));
      expect(s.isEmpty, isFalse);
    });

    test('handles missing items field', () {
      final s = HomeSectionV2.fromRow({
        'slug': 'x',
        'title_zh': 'x',
        'title_en': 'x',
        'source_type': 'popular',
      });
      expect(s.rawItems, isEmpty);
      expect(s.isEmpty, isTrue);
    });

    test('handles missing source_params', () {
      final s = HomeSectionV2.fromRow({
        'slug': 'x',
        'title_zh': 'x',
        'title_en': 'x',
        'source_type': 'popular',
        'items': <dynamic>[],
      });
      expect(s.sourceParams, isEmpty);
    });
  });

  group('HomeSectionV2 type dispatch', () {
    test('popular sourceType → parses as posters', () {
      final s = HomeSectionV2.fromRow({
        'slug': 'popular',
        'title_zh': '熱門',
        'title_en': 'Popular',
        'source_type': 'popular',
        'items': <Map<String, dynamic>>[
          {
            'id': 'p-1', 'title': 't', 'poster_url': 'x',
            'uploader_id': 'u', 'status': 'approved',
            'tags': <String>[], 'created_at': '2024-01-01T00:00:00Z',
          }
        ],
      });
      final posters = s.asPosters();
      expect(posters, hasLength(1));
      expect(posters.first.id, 'p-1');
    });

    test('trending_favorites sourceType → parses as TrendingPoster', () {
      final s = HomeSectionV2.fromRow({
        'slug': 'trending',
        'title_zh': '本週熱門',
        'title_en': 'Trending',
        'source_type': 'trending_favorites',
        'items': <Map<String, dynamic>>[
          {
            'id': 'p-1', 'title': 't', 'poster_url': 'x',
            'uploader_id': 'u', 'status': 'approved',
            'tags': <String>[], 'created_at': '2024-01-01T00:00:00Z',
            'recent_fav_count': 5,
            'collectors': <dynamic>[],
          }
        ],
      });
      final trending = s.asTrending();
      expect(trending, hasLength(1));
      expect(trending.first.recentFavCount, 5);
    });

    test('active_collectors sourceType → parses as CollectorPreview', () {
      final s = HomeSectionV2.fromRow({
        'slug': 'collectors',
        'title_zh': '活躍收藏家',
        'title_en': 'Active',
        'source_type': 'active_collectors',
        'items': <Map<String, dynamic>>[
          {
            'id': 'u-1', 'display_name': 'Henry',
            'submission_count': 5, 'activity_count': 12,
          }
        ],
      });
      final collectors = s.asCollectors();
      expect(collectors, hasLength(1));
      expect(collectors.first.displayName, 'Henry');
    });

    test('follow_feed sourceType → parses as FollowActivity', () {
      final s = HomeSectionV2.fromRow({
        'slug': 'follow',
        'title_zh': '追蹤動態',
        'title_en': 'Follow',
        'source_type': 'follow_feed',
        'items': <Map<String, dynamic>>[
          {
            'id': 'p-1', 'title': 't', 'poster_url': 'x',
            'uploader_id': 'u', 'status': 'approved',
            'tags': <String>[], 'created_at': '2024-01-01T00:00:00Z',
            'actor_id': 'u-99', 'actor_name': 'Alice',
            'action_type': 'favorite',
            'action_at': '2024-02-01T10:00:00Z',
          }
        ],
      });
      final feed = s.asFollowFeed();
      expect(feed, hasLength(1));
      expect(feed.first.actorName, 'Alice');
    });
  });
}
