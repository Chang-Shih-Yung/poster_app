import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:poster_app/core/theme/app_theme.dart';

/// Guards the day/night static-flag mechanism. v18 added AppTheme._day,
/// set by ThemeModeNotifier. Every color reference MUST go through a
/// getter so it re-resolves at build time; this test catches any future
/// `const Color = AppTheme.bg` slip that'd freeze the token.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppTheme.setDayMode(false); // baseline
  });

  test('AppTheme.bg flips with setDayMode', () {
    AppTheme.setDayMode(false);
    final night = AppTheme.bg;
    AppTheme.setDayMode(true);
    final day = AppTheme.bg;
    expect(night, isNot(equals(day)),
        reason: 'bg must differ between day and night');
    // Night: kit canonical --ink. Day: neutral white (Threads-style),
    // replacing the earlier warm-paper #F5F2EC per v18 reskin.
    expect(night, const Color(0xFF121212));
    expect(day, const Color(0xFFFFFFFF));
  });

  test('text token flips with setDayMode', () {
    AppTheme.setDayMode(false);
    expect(AppTheme.text, const Color(0xFFFFFFFF));
    AppTheme.setDayMode(true);
    expect(AppTheme.text, const Color(0xFF111111));
  });

  test('isDay reflects current static flag', () {
    AppTheme.setDayMode(false);
    expect(AppTheme.isDay, false);
    AppTheme.setDayMode(true);
    expect(AppTheme.isDay, true);
  });

  testWidgets('Theme rebuild picks up flipped bg', (tester) async {
    const _testKey = ValueKey('themeBox');
    AppTheme.setDayMode(false);
    Widget build() => MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(builder: (ctx) {
            return ColoredBox(
              key: _testKey,
              color: AppTheme.bg,
              child: const SizedBox.expand(),
            );
          }),
        );

    await tester.pumpWidget(build());
    final nightBox = tester.widget<ColoredBox>(find.byKey(_testKey));
    expect(nightBox.color, const Color(0xFF121212));

    AppTheme.setDayMode(true);
    await tester.pumpWidget(build());
    final dayBox = tester.widget<ColoredBox>(find.byKey(_testKey));
    expect(dayBox.color, const Color(0xFFFFFFFF));
  });
}
