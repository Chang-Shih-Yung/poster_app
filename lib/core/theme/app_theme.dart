import 'package:flutter/material.dart';
// google_fonts dropped 2026-04-17 — was causing first-paint CJK tofu (□□□)
// because fonts were fetched from CDN after initial render. NotoSansTC is
// now bundled as local asset in pubspec.yaml.

/// v13 "Cool Ink + Liquid Glass" theme (was v4 "Transparent Minimal").
///
/// 2026-04-20 — palette shifted from pure black to **Cool Ink** (#0D1116):
/// a slight blue undertone makes glass blur read as ambient light instead
/// of grey haze. Glass surfaces (Glass widget) replace the old "raised
/// card" pattern for top chrome, bottom nav, and detail drawer.
///
/// Design rules (v13):
/// - NO accent color. Hierarchy = colorless transparency + blur.
/// - Primary surface is **Cool Ink** (#0D1116), not pure black.
/// - Glassmorphism: 20px backdropFilter + saturate(140%) + 1px line2 border
///   + 1px inset top highlight + soft drop shadow. Use the [Glass] widget.
/// - CTA is pure white pill on ink; active states are white, not tinted.
/// - Bottom nav is a floating glass pill island (28dp from bottom),
///   not a full-width bar. Two circular icons: home + heart.
/// - Detail page is a Fuji drawer: full-bleed image background + glass
///   bottom panel with handle, 32px editorial title, stats row, white CTA.
/// - Fonts: Inter (latin) + Noto Sans TC (Chinese), w400-w700, no serif.
/// - Icons: lucide_icons_flutter (rounded line icons).
class AppTheme {
  // ── Day / Night mode (v18 tweak) ─────────────────────────────────────
  // Static flag, flipped by [themeModeProvider] on startup + at each
  // toggle. MaterialApp rebuilds on mode change, so every AppTheme.*
  // getter below resolves against the new value. Keep in lockstep with
  // the provider — never flip this directly.
  static bool _day = false;
  static bool get isDay => _day;

  /// Called by `PosterApp.build` before constructing the MaterialApp.
  /// Safe no-op if value unchanged.
  static void setDayMode(bool v) {
    _day = v;
  }

  // ── Palette — resolves per mode ──────────────────────────────────────
  // Night: kit canonical Cool Ink (ui_kits/poster/colors_and_type.css).
  // Day:   neutral black/white (Threads / iOS-system vibe) — pure
  //        white bg, near-black ink, hairline cool-gray tint on raised
  //        surfaces so cards stay visible on white without looking
  //        warm/paper-y. The earlier "warm paper" day palette
  //        (#F5F2EC) read yellow; this swap mirrors the Threads app
  //        the user referenced.

  // ── Palette: aligned to Spotify Encore tokens ─────────────────────
  // Night values match Spotify's content-first darkness: #121212 bg,
  // #181818 card, stepped surface tones for elevation. Day palette
  // stays parked for a future editorial-white mode but is currently
  // unreachable (setDayMode is hard-locked to false in main.dart).
  //
  // Colours: the app is monochrome by design — posters do all the
  // chromatic work. The only remaining hue is `favoriteActive` red,
  // kept as a semantic signal for the heart. No blue / green accent.
  static Color get bg =>
      _day ? const Color(0xFFFFFFFF) : const Color(0xFF121212);
  static Color get surface =>
      _day ? const Color(0xFFF4F5F7) : const Color(0xFF181818);
  static Color get surfaceAlt =>
      _day ? const Color(0xFFECEDEF) : const Color(0xFF1F1F1F);
  static Color get surfaceRaised =>
      _day ? const Color(0xFFE4E5E8) : const Color(0xFF252525);
  // Legacy aliases — ink2/3 were the pre-v19 names; kept so existing
  // widget code keeps compiling during the design-system rollout.
  static Color get ink2 => surface;
  static Color get ink3 => surfaceAlt;
  static Color get surfaceGlass => _day
      ? const Color(0xD9FFFFFF)
      : const Color(0x8C141414); // rgba(20,20,20,0.55)

  // Text — Spotify palette: #ffffff / #b3b3b3 / #7c7c7c.
  static Color get text =>
      _day ? const Color(0xFF111111) : const Color(0xFFFFFFFF);
  static Color get textMute => _day
      ? const Color(0xFF6B6B6B) // near-equiv to 60% black
      : const Color(0xFFB3B3B3); // Spotify secondary
  static Color get textFaint => _day
      ? const Color(0xFF999999)
      : const Color(0xFF7C7C7C); // Spotify tertiary

