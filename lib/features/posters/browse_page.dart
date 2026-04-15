import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/poster.dart';
import '../../data/repositories/poster_repository.dart';

class BrowsePage extends ConsumerStatefulWidget {
  const BrowsePage({super.key});

  @override
  ConsumerState<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends ConsumerState<BrowsePage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  final List<Poster> _items = [];
  bool _loading = false;
  bool _end = false;
  String? _search;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  int _requestSeq = 0;

  Future<void> _loadMore() async {
    if (_loading || _end) return;
    final seq = ++_requestSeq;
    final capturedSearch = _search;
    final offset = _items.length;
    setState(() => _loading = true);
    try {
      final page = await ref.read(posterRepositoryProvider).listApproved(
            filter: PosterFilter(search: capturedSearch),
            offset: offset,
          );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        final existing = _items.map((p) => p.id).toSet();
        _items.addAll(page.items.where((p) => !existing.contains(p.id)));
        _end = !page.hasMore;
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

  Future<void> _submitSearch(String text) async {
    _requestSeq++;
    setState(() {
      _items.clear();
      _end = false;
      _loading = false;
      _search = text.isEmpty ? null : text;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: '搜尋海報標題…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: _submitSearch,
          ),
        ),
        Expanded(
          child: _items.isEmpty && !_loading
              ? const _EmptyState()
              : RefreshIndicator(
                  onRefresh: () => _submitSearch(_search ?? ''),
                  child: GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.66,
                    ),
                    itemCount: _items.length + (_loading ? 2 : 0),
                    itemBuilder: (context, i) {
                      if (i >= _items.length) {
                        return const Card(
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _PosterCard(poster: _items[i]);
                    },
                  ),
                ),
        ),
      ],
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
          '目前還沒有已上架的海報。\n去上傳一張，或等管理員審核一下。',
          textAlign: TextAlign.center,
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
