import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
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
  bool? _optimistic;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    if (me == null || me.id == widget.targetUserId) {
      return const SizedBox.shrink();
    }

    final statsAsync =
        ref.watch(userRelationshipStatsProvider(widget.targetUserId));
    final amFollowing =
        _optimistic ?? statsAsync.asData?.value.amIFollowing ?? false;

    final label = amFollowing ? '追蹤中' : '追蹤';
    final icon = amFollowing ? LucideIcons.check : LucideIcons.plus;

    // v19: drop the 12×12 in-button spinner. It was flicker-noise on
    // slow networks (seizure-like swap between icon and tiny spinner
    // on every toggle). Optimistic state already updates the
    // icon+label instantly; a subtle alpha dim plus a disabled tap
    // target is all the "pending" feedback this button needs.
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
              color: amFollowing ? AppTheme.chipBgStrong : AppTheme.text,
              border: Border.all(
                color: amFollowing ? AppTheme.line2 : AppTheme.text,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: widget.compact ? 12 : 14,
                  color: amFollowing ? AppTheme.text : AppTheme.bg,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: widget.compact ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: amFollowing ? AppTheme.text : AppTheme.bg,
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
        ref.read(userRelationshipStatsProvider(widget.targetUserId)).asData?.value.amIFollowing ??
        false;

    setState(() {
      _optimistic = !current;
      _busy = true;
    });
    HapticFeedback.selectionClick();

    try {
      await ref
          .read(followRepositoryProvider)
          .toggle(widget.targetUserId);
      // Invalidate so stats refetch (counts update too).
      ref.invalidate(userRelationshipStatsProvider(widget.targetUserId));
      // Invalidate follow feed — it changes when the follow graph changes.
      // EPIC 14: home sections are now config-driven, refresh the combined
      // RPC so the follow-feed section re-evaluates with new follow graph.
      ref.invalidate(homeSectionsV2Provider);
    } catch (e) {
      // Rollback optimistic update.
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
