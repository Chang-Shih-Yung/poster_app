import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../../data/models/poster.dart';
import '../../data/repositories/poster_repository.dart';

enum _ViewMode { grid, list }

const _prefsKeyViewMode = 'browse.view_mode';
const _prefsKeySearchHistory = 'browse.search_history';
const _searchHistoryMax = 5;

class BrowsePage extends ConsumerStatefulWidget {
  const BrowsePage({super.key});

  @override
  ConsumerState<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends ConsumerState<BrowsePage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  final List<Poster> _items = [];
  bool _loading = false;
  bool _end = false;
  bool _firstLoad = true;
  PosterFilter _filter = const PosterFilter();
  _ViewMode _viewMode = _ViewMode.grid;
  List<String> _searchHistory = const [];
  bool _historyVisible = false;

  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadMore();
    _scrollController.addListener(_onScroll);
    _searchFocus.addListener(() {
      setState(() => _historyVisible =
          _searchFocus.hasFocus && _searchHistory.isNotEmpty);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final vm = prefs.getString(_prefsKeyViewMode);
    final hist = prefs.getStringList(_prefsKeySearchHistory) ?? const [];
    if (!mounted) return;
    setState(() {
      _viewMode = vm == 'list' ? _ViewMode.list : _ViewMode.grid;
      _searchHistory = hist;
    });
  }

  Future<void> _saveViewMode(_ViewMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKeyViewMode, mode == _ViewMode.list ? 'list' : 'grid');
  }

  Future<void> _pushHistory(String term) async {
    if (term.isEmpty) return;
    final next = [term, ..._searchHistory.where((e) => e != term)]
        .take(_searchHistoryMax)
        .toList();
    setState(() => _searchHistory = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKeySearchHistory, next);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _end) return;
    final seq = ++_requestSeq;
    final offset = _items.length;
    final capturedFilter = _filter;
    setState(() => _loading = true);
    try {
      final page = await ref.read(posterRepositoryProvider).listApproved(
            filter: capturedFilter,
            offset: offset,
          );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        final existing = _items.map((p) => p.id).toSet();
        _items.addAll(page.items.where((p) => !existing.contains(p.id)));
        _end = !page.hasMore;
        _firstLoad = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('載入失敗：$e')));
      }
    } finally {
      if (mounted && seq == _requestSeq) setState(() => _loading = false);
    }
  }

  Future<void> _applyFilter(PosterFilter next) async {
    _requestSeq++;
    setState(() {
      _items.clear();
      _end = false;
      _loading = false;
      _firstLoad = true;
      _filter = next;
    });
    await _loadMore();
  }

  Future<void> _submitSearch(String text) async {
    final t = text.trim();
    _searchController.text = t;
    _searchFocus.unfocus();
    setState(() => _historyVisible = false);
    await _pushHistory(t);
    await _applyFilter(
      PosterFilter(
        sortBy: _filter.sortBy,
        search: t.isEmpty ? null : t,
        tags: _filter.tags,
        director: _filter.director,
        yearMin: _filter.yearMin,
        yearMax: _filter.yearMax,
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<PosterFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(initial: _filter),
    );
    if (result != null) {
      await _applyFilter(result);
    }
  }

  void _toggleViewMode() {
    final next = _viewMode == _ViewMode.grid ? _ViewMode.list : _ViewMode.grid;
    setState(() => _viewMode = next);
    _saveViewMode(next);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _TopBar(
              controller: _searchController,
              focusNode: _searchFocus,
              onSubmitted: _submitSearch,
              onOpenFilters: _openFilterSheet,
              viewMode: _viewMode,
              onToggleView: _toggleViewMode,
              filterCount: _filter.advancedCount,
            ),
            _SortSegment(
              value: _filter.sortBy,
              onChanged: (s) => _applyFilter(
                PosterFilter(
                  sortBy: s,
                  search: _filter.search,
                  tags: _filter.tags,
                  director: _filter.director,
                  yearMin: _filter.yearMin,
                  yearMax: _filter.yearMax,
                ),
              ),
            ),
            if (_filter.hasAdvanced)
              _AppliedFiltersBar(
                count: _filter.advancedCount,
                onClear: () => _applyFilter(PosterFilter(
                  sortBy: _filter.sortBy,
                  search: _filter.search,
                )),
              ),
            Expanded(child: _buildContent()),
          ],
        ),
        if (_historyVisible)
          Positioned(
            top: 64,
            left: 16,
            right: 16,
            child: _SearchHistoryList(
              history: _searchHistory,
              onPick: (s) {
                _searchController.text = s;
                _submitSearch(s);
              },
              onClear: () async {
                setState(() => _searchHistory = const []);
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove(_prefsKeySearchHistory);
                if (mounted) setState(() => _historyVisible = false);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (_firstLoad && _loading) {
      return _viewMode == _ViewMode.grid
          ? const _GridSkeleton()
          : const _ListSkeleton();
    }
    if (_items.isEmpty && !_loading) {
      return const _EmptyState();
    }
    return RefreshIndicator(
      onRefresh: () => _applyFilter(_filter),
      child: _viewMode == _ViewMode.grid
          ? _GridView(
              controller: _scrollController,
              items: _items,
              trailingLoader: _loading,
            )
          : _ListView(
              controller: _scrollController,
              items: _items,
              trailingLoader: _loading,
            ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onOpenFilters,
    required this.viewMode,
    required this.onToggleView,
    required this.filterCount,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onOpenFilters;
  final _ViewMode viewMode;
  final VoidCallback onToggleView;
  final int filterCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: '搜尋海報標題…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: onSubmitted,
            ),
          ),
          const SizedBox(width: 4),
          Badge.count(
            count: filterCount,
            isLabelVisible: filterCount > 0,
            child: IconButton(
              icon: const Icon(Icons.tune),
              tooltip: '篩選',
              onPressed: onOpenFilters,
            ),
          ),
          IconButton(
            icon: Icon(
              viewMode == _ViewMode.grid ? Icons.view_list : Icons.grid_view,
            ),
            tooltip: viewMode == _ViewMode.grid ? '切列表' : '切格狀',
            onPressed: onToggleView,
          ),
        ],
      ),
    );
  }
}

