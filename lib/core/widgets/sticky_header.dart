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
    this.actionLabel,
    this.actionLoading = false,
    this.onAction,
    this.onBack,
    this.backIcon,
    this.backText,
    this.backIconBackground = true,
    this.actionEnabled = true,
  });

  final String title;

  /// When null, no action pill is rendered (used by pages like
  /// 通知 that no longer expose a trailing action).
  final String? actionLabel;
  final bool actionLoading;
  final VoidCallback? onAction;

  /// Defaults to `Navigator.of(context).maybePop()`.
  final VoidCallback? onBack;

  /// Defaults to [LucideIcons.chevronLeft]. Ignored when [backText]
  /// is set.
  final IconData? backIcon;

  /// When set, replaces the back icon slot with a plain text button
  /// (e.g. "取消" on the upload modal sheet). Takes precedence over
  /// [backIcon].
  final String? backText;

  /// When false, the back affordance is a bare icon (no chip bg) —
  /// v18 prototype spec for the upload page.
  final bool backIconBackground;

  /// When false, the action pill renders in the disabled state (grey
  /// background, faint label) and does not invoke [onAction]. Matches
  /// the prototype's "送審" pill that lights up only when required
  /// fields are filled.
  final bool actionEnabled;

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
              behavior: HitTestBehavior.opaque,
              child: backText != null
                  ? Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        backText!,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: AppTheme.text,
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                      ),
                    )
                  : Container(
                      width: 36,
                      height: 36,
                      decoration: backIconBackground
                          ? BoxDecoration(
                              color: AppTheme.chipBg,
                              shape: BoxShape.circle,
                            )
                          : const BoxDecoration(),
                      child: Icon(backIcon ?? LucideIcons.chevronLeft,
                          size: backIconBackground ? 20 : 24,
                          color: AppTheme.text),
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
            if (actionLabel == null)
              const SizedBox(width: 36)
            else
              Material(
              // Active pill = ink (white in night, near-black in day);
              // disabled falls back to a subtle chip bg. Label inverts
              // to `AppTheme.bg` so the pill reads correctly both ways.
              color: actionEnabled ? AppTheme.text : AppTheme.chipBg,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: actionEnabled ? onAction : null,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  child: actionLoading
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.bg),
                        )
                      : Text(
                          actionLabel!,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: actionEnabled
                                    ? AppTheme.bg
                                    : AppTheme.textFaint,
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
