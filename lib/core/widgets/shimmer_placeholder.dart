import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A subtle animated shimmer used as an image placeholder while network
/// thumbnails load. Replaces the hard-edge solid-color block that makes
/// the grid feel janky on slow connections.
///
/// Animation is CPU-cheap: one AnimationController drives an Alignment
/// tween, one LinearGradient per build. Safe to use in grids of 50+.
class ShimmerPlaceholder extends StatefulWidget {
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
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final t = _controller.value;
        // Sweep gradient from left to right.
        return ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.zero,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1.0 + 2.0 * t, 0),
                end: Alignment(1.0 + 2.0 * t, 0),
                colors: [
                  AppTheme.surfaceRaised,
                  AppTheme.chipBg,
                  AppTheme.surfaceRaised,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }
}
