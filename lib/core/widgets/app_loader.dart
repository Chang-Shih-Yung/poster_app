import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The one loader style the app uses.
///
/// Before v19, spinners ranged 12 → 14 → 18 → 22 → bare (default 36)
/// across 18 files, with mixed stroke widths and colors
/// (textMute / textFaint / white / no-color). Every page felt a bit
/// different. This widget is the single source of truth — import it,
/// use the defaults, move on.
///
/// Sizing:
///   - [AppLoaderSize.inline]  14px — embedded in small pills / rows
///   - [AppLoaderSize.standard] 18px — default for "content pending"
///   - [AppLoaderSize.page]     22px — full-page / detail-view load
///
/// Color defaults to [AppTheme.textMute] (cool neutral). Pass an
/// override only when sitting on an inverted surface (white CTA, dark
/// sheet handle).
enum AppLoaderSize { inline, standard, page }

class AppLoader extends StatelessWidget {
  const AppLoader({
    super.key,
    this.size = AppLoaderSize.standard,
    this.color,
    this.centered = false,
  });

  /// Shorthand for full-page / empty-state centered loaders.
  /// Equivalent to `AppLoader(size: AppLoaderSize.page, centered: true)`.
  const AppLoader.centered({super.key, this.color})
      : size = AppLoaderSize.page,
        centered = true;

  final AppLoaderSize size;
  final Color? color;
  final bool centered;

  double get _dim => switch (size) {
        AppLoaderSize.inline => 14,
        AppLoaderSize.standard => 18,
        AppLoaderSize.page => 22,
      };

  @override
  Widget build(BuildContext context) {
    final inner = SizedBox(
      width: _dim,
      height: _dim,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color ?? AppTheme.textMute,
      ),
    );
    return centered ? Center(child: inner) : inner;
  }
}
