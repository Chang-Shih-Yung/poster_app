import 'package:flutter_test/flutter_test.dart';
import 'package:poster_app/data/repositories/follow_repository.dart';

/// Coverage for the piece of FollowRepository that doesn't need a live
/// Supabase client: parsing a row returned from the embedded-FK select.
/// Guards against silent regressions in the field keys
/// (display_name / avatar_url / bio) that would turn all follows into
/// "null display name + no avatar".
void main() {
  group('FollowedProfile.fromEmbeddedUsers', () {
    test('maps display_name / avatar_url / bio from embedded users', () {
      final p = FollowedProfile.fromEmbeddedUsers(
        embedded: {
          'id': 'u-1',
          'display_name': 'BIU',
          'avatar_url': 'https://example.com/a.jpg',
          'bio': 'hello',
        },
        fallbackId: 'fallback',
      );
      expect(p.userId, 'u-1');
      expect(p.displayName, 'BIU');
      expect(p.avatarUrl, 'https://example.com/a.jpg');
      expect(p.bio, 'hello');
    });

    test('falls back to row id when embedded has no id', () {
      final p = FollowedProfile.fromEmbeddedUsers(
        embedded: {
          'display_name': 'BIU',
        },
        fallbackId: 'u-fallback',
      );
      expect(p.userId, 'u-fallback');
    });

    test('empty display_name stays empty (no placeholder injected)', () {
      final p = FollowedProfile.fromEmbeddedUsers(
        embedded: {
          'id': 'u-1',
        },
        fallbackId: 'fallback',
      );
      expect(p.displayName, '');
      expect(p.avatarUrl, isNull);
      expect(p.bio, isNull);
    });
  });
}
