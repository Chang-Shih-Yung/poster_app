import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_theme.dart';
import '../shimmer_placeholder.dart';
import 'app_card.dart';

/// Image-first poster tile — the masonry / grid / horizontal-scroll
/// card used everywhere the app shows a poster.
///
/// Shared surface for:
///   · library_density_views `_MediumPosterTile` (masonry)
///   · poster_detail_page `_RelatedCard` (horizontal list)
///   · search_page masonry
///   · home `_HeroCard` (when width is full)
///   · public_profile_page grid tile
///   · home_collection grid tile
///
/// Layout: full-bleed poster image as the card body, optional
/// title+meta overlay at the bottom (gradient dim behind text so
/// copy reads on bright imagery), optional favourite stamp in a
/// corner.
///
/// This is a tile — AppCard-shaped, aspect-ratio configurable.
/// For small horizontal-row thumbnail tiles (56×56 + text beside),
/// reach for [AppPosterRow] instead.
class AppPosterTile extends StatelessWidget {
  const AppPosterTile({
    super.key,
    required this.imageUrl,
    this.fullImageUrl,
    this.posterId,
    this.title,
    this.subtitle,
    this.aspectRatio,
    this.onTap,
    this.onLongPress,
    this.favorited = false,
    this.showFavIndicator = false,
    this.width,
    this.height,
    this.borderRadius,
    this.showOverlayText = true,
  });

  /// Canonical image URL — what the tile renders. Usually the
  /// thumbnail.
  final String? imageUrl;

  /// Optional larger image (the source we'll need on the detail
  /// route). When set + the user taps the default navigation, we
  /// precacheImage this URL before pushing the route so the detail
  /// page Hero already has the full-res frame hot in cache.
  final String? fullImageUrl;

  /// Passed purely to give the Hero tag parity with the detail route.
  /// Pass null to skip the Hero.
  final String? posterId;

  final String? title;
  final String? subtitle;

  /// Width / height of the image.  When only one is supplied, the
  /// [aspectRatio] controls the other.  Passing both overrides
  /// aspectRatio entirely.
  final double? aspectRatio;
  final double? width;
  final double? height;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Draw the little "favorited" heart stamp in the top-right.
  /// Only honoured when [showFavIndicator] is also true (lets the
  /// caller choose per-context — e.g. 投稿 tab shows, 收藏 tab hides
  /// because every tile would have the same stamp).
  final bool favorited;
  final bool showFavIndicator;

  /// Corner radius override. Defaults to [AppTheme.r3] (6px) — the
  /// Spotify album-art radius. Pass r4 for chunkier cards.
  final BorderRadiusGeometry? borderRadius;

  /// Toggle the gradient+title overlay. Off for cards that show
  /// their text outside the image (row-based layouts).
  final bool showOverlayText;

  @override
  Widget build(BuildContext context) {
    // v19 image-perf: decode hint capped at 800px (covers 2x DPR
    // 400-wide hero tiles + portrait orientations). Memory drop
    // is significant — original posters are routinely 2400-3600px
    // wide and full decoding eats 100MB+ across a masonry grid.
    // 200ms fade smooths the loaded reveal so the grid doesn't
    // pop in like a slideshow.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodeWidth = (800 * dpr).toInt();
    final img = imageUrl == null
        ? ColoredBox(color: AppTheme.surface)
        : CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            memCacheWidth: decodeWidth,
            maxWidthDiskCache: decodeWidth,
            fadeInDuration: const Duration(milliseconds: 200),
            fadeOutDuration: Duration.zero,
            placeholder: (_, _) => const ShimmerPlaceholder(),
            errorWidget: (_, _, _) => ColoredBox(
              color: AppTheme.surface,
              child: Icon(LucideIcons.imageOff,
                  color: AppTheme.textFaint, size: 28),
            ),
          );

    final hero = posterId != null ? Hero(tag: 'poster-$posterId', child: img) : img;

    final overlays = <Widget>[
      if (showOverlayText && (title != null || subtitle != null))
        Positioned(
          left: 10,
          right: 10,
          bottom: 10,
          child: IgnorePointer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Text(
                    title!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'InterDisplay',
                      fontFamilyFallback: ['NotoSansTC'],
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.2,
                      letterSpacing: -0.1,
                      shadows: [
                        Shadow(blurRadius: 6, color: Color(0x88000000)),
                      ],
                    ),
                  ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'InterDisplay',
              fontFamilyFallback: const ['NotoSansTC'],
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.75),
                      shadows: const [
                        Shadow(blurRadius: 6, color: Color(0x88000000)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      if (showFavIndicator && favorited)
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 0.5,
              ),
            ),
            child: Icon(Icons.favorite,
                size: 14, color: AppTheme.favoriteActive),
          ),
        ),
    ];

    final baseRadius =
        borderRadius ?? BorderRadius.circular(AppTheme.r3);

    Widget body = Stack(
      fit: StackFit.expand,
      children: [
        hero,
        if (showOverlayText && (title != null || subtitle != null))
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.58),
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
          ),
        ...overlays,
      ],
    );

    if (aspectRatio != null && width == null && height == null) {
      body = AspectRatio(aspectRatio: aspectRatio!, child: body);
    }

    // Default tap: precache the full-res image (when known) before
    // pushing the detail route so the Hero animation lands on a
    // hot frame instead of the white-flash → load-spinner sequence.
    final tap = onTap ??
        (posterId != null
            ? () async {
                final full = fullImageUrl;
                if (full != null && full.isNotEmpty) {
                  // Fire-and-forget — don't block navigation if the
                  // precache stalls; detail page falls back to its
                  // own load.
                  precacheImage(NetworkImage(full), context).catchError((_) {});
                }
                if (context.mounted) {
                  GoRouter.of(context).push('/poster/$posterId');
                }
              }
            : null);

    return AppCard(
      onTap: tap,
      onLongPress: onLongPress,
      padding: EdgeInsets.zero,
      background: AppTheme.surface,
      borderRadius: baseRadius,
      width: width,
      height: height,
      child: body,
    );
  }
}
