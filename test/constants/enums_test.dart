import 'package:flutter_test/flutter_test.dart';
import 'package:poster_app/core/constants/enums.dart';

void main() {
  group('Region', () {
    test('fromString matches known values', () {
      expect(Region.fromString('TW'), Region.tw);
      expect(Region.fromString('JP'), Region.jp);
      expect(Region.fromString('US'), Region.us);
    });

    test('fromString defaults to other for unknown', () {
      expect(Region.fromString('XX'), Region.other);
      expect(Region.fromString(null), Region.other);
    });

    test('value roundtrip', () {
      for (final r in Region.values) {
        expect(Region.fromString(r.value), r);
      }
    });
  });

  group('ReleaseType', () {
    test('fromString matches known values', () {
      expect(ReleaseType.fromString('theatrical'), ReleaseType.theatrical);
      expect(ReleaseType.fromString('reissue'), ReleaseType.reissue);
    });

    test('fromString defaults to other', () {
      expect(ReleaseType.fromString('unknown'), ReleaseType.other);
      expect(ReleaseType.fromString(null), ReleaseType.other);
    });

    test('value roundtrip', () {
      for (final r in ReleaseType.values) {
        expect(ReleaseType.fromString(r.value), r);
      }
    });
  });

  group('SizeType', () {
    test('fromString matches known values', () {
      expect(SizeType.fromString('B1'), SizeType.b1);
      expect(SizeType.fromString('A4'), SizeType.a4);
      expect(SizeType.fromString('mini'), SizeType.mini);
    });

    test('value roundtrip', () {
      for (final s in SizeType.values) {
        expect(SizeType.fromString(s.value), s);
      }
    });
  });

  group('ChannelCategory', () {
    test('fromString matches known values', () {
      expect(ChannelCategory.fromString('cinema'), ChannelCategory.cinema);
      expect(ChannelCategory.fromString('retail'), ChannelCategory.retail);
    });

    test('value roundtrip', () {
      for (final c in ChannelCategory.values) {
        expect(ChannelCategory.fromString(c.value), c);
      }
    });
  });

  group('SubmissionStatus', () {
    test('fromString matches known values', () {
      expect(SubmissionStatus.fromString('pending'), SubmissionStatus.pending);
      expect(
          SubmissionStatus.fromString('approved'), SubmissionStatus.approved);
      expect(
          SubmissionStatus.fromString('rejected'), SubmissionStatus.rejected);
      expect(SubmissionStatus.fromString('duplicate'),
          SubmissionStatus.duplicate);
    });

    test('fromString defaults to pending', () {
      expect(SubmissionStatus.fromString('unknown'), SubmissionStatus.pending);
      expect(SubmissionStatus.fromString(null), SubmissionStatus.pending);
    });

    test('value roundtrip', () {
      for (final s in SubmissionStatus.values) {
        expect(SubmissionStatus.fromString(s.value), s);
      }
    });
  });
}
