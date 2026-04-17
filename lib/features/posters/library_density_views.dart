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
                child: Hero(
                  tag: 'poster-${poster.id}',
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: poster.posterUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            const ColoredBox(color: AppTheme.surfaceRaised),
                        errorWidget: (_, _, _) =>
                            const ColoredBox(color: AppTheme.surfaceRaised),
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
                                ? const Color(0xFFE53935)
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
                  : Text(
                      '${heroIndex + 1} / ${items.length}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.6),
                            letterSpacing: 1.2,
                          ),
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
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: AppTheme.motionFast,
      child: Column(
        key: ValueKey(poster.id),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Eyebrow: first tag.
          if (poster.tags.isNotEmpty) ...[
            Text(
              poster.tags.first.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
                letterSpacing: 2.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
          ],
          // Title.
          Text(
            poster.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
          ),
          // Year.
          if (poster.year != null) ...[
            const SizedBox(height: 6),
            Text(
              '${poster.year}',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ],
          // Director.
          if (poster.director != null) ...[
            const SizedBox(height: 4),
            Text(
              poster.director!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// M: 2-col grid (Spotify style: image + meta below)
// ---------------------------------------------------------------------------

class _MediumGrid extends StatelessWidget {
  const _MediumGrid({
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
    return GridView.builder(
      controller: controller,
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, bottomPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.52,
      ),
      itemCount: items.length + (trailingLoader ? 2 : 0),
      itemBuilder: (context, i) {
        if (i >= items.length) {
          return Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceRaised,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.textMute),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        final poster = items[i];
        return _MediumCard(
          poster: poster,
          isFavorited: favIds.contains(poster.id),
          onToggleFavorite: () => onToggleFavorite(poster),
        );
      },
    );
  }
}

class _MediumCard extends StatelessWidget {
  const _MediumCard({
    required this.poster,
    required this.isFavorited,
    required this.onToggleFavorite,
  });
  final Poster poster;
  final bool isFavorited;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => context.push('/poster/${poster.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster image.
          Expanded(
            child: Hero(
              tag: 'poster-${poster.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: poster.thumbnailUrl ?? poster.posterUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, _) =>
                      const ColoredBox(color: AppTheme.surfaceRaised),
                  errorWidget: (_, _, _) =>
                      const ColoredBox(color: AppTheme.surfaceRaised),
                ),
              ),
            ),
          ),

          // Meta row: title + year/director on left, heart on right.
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        poster.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (poster.year != null) '${poster.year}',
                          if (poster.director != null) poster.director!,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMute,
                        ),
                      ),
                    ],
                  ),
                ),
                // Heart button.
                GestureDetector(
                  onTap: onToggleFavorite,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, top: 2),
                    child: Icon(
                      LucideIcons.heart,
                      size: 18,
                      color: isFavorited
                          ? const Color(0xFFE53935)
                          : AppTheme.textFaint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// S: Spotify-style list rows
// ---------------------------------------------------------------------------

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
            child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.textMute))),
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
    return InkWell(
      onTap: () => context.push('/poster/${poster.id}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              // 56x56 square thumb with r8.
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: CachedNetworkImage(
                    imageUrl: poster.thumbnailUrl ?? poster.posterUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        const ColoredBox(color: AppTheme.surfaceRaised),
                    errorWidget: (_, _, _) =>
                        const ColoredBox(color: AppTheme.surfaceRaised),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(poster.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            )),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (poster.year != null) '${poster.year}',
                        if (poster.director != null) poster.director!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMute,
                          ),
                    ),
                  ],
                ),
              ),
              // Heart icon — right side.
              GestureDetector(
                onTap: onToggleFavorite,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 40,
                  height: 56,
                  child: Center(
                    child: Icon(
                      LucideIcons.heart,
                      size: 16,
                      color: isFavorited
                          ? const Color(0xFFE53935)
                          : AppTheme.textFaint,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
