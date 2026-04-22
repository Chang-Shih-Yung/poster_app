import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_theme.dart';

/// Section header — used above every horizontal poster scroll row,
/// settings block, and admin queue. Spotify pattern: big bold title,
/// optional "查看全部 →" trailing link.
///
/// Replaces scattered `_SectionLabel`, `_Eyebrow`, `_HomeSectionEyebrow`,
/// `_RelatedSectionLabel` implementations — same visual, one widget.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailingLabel,
    this.onTrailingTap,
    this.horizontalPadding = AppTheme.s5,
  });

  /// Main heading — Spotify's 22-24 px / 700 section title.
  final String title;

  /// Small uppercase/letter-spaced text above the title, e.g.
  /// "精選合輯" / "RECENTLY PLAYED". Optional.
  final String? eyebrow;

  /// One-line grey subtitle beneath the title. Optional.
  final String? subtitle;

  /// Right-side link label ("查看全部"). Shown with a chevron when
  /// [onTrailingTap] is provided.
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  /// Horizontal padding applied to the whole row. Defaults to
  /// [AppTheme.s5] (20) to line up with the editorial body column.
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      fontFamily: 'InterDisplay',
              fontFamilyFallback: const ['NotoSansTC'],
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: AppTheme.text,
    );
    final eyebrowStyle = TextStyle(
      fontFamily: 'InterDisplay',
              fontFamilyFallback: const ['NotoSansTC'],
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.6,
      color: AppTheme.textMute,
    );
    final subStyle = TextStyle(
      fontFamily: 'InterDisplay',
              fontFamilyFallback: const ['NotoSansTC'],
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppTheme.textMute,
    );
    final trailingStyle = TextStyle(
      fontFamily: 'InterDisplay',
              fontFamilyFallback: const ['NotoSansTC'],
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppTheme.textMute,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null && eyebrow!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(eyebrow!.toUpperCase(), style: eyebrowStyle),
                  ),
                Text(
                  title,
                  style: titleStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: subStyle),
                  ),
              ],
            ),
          ),
          if (trailingLabel != null && onTrailingTap != null)
            InkWell(
              onTap: onTrailingTap,
              borderRadius: BorderRadius.circular(AppTheme.rPill),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(trailingLabel!, style: trailingStyle),
                    const SizedBox(width: 2),
                    Icon(LucideIcons.chevronRight,
                        size: 14, color: AppTheme.textMute),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
