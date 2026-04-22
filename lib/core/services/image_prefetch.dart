import 'package:flutter/material.dart';

/// v19 Phase 2 — scroll-ahead image prefetch.
///
/// When a horizontal carousel renders item at index `current`, fire
/// off precacheImage calls for the next [lookahead] items so they're
/// hot in the cache by the time the user scrolls into view. Errors
/// are swallowed (network blip on item N+5 is irrelevant — the user
/// hasn't reached it yet).
///
/// Wrap the work in a postFrameCallback so the precache happens
/// AFTER the current frame commits — keeps the build phase pure
/// and avoids "image fetch during paint" jank.
void prefetchAhead({
  required BuildContext context,
  required List<String> urls,
  required int currentIndex,
  int lookahead = 3,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final stop = (currentIndex + lookahead + 1).clamp(0, urls.length);
    for (var i = currentIndex + 1; i < stop; i++) {
      final url = urls[i];
      if (url.isEmpty) continue;
      precacheImage(NetworkImage(url), context).catchError((_) {});
    }
  });
}
