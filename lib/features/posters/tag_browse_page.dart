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
                      const AppText.label('#', tone: AppTextTone.faint),
                      const SizedBox(height: 4),
                      AppText.headline(tag.labelZh),
                      if (tag.labelEn != tag.labelZh)
                        AppText.title(tag.labelEn,
                            tone: AppTextTone.muted),
                      const SizedBox(height: 10),
                      AppText.caption(
                        '${result.posters.length} 張海報',
                        tone: AppTextTone.faint,
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
      fullImageUrl: poster.posterUrl,
      blurhash: poster.blurhash,
      posterId: poster.id,
      showOverlayText: false,
    );
  }
}
