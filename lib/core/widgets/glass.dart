import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// v13 liquid-glass surface.
///
/// Wraps [child] in a backdrop-blur + tinted overlay + 1px line border
/// + 1px inset top highlight + soft drop shadow. Used for the floating
/// bottom nav island, the sticky top chrome, the Fuji detail drawer,
/// and any floating glass button.
///
/// Notes:
///   - On Flutter Web (CanvasKit / Skwasm) BackdropFilter works but is
///     more expensive than native; keep glass surfaces thin (don't wrap
///     entire scrolling lists, just the chrome on top).
///   - [tint] is the alpha applied to the ink fill that sits on top of
///     the blur. Higher tint = more opaque, less of the background
///     bleeding through. v13 spec: 0.55 default.
///   - [blur] is sigma in logical pixels. v13 spec: 20.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.blur = 10,
    this.tint = 0.55,
    this.borderRadius = const BorderRadius.all(Radius.circular(0)),
    this.border,
    this.padding,
    this.shadow = true,
    this.highlight = true,
  });

  final Widget child;
  final double blur;
  final double tint;
  final BorderRadius borderRadius;
  final BoxBorder? border;
  final EdgeInsetsGeometry? padding;
  final bool shadow;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final fill = Color.fromRGBO(20, 24, 32, tint);
    final effectiveBorder = border ?? Border.all(color: AppTheme.line2, width: 1);

    Widget content = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: borderRadius,
            border: effectiveBorder,
          ),
          padding: padding,
          child: highlight
              ? _withInsetHighlight(child, borderRadius)
              : child,
        ),
      ),
    );

    if (shadow) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000), // rgba(0,0,0,0.4)
              blurRadius: 32,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: content,
      );
    }
    return content;
  }

  /// Paints a 1px white-with-alpha line at the very top edge inside the
  /// glass — sells the "specular highlight" you see on iOS liquid glass.
  Widget _withInsetHighlight(Widget inner, BorderRadius r) {
    return Stack(
      children: [
        inner,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.only(
                topLeft: r.topLeft,
                topRight: r.topRight,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Circular glass icon button — used for the floating chevron-down,
/// heart, share, search, plus actions overlaid on full-bleed imagery.
///
/// Spec: size 36-40, blur 18-20, tint 0.5-0.6, icon size = 0.5 * size.
///
/// For filled-state icons (e.g. heart when favorited), pass the already-
/// filled icon variant as [icon] (e.g. Icons.favorite vs LucideIcons.heart).
/// Lucide is stroke-only; Icon's `fill` property requires a variable font.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.color = Colors.white,
    this.semanticsLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color color;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Glass(
          blur: 18,
          tint: 0.5,
          borderRadius: BorderRadius.circular(999),
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Icon(
                icon,
                size: size * 0.5,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
