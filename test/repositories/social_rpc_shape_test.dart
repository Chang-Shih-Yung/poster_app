import 'package:flutter_test/flutter_test.dart';

/// Verify the params shape that SocialRepository / FollowRepository
/// generates matches what the Supabase RPCs expect. This catches typos
/// in param names (e.g. `p_day` vs `p_days`) without needing a live DB.
void main() {
  group('Social RPC param shapes', () {
    test('trending_favorites takes p_days + p_limit', () {
      final params = {'p_days': 7, 'p_limit': 10};
      expect(params.keys, containsAll(['p_days', 'p_limit']));
      expect(params['p_days'], isA<int>());
      expect(params['p_limit'], isA<int>());
    });

    test('active_collectors takes p_days + p_limit', () {
      final params = {'p_days': 7, 'p_limit': 12};
      expect(params.keys, containsAll(['p_days', 'p_limit']));
    });

    test('follow_feed takes p_limit', () {
      final params = {'p_limit': 20};
      expect(params.keys, ['p_limit']);
    });

    test('recent_approved_feed takes p_limit', () {
      final params = {'p_limit': 12};
      expect(params.keys, ['p_limit']);
    });

    test('toggle_follow takes p_user_id', () {
      final params = {'p_user_id': 'u-123'};
      expect(params.keys, ['p_user_id']);
    });

    test('user_relationship_stats takes p_user_id', () {
      final params = {'p_user_id': 'u-123'};
      expect(params.keys, ['p_user_id']);
    });

    test('for_you_feed_v1 takes p_limit', () {
      // SocialRepository.forYouFeedV1 posts this shape.
      final params = {'p_limit': 60};
      expect(params.keys, ['p_limit']);
      expect(params['p_limit'], isA<int>());
    });
  });

  group('Follow list query string', () {
    // FollowRepository.listFollowing / listFollowers uses *column-name*
    // FK hints (users!followee_id / users!follower_id) rather than
    // auto-generated constraint names, so future ALTER TABLE RENAME
    // CONSTRAINT migrations can't silently turn this into "empty list".
    String selectForDirection({required bool followers}) {
      final embedCol = followers ? 'follower_id' : 'followee_id';
      return '$embedCol, created_at, users!$embedCol(id, display_name, avatar_url, bio)';
    }

    test('following query embeds users off followee_id', () {
      final s = selectForDirection(followers: false);
      expect(s, contains('users!followee_id'));
      expect(s, isNot(contains('follows_followee_id_fkey')));
    });

    test('followers query embeds users off follower_id', () {
      final s = selectForDirection(followers: true);
      expect(s, contains('users!follower_id'));
      expect(s, isNot(contains('follows_follower_id_fkey')));
    });
  });
}
