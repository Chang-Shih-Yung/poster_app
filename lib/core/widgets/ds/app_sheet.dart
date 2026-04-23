import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Bottom sheet wrapper — consistent radius, grab handle, surface
/// colour, safe-area inset. Wrap your content and pass it to
/// [AppSheet.show].
///
/// Usage:
///   AppSheet.show(
///     context,
///     child: MyCustomBody(),
///   );
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 20),
    this.handle = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool handle;

  /// Opens the sheet — single entry point so every caller shares the
  /// same shape / background / clipping. Returns whatever the sheet's
  /// child passes to Navigator.pop.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry padding =
        const EdgeInsets.fromLTRB(20, 14, 20, 20),
    bool handle = true,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: isScrollControlled,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.r6)),
      ),
      builder: (_) =>
          AppSheet(padding: padding, handle: handle, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (handle)
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.line2,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}
