import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/favorite.dart';
import '../../data/models/favorite_category.dart';
import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/favorite_category_repository.dart';
import '../../data/repositories/favorite_repository.dart';

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  // null = 全部
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Center(child: Text('請先到「我的」tab 登入'));
    }

    final favsAsync = ref.watch(favoritesProvider);
    final catsAsync = ref.watch(favoriteCategoriesProvider);

    return Column(
      children: [
        catsAsync.when(
          loading: () => const SizedBox(height: 48),
          error: (_, _) => const SizedBox(height: 48),
          data: (cats) => _CategoryTabBar(
            categories: cats,
            selectedId: _selectedCategoryId,
            onSelect: (id) => setState(() => _selectedCategoryId = id),
            onAddCategory: () => _addCategoryDialog(user.id),
            onEdit: () => _openEditSheet(cats),
          ),
        ),
        Expanded(
          child: favsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('載入失敗：$e')),
            data: (all) {
              final items = _selectedCategoryId == null
                  ? all
                  : all
                      .where((f) => f.categoryId == _selectedCategoryId)
                      .toList();
              if (items.isEmpty) {
                return Center(
                  child: Text(_selectedCategoryId == null
                      ? '還沒有收藏任何海報'
                      : '這個分類還是空的'),
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(favoritesProvider);
                  ref.invalidate(favoriteCategoriesProvider);
                },
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.66,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _FavoriteCard(
                    favorite: items[i],
                    onLongPress: () => _openMoveSheet(items[i], user.id),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _addCategoryDialog(String userId) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('新增分類'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '分類名稱'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('建立'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref
          .read(favoriteCategoryRepositoryProvider)
          .create(userId, name);
      ref.invalidate(favoriteCategoriesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('建立失敗：$e')));
      }
    }
  }

  Future<void> _openMoveSheet(Favorite fav, String userId) async {
    final cats = ref.read(favoriteCategoriesProvider).asData?.value ?? [];
    final result = await showModalBottomSheet<_MoveResult>(
      context: context,
      showDragHandle: true,
      builder: (_) => _MoveSheet(
        categories: cats,
        currentCategoryId: fav.categoryId,
      ),
    );
    if (result == null) return;
    try {
      await ref.read(favoriteCategoryRepositoryProvider).moveFavorite(
            userId: userId,
            posterId: fav.posterId,
            categoryId: result.categoryId,
          );
      ref.invalidate(favoritesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('移動失敗：$e')));
      }
    }
  }

  Future<void> _openEditSheet(List<FavoriteCategory> cats) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditCategoriesSheet(categories: cats),
    );
    ref.invalidate(favoriteCategoriesProvider);
    ref.invalidate(favoritesProvider);
  }
}

class _CategoryTabBar extends StatelessWidget {
  const _CategoryTabBar({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    required this.onAddCategory,
    required this.onEdit,
  });

  final List<FavoriteCategory> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final VoidCallback onAddCategory;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _tab(context, '全部', selectedId == null, () => onSelect(null)),
          ...categories.map((c) => _tab(
                context,
                c.name,
                selectedId == c.id,
                () => onSelect(c.id),
              )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('新分類'),
              onPressed: onAddCategory,
            ),
          ),
          if (categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ActionChip(
                avatar: const Icon(Icons.edit, size: 18),
                label: const Text('編輯'),
                onPressed: onEdit,
              ),
            ),
        ],
      ),
    );
  }

  Widget _tab(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.favorite, required this.onLongPress});
  final Favorite favorite;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/poster/${favorite.posterId}'),
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: favorite.thumbnailUrl == null
                  ? const ColoredBox(color: Colors.black12)
                  : CachedNetworkImage(
                      imageUrl: favorite.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) =>
                          const ColoredBox(color: Colors.black12),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                favorite.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoveResult {
  const _MoveResult(this.categoryId);
  final String? categoryId;
}

class _MoveSheet extends StatelessWidget {
  const _MoveSheet({
    required this.categories,
    required this.currentCategoryId,
  });
  final List<FavoriteCategory> categories;
  final String? currentCategoryId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RadioGroup<String?>(
        groupValue: currentCategoryId,
        onChanged: (value) {
          Navigator.pop(context, _MoveResult(value));
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('移到分類',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const RadioListTile<String?>(
              value: null,
              title: Text('預設（無分類）'),
            ),
            ...categories.map((c) => RadioListTile<String?>(
                  value: c.id,
                  title: Text(c.name),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _EditCategoriesSheet extends ConsumerStatefulWidget {
  const _EditCategoriesSheet({required this.categories});
  final List<FavoriteCategory> categories;

  @override
  ConsumerState<_EditCategoriesSheet> createState() =>
      _EditCategoriesSheetState();
}

class _EditCategoriesSheetState extends ConsumerState<_EditCategoriesSheet> {
  late List<FavoriteCategory> _items;

  @override
  void initState() {
    super.initState();
    _items = [...widget.categories];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('編輯分類',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _items.length,
                onReorder: _reorder,
                itemBuilder: (_, i) {
                  final c = _items[i];
                  return ListTile(
                    key: ValueKey(c.id),
                    leading: const Icon(Icons.drag_handle),
                    title: Text(c.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _rename(c),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(c),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('完成'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
    try {
      await ref
          .read(favoriteCategoryRepositoryProvider)
          .reorder(_items.map((e) => e.id).toList());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('排序失敗：$e')));
      }
    }
  }

  Future<void> _rename(FavoriteCategory c) async {
    final controller = TextEditingController(text: c.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重新命名'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('儲存'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == c.name) return;
    try {
      await ref.read(favoriteCategoryRepositoryProvider).rename(c.id, name);
      setState(() {
        final i = _items.indexWhere((e) => e.id == c.id);
        if (i >= 0) {
          _items[i] = FavoriteCategory(
            id: c.id,
            userId: c.userId,
            name: name,
            sortOrder: c.sortOrder,
            createdAt: c.createdAt,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('改名失敗：$e')));
      }
    }
  }

  Future<void> _delete(FavoriteCategory c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('刪除分類「${c.name}」？'),
        content: const Text('裡面的收藏會回到預設，不會真的被刪除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(favoriteCategoryRepositoryProvider).delete(c.id);
      setState(() => _items.removeWhere((e) => e.id == c.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
      }
    }
  }
}
