import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_notifier.dart';
import '../../core/widgets/shimmer_placeholder.dart';
import '../../data/models/poster.dart';
import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/favorite_repository.dart';
import '../../data/repositories/follow_repository.dart';
import '../../data/repositories/social_repository.dart';
import '../shell/app_shell.dart';

/// Destinations opened from the IG-style home drawer + the 我的
/// stats row.
///   · favorites → flat 2-col grid of posters the viewer has favorited
///   · forYou    → flat 2-col grid driven by `for_you_feed_v1`
///   · following → list of accounts the viewer follows
///   · followers → list of accounts that follow the viewer
enum HomeCollectionMode { favorites, forYou, following, followers }

HomeCollectionMode parseHomeCollectionMode(String s) {
  switch (s) {
    case 'favorites':
      return HomeCollectionMode.favorites;
    case 'for-you':
    case 'for_you':
      return HomeCollectionMode.forYou;
    case 'following':
      return HomeCollectionMode.following;
    case 'followers':
      return HomeCollectionMode.followers;
    default:
      return HomeCollectionMode.forYou;
  }
}

final _followingListProvider =
    FutureProvider.autoDispose<List<FollowedProfile>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(followRepositoryProvider).listFollowing(user.id);
});

final _followersListProvider =
    FutureProvider.autoDispose<List<FollowedProfile>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(followRepositoryProvider).listFollowers(user.id);
});

final _favoritesListProvider =
    FutureProvider.autoDispose<List<Poster>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref
      .watch(favoriteRepositoryProvider)
      .listWithPosters(user.id, offset: 0, limit: 100);
});

/// 為你推薦 flat grid — shares the exact same RPC the search page's
/// 為你推薦 landing grid uses, so the two pages always surface matching
/// recommendations.
final _forYouListProvider =
    FutureProvider.autoDispose<List<Poster>>((ref) async {
  return ref.watch(socialRepositoryProvider).forYouFeedV1(limit: 60);
});

class HomeCollectionPage extends ConsumerWidget {
  const HomeCollectionPage({super.key, required this.mode});
  final HomeCollectionMode mode;

  String get _title => switch (mode) {
        HomeCollectionMode.favorites => '收藏',
        HomeCollectionMode.forYou => '為你推薦',
        HomeCollectionMode.following => '追蹤中',
        HomeCollectionMode.followers => '粉絲',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild when the user toggles day/night so AppTheme.* getters
    // get re-evaluated. Without this watch the page is cached by
    // the Navigator and the scaffold's bg lags a frame behind.
    ref.watch(themeModeProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      
      body: Column(
        children: [
          // Top bar — chevron-back + centred title. v18: all push
          // screens use `<` (chevronLeft). The left-edge swipe-back
          // gesture comes from CupertinoPageRoute.
          Padding(
            padding: EdgeInsets.fromLTRB(4, topInset + 8, 16, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(LucideIcons.chevronLeft,
                        size: 24, color: AppTheme.text),
                  ),
                ),
                Text(
                  _title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                const SizedBox(width: 44),
              ],
            ),
          ),
          Expanded(
            child: switch (mode) {
              HomeCollectionMode.favorites => _PosterGrid(
                  providerRef: _favoritesListProvider,
                  empty: const _EmptyState(
                    icon: LucideIcons.heart,
                    title: '存下你的第一張',
                    hint: '在探索頁長按任何一張海報就能加入收藏。',
                    ctaLabel: '去探索',
                    ctaTab: 0,
                  ),
                ),
              HomeCollectionMode.forYou => _PosterGrid(
                  providerRef: _forYouListProvider,
                  empty: const _EmptyState(
                    icon: LucideIcons.sparkles,
                    title: '還沒有推薦',
                    hint: '收藏幾張你喜歡的，我們再配對給你。',
                    ctaLabel: '去探索',
                    ctaTab: 0,
                  ),
                ),
              HomeCollectionMode.following => _FollowingList(
                  provider: _followingListProvider,
                  empty: const _EmptyState(
                    icon: LucideIcons.users,
                    title: '還沒關注誰',
                    hint: '到首頁的活躍收藏家看看，跟上口味接近的人。',
                    ctaLabel: '去探索',
                    ctaTab: 0,
                  ),
                ),
              HomeCollectionMode.followers => _FollowingList(
                  provider: _followersListProvider,
                  empty: const _EmptyState(
                    icon: LucideIcons.userPlus,
                    title: '還沒有人收到你的收藏',
                    hint: '多寄幾張投稿，讓別人更容易找到你。',
                    ctaLabel: '寄出第一張',
                    ctaRoute: '/upload',
                  ),
                ),
            },
          ),
        ],
      ),
    );
  }
}

