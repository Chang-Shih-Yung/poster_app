import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/shimmer_placeholder.dart';
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
        error: (e, _) => _ErrorView(message: '載入失敗：$e'),
        data: (work) => work == null
            ? const _ErrorView(message: '找不到這部作品')
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
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        // Header.
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, topInset + 60, 20, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '作品',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textFaint,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  work.displayTitle,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (work.titleEn != null && work.titleEn != work.titleZh) ...[
                  const SizedBox(height: 4),
                  Text(
                    work.titleEn!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.textMute,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
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
            child: _ErrorView(message: '海報載入失敗：$e'),
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
    final theme = Theme.of(context);
    final thumb = poster.thumbnailUrl ?? poster.posterUrl;

    return GestureDetector(
      onTap: () => context.push('/poster/${poster.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: thumb,
              fit: BoxFit.cover,
              placeholder: (_, _) => const ShimmerPlaceholder(),
              errorWidget: (_, _, _) => Container(
                color: AppTheme.surfaceRaised,
                child: Icon(Icons.broken_image, color: AppTheme.textFaint),
              ),
            ),
            // Bottom gradient + label.
            if (poster.posterName != null || poster.region != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 30, 10, 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                  child: Text(
                    poster.posterName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
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
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.textMute,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
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
