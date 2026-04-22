import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/shimmer_placeholder.dart';
import '../../data/models/poster.dart';
import '../../data/models/social.dart';
import '../../data/repositories/follow_repository.dart';
import '../../data/repositories/poster_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'follow_pill.dart';

/// Lists approved posters for a user. Uses a DB-indexed query on uploader_id
/// (O(log N) via index) instead of paging all posters client-side.
final _postersByUploaderProvider = FutureProvider.autoDispose
    .family<List<Poster>, String>((ref, uploaderId) async {
  return ref.watch(posterRepositoryProvider).listByUploader(uploaderId);
});

/// /user/:id — public profile.
class PublicProfilePage extends ConsumerWidget {
  const PublicProfilePage({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(publicProfileProvider(userId));
    final postersAsync = ref.watch(_postersByUploaderProvider(userId));

    return Scaffold(
      
      body: profileAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => _Err(message: '載入失敗：$e'),
        data: (p) => p == null
            ? const _Err(message: '這位使用者的個人檔案為私密或不存在')
            : _ProfileBody(profile: p, postersAsync: postersAsync),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile, required this.postersAsync});
  final PublicProfile profile;
  final AsyncValue<List<Poster>> postersAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final theme = Theme.of(context);
    final statsAsync = ref.watch(userRelationshipStatsProvider(profile.id));
    final stats = statsAsync.asData?.value;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, topInset + 60, 20, 20),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _Avatar(url: profile.avatarUrl),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.displayName.isEmpty
                                ? '無名使用者'
                                : profile.displayName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (stats?.isFollowingMe == true) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.chipBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '追蹤你',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppTheme.textMute,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    FollowPill(targetUserId: profile.id),
                  ],
                ),
                // Stats row — 4 numbers: followers, following, approved, submissions.
                const SizedBox(height: 14),
                _StatsRow(profile: profile, stats: stats),
                if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    profile.bio!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppTheme.textMute),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  '這位使用者上傳的海報',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textFaint,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        postersAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (e, _) =>
              SliverToBoxAdapter(child: _Err(message: '海報載入失敗：$e')),
          data: (posters) {
            if (posters.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Text(
                    '尚未有通過的海報',
                    style: TextStyle(color: AppTheme.textFaint),
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 32),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.66,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _PosterCell(poster: posters[i]),
                  childCount: posters.length,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    if (url == null || url!.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.surfaceRaised,
          shape: BoxShape.circle,
        ),
        child: Icon(LucideIcons.user, color: AppTheme.textFaint),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => Container(
          width: size,
          height: size,
          color: AppTheme.surfaceRaised,
          child: Icon(LucideIcons.user, color: AppTheme.textFaint),
        ),
      ),
    );
  }
}

class _PosterCell extends StatelessWidget {
  const _PosterCell({required this.poster});
  final Poster poster;

  @override
  Widget build(BuildContext context) {
    final thumb = poster.thumbnailUrl ?? poster.posterUrl;
    return GestureDetector(
      onTap: () => context.push('/poster/${poster.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: thumb,
          fit: BoxFit.cover,
          placeholder: (_, _) => const ShimmerPlaceholder(),
          errorWidget: (_, _, _) => Container(color: AppTheme.surfaceRaised),
        ),
      ),
    );
  }
}

class _Err extends StatelessWidget {
  const _Err({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: TextStyle(color: AppTheme.textMute),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Stats row: follower · following · approved · submissions.
/// Renders even before stats load — shows approved/submissions from profile.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.profile, this.stats});
  final PublicProfile profile;
  final UserRelationshipStats? stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget stat(String n, String label) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: AppTheme.textFaint)),
          ],
        );

    return Row(
      children: [
        stat('${stats?.followerCount ?? "—"}', '粉絲'),
        const SizedBox(width: 24),
        stat('${stats?.followingCount ?? "—"}', '追蹤中'),
        const SizedBox(width: 24),
        stat('${profile.approvedPosterCount}', '已通過'),
        const SizedBox(width: 24),
        stat('${profile.submissionCount}', '投稿'),
      ],
    );
  }
}
