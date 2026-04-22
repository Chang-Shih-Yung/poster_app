import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_notifier.dart';

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
    // Watch theme mode so this shell tab rebuilds on day/night flip
    // (otherwise the const widget stays cached in the IndexedStack).
    ref.watch(themeModeProvider);
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Rendered inside the shell — no back chrome, the bottom nav stays
    // visible. Content just needs enough bottom padding to clear the
    // floating pill tab bar (≈80dp above the safe-area inset).
    return Column(
      children: [
        SizedBox(height: topInset + 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '通知',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
            ),
          ),
        ),
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

/// v18 capsule filter — scrollable pill row, not an underlined tab bar.
/// Matches how IG / X filter notifications. Active pill fills white on
/// ink, inactive pills are outlined ghosts.
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
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: active ? AppTheme.bg : AppTheme.text,
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
      _NotifType.favorite => AppTheme.unreadDot,
      _NotifType.follow => AppTheme.accent1,
      _NotifType.comment => AppTheme.success,
      _NotifType.approved => AppTheme.success,
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
