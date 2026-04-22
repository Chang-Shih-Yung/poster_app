import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../app_loader.dart';

/// Button hierarchy — three variants, one widget.
///
/// Matches Spotify Encore's button system:
///   · primary  — filled white pill on dark ink. Main CTA. One per
///                view, ideally. Black text.
///   · secondary — filled dark pill (#1F1F1F) on dark ink. White
///                text. Paired with primary for "cancel / OK" style.
///   · outline  — transparent with 1px border. Use when you want a
///                tap target without competing with primary.
///   · text     — no background, no border. For destructive links
///                ("登出"), inline "查看更多" actions, etc.
///
/// Size:
///   · medium (default) — 44pt tall, 20px horizontal padding
///   · small            — 32pt tall, 14px horizontal padding
///   · large            — 52pt tall, 24px horizontal padding
///
/// Busy state shows [AppLoader] in place of the label. Disabled
/// state auto-fades the fill + label.
enum AppButtonVariant { primary, secondary, outline, text }

enum AppButtonSize { small, medium, large }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.busy = false,
    this.fullWidth = false,
    this.destructive = false,
  });

  /// Shorthand for the 3 most common variants — reads cleaner at
  /// call sites: `AppButton.primary(label: '使用 Google 登入', onPressed: ...)`.
  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.busy = false,
    this.fullWidth = false,
    this.destructive = false,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.busy = false,
    this.fullWidth = false,
    this.destructive = false,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.busy = false,
    this.fullWidth = false,
    this.destructive = false,
  }) : variant = AppButtonVariant.outline;

  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.busy = false,
    this.fullWidth = false,
    this.destructive = false,
  }) : variant = AppButtonVariant.text;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;

  /// Optional leading icon. Same size as label baseline, 6px gap.
  final IconData? icon;

  /// When true, swap the label for a centered [AppLoader] and
  /// disable taps. Leave [onPressed] wired so the disabled styling
  /// applies correctly.
  final bool busy;

  /// If true, the pill stretches to fill its parent (`SizedBox.expand`
  /// style). Default false = hug content.
  final bool fullWidth;

  /// For text-variant rows: flips the label red (`favoriteActive`).
  /// Used by 登出. Ignored on filled variants — they'd read as an
  /// error state rather than an intentional destructive action.
  final bool destructive;

  double get _height => switch (size) {
        AppButtonSize.small => 32,
        AppButtonSize.medium => 44,
        AppButtonSize.large => 52,
      };

  double get _hPad => switch (size) {
        AppButtonSize.small => 14,
        AppButtonSize.medium => 20,
        AppButtonSize.large => 24,
      };

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final onTap = enabled
        ? () {
            HapticFeedback.selectionClick();
            onPressed?.call();
          }
        : null;

    final (bg, fg, border) = _colors(enabled);
    final labelStyle = TextStyle(
      fontFamily: 'NotoSansTC',
      fontSize: size == AppButtonSize.small ? 13 : 14,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.14,
      color: fg,
    );

    Widget content = busy
        ? AppLoader(
            size: AppLoaderSize.inline,
            color: fg,
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: size == AppButtonSize.small ? 14 : 16,
                    color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  style: labelStyle,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          );

    final inner = Container(
      height: variant == AppButtonVariant.text ? null : _height,
      padding: variant == AppButtonVariant.text
          ? EdgeInsets.symmetric(vertical: size == AppButtonSize.small ? 4 : 8)
          : EdgeInsets.symmetric(horizontal: _hPad),
      alignment: Alignment.center,
      decoration: variant == AppButtonVariant.text
          ? null
          : BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppTheme.rPill),
              border: border,
            ),
      child: content,
    );

    final material = Material(
      color: Colors.transparent,
      borderRadius: variant == AppButtonVariant.text
          ? null
          : BorderRadius.circular(AppTheme.rPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: variant == AppButtonVariant.text
            ? null
            : BorderRadius.circular(AppTheme.rPill),
        child: inner,
      ),
    );

    return fullWidth
        ? SizedBox(width: double.infinity, child: material)
        : material;
  }

  (Color bg, Color fg, Border? border) _colors(bool enabled) {
    final fadeFg = enabled ? 1.0 : 0.4;
    switch (variant) {
      case AppButtonVariant.primary:
        // Spotify's white pill — inverted against dark bg.
        return (
          enabled
              ? const Color(0xFFEEEEEE)
              : const Color(0xFFEEEEEE).withValues(alpha: 0.35),
          AppTheme.bg, // black-on-white
          null,
        );
      case AppButtonVariant.secondary:
        return (
          enabled
              ? AppTheme.surfaceAlt
              : AppTheme.surfaceAlt.withValues(alpha: 0.5),
          AppTheme.text.withValues(alpha: fadeFg),
          null,
        );
      case AppButtonVariant.outline:
        return (
          Colors.transparent,
          AppTheme.text.withValues(alpha: fadeFg),
          Border.all(
              color: enabled
                  ? AppTheme.line3
                  : AppTheme.line3.withValues(alpha: 0.5),
              width: 1),
        );
      case AppButtonVariant.text:
        final color = destructive ? AppTheme.favoriteActive : AppTheme.text;
        return (
          Colors.transparent,
          color.withValues(alpha: fadeFg),
          null,
        );
    }
  }
}
