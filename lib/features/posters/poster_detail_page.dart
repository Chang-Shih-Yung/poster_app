import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/poster.dart';
import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/favorite_repository.dart';
import '../../data/repositories/poster_repository.dart';
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
      backgroundColor: AppTheme.bg,
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
  Widget build(BuildContext context) => Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.textMute,
          ),
        ),
      );
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
                  // ── Hero section (full-bleed poster) ──
                  SizedBox(
                    height: screenH,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Poster image.
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
                        // Top gradient.
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: topInset + 120,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.55),
                                    Colors.black.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Bottom gradient (taller for editorial content).
                        const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 480,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0x00000000),
                                    Color(0xB3000000),
                                    Color(0xF2000000),
                                  ],
                                  stops: [0.0, 0.45, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Top bar: close + fav.
                        Positioned(
                          top: topInset + 12,
                          left: 20,
                          right: 20,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _GlassIconButton(
                                icon: LucideIcons.chevronDown,
                                onTap: () => context.pop(),
                                semanticLabel: '關閉',
                              ),
                              _GlassIconButton(
                                icon: favIdsReady && isFav
                                    ? LucideIcons.heart
                                    : LucideIcons.heart,
                                onTap: favIdsReady ? toggleFav : null,
                                active: isFav,
                                semanticLabel: isFav ? '取消收藏' : '加入收藏',
                              ),
                            ],
                          ),
                        ),
                        // Title + metadata stack.
                        Positioned(
                          left: 24,
                          right: 24,
                          bottom: bottomInset + 28,
                          child: _TitleStack(poster: p),
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

// ── Title stack with column metadata ──

class _TitleStack extends StatelessWidget {
  const _TitleStack({required this.poster});
  final Poster poster;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Eyebrow: first tag uppercased.
        if (poster.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              poster.tags.first.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppTheme.textMute,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

        // Title — tappable to /work/:id if this poster is linked to a work.
        GestureDetector(
          onTap: poster.workId == null
              ? null
              : () => context.push('/work/${poster.workId}'),
          child: Text(
            poster.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.displaySmall?.copyWith(
              height: 1.05,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (poster.workId != null) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => context.push('/work/${poster.workId}'),
            child: Row(
              children: [
                Icon(LucideIcons.layers,
                    size: 13, color: AppTheme.textFaint),
                const SizedBox(width: 6),
                Text(
                  '看這部作品的所有海報',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.textFaint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronRight,
                    size: 13, color: AppTheme.textFaint),
              ],
            ),
          ),
        ],

        // Column metadata (Wind Rises style): Year / Director / Views.
        if (poster.year != null || poster.director != null) ...[
          const SizedBox(height: 18),
          _MetaColumns(poster: poster),
        ],

        // Tag chips.
        if (poster.tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: poster.tags
                .map((t) => _MiniChip(label: t))
                .toList(growable: false),
          ),
        ],

        // CTAs.
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: _WhitePillCta(
                label: '查看原圖',
                icon: LucideIcons.maximize,
                onTap: () {
                  HapticFeedback.selectionClick();
                  showDialog<void>(
                    context: context,
                    barrierColor: Colors.black.withValues(alpha: 0.92),
                    builder: (_) =>
                        _FullImageViewer(url: poster.posterUrl),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            _GlassPillCta(
              icon: LucideIcons.share2,
              onTap: () {
                HapticFeedback.selectionClick();
                Clipboard.setData(ClipboardData(text: poster.posterUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('連結已複製')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ── Column metadata (Year / Director / Views) ──

class _MetaColumns extends StatelessWidget {
  const _MetaColumns({required this.poster});
  final Poster poster;

  @override
  Widget build(BuildContext context) {
    final cols = <_MetaCol>[];

    if (poster.year != null) {
      cols.add(_MetaCol(label: '年份', value: '${poster.year}'));
    }
    if (poster.director != null && poster.director!.isNotEmpty) {
      cols.add(_MetaCol(label: '導演', value: poster.director!));
    }
    cols.add(_MetaCol(label: '瀏覽', value: '${poster.viewCount}'));

    return Row(
      children: [
        for (int i = 0; i < cols.length; i++) ...[
          if (i > 0) ...[
            Container(
              width: 1,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: AppTheme.line2,
            ),
          ],
          Flexible(child: cols[i]),
        ],
      ],
    );
  }
}

class _MetaCol extends StatelessWidget {
  const _MetaCol({required this.label, required this.value});
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
            letterSpacing: 1.6,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
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

        return Container(
          color: AppTheme.bg,
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
                  itemBuilder: (context, i) =>
                      _RelatedCard(poster: items[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RelatedCard extends StatelessWidget {
  const _RelatedCard({required this.poster});
  final Poster poster;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: AppTheme.surfaceRaised,
        child: InkWell(
          onTap: () => context.pushReplacement('/poster/${poster.id}'),
          child: SizedBox(
            width: 130,
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: poster.thumbnailUrl ?? poster.posterUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      const ColoredBox(color: AppTheme.surfaceRaised),
                  errorWidget: (_, _, _) =>
                      const ColoredBox(color: AppTheme.surfaceRaised),
                ),
                // Bottom gradient for title.
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 80,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00000000),
                          Color(0xBB000000),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Text(
                    poster.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
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

// ── Shared small widgets ──

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.line1),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.text,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}

class _WhitePillCta extends StatelessWidget {
  const _WhitePillCta({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.text,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.black),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPillCta extends StatelessWidget {
  const _GlassPillCta({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: Colors.white.withValues(alpha: 0.08),
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.line1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(icon, size: 18, color: AppTheme.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.semanticLabel,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Material(
            color: active
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.black.withValues(alpha: 0.28),
            child: InkWell(
              onTap: onTap,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.line1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(icon,
                    size: 18,
                    color: active
                        ? const Color(0xFFE53935)
                        : AppTheme.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
