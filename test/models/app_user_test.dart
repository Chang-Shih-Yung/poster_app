import 'package:flutter_test/flutter_test.dart';
import 'package:poster_app/data/models/app_user.dart';

void main() {
  group('AppUser.fromRow', () {
    test('parses full row with V2 fields', () {
      final row = {
        'id': 'u-1',
        'display_name': 'Test User',
        'avatar_url': 'https://example.com/avatar.jpg',
        'role': 'admin',
        'submission_count': 5,
        'is_public': false,
        'bio': 'Hello world',
      };

      final user = AppUser.fromRow(row);

      expect(user.id, 'u-1');
      expect(user.displayName, 'Test User');
      expect(user.avatarUrl, 'https://example.com/avatar.jpg');
      expect(user.role, 'admin');
      expect(user.isAdmin, true);
      expect(user.submissionCount, 5);
      expect(user.isPublic, false);
      expect(user.bio, 'Hello world');
    });

    test('handles missing V2 fields (V1 compat)', () {
      final row = {
        'id': 'u-2',
        'display_name': null,
        'avatar_url': null,
        'role': 'user',
        'submission_count': 0,
        // V2 fields absent
      };

      final user = AppUser.fromRow(row);

      expect(user.displayName, '');
      expect(user.isAdmin, false);
      expect(user.isPublic, true); // default
      expect(user.bio, isNull);
    });

    test('owner role is admin', () {
      final user = AppUser.fromRow({
        'id': 'u-3',
        'display_name': 'Owner',
        'avatar_url': null,
        'role': 'owner',
        'submission_count': 0,
      });
      expect(user.isAdmin, true);
    });
  });
}
