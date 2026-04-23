import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Thin separator line — horizontal or vertical. Replaces the
/// half-dozen `Container(height: 0.5, color: line1)` and `_StatDivider`
/// feature-local classes.
class AppDivider extends StatelessWidget {
  const AppDivider({
    super.key,
    this.axis = Axis.horizontal,
    this.thickness = 0.5,
    this.length,
    this.color,
    this.margin,
  });

  /// Horizontal = full-width hairline. Vertical = column-gap line.
  final Axis axis;
  final double thickness;

  /// For vertical dividers, sets the fixed height. For horizontal
  /// dividers, null = stretch full width.
  final double? length;
  final Color? color;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.line1;
    if (axis == Axis.horizontal) {
      final line = Container(height: thickness, color: c);
      return margin == null ? line : Padding(padding: margin!, child: line);
    }
    final line = Container(width: thickness, height: length ?? 14, color: c);
    return margin == null ? line : Padding(padding: margin!, child: line);
  }
}
