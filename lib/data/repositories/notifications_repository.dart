import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/supabase_providers.dart';

/// Server-side notification types — keep aligned with the
/// `notification_type` enum in the v19 migration.
enum NotificationKind {
  follow,
  favorite,
  submissionApproved,
  submissionRejected;

  static NotificationKind fromRaw(String s) {
    switch (s) {
      case 'follow':
        return NotificationKind.follow;
      case 'favorite':
        return NotificationKind.favorite;
      case 'submission_approved':
        return NotificationKind.submissionApproved;
      case 'submission_rejected':
        return NotificationKind.submissionRejected;
      default:
        return NotificationKind.follow;
    }
  }
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.kind,
    required this.actorId,
    required this.targetId,
    required this.targetKind,
    required this.payload,
    required this.readAt,
    required this.createdAt,
  });

  factory NotificationItem.fromRow(Map<String, dynamic> r) =>
      NotificationItem(
        id: r['id'] as String,
        kind: NotificationKind.fromRaw(r['type'] as String),
        actorId: r['actor_id'] as String?,
        targetId: r['target_id'] as String?,
        targetKind: r['target_kind'] as String?,
        payload: (r['payload'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
        readAt: r['read_at'] == null
            ? null
            : DateTime.parse(r['read_at'] as String).toLocal(),
        createdAt:
            DateTime.parse(r['created_at'] as String).toLocal(),
      );

  final String id;
  final NotificationKind kind;
  final String? actorId;
  final String? targetId;
  final String? targetKind;
  final Map<String, dynamic> payload;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;
}

class NotificationsRepository {
  NotificationsRepository(this._client);
  final SupabaseClient _client;

  Future<List<NotificationItem>> list({
    int offset = 0,
    int limit = 30,
    bool unreadOnly = false,
  }) async {
    final rows = await _client.rpc('list_notifications', params: {
      'p_offset': offset,
      'p_limit': limit,
      'p_unread_only': unreadOnly,
    });
    if (rows == null) return const [];
    return (rows as List)
        .map((r) => NotificationItem.fromRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<int> unreadCount() async {
    final n = await _client.rpc('unread_notifications_count');
    return (n as int?) ?? 0;
  }

  Future<void> markRead(List<String> ids) async {
    if (ids.isEmpty) return;
    await _client.rpc('mark_notifications_read', params: {
      'p_ids': ids,
    });
  }
}

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(supabaseClientProvider));
});

/// Newest-first page of the user's notifications.
final notificationsListProvider =
    FutureProvider.autoDispose<List<NotificationItem>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(notificationsRepositoryProvider).list();
});

/// Unread badge for the bottom nav. Auto-disposes when the heart tab
/// isn't watching it (cheap RPC anyway).
final unreadNotificationsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;
  return ref.watch(notificationsRepositoryProvider).unreadCount();
});
