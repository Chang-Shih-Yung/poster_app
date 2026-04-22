import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The card shell everything else composes on top of.
///
/// Spotify Encore pattern: cards are content containers — a dark
/// surface that is ONE shade lighter than the page bg (so elevation
/// comes from contrast, not from a border or shadow), an 8px corner
/// radius, padding around content, optional tap behaviour, and a
/// slot for corner overlays (fav stamp, selection badge, etc).
///
/// Rules:
/// - Never reach for a raw `Container(...decoration...)` to build a
///   card elsewhere in the app. Use this widget and pass slots.
/// - Padding defaults to 16 (s4). Override only when a layout
///   (masonry image tile, list row) genuinely needs something else.
/// - If you need a different background (glass, elevated, custom),
///   pass `background` — don't fork the class.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(AppTheme.s4),
    this.margin,
    this.borderRadius,
    this.background,
    this.border,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAlias,
    this.overlays,
    this.selected = false,
    this.elevated = false,
  });

  /// Body content. Anything — Column, Row, Text, masonry image, etc.
  final Widget child;

  /// Optional tap handler. Gives the card an InkWell ripple and
  /// exposes the whole surface as a semantics-button.
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Interior padding. Defaults to 16px all sides. Pass
  /// `EdgeInsets.zero` for image-first tiles (poster masonry) where
  /// the child fills edge to edge.
  final EdgeInsetsGeometry padding;

  /// Outer margin. Usually null — let the parent layout control
  /// spacing. Handy when a one-off card sits inline.
  final EdgeInsetsGeometry? margin;

  /// Corner radius. Defaults to [AppTheme.r4] (8px) — the Spotify
  /// card standard. For bigger surfaces (sheets, dialogs) reach for
  /// r5/r6/r7; for smaller stamps, r3.
  final BorderRadiusGeometry? borderRadius;

  /// Background fill. Defaults to [AppTheme.surface] (one shade
  /// lighter than bg). Pass [AppTheme.surfaceAlt] for a deeper sunk
  /// surface, or a custom color for badges / highlights.
  final Color? background;

  /// Optional hairline border. Pass `Border.all(color: AppTheme.line1)`
  /// for a subtle definition. Default (null) = no border — Spotify's
  /// preferred look; elevation comes from fill contrast alone.
  final Border? border;

  final double? width;
  final double? height;

  /// How to clip the child. Default clips to borderRadius so images
  /// with `fit: BoxFit.cover` don't leak past the corners.
  final Clip clipBehavior;

  /// Widgets painted on top of [child] — favorite stamp top-right,
  /// selection check bottom-left, etc. Each is a [Positioned]
  /// (caller decides placement).
  final List<Widget>? overlays;

  /// When true, adds a subtle white-glow border to mark "this card
  /// is the current selection" (e.g. the active tab row).
  final bool selected;

  /// When true, adds a medium drop-shadow for "floating" states
  /// (dragged cards, tooltips). Spotify uses shadow sparingly —
  /// only when a surface genuinely lifts off the page.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppTheme.r4);
    final fill = background ?? AppTheme.surface;

    Widget surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: selected
            ? Border.all(color: Colors.white, width: 1.2)
            : border,
        boxShadow: elevated
            ? const [
                BoxShadow(
                  color: Color(0x4D000000), // 30% black
                  blurRadius: 8,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (overlays != null && overlays!.isNotEmpty) {
      surface = Stack(
        clipBehavior: Clip.none,
        children: [surface, ...overlays!],
      );
    }

    if (onTap != null || onLongPress != null) {
      surface = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: radius is BorderRadius ? radius : null,
          child: surface,
        ),
      );
    }

    surface = ClipRRect(
      borderRadius: radius,
      clipBehavior: clipBehavior,
      child: surface,
    );

    if (width != null || height != null) {
      surface = SizedBox(width: width, height: height, child: surface);
    }

    if (margin != null) {
      surface = Padding(padding: margin!, child: surface);
    }

    return surface;
  }
}
