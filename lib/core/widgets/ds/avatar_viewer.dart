import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_theme.dart';
import '../app_loader.dart';

/// Full-screen avatar zoom viewer.
///
/// Tap the close button or the dim background to dismiss.
/// InteractiveViewer wraps the image so the user can pinch / drag.
///
/// Usage:
///   showAvatarViewer(context, url: profile.avatarUrl);
Future<void> showAvatarViewer(
  BuildContext context, {
  required String? url,
  String? fallbackLetter,
}) {
  HapticFeedback.selectionClick();
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.95),
    builder: (_) => _AvatarViewer(url: url, fallbackLetter: fallbackLetter),
  );
}

class _AvatarViewer extends StatelessWidget {
  const _AvatarViewer({this.url, this.fallbackLetter});
  final String? url;
  final String? fallbackLetter;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: ClipOval(
                child: SizedBox(
                  width: 320,
                  height: 320,
                  child: hasUrl
                      ? InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 4,
                          child: CachedNetworkImage(
                            imageUrl: url!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                const Center(child: AppLoader()),
                            errorWidget: (_, _, _) => _Fallback(
                                letter: fallbackLetter),
                          ),
                        )
                      : _Fallback(letter: fallbackLetter),
                ),
              ),
            ),
          ),
        ),
        // Close button — top-right.
        Positioned(
          top: MediaQuery.paddingOf(context).top + 12,
          right: 16,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(LucideIcons.x, color: Colors.white),
              tooltip: '關閉',
            ),
          ),
        ),
      ],
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({this.letter});
  final String? letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceRaised,
      alignment: Alignment.center,
      child: Text(
        (letter == null || letter!.isEmpty) ? '?' : letter!,
        style: const TextStyle(
          fontFamily: 'InterDisplay',
          fontFamilyFallback: ['NotoSansTC'],
          fontSize: 96,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
