import 'package:flutter_test/flutter_test.dart';
import 'package:poster_app/data/models/tag.dart';

void main() {
  group('TagCategory.fromRow', () {
    test('parses full row', () {
      final c = TagCategory.fromRow({
        'id': 'c-1',
        'slug': 'country',
        'title_zh': '國別',
        'title_en': 'Country',
        'description_zh': '海報印刷市場',
        'position': 1,
        'icon': 'globe',
        'kind': 'controlled_vocab',
        'is_required': true,
        'allow_other': true,
        'allows_suggestion': true,
      });
      expect(c.slug, 'country');
      expect(c.titleZh, '國別');
      expect(c.kind, 'controlled_vocab');
      expect(c.isRequired, isTrue);
    });

    test('defaults for missing optional fields', () {
      final c = TagCategory.fromRow({
        'id': 'c-1',
        'slug': 'era',
        'title_zh': '年代',
        'title_en': 'Era',
        'position': 2,
        'kind': 'free_tag',
      });
      expect(c.isRequired, isFalse);
      expect(c.allowOther, isTrue); // default
      expect(c.allowsSuggestion, isTrue);
    });
  });

  group('Tag.fromRow', () {
    test('parses aliases array', () {
      final t = Tag.fromRow({
        'id': 't-1',
        'slug': 'designer-huang-hai',
        'category_id': 'c-designer',
        'label_zh': '黃海',
        'label_en': 'Huang Hai',
        'aliases': <dynamic>['huang hai', '黃海', '黄海'],
        'poster_count': 42,
      });
      expect(t.labelZh, '黃海');
      expect(t.aliases, hasLength(3));
      expect(t.aliases.contains('huang hai'), isTrue);
      expect(t.posterCount, 42);
    });

    test('marks is_other_fallback', () {
      final t = Tag.fromRow({
        'id': 't-1',
        'slug': 'country-other',
        'category_id': 'c-1',
        'label_zh': '其他國別',
        'label_en': 'Other Country',
        'is_other_fallback': true,
      });
      expect(t.isOtherFallback, isTrue);
    });

    test('handles empty aliases', () {
      final t = Tag.fromRow({
        'id': 't-1',
        'slug': 'slug',
        'category_id': 'c-1',
        'label_zh': '中',
        'label_en': 'en',
      });
      expect(t.aliases, isEmpty);
      expect(t.deprecated, isFalse);
      expect(t.isCanonical, isTrue);
    });
  });

  group('TagSuggestion.fromRow', () {
    test('parses pending suggestion', () {
      final s = TagSuggestion.fromRow({
        'id': 's-1',
        'suggested_by': 'u-99',
        'suggested_label_zh': '伊朗版',
        'suggested_label_en': 'Iran',
        'category_id': 'c-country',
        'reason': 'Kiarostami 套海報',
        'status': 'pending',
        'created_at': '2026-04-20T10:00:00Z',
      });
      expect(s.isPending, isTrue);
      expect(s.isApproved, isFalse);
      expect(s.suggestedLabelZh, '伊朗版');
      expect(s.reason, 'Kiarostami 套海報');
    });

    test('parses merged state', () {
      final s = TagSuggestion.fromRow({
        'id': 's-1',
        'suggested_label_zh': 'Miyazaki',
        'category_id': 'c-designer',
        'status': 'merged',
        'merged_into_tag_id': 'existing-tag-宮崎駿',
        'created_at': '2026-04-20T10:00:00Z',
      });
      expect(s.isMerged, isTrue);
      expect(s.mergedIntoTagId, 'existing-tag-宮崎駿');
    });

    test('handles minimal row (null optional fields)', () {
      final s = TagSuggestion.fromRow({
        'id': 's-1',
        'suggested_label_zh': '新 tag',
        'category_id': 'c-1',
        'created_at': '2026-04-20T10:00:00Z',
      });
      expect(s.status, 'pending');
      expect(s.reason, isNull);
      expect(s.linkedSubmissionId, isNull);
    });
  });

  group('Tag search fallback logic (no DB)', () {
    // Simulate the fallback the UI + repo implement together.
    // Given user types "miyazaki", the search should match 宮崎駿 via aliases.

    final tags = [
      Tag.fromRow({
        'id': 't-1',
        'slug': 'designer-miyazaki',
        'category_id': 'c-designer',
        'label_zh': '宮崎駿',
        'label_en': 'Hayao Miyazaki',
        'aliases': <dynamic>['miyazaki', '宫崎骏', 'ミヤザキ'],
      }),
      Tag.fromRow({
        'id': 't-2',
        'slug': 'designer-saul-bass',
        'category_id': 'c-designer',
        'label_zh': 'Saul Bass',
        'label_en': 'Saul Bass',
        'aliases': <dynamic>['saul bass', 'bass'],
      }),
    ];

    List<Tag> clientSideSearch(String q) {
      final query = q.toLowerCase().trim();
      if (query.isEmpty) return const [];
      return tags.where((t) {
        if (t.labelZh.toLowerCase().contains(query)) return true;
        if (t.labelEn.toLowerCase().contains(query)) return true;
        return t.aliases.any((a) => a.toLowerCase().contains(query));
      }).toList();
    }

    test('alias hits match', () {
      final r = clientSideSearch('miyazaki');
      expect(r, hasLength(1));
      expect(r.first.labelZh, '宮崎駿');
    });

    test('simplified Chinese alias hit', () {
      final r = clientSideSearch('宫崎');
      expect(r, hasLength(1));
    });

    test('partial english name hit', () {
      final r = clientSideSearch('bass');
      expect(r, hasLength(1));
      expect(r.first.labelZh, 'Saul Bass');
    });

    test('empty query returns empty', () {
      expect(clientSideSearch(''), isEmpty);
      expect(clientSideSearch('   '), isEmpty);
    });
  });
}
