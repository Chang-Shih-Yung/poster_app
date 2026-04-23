import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Typography primitive — six canonical roles. Replaces every
/// `Theme.of(context).textTheme.X.copyWith(fontWeight: ..., color:
/// ..., fontSize: ...)` sprinkled across 50+ feature call sites.
///
/// Roles map directly to Spotify's typography scale (see AppTheme
/// docs):
///   · title       22-24 / 700 — section headers
///   · headline    32 / 600    — editorial display (poster title)
///   · body        16 / 400    — standard body
///   · bodyBold    16 / 700
///   · caption     14 / 400 muted
///   · label       11 / 600 letter-spaced — eyebrow / pill labels
///   · small       12 / 400 muted — metadata
///
/// All variants accept the standard Text props (maxLines, overflow,
/// textAlign). Color defaults to AppTheme.text; pass `muted` /
/// `faint` shorthands to switch to textMute / textFaint, or color
/// directly for explicit control.
enum AppTextRole { title, headline, body, bodyBold, caption, label, small }

enum AppTextTone { primary, muted, faint, inverse }

class AppText extends StatelessWidget {
  const AppText(
    this.text, {
    super.key,
    this.role = AppTextRole.body,
    this.tone = AppTextTone.primary,
    this.color,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.weight,
    this.size,
  });

  /// Shorthands so call sites read like prose, not enum spelling:
  /// `AppText.title('歡迎')`.
  const AppText.title(this.text,
      {super.key,
      this.tone = AppTextTone.primary,
      this.color,
      this.maxLines,
      this.overflow,
      this.textAlign,
      this.weight,
      this.size})
      : role = AppTextRole.title;

  const AppText.headline(this.text,
      {super.key,
      this.tone = AppTextTone.primary,
      this.color,
      this.maxLines,
      this.overflow,
      this.textAlign,
      this.weight,
      this.size})
      : role = AppTextRole.headline;

  const AppText.body(this.text,
      {super.key,
      this.tone = AppTextTone.primary,
      this.color,
      this.maxLines,
      this.overflow,
      this.textAlign,
      this.weight,
      this.size})
      : role = AppTextRole.body;

  const AppText.bodyBold(this.text,
      {super.key,
      this.tone = AppTextTone.primary,
      this.color,
      this.maxLines,
      this.overflow,
      this.textAlign,
      this.weight,
      this.size})
      : role = AppTextRole.bodyBold;

  const AppText.caption(this.text,
      {super.key,
      this.tone = AppTextTone.muted,
      this.color,
      this.maxLines,
      this.overflow,
      this.textAlign,
      this.weight,
      this.size})
      : role = AppTextRole.caption;

  const AppText.label(this.text,
      {super.key,
      this.tone = AppTextTone.muted,
      this.color,
      this.maxLines,
      this.overflow,
      this.textAlign,
      this.weight,
      this.size})
      : role = AppTextRole.label;

  const AppText.small(this.text,
      {super.key,
      this.tone = AppTextTone.muted,
      this.color,
      this.maxLines,
      this.overflow,
      this.textAlign,
      this.weight,
      this.size})
      : role = AppTextRole.small;

  final String text;
  final AppTextRole role;
  final AppTextTone tone;

  /// Hard-overrides tone; useful for inline destructive copy etc.
  final Color? color;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  /// Override the default weight for this role (rare — usually role
  /// already encodes the right weight).
  final FontWeight? weight;

  /// Override the default size (rare — keep to roles when possible).
  final double? size;

  @override
  Widget build(BuildContext context) {
    final spec = _specFor(role);
    final resolvedColor = color ?? _toneColor(tone);
    return Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      style: TextStyle(
        fontFamily: 'InterDisplay',
        fontFamilyFallback: const ['NotoSansTC'],
        fontSize: size ?? spec.size,
        fontWeight: weight ?? spec.weight,
        letterSpacing: spec.letterSpacing,
        color: resolvedColor,
        height: spec.height,
      ),
    );
  }

  Color _toneColor(AppTextTone t) {
    switch (t) {
      case AppTextTone.primary:
        return AppTheme.text;
      case AppTextTone.muted:
        return AppTheme.textMute;
      case AppTextTone.faint:
        return AppTheme.textFaint;
      case AppTextTone.inverse:
        return AppTheme.bg;
    }
  }
}

class _Spec {
  const _Spec({
    required this.size,
    required this.weight,
    required this.letterSpacing,
    this.height,
  });
  final double size;
  final FontWeight weight;
  final double letterSpacing;
  final double? height;
}

_Spec _specFor(AppTextRole r) {
  switch (r) {
    case AppTextRole.title:
      return const _Spec(size: 22, weight: FontWeight.w600, letterSpacing: -0.4);
    case AppTextRole.headline:
      return const _Spec(
          size: 32,
          weight: FontWeight.w600,
          letterSpacing: -0.8,
          height: 1.05);
    case AppTextRole.body:
      return const _Spec(size: 15, weight: FontWeight.w400, letterSpacing: 0);
    case AppTextRole.bodyBold:
      return const _Spec(size: 15, weight: FontWeight.w700, letterSpacing: 0);
    case AppTextRole.caption:
      return const _Spec(size: 13, weight: FontWeight.w400, letterSpacing: 0);
    case AppTextRole.label:
      return const _Spec(size: 11, weight: FontWeight.w600, letterSpacing: 1.6);
    case AppTextRole.small:
      return const _Spec(size: 11, weight: FontWeight.w400, letterSpacing: 0);
  }
}
