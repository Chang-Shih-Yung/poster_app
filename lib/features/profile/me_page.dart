import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass.dart';
import '../../data/models/app_user.dart';
import '../../data/models/poster.dart';
import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/favorite_repository.dart';
import '../../data/repositories/poster_repository.dart';

/// v13 Me tab — direct port of prototype `MeScreen`.
///
/// Layout:
///   ┌──────────────────────────────────┐
///   │ 我的                       [⚙]   │  title row with settings glass btn
///   ├──────────────────────────────────┤
///   │ ⊙   Yuki Lin                [編輯]│  64×64 avatar + name/bio + edit pill
///   │     bio line up to two lines      │
///   ├──────────────────────────────────┤
///   │       收藏 N    │   投稿 N        │  segmented tabs, 2px white underline
///   ╞════════════════════════════════════╡
///   │  [masonry of selected tab's posters]
///   └──────────────────────────────────┘
///
/// Settings icon → /profile (account/admin/logout).
/// 編輯 pill → /profile/edit.
class MePage extends ConsumerStatefulWidget {
  const MePage({super.key});

  @override
  ConsumerState<MePage> createState() => _MePageState();
}

enum _MeTab { favorites, submissions }

class _MePageState extends ConsumerState<MePage> {
  _MeTab _tab = _MeTab.favorites;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.asData?.value;
    final favIds = ref.watch(favoriteIdsProvider).asData?.value ?? const {};

    if (user == null) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(
          child: Text('請先登入', style: TextStyle(color: AppTheme.textMute)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        slivers: [
          // Title row + settings.
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 8),
              child: Row(
                children: [
                  Text('我的',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          )),
                  const Spacer(),
                  GlassButton(
                    icon: LucideIcons.settings,
                    size: 34,
                    color: Colors.white.withValues(alpha: 0.85),
                    semanticsLabel: '設定',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.push('/profile');
                    },
                  ),
                ],
              ),
            ),
          ),
          // Identity row.
          SliverToBoxAdapter(
            child: _IdentityRow(
              email: user.email ?? '',
              profile: profile,
              onEdit: () => context.push('/profile/edit'),
            ),
          ),
          // Segmented tabs (sticky).
          SliverPersistentHeader(
            pinned: true,
            delegate: _SegmentedHeader(
              tab: _tab,
              favCount: favIds.length,
              onChange: (t) {
                HapticFeedback.selectionClick();
                setState(() => _tab = t);
              },
            ),
          ),
          // Content: favorites masonry OR submissions masonry.
          if (_tab == _MeTab.favorites)
            _FavoritesMasonrySliver(favIds: favIds)
          else
            _SubmissionsMasonrySliver(uploaderId: user.id),
          // Bottom safe area + clear of floating tab bar.
          SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Identity row
// ───────────────────────────────────────────────────────────────────────

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({
    required this.email,
    required this.profile,
    required this.onEdit,
  });
  final String email;
  final AppUser? profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = profile?.displayName.trim() ?? '';
    final name = displayName.isNotEmpty ? displayName : email.split('@').first;
    final avatar = profile?.avatarUrl;
    final bio = profile?.bio?.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.line2),
            ),
            child: ClipOval(
              child: avatar != null
                  ? CachedNetworkImage(
                      imageUrl: avatar,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _AvatarFallback(name: name),
                    )
                  : _AvatarFallback(name: name),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  bio?.isNotEmpty == true ? bio! : email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMute,
                    fontSize: 11,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // 編輯 pill — exact prototype spec.
          Material(
            color: AppTheme.chipBg,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onEdit();
              },
              borderRadius: BorderRadius.circular(999),
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
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return Container(
      color: AppTheme.chipBgStrong,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Segmented tabs (sticky pinned header)
// ───────────────────────────────────────────────────────────────────────

class _SegmentedHeader extends SliverPersistentHeaderDelegate {
  _SegmentedHeader({
    required this.tab,
    required this.favCount,
    required this.onChange,
  });
  final _MeTab tab;
  final int favCount;
  final void Function(_MeTab) onChange;

  static const double _h = 48;

  @override
  double get minExtent => _h;
  @override
  double get maxExtent => _h;

  @override
  Widget build(BuildContext ctx, double shrink, bool overlaps) {
    return Container(
      color: AppTheme.bg,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        border: Border(bottom: BorderSide(color: AppTheme.line1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Seg(
              label: '收藏 $favCount',
              active: tab == _MeTab.favorites,
              onTap: () => onChange(_MeTab.favorites),
            ),
          ),
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final user = ref.watch(currentUserProvider);
                if (user == null) {
                  return _Seg(
                    label: '投稿 0',
                    active: tab == _MeTab.submissions,
                    onTap: () => onChange(_MeTab.submissions),
                  );
                }
                final countAsync = ref.watch(_myUploaderPostersProvider(user.id));
                final n = countAsync.asData?.value.length ?? 0;
                return _Seg(
                  label: '投稿 $n',
                  active: tab == _MeTab.submissions,
                  onTap: () => onChange(_MeTab.submissions),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SegmentedHeader old) =>
      old.tab != tab || old.favCount != favCount;
}

class _Seg extends StatelessWidget {
  const _Seg({
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
        padding: const EdgeInsets.symmetric(vertical: 12),
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

// ───────────────────────────────────────────────────────────────────────
// Masonry slivers for each segmented tab
// ───────────────────────────────────────────────────────────────────────

/// User's favorited posters (full Poster objects via a join in Favorite
/// model — the favoritesProvider already returns Favorite objects which
/// embed the poster).
final _favoritePostersProvider =
    FutureProvider.autoDispose<List<Poster>>((ref) async {
  final favs = await ref.watch(favoritesProvider.future);
  // Favorite objects already carry poster snapshots — we hydrate by
  // fetching full posters by id (so view_count etc. are fresh).
  if (favs.isEmpty) return const [];
  final repo = ref.watch(posterRepositoryProvider);
  final futures = favs.map((f) => repo.getById(f.posterId));
  final posters = await Future.wait(futures);
  return posters.whereType<Poster>().toList(growable: false);
});

/// Posters where the current user is the uploader (uploads that got
/// approved into posters table).
final _myUploaderPostersProvider =
    FutureProvider.autoDispose.family<List<Poster>, String>(
        (ref, uid) async {
  return ref.watch(posterRepositoryProvider).listByUploader(uid);
});

class _FavoritesMasonrySliver extends ConsumerWidget {
  const _FavoritesMasonrySliver({required this.favIds});
  final Set<String> favIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_favoritePostersProvider);
    return async.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Center(
            child: Text('載入失敗：$e',
                style: TextStyle(color: AppTheme.textMute)),
          ),
        ),
      ),
      data: (posters) {
        if (posters.isEmpty) {
          return const SliverToBoxAdapter(child: _EmptyMe(message: '還沒有收藏，去圖庫挑一張吧'));
        }
        return _MasonrySliver(posters: posters, favIds: favIds);
      },
    );
  }
}

class _SubmissionsMasonrySliver extends ConsumerWidget {
  const _SubmissionsMasonrySliver({required this.uploaderId});
  final String uploaderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myUploaderPostersProvider(uploaderId));
    final favIds =
        ref.watch(favoriteIdsProvider).asData?.value ?? const <String>{};
    return async.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Center(
            child: Text('載入失敗：$e',
                style: TextStyle(color: AppTheme.textMute)),
          ),
        ),
      ),
      data: (posters) {
        if (posters.isEmpty) {
          return const SliverToBoxAdapter(
              child: _EmptyMe(message: '還沒有投稿，按右上 + 上傳第一張'));
        }
        return _MasonrySliver(posters: posters, favIds: favIds);
      },
    );
  }
}

