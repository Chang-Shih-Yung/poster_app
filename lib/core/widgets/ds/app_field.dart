import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import 'app_text.dart';

/// Form text-field primitive — label + hint + input + error, all
/// styled consistently. Replaces the half-dozen `_DarkField` /
/// custom `InputDecoration` implementations sprinkled across
/// submission + profile-edit flows.
///
/// Shape: rounded rect `r4` with muted surface fill, 1px hairline
/// border, ghost focus state (`line3` when active). Follows the
/// editorial + Spotify pattern — NOT Material's underline / outline.
///
/// For multi-line / password / email, pass `maxLines`, `obscureText`,
/// `keyboardType`. For shape-constrained fields (e.g. @handle) pass
/// `inputFormatters`.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.error,
    this.prefixText,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helper;
  final String? error;
  final String? prefixText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final int? maxLength;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final borderSide = BorderSide(
      color: error != null ? AppTheme.favoriteActive : AppTheme.line1,
    );
    final focusedSide = BorderSide(
      color: error != null ? AppTheme.favoriteActive : AppTheme.line3,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          AppText.label(label!, tone: AppTextTone.muted),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          enabled: enabled,
          autofocus: autofocus,
          maxLines: maxLines,
          maxLength: maxLength,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: TextStyle(
            fontFamily: 'InterDisplay',
            fontFamilyFallback: const ['NotoSansTC'],
            fontSize: 15,
            color: AppTheme.text,
          ),
          cursorColor: AppTheme.text,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: 'InterDisplay',
              fontFamilyFallback: const ['NotoSansTC'],
              fontSize: 15,
              color: AppTheme.textFaint,
            ),
            prefixText: prefixText,
            prefixStyle: TextStyle(
              fontFamily: 'InterDisplay',
              fontFamilyFallback: const ['NotoSansTC'],
              fontSize: 15,
              color: AppTheme.textMute,
            ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppTheme.fieldFillTranslucent,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.r4),
              borderSide: borderSide,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.r4),
              borderSide: borderSide,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.r4),
              borderSide: focusedSide,
            ),
            errorText: null, // rendered below explicitly
            counterText: '',
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          AppText.small(error!, color: AppTheme.favoriteActive),
        ] else if (helper != null) ...[
          const SizedBox(height: 4),
          AppText.small(helper!, tone: AppTextTone.faint),
        ],
      ],
    );
  }
}
