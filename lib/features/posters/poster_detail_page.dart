import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/services/image_prefetch.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/ds/ds.dart';
import '../../core/widgets/glass.dart';
import '../../data/models/poster.dart';
import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/favorite_repository.dart';
import '../../data/repositories/poster_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/repositories/view_repository.dart';

final _posterByIdProvider =
    FutureProvider.family<Poster?, String>((ref, id) async {
  final repo = ref.watch(posterRepositoryProvider);
  final p = await repo.getById(id);
  if (p != null && p.status == 'approved') {
    // Session-level dedup: ViewRepository skips RPC if already viewed.
    ref.read(viewRepositoryProvider).recordView(id);
  }
  return p;
});

/// Fetches up to 6 related posters (same tags, excluding current).
final _relatedPostersProvider =
    FutureProvider.family<List<Poster>, Poster>((ref, poster) async {
  try {
    final repo = ref.watch(posterRepositoryProvider);
    // Try fetching by first tag if available.
    if (poster.tags.isNotEmpty) {
      final page = await repo.listApproved(
        filter: PosterFilter(tags: [poster.tags.first]),
      );
      final related =
          page.items.where((p) => p.id != poster.id).take(6).toList();
      if (related.isNotEmpty) return related;
    }
    // Fallback: just latest posters excluding self.
    final page = await repo.listApproved();
    return page.items.where((p) => p.id != poster.id).take(6).toList();
  } catch (_) {
    return const [];
  }
});

