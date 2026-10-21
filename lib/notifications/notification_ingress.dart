import 'package:flutter_api_layer/api_layer.dart';

import '../state/notification_merge.dart';
import 'notification_dedup.dart';
import 'push_drop_log.dart';
import 'push_payload.dart';

/// Push and poll door in front of [NotificationsController.ingest].
///
/// Push rows with a missing or foreign `recipientUserId` are dropped before
/// ingest. Poll rows from the session-scoped list may omit that field. A
/// logged-out reader drops everything. The LRU is shared with realtime.
class NotificationIngress {
  NotificationIngress({
    required this.userId,
    required this.dedup,
    required this.drops,
    required this.ingest,
  });

  /// Null or empty when nobody is signed in.
  final String? Function() userId;
  final NotificationIdDedup dedup;
  final PushDropLog drops;

  /// His controller. The transport does not merge rows itself.
  final Future<void> Function(
    List<AppNotification> items,
    NotificationSource source,
  )
  ingest;

  int ingestCalls = 0;

  Future<bool> acceptPush(Map<String, dynamic> raw) async {
    final owner = userId();
    if (owner == null || owner.isEmpty) {
      drops.loggedOut++;
      drops.logCounts();
      return false;
    }
    final clean = whitelistPushPayload(raw);
    final item = AppNotification.fromPushPayload(clean);
    final recipient = item.recipientUserId;
    if (recipient == null || recipient.isEmpty) {
      drops.missingRecipient++;
      drops.logCounts();
      return false;
    }
    if (recipient != owner) {
      drops.wrongUser++;
      drops.logCounts();
      return false;
    }
    if (item.notificationId.isEmpty) {
      drops.emptyId++;
      drops.logCounts();
      return false;
    }
    if (!dedup.add(item.notificationId)) {
      drops.duplicate++;
      drops.logCounts();
      return false;
    }
    ingestCalls++;
    await ingest([item], NotificationSource.push);
    return true;
  }

  /// Rows that survived the current-user filter and the transport LRU.
  List<AppNotification> acceptPoll(List<AppNotification> items) {
    final owner = userId();
    if (owner == null || owner.isEmpty) {
      if (items.isNotEmpty) {
        drops.loggedOut += items.length;
        drops.logCounts();
      }
      return const [];
    }
    final kept = <AppNotification>[];
    for (final item in items) {
      final recipient = item.recipientUserId;
      if (recipient != null && recipient.isNotEmpty && recipient != owner) {
        drops.wrongUser++;
        continue;
      }
      if (item.notificationId.isEmpty) {
        drops.emptyId++;
        continue;
      }
      if (!dedup.add(item.notificationId)) {
        drops.duplicate++;
        continue;
      }
      kept.add(item);
    }
    if (drops.total > 0) drops.logCounts();
    return kept;
  }

  Future<void> deliverPoll(List<AppNotification> items) async {
    await deliverFresh(acceptPoll(items));
  }

  /// [items] were already filtered. Does not consult the LRU again.
  Future<void> deliverFresh(List<AppNotification> items) async {
    if (items.isEmpty) return;
    ingestCalls++;
    await ingest(items, NotificationSource.poll);
  }
}
