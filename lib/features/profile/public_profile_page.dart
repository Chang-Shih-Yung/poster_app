import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/ds/ds.dart';
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
        loading: () => const AppLoader.centered(),
        error: (e, _) => AppEmptyState(title: '載入失敗：$e'),
        data: (p) => p == null
            ? const AppEmptyState(title: '這位使用者的個人檔案為私密或不存在')
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
                    AppAvatar(
                      url: profile.avatarUrl,
                      name: profile.displayName,
                      customSize: 64,
                      onTap: () => showAvatarViewer(
                        context,
                        url: profile.avatarUrl,
                        fallbackLetter: profile.displayName.isNotEmpty
                            ? profile.displayName.characters.first
                                .toUpperCase()
                            : '?',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText.title(
                            profile.displayName.isEmpty
                                ? '無名使用者'
                                : profile.displayName,
                          ),
                          if (stats?.isFollowingMe == true) ...[
                            const SizedBox(height: 4),
                            const AppBadge(label: '追蹤你'),
                          ],
                        ],
                      ),
                    ),
                    FollowPill(targetUserId: profile.id),
                    const SizedBox(width: 4),
                    // v19: report-avatar entry. Tap → ActionSheet
                    // with "檢舉頭像" + cancel. Free hybrid moderation
                    // — three reports auto-flag the avatar to admin
                    // queue (see avatar_moderation migration).
                    AppIconButton(
                      icon: LucideIcons.ellipsis,
                      size: AppIconButtonSize.small,
                      color: AppTheme.textMute,
                      semanticsLabel: '更多',
                      onTap: () => _openReportSheet(
                        context,
                        ref,
                        profile.id,
                        profile.displayName,
                        alreadyReported: profile.viewerReported,
                      ),
                    ),
                  ],
                ),
                // Stats row — 4 numbers: followers, following, approved, submissions.
                const SizedBox(height: 14),
                _StatsRow(profile: profile, stats: stats),
                if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  AppText.body(profile.bio!, tone: AppTextTone.muted),
                ],
                const SizedBox(height: 24),
                const AppText.label('這位使用者上傳的海報',
                    tone: AppTextTone.faint),
              ],
            ),
          ),
        ),

        // v19 round 10: private-account privacy gate. When the target
        // is_public=false and the viewer hasn't been accepted as a
        // follower, the posters grid is replaced with a "僅限追蹤者
        // 查看" placeholder — the header still renders so the viewer
        // can tap 追蹤 on a private profile and see the request UI.
        if (!profile.viewerCanSeeContent)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.r4),
                  border: Border.all(color: AppTheme.line1, width: 0.5),
                ),
                child: Column(
                  children: [
                    Icon(LucideIcons.lock,
                        size: 28, color: AppTheme.textFaint),
                    const SizedBox(height: 12),
                    const AppText.bodyBold('這是私人帳號',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    const AppText.caption(
                      '追蹤後才能看到這位使用者的收藏與投稿',
                      tone: AppTextTone.muted,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          postersAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: AppLoader.centered(),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
                child: AppEmptyState(title: '海報載入失敗：$e')),
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

/// Open the "..." options sheet for a public profile. Right now only
/// "檢舉頭像" — extend with mute / block when those land.
Future<void> _openReportSheet(
  BuildContext context,
  WidgetRef ref,
  String targetUserId,
  String targetName, {
  bool alreadyReported = false,
}) async {
  HapticFeedback.selectionClick();
  await AppSheet.show<void>(
    context,
    child: ListTile(
      leading: Icon(LucideIcons.flag,
          color: alreadyReported
              ? AppTheme.textFaint
              : AppTheme.favoriteActive,
          size: 20),
      title: AppText.body(
        alreadyReported ? '已檢舉頭像' : '檢舉頭像',
        color: alreadyReported
            ? AppTheme.textFaint
            : AppTheme.favoriteActive,
        weight: FontWeight.w600,
      ),
      // Disable the action when the viewer has already reported this
      // target. Sheet still renders the row so the user sees the
      // "done" state instead of the option silently disappearing.
      enabled: !alreadyReported,
      onTap: () async {
        Navigator.of(context).pop();
        try {
          await ref.read(userRepositoryProvider).reportAvatar(targetUserId);
          // Refetch the public profile so the `viewer_reported` flag
          // flips to true and a subsequent re-open shows the grey
          // "已檢舉頭像" row.
          ref.invalidate(publicProfileProvider(targetUserId));
          if (context.mounted) {
            AppToast.show(context, '已檢舉「$targetName」的頭像');
          }
        } catch (e) {
          if (context.mounted) {
            AppToast.show(context, '檢舉失敗：$e',
                kind: AppToastKind.destructive);
          }
        }
      },
    ),
  );
}

// _Avatar deleted in v19 — replaced by the shared AppAvatar primitive.

class _PosterCell extends StatelessWidget {
  const _PosterCell({required this.poster});
  final Poster poster;

  @override
  Widget build(BuildContext context) {
    return AppPosterTile(
      imageUrl: poster.thumbnailUrl ?? poster.posterUrl,
      fullImageUrl: poster.posterUrl,
      blurhash: poster.blurhash,
      posterId: poster.id,
      showOverlayText: false,
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
    Widget stat(String n, String label) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText.title(n),
            AppText.small(label, tone: AppTextTone.faint),
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
