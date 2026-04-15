import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertConfigured();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

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

class PosterApp extends StatelessWidget {
  const PosterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Poster App',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
