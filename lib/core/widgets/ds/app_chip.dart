import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

/// Pill chip — selectable or decorative, single-line text + optional
/// leading icon. One widget covers every chip/tag/pill pattern that
/// used to be `_MiniChip`, `_TappableTagChip`, `_LandingTagChip`,
/// `_SegTab`, `_ContextChipRow`, etc.
///
/// Spotify's chip pattern is a full-pill rounded rectangle with
/// generous horizontal padding, bold-ish label, and a binary
/// selection state — inactive sits on [AppTheme.surfaceAlt], active
/// inverts to white on black (same as primary button, so selection
/// reads as "this is the canonical chosen option").
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.onTap,
    this.selected = false,
    this.icon,
    this.size = AppChipSize.medium,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final IconData? icon;
  final AppChipSize size;

  @override
  Widget build(BuildContext context) {
    final (hPad, vPad, font, iconSize) = switch (size) {
      AppChipSize.small => (10.0, 4.0, 12.0, 12.0),
      AppChipSize.medium => (14.0, 8.0, 13.0, 14.0),
      AppChipSize.large => (18.0, 10.0, 14.0, 16.0),
    };

    // v19: chip bg uses surfaceRaised (#252525), one shade lighter
    // than surfaceAlt — pills read clearly on the #121212 page bg
    // without being heavy. Same value as AppButton.secondary so the
    // two read as one family.
    final bg = selected ? AppTheme.text : AppTheme.surfaceRaised;
    final fg = selected ? AppTheme.bg : AppTheme.text;

    final inner = Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'NotoSansTC',
              fontSize: font,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: fg,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return inner;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.rPill),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        borderRadius: BorderRadius.circular(AppTheme.rPill),
        child: inner,
      ),
    );
  }
}

enum AppChipSize { small, medium, large }
