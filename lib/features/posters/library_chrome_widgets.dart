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

// ignore: unused_element
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

// ───────────────────────────────────────────────────────────────────────
// v13 Me-tab chrome widgets
// ───────────────────────────────────────────────────────────────────────

/// Profile summary row inside the chrome — 64×64 avatar + name + bio +
/// 編輯 pill. Tap 編輯 → /profile/edit (handled inline since the chrome
/// is a stateless region).
class _MeProfileRow extends StatelessWidget {
  const _MeProfileRow({
    required this.profile,
    required this.fallbackEmail,
  });
  final AppUser? profile;
  final String fallbackEmail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = profile?.displayName.trim() ?? '';
    final name = displayName.isNotEmpty
        ? displayName
        : fallbackEmail.split('@').first;
    final bio = profile?.bio?.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Avatar(profile: profile, size: 64),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                bio?.isNotEmpty == true ? bio! : fallbackEmail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: AppTheme.textMute,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: AppTheme.chipBg,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/profile/edit');
            },
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.line2),
              ),
              alignment: Alignment.center,
              child: Text(
                '編輯',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Segmented sub-tab — text + 2px white underline when active. Used
/// for 收藏 / 投稿 split below the filter chrome.
class _SegTab extends StatelessWidget {
  const _SegTab({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 13,
                color: active ? Colors.white : AppTheme.textMute,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0,
              ),
        ),
      ),
    );
  }
}

/// L/M/S density toggle — kept around in case we resurface density
/// switching later; not currently rendered (我的 is masonry-only).
// ignore: unused_element
class _DensityToggle extends StatelessWidget {
  const _DensityToggle({
    required this.current,
    required this.onChange,
  });
  final BrowseDensity current;
  final ValueChanged<BrowseDensity> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final d in BrowseDensity.values)
            GestureDetector(
              onTap: () => onChange(d),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: AppTheme.motionFast,
                width: 28,
                height: 24,
                decoration: BoxDecoration(
                  color: current == d
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(
                  child: Icon(
                    d.icon,
                    size: 14,
                    color: current == d ? Colors.white : AppTheme.textMute,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// v13 我的 density toggle — only M (masonry) and S (list). L has no
/// place on a personal page where each card needs its metadata around
/// it. Lives in the title row alongside ＋ and ☰.
class _MeDensityToggle extends StatelessWidget {
  const _MeDensityToggle({
    required this.current,
    required this.onChange,
  });
  final BrowseDensity current;
  final ValueChanged<BrowseDensity> onChange;

  @override
  Widget build(BuildContext context) {
    const opts = <BrowseDensity>[BrowseDensity.medium, BrowseDensity.small];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final d in opts)
            Semantics(
              label: d == BrowseDensity.medium ? '網格檢視' : '列表檢視',
              button: true,
              selected: current == d,
              child: GestureDetector(
                onTap: () => onChange(d),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: AppTheme.motionFast,
                  width: 30,
                  height: 26,
                  decoration: BoxDecoration(
                    color: current == d
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Icon(
                      d.icon,
                      size: 14,
                      color: current == d ? Colors.white : AppTheme.textMute,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
