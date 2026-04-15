class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  static const appEnv =
      String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL / SUPABASE_ANON_KEY. '
        'Run: flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
  }
}
