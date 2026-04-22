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

    return GestureDetector(
      onTap: () => showAvatarViewer(
        context,
        url: avatar,
        fallbackLetter: letter,
      ),
      child: ClipOval(
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

/// v19: thin shim around AppIconButton — kept under the `_ChromeIconButton`
/// name so the dozen call sites in library_page don't all need touching
/// in the same commit. New code should import AppIconButton directly.
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
    return AppIconButton(
      icon: icon,
      onTap: onTap,
      size: AppIconButtonSize.large,
      color: AppTheme.textMute,
      semanticsLabel: semanticLabel,
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
    // v19: drop the reflective shimmer sweep (was using
    // Shimmer.fromColors with white tiles → read as "iridescent cards"
    // rather than "pending content"). Now just flat muted-surface
    // rectangles in the grid positions — the layout alone tells you
    // content is loading. IG / Threads do exactly this.
    final fill = AppTheme.surfaceRaised;
    return switch (density) {
      BrowseDensity.large => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: fill,
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
              color: fill,
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
                  color: fill,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Container(
                height: 14,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ],
          ),
        ),
    };
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

/// Profile summary row — 72×72 avatar + name + @handle + bio.
/// v19: 編輯檔案 pill moved into this row (right side), so the stats
/// row below is purely numbers.
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
    final emailPrefix = fallbackEmail.contains('@')
        ? fallbackEmail.split('@').first
        : fallbackEmail;
    final name = displayName.isNotEmpty ? displayName : emailPrefix;
    final handle =
        '@${profile?.resolvedHandle(emailFallback: emailPrefix) ?? emailPrefix}';
    final bio = profile?.bio?.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Avatar(profile: profile, size: 72),
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
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                handle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: AppTheme.textFaint,
                ),
              ),
              if (bio != null && bio.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: AppTheme.textMute,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        // 編輯 pill moved up here — sits next to the name. The stats
        // row below now only shows numbers (粉絲 / 追蹤 / 投稿 / 收藏).
        _EditPill(),
      ],
    );
  }
}

/// Segmented sub-tab — text + 2px underline (ink colour) when active.
/// Used for 收藏 / 投稿 split below the filter chrome. Uses
/// `AppTheme.text` so the underline flips to near-black in day mode —
/// previously hardcoded to `Colors.white` which disappeared on the
/// new neutral-white day scaffold.
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
              color: active ? AppTheme.text : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 13,
                color: active ? AppTheme.text : AppTheme.textMute,
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

/// v13 我的 density toggle — currently unused (M/S moved to 探索).
/// Kept in case we want to resurface density switching here later.
// ignore: unused_element
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

/// v18 stats row — 追蹤者 / 追蹤中 / 已通過 + 編輯檔案 pill.
/// Pulls real follower/following counts from user_relationship_stats RPC.
/// 已通過 = approved submissions count (from submissionsProvider).
/// Pure inline typography with thin dividers — no card/box chrome.
class _MeStatsRow extends ConsumerWidget {
  const _MeStatsRow({
    required this.userId,
    required this.favCount,
    required this.subCount,
  });
  final String? userId;
  final int favCount;
  final int subCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    int? followers;
    int? following;
    if (userId != null) {
      final stats =
          ref.watch(userRelationshipStatsProvider(userId!)).asData?.value;
      followers = stats?.followerCount;
      following = stats?.followingCount;
    }
    // v19: 4-stat row, no edit pill (moved up to _MeProfileRow).
    // 已通過 → 投稿; new 收藏 stat shows favourite count. Renaming
    // matches the segmented sub-tabs below so 投稿 reads as one
    // concept across the page.
    return Row(
      children: [
        _Stat(
          n: followers,
          label: '粉絲',
          onTap: () => context.push('/home/collection/followers'),
        ),
        _StatDivider(),
        _Stat(
          n: following,
          label: '追蹤中',
          onTap: () => context.push('/home/collection/following'),
        ),
        _StatDivider(),
        _Stat(
          n: subCount,
          label: '投稿',
          onTap: () => context.push('/me/submissions'),
        ),
        _StatDivider(),
        _Stat(
          n: favCount,
          label: '收藏',
          onTap: () => context.push('/home/collection/favorites'),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.n, required this.label, this.onTap});
  final int? n;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          n == null ? '–' : '$n',
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10,
            color: AppTheme.textFaint,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
    if (onTap == null) return inner;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      behavior: HitTestBehavior.opaque,
      child: inner,
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: AppTheme.line1,
    );
  }
}

class _EditPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppButton.outline(
      label: '編輯檔案',
      size: AppButtonSize.small,
      onPressed: () => context.push('/profile/edit'),
    );
  }
}