class _SortSegment extends StatelessWidget {
  const _SortSegment({required this.value, required this.onChanged});
  final PosterSort value;
  final ValueChanged<PosterSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SegmentedButton<PosterSort>(
        segments: const [
          ButtonSegment(
            value: PosterSort.latest,
            label: Text('最新'),
            icon: Icon(Icons.schedule),
          ),
          ButtonSegment(
            value: PosterSort.popular,
            label: Text('熱門'),
            icon: Icon(Icons.local_fire_department),
          ),
        ],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

class _AppliedFiltersBar extends StatelessWidget {
  const _AppliedFiltersBar({required this.count, required this.onClear});
  final int count;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          InputChip(
            label: Text('已套用 $count 項篩選'),
            onDeleted: onClear,
            deleteIcon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

class _SearchHistoryList extends StatelessWidget {
  const _SearchHistoryList({
    required this.history,
    required this.onPick,
    required this.onClear,
  });
  final List<String> history;
  final ValueChanged<String> onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...history.map((s) => ListTile(
                dense: true,
                leading: const Icon(Icons.history),
                title: Text(s),
                onTap: () => onPick(s),
              )),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline),
            label: const Text('清除搜尋歷史'),
          ),
        ],
      ),
    );
  }
}

class _GridView extends StatelessWidget {
  const _GridView({
    required this.controller,
    required this.items,
    required this.trailingLoader,
  });
  final ScrollController controller;
  final List<Poster> items;
  final bool trailingLoader;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: controller,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.66,
      ),
      itemCount: items.length + (trailingLoader ? 2 : 0),
      itemBuilder: (context, i) {
        if (i >= items.length) {
          return const Card(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _PosterCard(poster: items[i]);
      },
    );
  }
}

