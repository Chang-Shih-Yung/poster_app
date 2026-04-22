import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_theme.dart';
import '../shimmer_placeholder.dart';

/// Horizontal poster row — small square thumb + title/meta beside it.
/// Used in list-view density, Small density grids, unified search
/// result lists, etc.
///
/// Shape: bare row (NOT an AppCard — Spotify's list pattern uses
/// dividers instead of wrapping each row in a surface). Taps route
/// to the poster detail unless a custom [onTap] is passed.
class AppPosterRow extends StatelessWidget {
  const AppPosterRow({
    super.key,
    this.imageUrl,
    this.posterId,
    required this.title,
    this.subtitle,
    this.onTap,
    this.onLongPress,
    this.thumbSize = 56,
    this.trailing,
  });

  final String? imageUrl;
  final String? posterId;
  final String title;
  final String? subtitle;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double thumbSize;

  /// Right-side slot — e.g. a favorite icon button, a chevron,
  /// a follow pill.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tap = onTap ??
        (posterId != null
            ? () => GoRouter.of(context).push('/poster/$posterId')
            : null);
    return InkWell(
      onTap: tap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppTheme.r3),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.r3),
              child: SizedBox(
                width: thumbSize,
                height: thumbSize,
                child: imageUrl == null
                    ? ColoredBox(color: AppTheme.surface)
                    : CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => const ShimmerPlaceholder(),
                        errorWidget: (_, _, _) => ColoredBox(
                          color: AppTheme.surface,
                          child: Icon(LucideIcons.imageOff,
                              color: AppTheme.textFaint, size: 20),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'InterDisplay',
              fontFamilyFallback: const ['NotoSansTC'],
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'InterDisplay',
              fontFamilyFallback: const ['NotoSansTC'],
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textMute,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
