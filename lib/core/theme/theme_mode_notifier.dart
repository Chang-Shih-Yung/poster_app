import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User's theme preference. Three possible values:
///   · system — follow the OS brightness (default for new users)
///   · night  — force dark regardless of OS
///   · day    — force light regardless of OS
///
/// The *effective* day/night resolution happens in PosterApp, where
/// MediaQuery.platformBrightness is available. This notifier only
/// stores the user's preference; it doesn't know (and shouldn't
/// know) what that resolves to in pixels.
enum AppThemeMode { system, night, day }

const _key = 'theme.mode';

class ThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    // Load from prefs asynchronously; synchronously return system so
    // first paint has a deterministic starting point. The actual
    // day/night pixel resolution happens in PosterApp.
    _load();
    return AppThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    state = switch (raw) {
      'day' => AppThemeMode.day,
      'night' => AppThemeMode.night,
      _ => AppThemeMode.system,
    };
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, AppThemeMode>(ThemeModeNotifier.new);
