import 'package:flutter_test/flutter_test.dart';
import 'package:poster_app/data/repositories/user_repository.dart';

void main() {
  group('PublicProfile.fromRow', () {
    test('parses full payload', () {
      final p = PublicProfile.fromRow({
        'id': 'u-1',
        'display_name': 'Henry',
        'avatar_url': 'https://example.com/a.jpg',
        'bio': 'Kill Bill forever',
        'submission_count': 12,
        'approved_poster_count': 8,
      });
      expect(p.id, 'u-1');
      expect(p.displayName, 'Henry');
      expect(p.avatarUrl, 'https://example.com/a.jpg');
      expect(p.bio, 'Kill Bill forever');
      expect(p.submissionCount, 12);
      expect(p.approvedPosterCount, 8);
    });

    test('handles null optional fields', () {
      final p = PublicProfile.fromRow({
        'id': 'u-1',
        'display_name': null,
        'avatar_url': null,
        'bio': null,
        'submission_count': null,
        'approved_poster_count': null,
      });
      expect(p.displayName, '');
      expect(p.avatarUrl, isNull);
      expect(p.bio, isNull);
      expect(p.submissionCount, 0);
      expect(p.approvedPosterCount, 0);
    });
  });
}
