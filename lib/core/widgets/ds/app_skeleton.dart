import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Generic rectangular skeleton — a muted-surface box used during
/// provider loading. Separate from `ShimmerPlaceholder` (which is
/// image-specific, auto-fits a parent in masonry tiles). Use this
/// for text placeholders, chip placeholders, row placeholders —
/// anywhere a plain muted rect reads as "pending content".
///
/// No animation (shimmer was removed v19 for the "pending" rather
/// than "iridescent" vibe). Spotify / Threads do the same.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height,
    this.radius = AppTheme.r3,
    this.margin,
    this.color,
  });

  /// Convenience: a pill-shaped skeleton (full rounded). Common for
  /// text line placeholders.
  const AppSkeleton.pill({
    super.key,
    this.width,
    this.height = 14,
    this.margin,
    this.color,
  }) : radius = AppTheme.rPill;

  /// Convenience: square placeholder.
  const AppSkeleton.square({
    super.key,
    required double size,
    this.radius = AppTheme.r3,
    this.margin,
    this.color,
  })  : width = size,
        height = size;

  final double? width;
  final double? height;
  final double radius;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    if (margin != null) return Padding(padding: margin!, child: box);
    return box;
  }
}
