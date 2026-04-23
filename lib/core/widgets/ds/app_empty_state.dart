import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'app_button.dart';
import 'app_text.dart';

/// Empty / error / zero-state content block. Replaces the 4+ copies
/// of `_Err` / `_ErrorView` / inline "沒有 X" messages scattered
/// across features.
///
/// Structure: optional icon → title → optional subtitle → optional
/// action button. All centered. Works as the body of a Scaffold, a
/// SliverFillRemaining, or a Center inside anything.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.all(32),
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 36, color: AppTheme.textFaint),
              const SizedBox(height: 14),
            ],
            AppText.title(title, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              AppText.caption(subtitle!, textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              AppButton.outline(
                label: actionLabel!,
                size: AppButtonSize.small,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
