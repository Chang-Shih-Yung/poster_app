import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

/// v13 sticky black header for sub-pages (Upload, Edit Profile).
///
/// Layout (mirrors v13 prototype):
///   ◀ back  [—————— title ——————]  ▢ action pill
///
/// Sits at the very top of the page with `AppTheme.bg` so the form below
/// can scroll under it, with a fixed top padding equal to safe-area top
/// + header height.
///
/// Use inside a `Stack`:
/// ```dart
/// Scaffold(
///   body: Stack(children: [
///     Padding(padding: EdgeInsets.only(top: kStickyHeaderHeight + topInset),
///             child: ScrollableForm()),
///     const StickyHeader(title: '上傳海報', actionLabel: '送出'),
///   ]),
/// )
/// ```
class StickyHeader extends StatelessWidget {
  const StickyHeader({
    super.key,
    required this.title,
    required this.actionLabel,
    this.actionLoading = false,
    this.onAction,
    this.onBack,
  });

  final String title;
  final String actionLabel;
  final bool actionLoading;
  final VoidCallback? onAction;

  /// Defaults to `Navigator.of(context).maybePop()`.
  final VoidCallback? onBack;

  /// Total height including safe-area top inset.
  static double heightWithInset(BuildContext context) =>
      MediaQuery.paddingOf(context).top + 60;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: AppTheme.bg,
        padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                if (onBack != null) {
                  onBack!();
                } else {
                  Navigator.of(context).maybePop();
                }
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0x14FFFFFF), // chipBg flattened
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.arrowLeft,
                    size: 18, color: AppTheme.text),
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  child: actionLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : Text(
                          actionLabel,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                              ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
