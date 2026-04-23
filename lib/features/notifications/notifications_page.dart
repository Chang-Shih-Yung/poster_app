import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_notifier.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/ds/ds.dart';
import '../../data/repositories/notifications_repository.dart';

/// v19 notifications centre — wired to the real backend.
///
/// Backend: notifications table + DB triggers on follows / favorites
/// / submission status change automatically insert rows. RPCs:
///   list_notifications · unread_notifications_count
///   mark_notifications_read
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});
  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  _NotifTab _tab = _NotifTab.all;

  @override
  Widget build(BuildContext context) {
    ref.watch(themeModeProvider);
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final async = ref.watch(notificationsListProvider);

    return Column(
      children: [
        SizedBox(height: topInset + 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: const AppText.title('通知', weight: FontWeight.w700),
          ),
        ),
        _TabRow(tab: _tab, onChange: (t) => setState(() => _tab = t)),
        Expanded(
          child: async.when(
            loading: () => const AppLoader.centered(),
            error: (e, _) => AppEmptyState(title: '載入失敗：$e'),
            data: (items) {
              final filtered =
                  items.where((e) => _matchesTab(e, _tab)).toList(growable: false);
              if (filtered.isEmpty) return const _EmptyView();
              final groups = _groupByRecency(filtered);
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(notificationsListProvider);
                  ref.invalidate(unreadNotificationsCountProvider);
                  await ref.read(notificationsListProvider.future);
                },
                child: ListView(
                  padding:
                      EdgeInsets.only(top: 8, bottom: bottomInset + 120),
                  children: [
                    for (final entry in groups.entries) ...[
                      _GroupHeader(label: entry.key),
                      ...entry.value.map((n) => _NotifTile(item: n)),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _matchesTab(NotificationItem item, _NotifTab tab) {
    switch (tab) {
      case _NotifTab.all:
        return true;
      case _NotifTab.social:
        return item.kind == NotificationKind.follow ||
            item.kind == NotificationKind.favorite;
      case _NotifTab.system:
        return item.kind == NotificationKind.submissionApproved ||
            item.kind == NotificationKind.submissionRejected;
    }
  }

  /// Bucket the list into 今天 / 本週 / 更早 by createdAt.
  Map<String, List<NotificationItem>> _groupByRecency(
      List<NotificationItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 7));
    final out = <String, List<NotificationItem>>{
      '今天': [],
      '本週': [],
      '更早': [],
    };
    for (final n in items) {
      if (n.createdAt.isAfter(today)) {
        out['今天']!.add(n);
      } else if (n.createdAt.isAfter(weekStart)) {
        out['本週']!.add(n);
      } else {
        out['更早']!.add(n);
      }
    }
    out.removeWhere((_, v) => v.isEmpty);
    return out;
  }
}

enum _NotifTab { all, social, system }

class _TabRow extends StatelessWidget {
  const _TabRow({required this.tab, required this.onChange});
  final _NotifTab tab;
  final ValueChanged<_NotifTab> onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _pill(context, '全部', _NotifTab.all),
          _pill(context, '互動', _NotifTab.social),
          _pill(context, '系統', _NotifTab.system),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String label, _NotifTab t) {
    final active = t == tab;
    return GestureDetector(
      onTap: () => onChange(t),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppTheme.text : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppTheme.text : AppTheme.line2,
          ),
        ),
        child: AppText.body(
          label,
          color: active ? AppTheme.bg : AppTheme.text,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: AppText.label(label, tone: AppTextTone.faint),
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.item});
  final NotificationItem item;
  @override
  Widget build(BuildContext context) {
    final (icon, tint) = switch (item.kind) {
      NotificationKind.favorite => (Icons.favorite, AppTheme.favoriteActive),
      NotificationKind.follow => (LucideIcons.userPlus, AppTheme.text),
      NotificationKind.submissionApproved =>
        (LucideIcons.check, AppTheme.success),
      NotificationKind.submissionRejected =>
        (LucideIcons.x, AppTheme.textMute),
    };
    final lead = switch (item.kind) {
      NotificationKind.favorite => '有人收藏了',
      NotificationKind.follow => '有人開始追蹤你',
      NotificationKind.submissionApproved => '投稿已核准',
      NotificationKind.submissionRejected => '投稿被退回',
    };
    final detail = (item.payload['title'] as String?)?.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.surfaceRaised,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.body(
                  detail == null || detail.isEmpty
                      ? lead
                      : '$lead「$detail」',
                ),
                const SizedBox(height: 2),
                AppText.small(_relative(item.createdAt),
                    tone: AppTextTone.faint),
              ],
            ),
          ),
          if (item.isUnread) ...[
            const SizedBox(width: 10),
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: AppTheme.unreadDot,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _relative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '剛剛';
    if (d.inHours < 1) return '${d.inMinutes} 分鐘前';
    if (d.inDays < 1) return '${d.inHours} 小時前';
    if (d.inDays < 7) return '${d.inDays} 天前';
    return '${t.year}/${t.month.toString().padLeft(2, '0')}/${t.day.toString().padLeft(2, '0')}';
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: LucideIcons.bellOff,
      title: '還沒有通知',
      subtitle: '有人追蹤你或收藏你的海報時會出現在這裡',
    );
  }
}
