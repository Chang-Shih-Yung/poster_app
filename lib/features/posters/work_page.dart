import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/ds/ds.dart';
import '../../data/models/poster.dart';
import '../../data/models/work.dart';
import '../../data/repositories/poster_repository.dart';
import '../../data/repositories/work_repository.dart';

/// /work/:id — one movie, all its posters.
/// Header shows titleZh + titleEn + year + poster count.
/// Body is a 2-column grid of posters, tappable to /poster/:id.
class WorkPage extends ConsumerWidget {
  const WorkPage({super.key, required this.workId});
  final String workId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workAsync = ref.watch(workByIdProvider(workId));
    final postersAsync = ref.watch(postersByWorkIdProvider(workId));

    return Scaffold(
      
      body: workAsync.when(
        loading: () => const AppLoader.centered(),
        error: (e, _) => AppEmptyState(title: '載入失敗：$e'),
        data: (work) => work == null
            ? const AppEmptyState(title: '找不到這部作品')
            : _WorkBody(work: work, postersAsync: postersAsync),
      ),
    );
  }
}

class _WorkBody extends StatelessWidget {
  const _WorkBody({required this.work, required this.postersAsync});
  final Work work;
  final AsyncValue<List<Poster>> postersAsync;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CustomScrollView(
      slivers: [
        // Header.
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, topInset + 60, 20, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText.label('作品', tone: AppTextTone.faint),
                const SizedBox(height: 8),
                AppText.headline(work.displayTitle),
                if (work.titleEn != null && work.titleEn != work.titleZh) ...[
                  const SizedBox(height: 4),
                  AppText.title(work.titleEn!, tone: AppTextTone.muted),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (work.movieReleaseYear != null) ...[
                      _MetaPill(label: '${work.movieReleaseYear}'),
                      const SizedBox(width: 8),
                    ],
                    _MetaPill(label: '${work.posterCount} 張海報'),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Poster grid.
        postersAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: AppLoader.centered(),
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: AppEmptyState(title: '海報載入失敗：$e'),
          ),
          data: (posters) {
            if (posters.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      '這部作品還沒有海報',
                      style: TextStyle(color: AppTheme.textMute),
                    ),
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 32),
              sliver: SliverGrid(
                // Responsive: each cell ~180 wide → 2 cols on phone,
                // 4-6 on desktop. Avoids the 2-col-stretched-forever look
                // that Flutter's fixed count produces on wide viewports.
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

class _PosterCell extends StatelessWidget {
  const _PosterCell({required this.poster});
  final Poster poster;

  @override
  Widget build(BuildContext context) {
    // Work page cells usually show posterName (e.g. "IMAX 限定版")
    // rather than full title — same tile contract though.
    return AppPosterTile(
      imageUrl: poster.thumbnailUrl ?? poster.posterUrl,
      fullImageUrl: poster.posterUrl,
      blurhash: poster.blurhash,
      posterId: poster.id,
      title: poster.posterName,
      showOverlayText: poster.posterName != null,
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.chipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: AppText.small(
        label,
        tone: AppTextTone.muted,
        weight: FontWeight.w500,
      ),
    );
  }
}

