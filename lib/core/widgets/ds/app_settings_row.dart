import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_theme.dart';

/// Settings list row — icon + label + (value / chevron / switch).
///
/// Covers the old `_CardRow`, `_TextActionRow`, and the bare list
/// rows sprinkled through Profile / admin pages. Pattern matches
/// Spotify's settings surface: no card wrapping, hairline divider
/// between rows handled by the caller.
class AppSettingsRow extends StatelessWidget {
  const AppSettingsRow({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.trailing,
    this.trailingText,
    this.showChevron = true,
    this.destructive = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  /// Right-side slot — pass a Switch, a chip, a small avatar, etc.
  /// Mutually exclusive with [trailingText]; if you pass both,
  /// [trailing] wins.
  final Widget? trailing;

  /// Right-aligned grey text — the iOS "Version 1.2.3" / "English"
  /// value shown opposite the label.
  final String? trailingText;

  /// Append a chevron-right after the trailing content. Hidden when
  /// [onTap] is null (a row with no tap target shouldn't suggest
  /// pushing into something).
  final bool showChevron;

  /// Tints the label red. For 登出 / 刪除帳號 etc.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final fg = destructive ? AppTheme.favoriteActive : AppTheme.text;
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'NotoSansTC',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ),
            if (trailing != null)
              trailing!
            else if (trailingText != null)
              Text(
                trailingText!,
                style: TextStyle(
                  fontFamily: 'NotoSansTC',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textMute,
                ),
              ),
            if (showChevron && onTap != null && trailing == null) ...[
              const SizedBox(width: 6),
              Icon(LucideIcons.chevronRight,
                  size: 16, color: AppTheme.textFaint),
            ],
          ],
        ),
      ),
    );
  }
}
