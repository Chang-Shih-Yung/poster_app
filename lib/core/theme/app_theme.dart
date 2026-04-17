import 'package:flutter/material.dart';
// google_fonts dropped 2026-04-17 — was causing first-paint CJK tofu (□□□)
// because fonts were fetched from CDN after initial render. NotoSansTC is
// now bundled as local asset in pubspec.yaml.

/// v4 "Transparent Minimal" theme.
///
/// Design rules:
/// - NO accent color. Luxury = colorless, transparent, blur.
/// - Primary surface is pure black. Text hierarchy by alpha, not color.
/// - CTA is pure white pill on black; active states are white, not tinted.
/// - Fonts: Geist (latin) + Noto Sans TC (Chinese). No italic, no serif.
/// - Icons: lucide_icons_flutter (rounded line icons).
class AppTheme {
  // Surface tokens
  static const bg = Color(0xFF050506);
  static const surface = Color(0xFF0A0A0C);
  static const surfaceRaised = Color(0xFF131316);
  static const surfaceGlass = Color(0x8C141416); // rgba(20,20,22,0.55)

  // Text tokens (all white w/ alpha)
  static const text = Color(0xFFFFFFFF);
  static Color get textMute => Colors.white.withValues(alpha: 0.55);
  static Color get textFaint => Colors.white.withValues(alpha: 0.35);

  // Line tokens
  static Color get line1 => Colors.white.withValues(alpha: 0.08);
  static Color get line2 => Colors.white.withValues(alpha: 0.14);

  // Chip tokens
  static Color get chipBg => Colors.white.withValues(alpha: 0.08);
  static Color get chipBgStrong => Colors.white.withValues(alpha: 0.14);

  // Motion curves (matches v4 Motion spec)
  static const Curve easeStandard = Cubic(0.2, 0.8, 0.2, 1);
  static const Curve easeOut = Cubic(0.4, 0, 1, 1);
  static const Duration motionFast = Duration(milliseconds: 180);
  static const Duration motionMed = Duration(milliseconds: 220);
  static const Duration motionSlow = Duration(milliseconds: 320);

  // Spacing scale (4pt)
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;
  static const double s12 = 48;

  static TextTheme _textTheme() {
    final base = ThemeData.dark().textTheme;
    // NotoSansTC as primary — bundled local asset, no CDN fetch, no tofu.
    // CanvasKit synthesizes FontWeight.w600 from the Medium (w500) we ship;
    // close enough visually, saves ~4.5MB vs bundling a third weight.
    TextStyle style(TextStyle? s, {double? size, FontWeight? w, double? ls}) {
      return (s ?? const TextStyle()).copyWith(
        fontFamily: 'NotoSansTC',
        fontSize: size,
        fontWeight: w,
        letterSpacing: ls,
        color: text,
      );
    }

    return base.copyWith(
      displayLarge: style(base.displayLarge,
          size: 56, w: FontWeight.w500, ls: -1.8),
      displayMedium: style(base.displayMedium,
          size: 44, w: FontWeight.w500, ls: -1.4),
      displaySmall: style(base.displaySmall,
          size: 34, w: FontWeight.w500, ls: -0.8),
      headlineLarge: style(base.headlineLarge,
          size: 28, w: FontWeight.w500, ls: -0.6),
      headlineMedium: style(base.headlineMedium,
          size: 24, w: FontWeight.w500, ls: -0.4),
      headlineSmall: style(base.headlineSmall,
          size: 20, w: FontWeight.w500, ls: -0.2),
      titleLarge:
          style(base.titleLarge, size: 18, w: FontWeight.w600, ls: -0.2),
      titleMedium:
          style(base.titleMedium, size: 16, w: FontWeight.w500, ls: -0.1),
      titleSmall: style(base.titleSmall, size: 14, w: FontWeight.w500),
      bodyLarge: style(base.bodyLarge, size: 16, w: FontWeight.w400),
      bodyMedium: style(base.bodyMedium, size: 14, w: FontWeight.w400),
      bodySmall: style(base.bodySmall, size: 12, w: FontWeight.w400)
          .copyWith(color: textMute),
      labelLarge:
          style(base.labelLarge, size: 13, w: FontWeight.w500, ls: 0.3),
      labelMedium:
          style(base.labelMedium, size: 11, w: FontWeight.w500, ls: 1.2),
      labelSmall:
          style(base.labelSmall, size: 10, w: FontWeight.w500, ls: 1.6),
    );
  }

  static ThemeData dark() {
    final textTheme = _textTheme();
    final scheme = ColorScheme.dark(
      surface: surface,
      onSurface: text,
      primary: text,
      onPrimary: Colors.black,
      secondary: text,
      onSecondary: Colors.black,
      surfaceContainerLowest: bg,
      surfaceContainerLow: surface,
      surfaceContainer: surfaceRaised,
      surfaceContainerHigh: surfaceRaised,
      surfaceContainerHighest: surfaceRaised,
      onSurfaceVariant: textMute,
      outline: line2,
      outlineVariant: line1,
      error: const Color(0xFFE86464),
      onError: Colors.white,
    );
    return _build(scheme, bg, textTheme);
  }

  static ThemeData light() => dark(); // one mode only

  static ThemeData _build(
      ColorScheme scheme, Color scaffoldBg, TextTheme textTheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      dividerColor: line1,
      splashFactory: InkSparkle.splashFactory,
      canvasColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        toolbarTextStyle: textTheme.bodyMedium,
        iconTheme: IconThemeData(color: text, size: 22),
      ),
      cardTheme: CardThemeData(
        color: surfaceRaised,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: line1),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: chipBg,
        selectedColor: text,
        labelStyle:
            textTheme.labelLarge?.copyWith(color: text, fontWeight: FontWeight.w500),
        secondaryLabelStyle:
            textTheme.labelLarge?.copyWith(color: Colors.black),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        showCheckmark: false,
      ),
      // White pill CTA
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: text,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          side: BorderSide(color: line2),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: text,
          textStyle: textTheme.labelLarge,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(BorderSide.none),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return text;
            return chipBg;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.black;
            return text;
          }),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: chipBg,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: line2, width: 1),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textFaint),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scaffoldBg.withValues(alpha: 0.85),
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: text, size: 24);
          }
          return IconThemeData(color: textMute, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final style = textTheme.labelSmall?.copyWith(
            fontSize: 10,
            letterSpacing: 0.4,
            fontWeight: FontWeight.w500,
          );
          if (states.contains(WidgetState.selected)) {
            return style?.copyWith(color: text);
          }
          return style?.copyWith(color: textFaint);
        }),
        height: 72,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerTheme: DividerThemeData(color: line1, space: 1, thickness: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceGlass,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceRaised,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      iconTheme: const IconThemeData(color: text, size: 22),
      // iOS transitions on every platform (including web) for that slide-in feel.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.2)),
        thickness: const WidgetStatePropertyAll(3),
        radius: const Radius.circular(4),
      ),
    );
  }
}