class _EmptyMe extends StatelessWidget {
  const _EmptyMe({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textFaint, fontSize: 13),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Local masonry — same algorithm as library's M mode but as a sliver.
// We keep a small copy here (rather than reuse library_density_views
// which is `part of` the library file) to avoid coupling.
// ───────────────────────────────────────────────────────────────────────

double _ratioForId(String id) {
  const ratios = <double>[0.67, 0.67, 0.75, 1.0, 1.33, 0.56];
  var h = 0;
  for (final r in id.runes) {
    h = (h * 31 + r) & 0x7fffffff;
  }
  return ratios[h % ratios.length];
}

class _MasonrySliver extends StatelessWidget {
  const _MasonrySliver({required this.posters, required this.favIds});
  final List<Poster> posters;
  final Set<String> favIds;

  @override
  Widget build(BuildContext context) {
    // Two-column balanced masonry — assign each poster to whichever
    // column is currently shorter.
    final colA = <Poster>[];
    final colB = <Poster>[];
    var hA = 0.0;
    var hB = 0.0;
    for (final p in posters) {
      final h = 1 / _ratioForId(p.id);
      if (hA <= hB) {
        colA.add(p);
        hA += h + 0.05;
      } else {
        colB.add(p);
        hB += h + 0.05;
      }
    }

    Widget col(List<Poster> items) => Column(
          children: items
              .map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MeMasonryCard(
                      poster: p,
                      isFavorited: favIds.contains(p.id),
                      aspectRatio: _ratioForId(p.id),
                    ),
                  ))
              .toList(),
        );

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      sliver: SliverToBoxAdapter(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: col(colA)),
            const SizedBox(width: 8),
            Expanded(child: col(colB)),
          ],
        ),
      ),
    );
  }
}

class _MeMasonryCard extends ConsumerWidget {
  const _MeMasonryCard({
    required this.poster,
    required this.isFavorited,
    required this.aspectRatio,
  });
  final Poster poster;
  final bool isFavorited;
  final double aspectRatio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.push('/poster/${poster.id}'),
      onLongPress: () async {
        final user = ref.read(currentUserProvider);
        if (user == null) return;
        HapticFeedback.mediumImpact();
        final repo = ref.read(favoriteRepositoryProvider);
        try {
          if (isFavorited) {
            await repo.remove(user.id, poster.id);
          } else {
            await repo.add(user.id, poster);
          }
          ref.invalidate(favoriteIdsProvider);
          ref.invalidate(favoritesProvider);
          ref.invalidate(_favoritePostersProvider);
        } catch (_) {}
      },
      child: Hero(
        tag: 'poster-${poster.id}',
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.ink3,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.line1),
              ),
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
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0xBF000000), Color(0x00000000)],
                            stops: [0, 0.45],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          poster.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            letterSpacing: -0.2,
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
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isFavorited)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(Icons.favorite,
                          size: 16, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
