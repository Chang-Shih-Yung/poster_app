import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/social.dart';
import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/follow_repository.dart';
import '../../data/repositories/social_repository.dart';

/// Follow / unfollow pill button used on PublicProfilePage and in search
/// results. Optimistic update with rollback on failure.
///
/// Hidden entirely when:
///   - caller is not signed in (no auth → can't follow)
///   - targetUserId == caller's uid (no self-follow; matches DB CHECK)
class FollowPill extends ConsumerStatefulWidget {
  const FollowPill({
    super.key,
    required this.targetUserId,
    this.compact = false,
  });

  final String targetUserId;
  /// compact=true: small pill suitable for list rows; compact=false: full width
  final bool compact;

  @override
  ConsumerState<FollowPill> createState() => _FollowPillState();
}

class _FollowPillState extends ConsumerState<FollowPill> {
  /// Optimistic status while the RPC is in flight. Null = fall back
  /// to the latest stat.
  FollowStatus? _optimistic;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    if (me == null || me.id == widget.targetUserId) {
      return const SizedBox.shrink();
    }

    final statsAsync =
        ref.watch(userRelationshipStatsProvider(widget.targetUserId));
    final status =
        _optimistic ?? statsAsync.asData?.value.viewerStatus ?? FollowStatus.none;

    // Three visual states:
    //   none      → primary-filled "追蹤"     (positive CTA)
    //   pending   → outlined  "等待確認"       (neutral, tappable to cancel)
    //   accepted  → outlined  "追蹤中"         (neutral, tappable to unfollow)
    final (label, icon, filled) = switch (status) {
      FollowStatus.none => ('追蹤', LucideIcons.plus, true),
      FollowStatus.pending => ('等待確認', LucideIcons.clock, false),
      FollowStatus.accepted => ('追蹤中', LucideIcons.check, false),
      FollowStatus.self => ('', LucideIcons.plus, false), // unreachable
    };

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: _busy ? null : _toggle,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedOpacity(
          opacity: _busy ? 0.62 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 12 : 18,
              vertical: widget.compact ? 6 : 9,
            ),
            decoration: BoxDecoration(
              color: filled ? AppTheme.text : AppTheme.chipBgStrong,
              border: Border.all(
                color: filled ? AppTheme.text : AppTheme.line2,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: widget.compact ? 12 : 14,
                  color: filled ? AppTheme.bg : AppTheme.text,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: widget.compact ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: filled ? AppTheme.bg : AppTheme.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggle() async {
    final current = _optimistic ??
        ref
                .read(userRelationshipStatsProvider(widget.targetUserId))
                .asData
                ?.value
                .viewerStatus ??
        FollowStatus.none;

    // Optimistic next state — we don't know public-vs-private yet so
    // guess: if currently none, flip to pending if we previously knew
    // the target was private (not tracked here, assume accepted and
    // re-sync from the RPC response).
    FollowStatus optimisticNext;
    switch (current) {
      case FollowStatus.none:
        optimisticNext = FollowStatus.accepted; // will be corrected by RPC
        break;
      case FollowStatus.pending:
      case FollowStatus.accepted:
        optimisticNext = FollowStatus.none;
        break;
      case FollowStatus.self:
        return; // can't toggle self-follow
    }

    setState(() {
      _optimistic = optimisticNext;
      _busy = true;
    });
    HapticFeedback.selectionClick();

    try {
      final result =
          await ref.read(followRepositoryProvider).toggle(widget.targetUserId);
      // Sync optimistic guess against the authoritative response.
      final authoritative = result.following
          ? FollowStatus.accepted
          : result.pending
              ? FollowStatus.pending
              : FollowStatus.none;
      if (mounted && authoritative != optimisticNext) {
        setState(() => _optimistic = authoritative);
      }
      ref.invalidate(userRelationshipStatsProvider(widget.targetUserId));
      final viewerId = ref.read(currentUserProvider)?.id;
      if (viewerId != null) {
        ref.invalidate(userRelationshipStatsProvider(viewerId));
      }
      ref.invalidate(homeSectionsV2Provider);
    } catch (e) {
      setState(() => _optimistic = current);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失敗：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
