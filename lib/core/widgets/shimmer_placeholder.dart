import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Flat loading placeholder used while network thumbnails load.
///
/// v18: dropped the left-to-right animated shimmer — the reflective
/// sweep read as "this element is shiny on purpose" rather than
/// "content is pending", and stacked dozens of them in a masonry
/// grid felt jittery. IG / Threads use a plain muted silhouette;
/// this matches that pattern. Dead simple, zero animation cost.
class ShimmerPlaceholder extends StatelessWidget {
  const ShimmerPlaceholder({
    super.key,
    this.borderRadius,
    this.height,
    this.width,
  });

  final BorderRadius? borderRadius;
  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Container(
        width: width,
        height: height,
        color: AppTheme.surfaceRaised,
      ),
    );
  }
}
