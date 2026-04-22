import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/ds/ds.dart';
import '../../data/models/poster.dart';
import '../../data/repositories/tag_repository.dart';

/// /tags/:slug — browse all approved posters tagged with a specific tag.
/// Reached from tag chips on poster detail, search results, and (future)
/// home page faceted entries.
class TagBrowsePage extends ConsumerWidget {
  const TagBrowsePage({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final theme = Theme.of(context);
    final async = ref.watch(browseByTagProvider(slug));

    return Scaffold(
      
      body: async.when(
        loading: () => const AppLoader.centered(),
        error: (e, _) => Center(
          child: Text('載入失敗：$e',
              style: TextStyle(color: AppTheme.textMute)),
        ),
        data: (result) {
          if (result.tag == null) {
            return Center(
              child: Text('找不到這個 tag',
                  style: TextStyle(color: AppTheme.textMute)),
            );
          }
          final tag = result.tag!;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, topInset + 60, 20, 20),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.textFaint,
                          letterSpacing: 2.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tag.labelZh,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (tag.labelEn != tag.labelZh)
                        Text(
                          tag.labelEn,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppTheme.textMute,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        '${result.posters.length} 張海報',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppTheme.textFaint),
                      ),
                    ],
                  ),
                ),
              ),
              if (result.posters.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text('這個分類目前沒有海報',
                        style: TextStyle(color: AppTheme.textFaint)),
                  ),
                )
              else
                SliverPadding(
                  padding:
                      EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 32),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.66,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) =>
                          _PosterCell(poster: result.posters[i]),
                      childCount: result.posters.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PosterCell extends StatelessWidget {
  const _PosterCell({required this.poster});
  final Poster poster;

  @override
  Widget build(BuildContext context) {
    return AppPosterTile(
      imageUrl: poster.thumbnailUrl ?? poster.posterUrl,
      posterId: poster.id,
      showOverlayText: false,
    );
  }
}