class _ListView extends StatelessWidget {
  const _ListView({
    required this.controller,
    required this.items,
    required this.trailingLoader,
  });
  final ScrollController controller;
  final List<Poster> items;
  final bool trailingLoader;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.all(12),
      itemCount: items.length + (trailingLoader ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (i >= items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _PosterListTile(poster: items[i]);
      },
    );
  }
}

class _PosterListTile extends StatelessWidget {
  const _PosterListTile({required this.poster});
  final Poster poster;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/poster/${poster.id}'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 90,
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: CachedNetworkImage(
                  imageUrl: poster.thumbnailUrl ?? poster.posterUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) =>
                      const ColoredBox(color: Colors.black12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      poster.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (poster.year != null) '${poster.year}',
                        if (poster.director != null) poster.director!,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (poster.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: poster.tags
                            .take(4)
                            .map((t) => Chip(
                                  label: Text(t,
                                      style: const TextStyle(fontSize: 11)),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.poster});
  final Poster poster;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/poster/${poster.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CachedNetworkImage(
                imageUrl: poster.thumbnailUrl ?? poster.posterUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (_, _, _) => const ColoredBox(
                  color: Colors.black12,
                  child: Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    poster.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (poster.year != null)
                    Text(
                      '${poster.year}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.black12,
      highlightColor: Colors.black26,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.66,
        ),
        itemCount: 6,
        itemBuilder: (_, _) => Card(
          clipBehavior: Clip.antiAlias,
          child: Container(color: Colors.white),
        ),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.black12,
      highlightColor: Colors.black26,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Card(
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 110,
            child: Container(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '目前沒有符合條件的海報。\n試試調整搜尋或清除篩選。',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});
  final PosterFilter initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late final TextEditingController _directorController;
  late RangeValues _yearRange;
  late Set<String> _selectedTags;

  static const _yearMin = 1960.0;
  static final _yearMax = DateTime.now().year.toDouble();

  @override
  void initState() {
    super.initState();
    _directorController =
        TextEditingController(text: widget.initial.director ?? '');
    _yearRange = RangeValues(
      widget.initial.yearMin?.toDouble() ?? _yearMin,
      widget.initial.yearMax?.toDouble() ?? _yearMax,
    );
    _selectedTags = widget.initial.tags.toSet();
  }

  @override
  void dispose() {
    _directorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topTagsAsync = ref.watch(topTagsProvider);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 8,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('進階篩選', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('年份：${_yearRange.start.round()} – ${_yearRange.end.round()}'),
            RangeSlider(
              values: _yearRange,
              min: _yearMin,
              max: _yearMax,
              divisions: (_yearMax - _yearMin).toInt(),
              labels: RangeLabels(
                _yearRange.start.round().toString(),
                _yearRange.end.round().toString(),
              ),
              onChanged: (v) => setState(() => _yearRange = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _directorController,
              decoration: const InputDecoration(
                labelText: '導演',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Tags'),
            const SizedBox(height: 8),
            topTagsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Text('載入 tags 失敗：$e'),
              data: (tags) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags
                    .map((t) => FilterChip(
                          label: Text(t),
                          selected: _selectedTags.contains(t),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _selectedTags.add(t);
                            } else {
                              _selectedTags.remove(t);
                            }
                          }),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _directorController.clear();
                      _yearRange = RangeValues(_yearMin, _yearMax);
                      _selectedTags = {};
                    });
                  },
                  child: const Text('清除'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    final ymin = _yearRange.start.round();
                    final ymax = _yearRange.end.round();
                    Navigator.of(context).pop(
                      PosterFilter(
                        sortBy: widget.initial.sortBy,
                        search: widget.initial.search,
                        tags: _selectedTags.toList(),
                        director: _directorController.text.trim().isEmpty
                            ? null
                            : _directorController.text.trim(),
                        yearMin: ymin == _yearMin.round() ? null : ymin,
                        yearMax: ymax == _yearMax.round() ? null : ymax,
                      ),
                    );
                  },
                  child: const Text('套用'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
