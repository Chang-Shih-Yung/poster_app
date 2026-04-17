import 'package:flutter_test/flutter_test.dart';
import 'package:poster_app/data/models/social.dart';

void main() {
  group('MiniUser.fromRow', () {
    test('parses full row', () {
      final u = MiniUser.fromRow({
        'id': 'u-1',
        'name': 'Henry',
        'avatar': 'https://example.com/a.jpg',
      });
      expect(u.id, 'u-1');
      expect(u.name, 'Henry');
      expect(u.avatarUrl, 'https://example.com/a.jpg');
    });

    test('null name defaults to empty string', () {
      final u = MiniUser.fromRow({'id': 'u-1', 'name': null, 'avatar': null});
      expect(u.name, '');
      expect(u.avatarUrl, isNull);
    });
  });

  group('TrendingPoster.fromRow', () {
    test('parses poster + fav count + collectors', () {
      final t = TrendingPoster.fromRow({
        'id': 'p-1',
        'title': '追殺比爾',
        'poster_url': 'https://example.com/p.jpg',
        'uploader_id': 'u-0',
        'status': 'approved',
        'tags': <String>[],
        'created_at': '2024-01-01T00:00:00Z',
        'recent_fav_count': 12,
        'collectors': [
          {'id': 'u-1', 'name': 'Alice', 'avatar': null},
          {'id': 'u-2', 'name': 'Bob', 'avatar': 'https://a.jpg'},
        ],
      });
      expect(t.poster.title, '追殺比爾');
      expect(t.recentFavCount, 12);
      expect(t.collectors, hasLength(2));
      expect(t.collectors[0].name, 'Alice');
      expect(t.collectors[1].avatarUrl, 'https://a.jpg');
    });

    test('missing collectors field defaults to empty list', () {
      final t = TrendingPoster.fromRow({
        'id': 'p-1',
        'title': 't',
        'poster_url': 'x',
        'uploader_id': 'u',
        'status': 'approved',
        'tags': <String>[],
        'created_at': '2024-01-01T00:00:00Z',
        'recent_fav_count': 3,
      });
      expect(t.collectors, isEmpty);
    });
  });

  group('CollectorPreview.fromRow', () {
    test('parses full row including thumbs', () {
      final c = CollectorPreview.fromRow({
        'id': 'u-1',
        'display_name': 'Henry',
        'avatar_url': null,
        'bio': '收電影海報',
        'submission_count': 5,
        'activity_count': 12,
        'recent_posters': [
          {'id': 'p-1', 'thumbnail_url': 't1', 'poster_url': 'p1'},
          {'id': 'p-2', 'thumbnail_url': null, 'poster_url': 'p2'},
        ],
      });
      expect(c.userId, 'u-1');
      expect(c.displayName, 'Henry');
      expect(c.activityCount, 12);
      expect(c.recentPosters, hasLength(2));
      expect(c.recentPosters[0].thumbnailUrl, 't1');
      expect(c.recentPosters[1].displayUrl, 'p2'); // falls back to posterUrl
    });
  });

  group('FollowActivity.fromRow', () {
    test('parses actor metadata', () {
      final a = FollowActivity.fromRow({
        'id': 'p-1',
        'title': '龍貓',
        'poster_url': 'x',
        'uploader_id': 'u-0',
        'status': 'approved',
        'tags': <String>[],
        'created_at': '2024-01-01T00:00:00Z',
        'actor_id': 'u-99',
        'actor_name': 'Alice',
        'actor_avatar': 'https://a.jpg',
        'action_type': 'favorite',
        'action_at': '2024-02-01T10:00:00Z',
      });
      expect(a.actorId, 'u-99');
      expect(a.actorName, 'Alice');
      expect(a.actionType, 'favorite');
      expect(a.actionAt.year, 2024);
      expect(a.poster.title, '龍貓');
    });
  });

  group('UserRelationshipStats.fromRow', () {
    test('parses counts + flags', () {
      final s = UserRelationshipStats.fromRow({
        'follower_count': 42,
        'following_count': 17,
        'am_i_following': true,
        'is_following_me': false,
      });
      expect(s.followerCount, 42);
      expect(s.followingCount, 17);
      expect(s.amIFollowing, isTrue);
      expect(s.isFollowingMe, isFalse);
    });

    test('empty sentinel has zeros + false flags', () {
      expect(UserRelationshipStats.empty.followerCount, 0);
      expect(UserRelationshipStats.empty.amIFollowing, isFalse);
    });

    test('missing fields default safely', () {
      final s = UserRelationshipStats.fromRow(<String, dynamic>{});
      expect(s.followerCount, 0);
      expect(s.followingCount, 0);
      expect(s.amIFollowing, isFalse);
      expect(s.isFollowingMe, isFalse);
    });
  });

  group('Poster.fromRow social extension', () {
    // Verifies that uploader_name/uploader_avatar flow through correctly
    // for rows coming from recent_approved_feed / trending_favorites.
    test('picks up uploader_name/avatar from RPC row', () {
      // Note: this imports directly; covered by poster_test.dart too,
      // just verifying the new social fields round-trip.
      // Inline here to keep group intent clear.
      const row = {
        'id': 'p-1',
        'title': 'Chungking Express',
        'poster_url': 'x',
        'uploader_id': 'u-99',
        'status': 'approved',
        'tags': <String>[],
        'created_at': '2024-01-01T00:00:00Z',
        'uploader_name': 'Henry',
        'uploader_avatar': 'https://a.jpg',
      };
      // Avoid leaking import order — use library-level helper.
      final activity = FollowActivity.fromRow({
        ...row,
        'actor_id': 'u-99',
        'actor_name': 'Henry',
        'actor_avatar': 'https://a.jpg',
        'action_type': 'favorite',
        'action_at': '2024-01-01T00:00:00Z',
      });
      expect(activity.poster.uploaderName, 'Henry');
      expect(activity.poster.uploaderAvatar, 'https://a.jpg');
    });
  });
}
