import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

/// Circular icon-only button.
///
/// Spotify uses these everywhere — top-bar avatars, playbar controls,
/// card overlays. Three variants map to three levels of emphasis:
///
///   · ghost   — transparent fill, icon sits naked on bg. Used as
///               top-bar affordances (menu, search) where the page
///               below already has hierarchy.
///   · filled  — [AppTheme.surfaceAlt] fill. The standalone pill
///               that the eye latches onto as "tap target".
///   · glass   — translucent + backdrop blur; use ONLY when overlaid
///               on full-bleed imagery (poster hero). Don't use on
///               plain surfaces — the blur wastes GPU on no effect.
///               (See [GlassButton] for the canonical glass variant;
///               this class wraps it so callers stay in one widget
///               family.)
enum AppIconButtonVariant { ghost, filled, glass }

enum AppIconButtonSize { small, medium, large }

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.variant = AppIconButtonVariant.ghost,
    this.size = AppIconButtonSize.medium,
    this.color,
    this.semanticsLabel,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final AppIconButtonVariant variant;
  final AppIconButtonSize size;

  /// Icon tint. Defaults to [AppTheme.text] (white) for ghost/filled,
  /// which usually reads correctly on any surface. Pass
  /// [AppTheme.favoriteActive] for a filled heart, etc.
  final Color? color;

  final String? semanticsLabel;

  /// Small red dot in the top-right corner — used for unread counts /
  /// notifications. Visual parity with the heart tab's unread badge.
  final bool badge;

  double get _dim => switch (size) {
        AppIconButtonSize.small => 32,
        AppIconButtonSize.medium => 40,
        AppIconButtonSize.large => 48,
      };

  double get _iconSize => switch (size) {
        AppIconButtonSize.small => 16,
        AppIconButtonSize.medium => 20,
        AppIconButtonSize.large => 24,
      };

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppTheme.text;
    final bg = switch (variant) {
      AppIconButtonVariant.ghost => Colors.transparent,
      AppIconButtonVariant.filled => AppTheme.surfaceAlt,
      AppIconButtonVariant.glass => Colors.black.withValues(alpha: 0.38),
    };

    Widget core = Container(
      width: _dim,
      height: _dim,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: variant == AppIconButtonVariant.glass
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.12), width: 0.5)
            : null,
      ),
      child: Icon(icon, size: _iconSize, color: fg),
    );

    if (badge) {
      core = Stack(
        clipBehavior: Clip.none,
        children: [
          core,
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.unreadDot,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      );
    }

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: core,
        ),
      ),
    );
  }
}
