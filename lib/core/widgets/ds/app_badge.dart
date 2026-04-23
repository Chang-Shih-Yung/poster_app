import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Read-only badge — tiny status/label pill. NOT tappable. NOT
/// selectable. For tappable pills use [AppChip].
///
/// Use for:
///   · ADMIN badge on user cards
///   · "追蹤你" hint on public profile
///   · upload status (「審核中」/「已核准」/「退回」)
///   · category label beside an item
///
/// Three variants:
///   · neutral  — muted dark surface, textMute label
///   · accent   — filled with the caller's colour @ 15%, label in same
///                colour (e.g. green success, red danger, blue info)
///   · strong   — filled with the caller's colour opaque, inverted label
enum AppBadgeVariant { neutral, accent, strong }

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.neutral,
    this.color,
    this.icon,
  });

  final String label;
  final AppBadgeVariant variant;

  /// Only used for [AppBadgeVariant.accent] / [.strong]. Ignored on
  /// neutral (which always uses the surface palette).
  final Color? color;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colours();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: icon == null ? 8 : 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'InterDisplay',
              fontFamilyFallback: const ['NotoSansTC'],
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  (Color bg, Color fg) _colours() {
    switch (variant) {
      case AppBadgeVariant.neutral:
        return (AppTheme.chipBgStrong, AppTheme.textMute);
      case AppBadgeVariant.accent:
        final c = color ?? AppTheme.text;
        return (c.withValues(alpha: 0.15), c);
      case AppBadgeVariant.strong:
        final c = color ?? AppTheme.text;
        return (c, AppTheme.bg);
    }
  }
}
