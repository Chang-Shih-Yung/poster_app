part of 'library_page.dart';

// ---------------------------------------------------------------------------
// L: Full-bleed immersive hero
// ---------------------------------------------------------------------------

class _FullBleedFeed extends StatefulWidget {
  const _FullBleedFeed({
    required this.pageController,
    required this.items,
    required this.heroIndex,
    required this.topPadding,
    required this.favIds,
    required this.onToggleFavorite,
  });
  final PageController pageController;
  final List<Poster> items;
  final int heroIndex;
  final double topPadding;
  final Set<String> favIds;
  final void Function(Poster) onToggleFavorite;

  @override
  State<_FullBleedFeed> createState() => _FullBleedFeedState();
}

class _FullBleedFeedState extends State<_FullBleedFeed>
    with SingleTickerProviderStateMixin {
  double _swipeY = 0;
  bool _showHeartPulse = false;
  late final AnimationController _heartAnim;

  @override
  void initState() {
    super.initState();
    _heartAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() => _showHeartPulse = false);
          _heartAnim.reset();
        }
      });
  }

  @override
  void dispose() {
    _heartAnim.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    // Only track upward swipes (negative dy).
    setState(() => _swipeY = (_swipeY + d.delta.dy).clamp(-200.0, 0.0));
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dy;
    // Trigger favorite if swiped up past threshold or fast velocity.
    if (_swipeY < -60 || v < -600) {
      final items = widget.items;
      final idx = widget.heroIndex.clamp(0, items.length - 1);
      if (items.isNotEmpty) {
        HapticFeedback.mediumImpact();
        widget.onToggleFavorite(items[idx]);
        setState(() => _showHeartPulse = true);
        _heartAnim.forward();
      }
    }
    setState(() => _swipeY = 0);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final items = widget.items;
    final heroIndex = widget.heroIndex;
    final pageController = widget.pageController;
    final favIds = widget.favIds;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-screen PageView with vertical swipe detection.
        GestureDetector(
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          child: PageView.builder(
            controller: pageController,
            itemCount: items.length,
            itemBuilder: (context, i) {
              final poster = items[i];
              return GestureDetector(
                onTap: () => context.push('/poster/${poster.id}'),
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  widget.onToggleFavorite(poster);
                  setState(() => _showHeartPulse = true);
                  _heartAnim.forward();
                },
                child: Hero(
                  tag: 'poster-${poster.id}',
                  placeholderBuilder: (_, size, _) =>
                      SizedBox(width: size.width, height: size.height),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: poster.posterUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            ColoredBox(color: AppTheme.surfaceRaised),
                        errorWidget: (_, _, _) =>
                            ColoredBox(color: AppTheme.surfaceRaised),
                      ),
                      // Gradient overlays.
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x88000000),
                              Colors.transparent,
                              Colors.transparent,
                              Color(0xCC000000),
                            ],
                            stops: [0, 0.25, 0.55, 1],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Swipe hint — subtle upward arrow when dragging.
        if (_swipeY < -10)
          Positioned(
            bottom: (bottomInset > 0 ? bottomInset : 18.0) + 160,
            left: 0,
            right: 0,
            child: Center(
              child: Opacity(
                opacity: (_swipeY.abs() / 60).clamp(0.0, 1.0),
                child: Icon(LucideIcons.chevronUp,
                    size: 28, color: Colors.white.withValues(alpha: 0.6)),
              ),
            ),
          ),

        // Bottom chrome: title-left + heart-right, page indicator below.
        Positioned(
          bottom: (bottomInset > 0 ? bottomInset : 18.0) + 16,
          left: 24,
          right: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title row: text left, heart right.
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: _buildTitleOverlay(context)),
                  if (items.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        final idx = heroIndex.clamp(0, items.length - 1);
                        widget.onToggleFavorite(items[idx]);
                        setState(() => _showHeartPulse = true);
                        _heartAnim.forward();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 4),
                        child: AnimatedScale(
                          scale: _showHeartPulse ? 1.4 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
                          child: Icon(
                            LucideIcons.heart,
                            size: 22,
                            color: favIds.contains(items[
                                    heroIndex.clamp(0, items.length - 1)].id)
                                ? AppTheme.favoriteActive
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Page indicator — left-aligned.
              items.length <= 12
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < items.length; i++)
                          AnimatedContainer(
                            duration: AppTheme.motionFast,
                            margin:
                                const EdgeInsets.symmetric(horizontal: 2.5),
                            width: i == heroIndex ? 16 : 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: i == heroIndex
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    )
                  : AppText.small(
                      '${heroIndex + 1} / ${items.length}',
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTitleOverlay(BuildContext context) {
    final items = widget.items;
    final heroIndex = widget.heroIndex;
    if (items.isEmpty) return const SizedBox.shrink();
    final poster = items[heroIndex.clamp(0, items.length - 1)];
    return AnimatedSwitcher(
      duration: AppTheme.motionFast,
      child: Column(
        key: ValueKey(poster.id),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Eyebrow: first tag.
          if (poster.tags.isNotEmpty) ...[
            AppText.label(
              poster.tags.first.toUpperCase(),
              color: Colors.white.withValues(alpha: 0.55),
              weight: FontWeight.w500,
            ),
            const SizedBox(height: 10),
          ],
          // Title.
          AppText.headline(
            poster.title,
            color: Colors.white,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // Year.
          if (poster.year != null) ...[
            const SizedBox(height: 6),
            AppText.title(
              '${poster.year}',
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ],
          // Director.
          if (poster.director != null) ...[
            const SizedBox(height: 4),
            AppText.body(
              poster.director!,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// M: v13 Pinterest masonry — 2 cols of variable-height cards
// ---------------------------------------------------------------------------

/// Deterministic aspect ratio per poster id. Real images load with
/// BoxFit.cover so the card stays the chosen height regardless. This
/// gives the visual "Pinterest" rhythm without needing image dimensions
/// in the database.
double _ratioForId(String id) {
  // 5 movie-poster-leaning ratios. Bias toward the canonical 2:3 (=0.67)
  // because most posters are that shape; the others give visual variety.
  const ratios = <double>[0.67, 0.67, 0.75, 1.0, 1.33, 0.56];
  var h = 0;
  for (final r in id.runes) {
    h = (h * 31 + r) & 0x7fffffff;
  }
  return ratios[h % ratios.length];
}

class _MediumGrid extends StatelessWidget {
  const _MediumGrid({
    required this.controller,
    required this.items,
    required this.trailingLoader,
    required this.topPadding,
    required this.bottomPadding,
    required this.favIds,
    required this.onToggleFavorite,
    this.showFav = true,
    this.header,
  });
  final ScrollController controller;
  final List<Poster> items;
  final bool trailingLoader;
  final double topPadding;
  final double bottomPadding;
  final Set<String> favIds;
  final void Function(Poster) onToggleFavorite;

  /// When false, cards never render the heart overlay — e.g. on the
  /// 收藏 segmented tab where the category itself already implies
  /// "favorited". Submissions use showFav=true with the fancy heart.
  final bool showFav;

  /// Optional widget rendered BEFORE the masonry rows, inside the
  /// same scroll view. Used by 我的 to inline the avatar/stats/tabs
  /// chrome so the whole page scrolls together as one surface.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    // Two-column masonry: assign each poster to whichever column is
    // currently shorter. Same algorithm the v13 prototype uses.
    final colA = <Poster>[];
    final colB = <Poster>[];
    var hA = 0.0;
    var hB = 0.0;
    for (final p in items) {
      final h = 1 / _ratioForId(p.id);
      if (hA <= hB) {
        colA.add(p);
        hA += h + 0.05;
      } else {
        colB.add(p);
        hB += h + 0.05;
      }
    }

    Widget renderCard(Poster p) => _MasonryCard(
          poster: p,
          isFavorited: favIds.contains(p.id),
          showFav: showFav,
          onToggleFavorite: () => onToggleFavorite(p),
          aspectRatio: _ratioForId(p.id),
        );

    return SingleChildScrollView(
      controller: controller,
      // Horizontal padding stays constant; vertical gap below the
      // chrome (if any) is provided by `topPadding`. When a header
      // is inlined, it ignores the outer horizontal padding and
      // renders edge-to-edge — so we wrap it in a Transform to
      // punch through, then the masonry picks up at 12px gutters.
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        children: [
          ?header,
          Padding(
            padding: EdgeInsets.fromLTRB(12, topPadding, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: colA
                        .map((p) => Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: renderCard(p),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    children: colB
                        .map((p) => Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: renderCard(p),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          if (trailingLoader)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: const AppLoader(),
              ),
            ),
        ],
      ),
    );
  }
}

/// v19 masonry card — delegates to the shared [AppPosterTile] so
/// every masonry grid in the app (me tab, tag browse, work page,
/// public profile) renders with one contract.
class _MasonryCard extends StatelessWidget {
  const _MasonryCard({
    required this.poster,
    required this.isFavorited,
    required this.onToggleFavorite,
    required this.aspectRatio,
    this.showFav = true,
  });
  final Poster poster;
  final bool isFavorited;
  final VoidCallback onToggleFavorite;
  final double aspectRatio;

  /// Hide the heart overlay entirely — used on the 收藏 tab where
  /// every card is by definition favorited.
  final bool showFav;

  @override
  Widget build(BuildContext context) {
    // v19: 我的 tab tiles are pure image (no overlay title or
    // year/director caption). Hover the poster — content is the
    // poster, not text on top of the poster.
    return AppPosterTile(
      imageUrl: poster.thumbnailUrl ?? poster.posterUrl,
      fullImageUrl: poster.posterUrl,
      blurhash: poster.blurhash,
      posterId: poster.id,
      aspectRatio: aspectRatio,
      favorited: isFavorited,
      showFavIndicator: showFav,
      onLongPress: onToggleFavorite,
      showOverlayText: false,
    );
  }
}

// ---------------------------------------------------------------------------
// S: Spotify-style list rows
// ---------------------------------------------------------------------------

// ignore: unused_element
class _SmallList extends StatelessWidget {
  const _SmallList({
    required this.controller,
    required this.items,
    required this.trailingLoader,
    required this.topPadding,
    required this.bottomPadding,
    required this.favIds,
    required this.onToggleFavorite,
  });
  final ScrollController controller;
  final List<Poster> items;
  final bool trailingLoader;
  final double topPadding;
  final double bottomPadding;
  final Set<String> favIds;
  final void Function(Poster) onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: controller,
      padding: EdgeInsets.fromLTRB(20, topPadding, 20, bottomPadding),
      itemCount: items.length + (trailingLoader ? 1 : 0),
      separatorBuilder: (_, _) => Divider(
        color: AppTheme.line1,
        height: 0.5,
        thickness: 0.5,
      ),
      itemBuilder: (context, i) {
        if (i >= items.length) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: const Center(child: AppLoader()),
          );
        }
        final poster = items[i];
        return _SmallTile(
          poster: poster,
          isFavorited: favIds.contains(poster.id),
          onToggleFavorite: () => onToggleFavorite(poster),
        );
      },
    );
  }
}

class _SmallTile extends StatelessWidget {
  const _SmallTile({
    required this.poster,
    required this.isFavorited,
    required this.onToggleFavorite,
  });
  final Poster poster;
  final bool isFavorited;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return AppPosterRow(
      imageUrl: poster.thumbnailUrl ?? poster.posterUrl,
      posterId: poster.id,
      title: poster.title,
      subtitle: [
        if (poster.year != null) '${poster.year}',
        if (poster.director != null) poster.director!,
      ].join(' · '),
      onLongPress: onToggleFavorite,
      trailing: AppIconButton(
        icon: isFavorited ? Icons.favorite : LucideIcons.heart,
        size: AppIconButtonSize.small,
        color:
            isFavorited ? AppTheme.favoriteActive : AppTheme.textFaint,
        onTap: onToggleFavorite,
        semanticsLabel: isFavorited ? '取消收藏' : '加入收藏',
      ),
    );
  }
}

