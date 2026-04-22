import 'package:flutter/material.dart';

/// IG-style two-bar menu glyph (not the 3-bar Material hamburger).
/// Pure paint — no font dep, no asset. Use as an Icon replacement.
class TwoBarIcon extends StatelessWidget {
  const TwoBarIcon({super.key, this.size = 22, this.color, this.strokeWidth});

  final double size;
  final Color? color;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Colors.white;
    // Default stroke width scales with size so the glyph doesn't get
    // chunky at 16 or wispy at 32. Matches Lucide's 2px @ 24 visual.
    final sw = strokeWidth ?? (size / 12).clamp(1.6, 2.4);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TwoBarPainter(color: c, strokeWidth: sw),
      ),
    );
  }
}

class _TwoBarPainter extends CustomPainter {
  const _TwoBarPainter({required this.color, required this.strokeWidth});
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    // Two horizontal bars, symmetrical around the vertical centre.
    // Slight inset from the box so the glyph doesn't kiss the bounds.
    final inset = size.width * 0.10;
    final left = inset;
    final right = size.width - inset;
    final cy = size.height / 2;
    final gap = size.height * 0.17;
    canvas.drawLine(Offset(left, cy - gap), Offset(right, cy - gap), paint);
    canvas.drawLine(Offset(left, cy + gap), Offset(right, cy + gap), paint);
  }

  @override
  bool shouldRepaint(_TwoBarPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
