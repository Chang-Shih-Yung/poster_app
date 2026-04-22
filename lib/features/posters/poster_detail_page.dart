import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  // ── Hero (full-bleed poster + Fuji drawer overlay) ──
                  // Slightly less than full-height so the "相關海報"
                  // eyebrow below peeks above the fold — Spotify-style
                  // scroll-affordance hint that there is more content.
                  SizedBox(
                    height: screenH - 64,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Poster image — full bleed.
                        Hero(
                          tag: 'poster-${p.id}',
                          child: CachedNetworkImage(
                            imageUrl: p.posterUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                ColoredBox(color: AppTheme.surfaceRaised),
                            errorWidget: (_, _, _) => ColoredBox(
                              color: AppTheme.surfaceRaised,
                              child: Icon(LucideIcons.imageOff,
                                  color: AppTheme.textFaint, size: 40),
                            ),
                          ),
                        ),
                        // Spotify-style bottom fade. Image fades into
                        // surfaceAlt (#1F1F1F) — 4 brightness units
                        // darker than the _RelatedSection below
                        // (surfaceRaised #252525). That tiny delta is
                        // enough for the rounded-top sheet to read as
                        // "rising out of the haze" while hiding the
                        // hard seam the user was seeing against pure
                        // black. Top chrome still gets its 45% dim.
                        const Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0x73000000), // 0.45 top dim
                                    Color(0x00000000),
                                    Color(0x00000000),
                                    Color(0xFF1F1F1F), // surfaceAlt at hem
                                  ],
                                  stops: [0.0, 0.20, 0.50, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Top floating glass button — close only.
                        // v19: dropped the top-right heart. The Fuji
                        // drawer already has a prominent 已收藏 /
                        // 加入收藏 pill CTA; two affordances for the
                        // same action on one screen is clutter.
                        Positioned(
                          top: topInset + 12,
                          left: 16,
                          child: GlassButton(
                            icon: LucideIcons.chevronDown,
                            onTap: () => context.pop(),
                            semanticsLabel: '關閉',
                          ),
                        ),
                        // Fuji drawer (bottom glass panel).
                        Positioned(
                          left: 16,
                          right: 16,
                          // Detail page is pushed above the shell, so
                          // there's no floating tab bar to clear. Sit
                          // the drawer just above the safe-area edge.
                          bottom: bottomInset + 16,
                          child: _FujiDrawer(
                            poster: p,
                            isFav: isFav,
                            favIdsReady: favIdsReady,
                            onToggleFav: toggleFav,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Below the fold: related posters ──
                  _RelatedSection(poster: p),
                ],
              ),
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
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.poster;
    final theme = Theme.of(context);

    return AnimatedSize(
      duration: AppTheme.motionMed,
      curve: AppTheme.easeStandard,
      alignment: Alignment.topCenter,
      child: Glass(
        blur: 30,
        tint: 0.18,
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
        // Drop the inset top highlight — Glass paints a 1px white
        // line at the top edge to read as "specular highlight" but
        // on the Fuji drawer it shows up as a stray hairline directly
        // above the drag handle. Disable here.
        highlight: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle — tap to expand/collapse. App-style (no
            // chevron indicator — just the pill). 16dp vertical hit
            // area around the visible 4dp pill.
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            // Eyebrow: first tag · year (uppercase, letter-spaced).
            _Eyebrow(
              parts: [
                if (p.tags.isNotEmpty) p.tags.first.toUpperCase(),
                if (p.year != null) '${p.year}',
              ],
            ),
            const SizedBox(height: 6),
            // Title — 32px editorial.
            GestureDetector(
              onTap: p.workId == null
                  ? null
                  : () => context.push('/work/${p.workId}'),
              child: Text(
                p.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontSize: 32,
                  height: 1.05,
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
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
            // Everything below title + director collapses together:
            // stats row (年份/瀏覽/收藏), tags, work link. Collapsed
            // state is just drag-handle + eyebrow + title + director
            // + CTA row — a taller-than-a-snackbar but much smaller
            // than expanded.
            if (_expanded) ...[
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1)),
                    bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _StatsRow(poster: p),
              ),
              _ExpandedInfo(poster: p),
              const SizedBox(height: 14),
            ] else
              const SizedBox(height: 12),
            // CTAs.
            Row(
              children: [
                Expanded(
                  child: _PrimaryCta(
                    isFav: widget.isFav,
                    enabled: widget.favIdsReady,
                    onTap: widget.onToggleFav,
                  ),
                ),
                const SizedBox(width: 8),
                GlassButton(
                  icon: LucideIcons.share2,
                  size: 46,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Clipboard.setData(ClipboardData(text: p.posterUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('連結已複製')),
                    );
                  },
                ),
                const SizedBox(width: 8),
                GlassButton(
                  icon: LucideIcons.maximize,
                  size: 46,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    showDialog<void>(
                      context: context,
                      barrierColor: Colors.black.withValues(alpha: 0.92),
                      builder: (_) => _FullImageViewer(url: p.posterUrl),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
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
            color: Colors.white.withValues(alpha: 0.65),
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
            color: Colors.white.withValues(alpha: 0.5),
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
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
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.55)),
                  const SizedBox(width: 6),
                  Text(
                    '看這部作品的所有海報',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(LucideIcons.chevronRight,
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.55)),
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
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return relatedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        // Soften the peek seam — Spotify style.
        //
        // Hero fade ends at surfaceAlt (#1F1F1F); this sheet sits on
        // surfaceRaised (#252525). 4 brightness units of delta is
        // enough for the rounded top to register as a sheet rising
        // out of a hazy dark zone rather than a pure-black seam.
        //
        // A subtle upward boxShadow (negative Y offset, low alpha)
        // adds a breath of haze right at the seam — the rounded
        // corners read as "lifted" instead of "cut".
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceRaised,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, -12),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            top: 28,
            bottom: bottomInset + 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '相關海報',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.textMute,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final p = items[i];
                    return AppPosterTile(
                      imageUrl: p.thumbnailUrl ?? p.posterUrl,
                      posterId: p.id,
                      title: p.title,
                      width: 130,
                      height: 200,
                      onTap: () =>
                          context.pushReplacement('/poster/${p.id}'),
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
