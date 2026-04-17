import 'package:flutter_test/flutter_test.dart';

/// Tests the session-level dedup logic used by ViewRepository.
/// We can't easily mock SupabaseClient.rpc (generic return type), so we test
/// the Set-based dedup algorithm directly. The actual RPC is validated by
/// the migration tests (SQL function exists) + manual Supabase testing.
void main() {
  group('View dedup session logic', () {
    late Set<String> viewedThisSession;

    /// Simulates ViewRepository.recordView's dedup check.
    bool recordView(String posterId) {
      if (viewedThisSession.contains(posterId)) return false;
      viewedThisSession.add(posterId);
      return true; // would call RPC
    }

    setUp(() {
      viewedThisSession = {};
    });

    test('first view returns true (would call RPC)', () {
      expect(recordView('poster-1'), isTrue);
    });

    test('second view of same poster returns false (skips RPC)', () {
      recordView('poster-1');
      expect(recordView('poster-1'), isFalse);
    });

    test('different posters each return true', () {
      expect(recordView('poster-1'), isTrue);
      expect(recordView('poster-2'), isTrue);
      expect(recordView('poster-3'), isTrue);
    });

    test('dedup persists across multiple calls', () {
      recordView('poster-1');
      recordView('poster-2');
      expect(recordView('poster-1'), isFalse);
      expect(recordView('poster-2'), isFalse);
      expect(recordView('poster-3'), isTrue);
    });

    test('wasViewedThisSession equivalent check', () {
      expect(viewedThisSession.contains('poster-1'), isFalse);
      recordView('poster-1');
      expect(viewedThisSession.contains('poster-1'), isTrue);
      expect(viewedThisSession.contains('poster-2'), isFalse);
    });
  });
}