  // Line tokens — concrete dark neutrals on night (no more alpha-
  // based tinting that shifted with background). Matches Spotify's
  // stepped borders `#2a2a2a` / `#4d4d4d` / `#7c7c7c`.
  static Color get line1 => _day
      ? const Color(0xFFEDEDED)
      : const Color(0xFF2A2A2A); // hairline
  static Color get line2 => _day
      ? const Color(0xFFDEDEDE)
      : const Color(0xFF4D4D4D); // visible border
  static Color get line3 => _day
      ? const Color(0xFFBFBFBF)
      : const Color(0xFF7C7C7C); // prominent

  // Chip tokens — surfaces, not dividers. Aligned with Spotify's
  // dark pill (#1f1f1f) and its pressed variant.
  static Color get chipBg => _day
      ? const Color(0xFFE4E5E8)
      : const Color(0xFF1F1F1F);
  static Color get chipBgStrong => _day
      ? const Color(0xFFD6D7DA)
      : const Color(0xFF2A2A2A);

  // ── Accent palette (retained, currently unused) ──────────────────
  // v19 removes blue/green accents from the product surface. These
  // constants stay so any lingering imports keep compiling; new code
  // should NOT use them. The monochrome rule is: white for active,
  // muted grey for inactive, red only for the favorite heart.
  static const Color accent1 = Color(0xFF8FB4FF);
  static const Color accent2 = Color(0xFF5B8BFF);
  static const Color accentBg = Color(0x2E5B8BFF);

  // ── Fancy-heart gradient ──────────────────────────────────────────
  // Kit: --heart-1 / --heart-2 / --heart-3. Used ONLY on the favorite
  // stamp rendered on "已收藏" poster cards in the 投稿 grid. Not for
  // tab-bar icons, buttons, or any other affordance.
  static const Color heart1 = Color(0xFFFFD1DC);
  static const Color heart2 = Color(0xFFFF6B95);
  static const Color heart3 = Color(0xFFE11D48);

  // ── Scrim / modal barrier ─────────────────────────────────────────
  // Night uses a strong black dim (content darkens). Day uses a very
  // light black tint + a slight white wash so the underlying content
  // *fades* rather than going charcoal — per reference, drawer
  // opening on a white app should look like a pale haze, not a
  // blackout curtain.
  static Color get scrim => _day
      ? Colors.black.withValues(alpha: 0.18)
      : Colors.black.withValues(alpha: 0.55);

  // ── Semantic state colours ────────────────────────────────────────
  // The kit bans "green success / red error" strips, but it does
  // allow discrete semantic accents: an unread dot, a favorite
  // indicator, a destructive action hint, a subtle success tint
  // (sampled from the "forest" palette) for things like an "approved"
  // submission notification. These are the canonical hex values the
  // app has been using inline; lifting them to tokens so a future
  // palette rework is one file, not a grep.
  static const Color unreadDot = Color(0xFFFF5C5C);
  static const Color favoriteActive = Color(0xFFE53935);
  static const Color danger = Color(0xFFE25C5C);
  static const Color success = Color(0xFFA8E6B0);

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

  // ── Corner-radius scale (Spotify Encore) ─────────────────────────
  // Aligned to Spotify's actual values, which are SMALLER than the
  // 14-28px we used pre-v19. Use these instead of hardcoded Radius
  // numbers sprinkled across widgets.
  //
  //   r1   2px — badges, tags
  //   r2   4px — inputs, small chips
  //   r3   6px — album thumbs, small cards
  //   r4   8px — standard cards (default)
  //   r5  12px — panels, dialogs
  //   r6  16px — sheets / bottom drawers
  //   r7  20px — large overlays
  //   pill  — fully rounded (500+ → use 9999)
  //   circle — 50% (icon buttons, avatars, play button)
  static const double r1 = 2;
  static const double r2 = 4;
  static const double r3 = 6;
  static const double r4 = 8;
  static const double r5 = 12;
  static const double r6 = 16;
  static const double r7 = 20;
  static const double rPill = 9999;

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
    final scheme = _day
        ? ColorScheme.light(
            surface: surface,
            onSurface: text,
            primary: text,
            onPrimary: const Color(0xFFF5F2EC),
            secondary: text,
            onSecondary: const Color(0xFFF5F2EC),
            surfaceContainerLowest: bg,
            surfaceContainerLow: surface,
            surfaceContainer: surfaceRaised,
            surfaceContainerHigh: surfaceRaised,
            surfaceContainerHighest: surfaceRaised,
            onSurfaceVariant: textMute,
            outline: line2,
            outlineVariant: line1,
            error: const Color(0xFFC0392B),
            onError: Colors.white,
          )
        : ColorScheme.dark(
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

  static ThemeData light() => dark(); // single resolver, mode via [_day]

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
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r4),
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
      // Inverted pill CTA — fill = ink, label = scaffold bg. Matches
      // the kit `.btn--solid { background: var(--text); color: var(--ink); }`
      // and stays readable in both day and night modes.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: text,
          foregroundColor: scaffoldBg,
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
            return IconThemeData(color: text, size: 24);
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
      iconTheme: IconThemeData(color: text, size: 22),
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
