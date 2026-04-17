part of 'library_page.dart';

// ---------------------------------------------------------------------------
// Chrome widgets
// ---------------------------------------------------------------------------

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, this.size = 32});
  final AppUser? profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatar = profile?.avatarUrl;
    final name = profile?.displayName.trim() ?? '';
    final letter = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: avatar != null
            ? CachedNetworkImage(
                imageUrl: avatar,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) =>
                    _AvatarFallback(letter: letter, size: size),
              )
            : _AvatarFallback(letter: letter, size: size),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.letter, required this.size});
  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: AppTheme.chipBgStrong,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ChromeIconButton extends StatelessWidget {
  const _ChromeIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Icon(icon, size: 22, color: AppTheme.textMute),
          ),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.motionFast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppTheme.chipBgStrong : AppTheme.chipBg,
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.14), width: 0.5)
              : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? Colors.white : AppTheme.textMute,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                height: 1.3,
              ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton / Empty states
// ---------------------------------------------------------------------------

class LibraryDensitySkeleton extends StatelessWidget {
  const LibraryDensitySkeleton({super.key, required this.density});
  final BrowseDensity density;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceRaised,
      highlightColor: AppTheme.chipBgStrong,
      child: switch (density) {
        BrowseDensity.large => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        BrowseDensity.medium => GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.64,
            ),
            itemCount: 6,
            itemBuilder: (_, _) => Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        BrowseDensity.small => ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            itemCount: 8,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, _) => Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ],
            ),
          ),
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.film, size: 36, color: AppTheme.textFaint),
            const SizedBox(height: 14),
            Text('目前沒有符合條件的海報',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('試試調整搜尋或清除篩選',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _EmptyFavoritesState extends StatelessWidget {
  const _EmptyFavoritesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.heartCrack,
                size: 36, color: AppTheme.textFaint),
            const SizedBox(height: 14),
            Text('還沒有收藏的海報',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('長按海報即可加入收藏',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMute,
                    )),
          ],
        ),
      ),
    );
  }
}