class _PosterGrid extends ConsumerWidget {
  const _PosterGrid({required this.providerRef, required this.empty});
  final FutureProvider<List<Poster>> providerRef;
  final _EmptyState empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(providerRef);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return async.when(
      loading: () => const _GridSkeleton(),
      error: (e, _) => _ErrorState(
        message: '載入失敗',
        detail: '$e',
        onRetry: () => ref.invalidate(providerRef),
      ),
      data: (items) {
        if (items.isEmpty) return empty;
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(14, 4, 14, bottomInset + 40),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2 / 3,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _PosterTile(poster: items[i]),
        );
      },
    );
  }
}

/// Flat 2-col grid skeleton shown while the posters are loading.
/// Six muted 2:3 tiles feel like content is incoming, not broken.
class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2 / 3,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Shared empty state for home collection pages. Icon + title + hint
/// + optional primary CTA. Matches the kit voice
/// (`存下你的第一張`, `寄出投稿` — active verbs, no generic
/// "you have no items").
class _EmptyState extends ConsumerWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.hint,
    this.ctaLabel,
    this.ctaTab,
    this.ctaRoute,
  });
  final IconData icon;
  final String title;
  final String hint;
  final String? ctaLabel;

  /// If set, the CTA pops this page and switches the shell to this
  /// tab index. Used for "go back to explore" style actions.
  final int? ctaTab;

  /// If set, the CTA pushes this route. Used when the action lives
  /// on a dedicated sub-page (e.g. /upload).
  final String? ctaRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: AppTheme.textFaint),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMute,
                  ),
            ),
            if (ctaLabel != null) ...[
              const SizedBox(height: 18),
              _EmptyCtaPill(
                label: ctaLabel!,
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (ctaRoute != null) {
                    context.push(ctaRoute!);
                  } else if (ctaTab != null) {
                    // Pop back to the shell, then switch tabs.
                    ref.read(shellTabProvider.notifier).setIndex(ctaTab!);
                    Navigator.of(context).maybePop();
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyCtaPill extends StatelessWidget {
  const _EmptyCtaPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.text,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.bg,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0,
                ),
          ),
        ),
      ),
    );
  }
}

/// Retry-able error state. Presents a short reason + action over the
/// raw exception, so users don't stare at an SDK stacktrace.
class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.detail,
    required this.onRetry,
  });
  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.cloudOff, size: 32, color: AppTheme.textFaint),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textFaint,
                  ),
            ),
            const SizedBox(height: 18),
            _EmptyCtaPill(label: '重試', onTap: onRetry),
          ],
        ),
      ),
    );
  }
}

class _PosterTile extends StatelessWidget {
  const _PosterTile({required this.poster});
  final Poster poster;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/poster/${poster.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: poster.thumbnailUrl ?? poster.posterUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => const ShimmerPlaceholder(),
              errorWidget: (_, _, _) =>
                  ColoredBox(color: AppTheme.surfaceRaised),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 16, 10, 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xB3000000)],
                  ),
                ),
                child: Text(
                  poster.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowingList extends ConsumerWidget {
  const _FollowingList({required this.provider, required this.empty});
  final FutureProvider<List<FollowedProfile>> provider;
  final _EmptyState empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return async.when(
      loading: () => Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppTheme.textMute),
        ),
      ),
      error: (e, _) => _ErrorState(
        message: '載入失敗',
        detail: '$e',
        onRetry: () => ref.invalidate(provider),
      ),
      data: (users) {
        if (users.isEmpty) return empty;
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(0, 4, 0, bottomInset + 40),
          itemCount: users.length,
          separatorBuilder: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(height: 1, color: AppTheme.line1),
          ),
          itemBuilder: (_, i) => _UserRow(profile: users[i]),
        );
      },
    );
  }
}

/// Bare IG-style user row — no card chrome, just avatar + name/bio +
/// chevron, with hairline dividers between rows (owned by the parent
/// list). Tap opens the user's public profile.
class _UserRow extends StatelessWidget {
  const _UserRow({required this.profile});
  final FollowedProfile profile;

  @override
  Widget build(BuildContext context) {
    final letter = profile.displayName.isNotEmpty
        ? profile.displayName.characters.first.toUpperCase()
        : '?';
    return InkWell(
      onTap: () => context.push('/user/${profile.userId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 48,
                height: 48,
                child: (profile.avatarUrl != null &&
                        profile.avatarUrl!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: profile.avatarUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            _fallback(context, letter),
                      )
                    : _fallback(context, letter),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName.isEmpty
                        ? '無名使用者'
                        : profile.displayName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (profile.bio?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      profile.bio!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMute,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight,
                size: 16, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context, String letter) {
    return Container(
      color: AppTheme.chipBgStrong,
      alignment: Alignment.center,
      child: Text(letter,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              )),
    );
  }
}
