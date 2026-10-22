import 'package:flutter_api_layer/api_layer.dart';

/// Where a row entered the in-memory list.
enum NotificationSource { push, poll, fetch }

/// Merges [incoming] into [current] by `notificationId`.
///
/// Later [AppNotification.readAt] wins. Null is earlier than any timestamp.
/// Order is `createdAt` descending, then `notificationId` ascending.
///
/// Fetch and poll keep a null [AppNotification.recipientUserId] (the server
/// already bound the row to the session) and drop a present id that is not
/// [currentUserId]. Push drops the row unless `recipientUserId` is present
/// and equal to [currentUserId].
List<AppNotification> mergeAppNotifications({
  required List<AppNotification> current,
  required List<AppNotification> incoming,
  required String? currentUserId,
  required NotificationSource source,
}) {
  final merged = <String, AppNotification>{
    for (final item in current)
      if (item.notificationId.isNotEmpty) item.notificationId: item,
  };
  for (final item in incoming) {
    if (!_visible(item, currentUserId, source)) continue;
    final previous = merged[item.notificationId];
    merged[item.notificationId] =
        previous == null ? item : previous.mergeWith(item);
  }
  final items = merged.values.toList(growable: false)..sort(_byCreatedDesc);
  return items;
}

/// Ids that were not in [before], are still unread, and should raise a banner.
List<AppNotification> newlySeenUnread({
  required List<AppNotification> before,
  required List<AppNotification> after,
}) {
  final seen = {for (final item in before) item.notificationId};
  return [
    for (final item in after)
      if (!item.isRead && !seen.contains(item.notificationId)) item,
  ];
}

bool _visible(
  AppNotification item,
  String? currentUserId,
  NotificationSource source,
) {
  if (item.notificationId.isEmpty) return false;
  if (currentUserId == null || currentUserId.isEmpty) return false;
  final owner = item.recipientUserId;
  if (source == NotificationSource.push) {
    return owner != null && owner == currentUserId;
  }
  if (owner == null) return true;
  return owner == currentUserId;
}

int _byCreatedDesc(AppNotification a, AppNotification b) {
  final byTime = b.createdAt.compareTo(a.createdAt);
  if (byTime != 0) return byTime;
  return a.notificationId.compareTo(b.notificationId);
}
