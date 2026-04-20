import 'package:flutter_test/flutter_test.dart';
import 'package:poster_app/data/models/tag.dart';
import 'package:poster_app/data/repositories/tag_suggestion_repository.dart';

void main() {
  group('SimilarTag.fromRow', () {
    test('parses full row with score', () {
      final m = SimilarTag.fromRow({
        'tag_id': 't-1',
        'slug': 'designer-miyazaki',
        'label_zh': '宮崎駿',
        'label_en': 'Hayao Miyazaki',
        'aliases': <dynamic>['miyazaki', '宫崎骏'],
        'poster_count': 42,
        'similarity': 0.87,
      });
      expect(m.tagId, 't-1');
      expect(m.labelZh, '宮崎駿');
      expect(m.similarity, closeTo(0.87, 0.001));
      expect(m.similarityPercent, 87);
      expect(m.posterCount, 42);
    });

    test('handles missing optional fields safely', () {
      final m = SimilarTag.fromRow({
        'tag_id': 't-1',
        'slug': 'x',
        'label_zh': 'x',
      });
      expect(m.labelEn, '');
      expect(m.similarity, 0.0);
      expect(m.posterCount, 0);
    });
  });

  group('SimilarTag thresholds', () {
    test('thresholds are the right order', () {
      expect(SimilarTag.weakHintThreshold, lessThan(SimilarTag.strongHintThreshold));
      expect(SimilarTag.strongHintThreshold, lessThan(SimilarTag.autoMergeThreshold));
      expect(SimilarTag.autoMergeThreshold, lessThanOrEqualTo(1.0));
    });

    test('admin UI shows hint when score ≥ weakHintThreshold', () {
      final shouldShow = _adminShouldShowHint;
      expect(shouldShow(SimilarTag.weakHintThreshold - 0.01), isFalse);
      expect(shouldShow(SimilarTag.weakHintThreshold), isTrue);
      expect(shouldShow(0.99), isTrue);
    });

    test('user form shows "did you mean" at strongHintThreshold', () {
      final shouldShow = _userShouldShowHint;
      expect(shouldShow(0.74), isFalse);
      expect(shouldShow(SimilarTag.strongHintThreshold), isTrue);
    });

    test('similarityPercent rounds sensibly', () {
      final cases = {
        0.0: 0,
        0.5: 50,
        0.856: 86,
        0.951: 95,
        1.0: 100,
      };
      cases.forEach((score, expected) {
        final m = SimilarTag(
          tagId: 't', slug: 's', labelZh: 'x', labelEn: 'x',
          similarity: score,
        );
        expect(m.similarityPercent, expected,
            reason: 'score $score should → $expected%');
      });
    });
  });

  group('SuggestionOutcome.fromJson', () {
    test('parses auto-merged result', () {
      final o = SuggestionOutcome.fromJson({
        'auto_merged': true,
        'tag_id': 'existing-tag-id',
        'tag_label_zh': '宮崎駿',
        'similarity': 0.97,
      });
      expect(o, isA<SuggestionAutoMerged>());
      final merged = o as SuggestionAutoMerged;
      expect(merged.tagId, 'existing-tag-id');
      expect(merged.tagLabelZh, '宮崎駿');
      expect(merged.similarity, closeTo(0.97, 0.001));
    });

    test('parses queued result', () {
      final o = SuggestionOutcome.fromJson({
        'auto_merged': false,
        'suggestion_id': 's-1',
      });
      expect(o, isA<SuggestionQueued>());
      expect((o as SuggestionQueued).suggestionId, 's-1');
    });

    test('defaults to queued when auto_merged missing', () {
      final o = SuggestionOutcome.fromJson({
        'suggestion_id': 's-2',
      });
      expect(o, isA<SuggestionQueued>());
    });
  });
}

bool _adminShouldShowHint(double score) =>
    score >= SimilarTag.weakHintThreshold;

bool _userShouldShowHint(double score) =>
    score >= SimilarTag.strongHintThreshold;
