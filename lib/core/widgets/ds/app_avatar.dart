import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Circular avatar — the single `ClipOval + CachedNetworkImage +
/// fallback-letter` pattern the app used in 10+ inline places.
///
/// Fallback cascade when [url] is null / errors out:
///   1. First character of [name] (upper-cased)
///   2. `?`
///
/// Three canonical sizes plus a custom option. Optional tap
/// (routes the viewer to `/user/<id>` when caller wires it).
///
/// Use this instead of hand-rolling ClipOval + CachedNetworkImage;
/// consistent decode hints (cacheWidth) and fallback behaviour land
/// everywhere at once.
enum AppAvatarSize { xs, sm, md, lg, xl }

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.url,
    this.name = '',
    this.size = AppAvatarSize.md,
    this.customSize,
    this.onTap,
    this.ring,
  });

  final String? url;

  /// Used for the fallback letter only. Empty string → '?'.
  final String name;

  final AppAvatarSize size;

  /// Override [size]'s dimension when you need a specific px value
  /// (e.g. 72 in the profile header).
  final double? customSize;

  final VoidCallback? onTap;

  /// Optional coloured ring around the avatar — used for "story ring"
  /// style treatments on home rows.
  final Color? ring;

  double get _dim =>
      customSize ??
      switch (size) {
        AppAvatarSize.xs => 24,
        AppAvatarSize.sm => 32,
        AppAvatarSize.md => 40,
        AppAvatarSize.lg => 56,
        AppAvatarSize.xl => 80,
      };

  @override
  Widget build(BuildContext context) {
    final dim = _dim;
    final letter = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    final decodeWidth = (dim * MediaQuery.devicePixelRatioOf(context)).toInt();

    Widget inner;
    if (url == null || url!.isEmpty) {
      inner = _Fallback(letter: letter, size: dim);
    } else {
      inner = CachedNetworkImage(
        imageUrl: url!,
        fit: BoxFit.cover,
        memCacheWidth: decodeWidth,
        maxWidthDiskCache: decodeWidth * 2,
        fadeInDuration: const Duration(milliseconds: 150),
        errorWidget: (_, _, _) => _Fallback(letter: letter, size: dim),
      );
    }

    Widget body = ClipOval(child: SizedBox(width: dim, height: dim, child: inner));

    if (ring != null) {
      body = Container(
        width: dim + 4,
        height: dim + 4,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: ring,
          shape: BoxShape.circle,
        ),
        child: body,
      );
    }

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.hardEdge,
        child: InkWell(onTap: onTap, child: body),
      );
    }
    return body;
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.letter, required this.size});
  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: AppTheme.surfaceRaised,
      child: Text(
        letter,
        style: TextStyle(
          fontFamily: 'InterDisplay',
          fontFamilyFallback: const ['NotoSansTC'],
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: AppTheme.text,
        ),
      ),
    );
  }
}