/// Detail page — v10 editorial style.
///
/// - Full-bleed hero with shared [Hero] tag `poster-${id}` from browse.
/// - Gradient mask (top for close button, bottom for content).
/// - Column metadata (Year / Director / Views) inspired by Wind Rises.
/// - Related posters horizontal scroll.
/// - Drag-to-dismiss gesture (threshold 120pt or velocity > 800).
class PosterDetailPage extends ConsumerWidget {
  const PosterDetailPage({super.key, required this.posterId});
  final String posterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_posterByIdProvider(posterId));
    return Scaffold(
      
      extendBodyBehindAppBar: true,
      body: async.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(message: '$e'),
        data: (p) => p == null
            ? const _ErrorView(message: '找不到這張海報')
            : _DetailBody(poster: p),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const AppLoader.centered();
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMute,
              ),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({required this.poster});
  final Poster poster;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  double _dragY = 0;

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    setState(() => _dragY = (_dragY + d.delta.dy).clamp(0.0, 600.0));
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dy;
    if (_dragY > 120 || v > 800) {
      context.pop();
    } else {
      setState(() => _dragY = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.poster;
    final user = ref.watch(currentUserProvider);
    final favIdsAsync = ref.watch(favoriteIdsProvider);
    final favIds = favIdsAsync.asData?.value;
    final isFav = favIds?.contains(p.id) ?? false;
    final favIdsReady = favIds != null;

    Future<void> toggleFav() async {
      HapticFeedback.mediumImpact();
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請先登入才能收藏')),
        );
        return;
      }
      final repo = ref.read(favoriteRepositoryProvider);
      try {
        await repo.toggle(p.id);
        ref.invalidate(favoriteIdsProvider);
        ref.invalidate(favoritesProvider);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('失敗：$e')));
      }
    }

    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;
    final progress = (_dragY / 200).clamp(0.0, 1.0);
    final scale = 1.0 - progress * 0.06;

    // v19 (round 3) detail layout — Spotify now-playing.
    //
    // Everything scrolls together (no parallax). Hero image at top,
    // inline title/director/CTAs (no card chrome) directly below,
    // then a slightly LIGHTER dark sheet for "相關海報" so the next
    // section reads as a separate surface tone.
    //
    // Layout:
    //   - Image (heroH) — scrolls with content
    //   - Inline Fuji content — text + actions on bg, no Glass card
    //   - 24px gap (bg shows through)
    //   - Related section (lighter card) — surfaceAlt fill
    //   - Bottom inset
    //
    // Floating: only the close button stays pinned top-left.
    // Hero takes 50% of screen — leaves enough room for the inline
    // Fuji content + 24px gap + the 相關海報 eyebrow peek above the
    // fold. Title overlapping the bottom of the poster a touch is
    // intentional (gradient covers the bleed).
    final heroH = screenH * 0.50;

    return GestureDetector(
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppTheme.motionFast,
        color: Color.lerp(AppTheme.bg, Colors.black, progress) ?? AppTheme.bg,
        child: Transform.translate(
          offset: Offset(0, _dragY),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topCenter,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Page bg.
                Positioned.fill(child: ColoredBox(color: AppTheme.bg)),

                // Scrollable content.
                SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hero image with bottom fade into bg.
                      SizedBox(
                        height: heroH,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Hero(
                              tag: 'poster-${p.id}',
                              child: CachedNetworkImage(
                                imageUrl: p.posterUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => ColoredBox(
                                    color: AppTheme.surfaceRaised),
                                errorWidget: (_, _, _) => ColoredBox(
                                  color: AppTheme.surfaceRaised,
                                  child: Icon(LucideIcons.imageOff,
                                      color: AppTheme.textFaint, size: 40),
                                ),
                              ),
                            ),
                            const IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0x73000000), // 0.45 top dim
                                      Color(0x00000000),
                                      Color(0x00000000),
                                      Color(0xFF121212), // bg at hem
                                    ],
                                    stops: [0.0, 0.18, 0.50, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Inline Fuji content — no card chrome,
                      // just text + actions on the page bg.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                        child: _FujiInline(
                          poster: p,
                          isFav: isFav,
                          favIdsReady: favIdsReady,
                          onToggleFav: toggleFav,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Related section as its own lighter card.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _RelatedSection(poster: p),
                      ),

                      SizedBox(height: bottomInset + 32),
                    ],
                  ),
                ),

                // Top close button, fixed.
                Positioned(
                  top: topInset + 12,
                  left: 16,
                  child: GlassButton(
                    icon: LucideIcons.chevronDown,
                    onTap: () => context.pop(),
                    semanticsLabel: '關閉',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── v13 Fuji drawer ────────────────────────────────────────────────
//
// A glass panel anchored at the bottom of the hero image. Contains
// drag handle + eyebrow + 32px editorial title + director + stats
// row (年份/時長/瀏覽) + white pill CTA + share. Replaces the v12
// inline title stack + gradient overlay metadata.

class _FujiDrawer extends StatefulWidget {
  const _FujiDrawer({
    required this.poster,
    required this.isFav,
    required this.favIdsReady,
    required this.onToggleFav,
  });
  final Poster poster;
  final bool isFav;
  final bool favIdsReady;
  final Future<void> Function() onToggleFav;

  @override
  State<_FujiDrawer> createState() => _FujiDrawerState();
}

class _FujiDrawerState extends State<_FujiDrawer> {
  @override
  Widget build(BuildContext context) {
    // v19 round 3: kept name for back-compat but the Glass card is
    // gone. Real implementation lives in [_FujiInline] which renders
    // directly on bg, no chrome — Spotify's now-playing pattern.
    return _FujiInline(
      poster: widget.poster,
      isFav: widget.isFav,
      favIdsReady: widget.favIdsReady,
      onToggleFav: widget.onToggleFav,
    );
  }
}

/// Inline poster info. Sits on the page bg directly — no Glass, no
/// border, no card chrome. Eyebrow + 32px title + director + stats
/// + tags + CTAs.
class _FujiInline extends ConsumerWidget {
  const _FujiInline({
    required this.poster,
    required this.isFav,
    required this.favIdsReady,
    required this.onToggleFav,
  });
  final Poster poster;
  final bool isFav;
  final bool favIdsReady;
  final Future<void> Function() onToggleFav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = poster;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Eyebrow.
        _Eyebrow(
          parts: [
            if (p.tags.isNotEmpty) p.tags.first.toUpperCase(),
            if (p.year != null) '${p.year}',
          ],
        ),
        const SizedBox(height: 6),
        // Title — 32px editorial. Tap → work page if linked.
        GestureDetector(
          onTap: p.workId == null
              ? null
              : () => context.push('/work/${p.workId}'),
          child: Text(
            p.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineLarge?.copyWith(
              color: AppTheme.text,
              fontSize: 32,
              height: 1.05,
              // 600 — Inter SemiBold renders cleanly for Latin and
              // CJK glyphs (NotoSansTC fallback at w500 is closest
              // visually); w700 was clumping CJK strokes together.
              fontWeight: FontWeight.w600,
              letterSpacing: -0.8,
            ),
          ),
        ),
        if (p.director != null && p.director!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            p.director!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textMute,
            ),
          ),
        ],
        const SizedBox(height: 16),
        // Stats row + tags shown unconditionally — no more
        // expand/collapse. Inline content has room to breathe now
        // that there's no card constraining it.
        _StatsRow(poster: p),
        const SizedBox(height: 14),
        _ExpandedInfo(poster: p),
        const SizedBox(height: 18),
        // CTAs.
        Row(
          children: [
            Expanded(
              child: _PrimaryCta(
                isFav: isFav,
                enabled: favIdsReady,
                onTap: onToggleFav,
              ),
            ),
            const SizedBox(width: 8),
            AppIconButton(
              icon: LucideIcons.share2,
              size: AppIconButtonSize.large,
              variant: AppIconButtonVariant.filled,
              onTap: () {
                HapticFeedback.selectionClick();
                Clipboard.setData(ClipboardData(text: p.posterUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('連結已複製')),
                );
              },
              semanticsLabel: '分享',
            ),
            const SizedBox(width: 8),
            AppIconButton(
              icon: LucideIcons.maximize,
              size: AppIconButtonSize.large,
              variant: AppIconButtonVariant.filled,
              onTap: () {
                HapticFeedback.selectionClick();
                showDialog<void>(
                  context: context,
                  barrierColor: Colors.black.withValues(alpha: 0.92),
                  builder: (_) => _FullImageViewer(url: p.posterUrl),
                );
              },
              semanticsLabel: '放大',
            ),
          ],
        ),
      ],
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.parts});
  final List<String> parts;

  @override
  Widget build(BuildContext context) {
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' · '),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textMute,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.poster});
  final Poster poster;

  @override
  Widget build(BuildContext context) {
    final stats = <_Stat>[];
    if (poster.year != null) {
      stats.add(_Stat(label: '年份', value: '${poster.year}'));
    }
    stats.add(_Stat(
      label: '瀏覽',
      value: poster.viewCount > 1000
          ? '${(poster.viewCount / 1000).toStringAsFixed(1)}k'
          : '${poster.viewCount}',
    ));
    stats.add(_Stat(
      label: '收藏',
      value: '${poster.favoriteCount}',
    ));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: stats.map((s) => Expanded(child: s)).toList(),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppTheme.textFaint,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.text,
          ),
        ),
      ],
    );
  }
}

