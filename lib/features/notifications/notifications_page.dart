import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/sticky_header.dart';

/// v18 notifications centre — **UI shell only, no backend yet**.
///
/// This ships the visual pattern (tabbed list, today / this week / earlier
/// groups, unread dots) so the heart icon in the bottom nav goes somewhere
/// real. When we add a `notifications` table + RPC we just swap the
/// hardcoded [_demoItems] for a real provider.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});
  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  _NotifTab _tab = _NotifTab.all;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final headerH = StickyHeader.heightWithInset(context);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          Positioned(
            top: headerH,
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              children: [
                _TabRow(tab: _tab, onChange: (t) => setState(() => _tab = t)),
                Expanded(
                  child: _demoItems.isEmpty
                      ? const _EmptyView()
                      : ListView(
                          padding: EdgeInsets.only(
                              top: 8, bottom: bottomInset + 120),
                          children: [
                            _GroupHeader(label: '今天'),
                            ..._demoItems
                                .where((e) => e.group == _Group.today)
                                .where(_tabFilter)
                                .map((e) => _NotifTile(item: e)),
                            _GroupHeader(label: '本週'),
                            ..._demoItems
                                .where((e) => e.group == _Group.week)
                                .where(_tabFilter)
                                .map((e) => _NotifTile(item: e)),
                            _GroupHeader(label: '更早'),
                            ..._demoItems
                                .where((e) => e.group == _Group.earlier)
                                .where(_tabFilter)
                                .map((e) => _NotifTile(item: e)),
                          ],
                        ),
                ),
              ],
            ),
          ),
          StickyHeader(
            title: '通知',
            actionLabel: '全部已讀',
            onAction: () {
              // TODO: mark-all-read when backend exists.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已全部標為已讀')),
              );
            },
          ),
        ],
      ),
    );
  }

  bool _tabFilter(_NotifItem e) {
    switch (_tab) {
      case _NotifTab.all:
        return true;
      case _NotifTab.social:
        return e.type == _NotifType.favorite ||
            e.type == _NotifType.follow ||
            e.type == _NotifType.comment;
      case _NotifTab.system:
        return e.type == _NotifType.approved || e.type == _NotifType.rejected;
    }
  }
}

// ───────────────────────────────────────────────────────────────────────

enum _NotifTab { all, social, system }

class _TabRow extends StatelessWidget {
  const _TabRow({required this.tab, required this.onChange});
  final _NotifTab tab;
  final ValueChanged<_NotifTab> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.line1)),
      ),
      child: Row(
        children: [
          _tab('全部', _NotifTab.all),
          _tab('互動', _NotifTab.social),
          _tab('系統', _NotifTab.system),
        ],
      ),
    );
  }

  Widget _tab(String label, _NotifTab t) {
    final active = t == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChange(t),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? Colors.white : AppTheme.textMute,
            ),
          ),
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
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.textFaint,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.item});
  final _NotifItem item;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActorAvatar(item: item),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: item.actor,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: '  ${item.action}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textMute,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.when,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textFaint,
                  ),
                ),
              ],
            ),
          ),
          if (item.unread) ...[
            const SizedBox(width: 10),
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFFF5C5C),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActorAvatar extends StatelessWidget {
  const _ActorAvatar({required this.item});
  final _NotifItem item;
  @override
  Widget build(BuildContext context) {
    final icon = switch (item.type) {
      _NotifType.favorite => Icons.favorite,
      _NotifType.follow => LucideIcons.userPlus,
      _NotifType.comment => LucideIcons.messageCircle,
      _NotifType.approved => LucideIcons.check,
      _NotifType.rejected => LucideIcons.x,
    };
    final tint = switch (item.type) {
      _NotifType.favorite => const Color(0xFFFF5C5C),
      _NotifType.follow => const Color(0xFF8FB4FF),
      _NotifType.comment => const Color(0xFFA8E6B0),
      _NotifType.approved => const Color(0xFFA8E6B0),
      _NotifType.rejected => AppTheme.textMute,
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.chipBgStrong,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: tint),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.bellOff, size: 36, color: AppTheme.textFaint),
          const SizedBox(height: 12),
          Text('還沒有通知',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('有人收藏你的海報時會出現在這裡',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMute,
                  )),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Placeholder data until backend lands.
// ───────────────────────────────────────────────────────────────────────

enum _NotifType { favorite, follow, comment, approved, rejected }

enum _Group { today, week, earlier }

class _NotifItem {
  const _NotifItem({
    required this.actor,
    required this.action,
    required this.when,
    required this.type,
    required this.group,
    // ignore: unused_element_parameter
    this.unread = false,
  });
  final String actor;
  final String action;
  final String when;
  final _NotifType type;
  final _Group group;
  final bool unread;
}

const _demoItems = <_NotifItem>[];
