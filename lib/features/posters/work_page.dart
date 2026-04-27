import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/ds/ds.dart';
import '../../data/models/poster.dart';
import '../../data/models/poster_group.dart';
import '../../data/models/work.dart';
import '../../data/repositories/poster_group_repository.dart';
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

    final groupsAsync = ref.watch(posterGroupsForWorkProvider(workId));

    return Scaffold(

      body: workAsync.when(
        loading: () => const AppLoader.centered(),
        error: (e, _) => AppEmptyState(title: '載入失敗：$e'),
        data: (work) => work == null
            ? const AppEmptyState(title: '找不到這部作品')
            : _WorkBody(
                work: work,
                postersAsync: postersAsync,
                groupsAsync: groupsAsync,
              ),
      ),
    );
  }
}

/// Display labels for work_kind enum. Mirrors admin/lib/enums.ts WORK_KINDS.
const Map<String, String> _kKindLabels = {
  'movie': '電影',
  'concert': '演唱會',
  'theatre': '戲劇',
  'exhibition': '展覽',
  'event': '活動',
  'original_art': '原創作品',
  'advertisement': '商業廣告',
  'other': '其他',
};

class _WorkBody extends StatelessWidget {
  const _WorkBody({
    required this.work,
    required this.postersAsync,
    required this.groupsAsync,
  });
  final Work work;
  final AsyncValue<List<Poster>> postersAsync;
  final AsyncValue<List<PosterGroup>> groupsAsync;

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
                AppText.label(
                  work.studio ?? '作品',
                  tone: AppTextTone.faint,
                ),
                const SizedBox(height: 8),
                AppText.headline(work.displayTitle),
                if (work.titleEn != null && work.titleEn != work.titleZh) ...[
                  const SizedBox(height: 4),
                  AppText.title(work.titleEn!, tone: AppTextTone.muted),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (work.workKind != null)
                      _MetaPill(
                        label: _kKindLabels[work.workKind] ?? work.workKind!,
                      ),
                    if (work.movieReleaseYear != null)
                      _MetaPill(label: '${work.movieReleaseYear}'),
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
            // Section the posters by their parent group's path. Groups
            // come from a separate query — while it's loading we show a
            // flat grid (cheaper than waiting for both); on error we
            // also fall back to flat. This means an isolated group-tree
            // failure never blocks the user from seeing posters.
            final groups = groupsAsync.maybeWhen(
              data: (g) => g,
              orElse: () => const <PosterGroup>[],
            );
            final sections = _buildSections(groups, posters);
            return SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 32),
              sliver: SliverList.builder(
                itemCount: sections.length,
                itemBuilder: (context, i) => _PosterSection(section: sections[i]),
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
    final tile = AppPosterTile(
      imageUrl: poster.thumbnailUrl ?? poster.posterUrl,
      fullImageUrl: poster.posterUrl,
      blurhash: poster.blurhash,
      posterId: poster.id,
      title: poster.posterName,
      showOverlayText: poster.posterName != null,
    );
    if (!poster.isPlaceholder) return tile;
    // Admin hasn't uploaded a real scan yet — overlay a "待補真圖" badge
    // so the user understands why this row looks like a generic silhouette.
    return Stack(
      children: [
        Positioned.fill(child: tile),
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const AppText.small(
              '待補真圖',
              tone: AppTextTone.muted,
              weight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// One pre-order section in the work page: header text (a "/"-joined
/// breadcrumb of group names from work root, or null for ungrouped
/// posters) plus the posters that hang directly off that group.
class _Section {
  const _Section({required this.title, required this.posters});
  final String? title;
  final List<Poster> posters;
}

/// Walk the group tree, emitting one _Section per leaf group whose
/// children are posters. Posters with NULL parent_group_id (legacy v2
/// uploads or rows the admin hasn't filed yet) get their own trailing
/// "(未分類)" section so they remain visible.
List<_Section> _buildSections(List<PosterGroup> groups, List<Poster> posters) {
  if (groups.isEmpty) {
    return [_Section(title: null, posters: posters)];
  }
  final byParent = <String?, List<PosterGroup>>{};
  for (final g in groups) {
    byParent.putIfAbsent(g.parentGroupId, () => []).add(g);
  }
  final postersByGroup = <String, List<Poster>>{};
  final ungrouped = <Poster>[];
  for (final p in posters) {
    final pid = p.parentGroupId;
    if (pid == null) {
      ungrouped.add(p);
    } else {
      postersByGroup.putIfAbsent(pid, () => []).add(p);
    }
  }
  final sections = <_Section>[];
  void walk(String? parentId, List<String> path) {
    final children = byParent[parentId] ?? const [];
    for (final g in children) {
      final newPath = [...path, g.name];
      final hereSorted = (postersByGroup[g.id] ?? const <Poster>[])
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (hereSorted.isNotEmpty) {
        sections.add(_Section(title: newPath.join(' / '), posters: hereSorted));
      }
      walk(g.id, newPath);
    }
  }
  walk(null, const []);
  if (ungrouped.isNotEmpty) {
    sections.add(_Section(title: '(未分類)', posters: ungrouped));
  }
  return sections;
}

class _PosterSection extends StatelessWidget {
  const _PosterSection({required this.section});
  final _Section section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.title != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8, left: 4),
            child: AppText.title(section.title!, tone: AppTextTone.muted),
          ),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.66,
          ),
          itemCount: section.posters.length,
          itemBuilder: (context, i) =>
              _PosterCell(poster: section.posters[i]),
        ),
      ],
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