class _ExpandedInfo extends ConsumerWidget {
  const _ExpandedInfo({required this.poster});
  final Poster poster;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tagsAsync = ref.watch(tagsForPosterProvider(poster.id));
    final canonical = tagsAsync.asData?.value ?? const [];

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canonical.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: canonical
                  .map((t) => AppChip(
                        label: '# ${t.labelZh}',
                        size: AppChipSize.small,
                        onTap: () => context.push('/tags/${t.slug}'),
                      ))
                  .toList(growable: false),
            )
          else if (poster.tags.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: poster.tags
                  .map((t) =>
                      AppChip(label: t, size: AppChipSize.small))
                  .toList(growable: false),
            ),
          if (poster.workId != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => context.push('/work/${poster.workId}'),
              child: Row(
                children: [
                  Icon(LucideIcons.layers,
                      size: 13, color: AppTheme.textMute),
                  const SizedBox(width: 6),
                  Text(
                    '看這部作品的所有海報',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.textMute,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(LucideIcons.chevronRight,
                      size: 13, color: AppTheme.textMute),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({
    required this.isFav,
    required this.enabled,
    required this.onTap,
  });
  final bool isFav;
  final bool enabled;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    // v19: inverted state picks variant, not bespoke colours.
    //   · un-favorited → AppButton.primary (white pill, 加入收藏)
    //   · favorited    → AppButton.outline  (ghost-ish, 已收藏)
    if (isFav) {
      return AppButton.outline(
        label: '已收藏',
        icon: Icons.favorite,
        fullWidth: true,
        onPressed: enabled ? () => onTap() : null,
      );
    }
    return AppButton.primary(
      label: '加入收藏',
      icon: LucideIcons.heart,
      fullWidth: true,
      onPressed: enabled ? () => onTap() : null,
    );
  }
}

// ── Related posters section ──

class _RelatedSection extends ConsumerWidget {
  const _RelatedSection({required this.poster});
  final Poster poster;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relatedAsync = ref.watch(_relatedPostersProvider(poster));

    return relatedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        // v19 round 4: card bg matches the pill family so the
        // related sheet, AppChip, and AppButton.secondary all read
        // at one tone — surfaceRaised (#2E2E2E).
        return AppCard(
          padding: const EdgeInsets.fromLTRB(0, 18, 0, 18),
          background: AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(AppTheme.r5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: AppSectionHeader(
                  title: '相關海報',
                  horizontalPadding: 0,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    // Prefetch the next 3 thumbs into the cache so
                    // they're hot when the user scrolls right.
                    prefetchAhead(
                      context: context,
                      urls: items
                          .map((p) => p.thumbnailUrl ?? p.posterUrl)
                          .toList(growable: false),
                      currentIndex: i,
                    );
                    final p = items[i];
                    return AppPosterTile(
                      imageUrl: p.thumbnailUrl ?? p.posterUrl,
                      fullImageUrl: p.posterUrl,
                      posterId: p.id,
                      title: p.title,
                      width: 130,
                      height: 200,
                      onTap: () {
                        precacheImage(NetworkImage(p.posterUrl), context)
                            .catchError((_) {});
                        if (context.mounted) {
                          context.pushReplacement('/poster/${p.id}');
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// _RelatedCard / _MiniChip / _TappableTagChip removed in v19 —
// replaced by AppPosterTile and AppChip from the design system.

class _FullImageViewer extends StatelessWidget {
  const _FullImageViewer({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
