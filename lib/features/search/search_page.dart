import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_user.dart';
import '../../data/models/poster.dart';
import '../../data/models/work.dart';
import '../../data/repositories/search_repository.dart';

/// /search — unified search across works, posters, users.
/// Debounces input by 250ms to avoid hammering the RPC.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  String _effectiveQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    // Rebuild immediately so the clear-X suffix icon tracks keystrokes;
    // debounce only the actual search RPC so we don't hammer the DB.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _effectiveQuery = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          // Search field.
          Padding(
            padding: EdgeInsets.fromLTRB(16, topInset + 56, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceRaised,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.line1),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onChanged,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: '搜尋作品、海報、使用者…',
                  hintStyle:
                      TextStyle(color: AppTheme.textFaint, fontSize: 15),
                  prefixIcon: Icon(LucideIcons.search,
                      size: 18, color: AppTheme.textMute),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(LucideIcons.x,
                              size: 16, color: AppTheme.textMute),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _effectiveQuery = '');
                          },
                        ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                ),
              ),
            ),
          ),

          Expanded(
            child: _effectiveQuery.isEmpty
                ? _EmptyState()
                : _ResultsView(
                    query: _effectiveQuery,
                    bottomInset: bottomInset,
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.search,
                size: 40, color: AppTheme.textFaint),
            const SizedBox(height: 12),
            Text(
              '輸入關鍵字開始搜尋',
              style: TextStyle(color: AppTheme.textMute),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsView extends ConsumerWidget {
  const _ResultsView({required this.query, required this.bottomInset});
  final String query;
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(unifiedSearchProvider(query));
    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(
        child: Text('搜尋失敗：$e',
            style: TextStyle(color: AppTheme.textMute)),
      ),
      data: (r) {
        if (r.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('找不到「$query」的相關結果',
                  style: TextStyle(color: AppTheme.textMute)),
            ),
          );
        }
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 32),
          children: [
            if (r.works.isNotEmpty) ...[
              _SectionHeader(icon: LucideIcons.film, label: '作品', count: r.works.length),
              ...r.works.map((w) => _WorkTile(work: w)),
              const SizedBox(height: 16),
            ],
            if (r.posters.isNotEmpty) ...[
              _SectionHeader(
                  icon: LucideIcons.image, label: '海報', count: r.posters.length),
              ...r.posters.map((p) => _PosterTile(poster: p)),
              const SizedBox(height: 16),
            ],
            if (r.users.isNotEmpty) ...[
              _SectionHeader(
                  icon: LucideIcons.users, label: '使用者', count: r.users.length),
              ...r.users.map((u) => _UserTile(user: u)),
            ],
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.count,
  });
  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textFaint),
          const SizedBox(width: 6),
          Text(
            '$label · $count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.textFaint,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkTile extends StatelessWidget {
  const _WorkTile({required this.work});
  final Work work;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/work/${work.id}'),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.chipBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(LucideIcons.film,
                    size: 18, color: AppTheme.textMute),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(work.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall),
                    Text(
                      [
                        if (work.movieReleaseYear != null)
                          '${work.movieReleaseYear}',
                        '${work.posterCount} 張海報',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppTheme.textMute),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight,
                  size: 14, color: AppTheme.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterTile extends StatelessWidget {
  const _PosterTile({required this.poster});
  final Poster poster;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/poster/${poster.id}'),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 40,
                  height: 56,
                  child: CachedNetworkImage(
                    imageUrl: poster.thumbnailUrl ?? poster.posterUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      color: AppTheme.surfaceRaised,
                      child: Icon(LucideIcons.image,
                          size: 16, color: AppTheme.textFaint),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(poster.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall),
                    Text(
                      [
                        if (poster.posterName != null) poster.posterName!,
                        if (poster.year != null) '${poster.year}',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppTheme.textMute),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight,
                  size: 14, color: AppTheme.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/user/${user.id}'),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: user.avatarUrl != null
                      ? CachedNetworkImage(
                          imageUrl: user.avatarUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) =>
                              _UserAvatarFallback(name: user.displayName),
                        )
                      : _UserAvatarFallback(name: user.displayName),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        user.displayName.isEmpty
                            ? '無名使用者'
                            : user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall),
                    if (user.bio != null && user.bio!.isNotEmpty)
                      Text(user.bio!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textMute)),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight,
                  size: 14, color: AppTheme.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserAvatarFallback extends StatelessWidget {
  const _UserAvatarFallback({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final letter =
        name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return Container(
      color: AppTheme.chipBgStrong,
      alignment: Alignment.center,
      child: Text(letter,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}
