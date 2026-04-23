import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Thin wrapper over ScaffoldMessenger.showSnackBar so every feature
/// file stops inventing its own `_toast()` helper. Themed, typed
/// destructive / info variants, auto-hides after 2.4s.
///
/// Usage:
///   AppToast.show(context, '已儲存');
///   AppToast.show(context, '失敗', kind: AppToastKind.destructive);
enum AppToastKind { info, success, destructive }

class AppToast {
  const AppToast._();

  static void show(
    BuildContext context,
    String message, {
    AppToastKind kind = AppToastKind.info,
    Duration duration = const Duration(milliseconds: 2400),
  }) {
    final (bg, fg) = _paletteFor(kind);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.r4),
        ),
        duration: duration,
        content: Text(
          message,
          style: TextStyle(
            fontFamily: 'InterDisplay',
            fontFamilyFallback: const ['NotoSansTC'],
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: fg,
          ),
        ),
      ),
    );
  }

  static (Color bg, Color fg) _paletteFor(AppToastKind k) {
    switch (k) {
      case AppToastKind.info:
        return (AppTheme.surfaceRaised, AppTheme.text);
      case AppToastKind.success:
        return (AppTheme.success, AppTheme.bg);
      case AppToastKind.destructive:
        return (AppTheme.favoriteActive, Colors.white);
    }
  }
}
