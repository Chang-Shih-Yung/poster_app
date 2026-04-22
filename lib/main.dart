import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertConfigured();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // Handle Google OAuth PKCE callback on web.
  //
  // Google returns the user to https://<app>/?code=<authorization_code>
  // after they pick an account. Supabase-Flutter auto-detects
  // hash-fragment auth (#access_token=...) but NOT query-param PKCE
  // codes on web — you have to exchange explicitly. Without this the
  // user lands back on the app with ?code=... in the URL, the
  // SigninPage spins forever because no session ever materialises,
  // and only a hard refresh "fixes" it (the code param gets dropped
  // and Supabase loads nothing, leaving them signed out again).
  if (kIsWeb) {
    final uri = Uri.base;
    final code = uri.queryParameters['code'];
    if (code != null && code.isNotEmpty) {
      try {
        await Supabase.instance.client.auth.exchangeCodeForSession(code);
      } catch (_) {
        // Invalid / stale code — fall through; the signin page will
        // prompt them again rather than silently spinning.
      }
    }
  }

  if (Env.sentryDsn.isEmpty) {
    runApp(const ProviderScope(child: PosterApp()));
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = Env.sentryDsn;
      options.environment = Env.appEnv;
      options.tracesSampleRate = Env.appEnv == 'prod' ? 0.2 : 1.0;
      options.sendDefaultPii = false;
    },
    appRunner: () =>
        runApp(const ProviderScope(child: PosterApp())),
  );
}

/// Mobile viewport width we lock onto on wide screens.
/// 430 ≈ iPhone 15 Pro Max logical width. Wide enough that none of the
/// hand-tuned layouts feel cramped, narrow enough that desktop browsers
/// show the app as a phone sitting on a black desk.
const double _kMobileMaxWidth = 430;

class PosterApp extends ConsumerWidget {
  const PosterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Watching the preference + platform brightness triggers a
    // rebuild (and fresh AppTheme.dark()) whenever either changes —
    // user picks 白天, OS goes into dark mode at sunset, etc.
    final pref = ref.watch(themeModeProvider);
    final osBrightness = MediaQuery.platformBrightnessOf(context);
    final effectiveDay = switch (pref) {
      AppThemeMode.day => true,
      AppThemeMode.night => false,
      AppThemeMode.system => osBrightness == Brightness.light,
    };
    AppTheme.setDayMode(effectiveDay);
    final theme = AppTheme.dark();
    return MaterialApp.router(
      title: 'Poster App',
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      // v18: this is a mobile app. On wide viewports (desktop browser
      // while the author uses Chrome to QA) we don't want the UI to
      // stretch into an ugly 1400px-wide landscape page — lock it to
      // mobile width, centred, with black gutters. On native phones
      // and narrow browsers this is a no-op.
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        final screen = MediaQuery.sizeOf(context);
        if (screen.width <= _kMobileMaxWidth) return child;
        final mobile = Size(_kMobileMaxWidth, screen.height);
        return ColoredBox(
          color: const Color(0xFF000000),
          child: Center(
            child: SizedBox.fromSize(
              size: mobile,
              // Override MediaQuery size so descendants that read
              // MediaQuery.sizeOf(context).width (e.g. full-bleed
              // hero cards) see the mobile width instead of the
              // desktop window.
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(size: mobile),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
