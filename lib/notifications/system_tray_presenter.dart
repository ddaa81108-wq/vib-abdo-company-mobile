import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/error_mapper.dart';

import 'local_notification_poster.dart';
import 'notification_dedup.dart';
import 'notification_ingress.dart';
import 'push_payload.dart';
import 'shown_notification_store.dart';
import 'tray_notification.dart';

enum TrayDelivery {
  posted,
  nameless,
  duplicate,
  loggedOut,
  accountChanged,
  sessionEnded,
  notFound,
  read,
  dropped,
  idle,
}

/// Posts a system notification from a server row, after the user id is checked.
///
/// A push map never supplies [AppNotification.employeeName]. The name is read
/// from the row [reload] returns. If the signed-in user changed while that
/// GET was in flight, nothing is posted.
class SystemTrayPresenter {
  SystemTrayPresenter({
    required this.userId,
    required this.ingress,
    required this.poster,
    required this.reload,
    required this.shown,
    required this.dedup,
  });

  final String? Function() userId;
  final NotificationIngress ingress;
  final LocalNotificationPoster poster;
  final Future<AppNotification?> Function(String id) reload;
  final ShownNotificationStore shown;
  final NotificationIdDedup dedup;

  Future<TrayDelivery> presentPush(Map<String, dynamic> raw) async {
    final started = userId();
    if (started == null || started.isEmpty) return TrayDelivery.loggedOut;
    final id = _notificationId(raw);
    if (id.isEmpty) return TrayDelivery.dropped;
    // acceptPush ingests and then resolves the unread count. A 401/419 throws
    // from that path. It has to stay inside this try: the host does not await
    // presentPush, so a throw becomes an uncaught async error.
    var accepted = false;
    try {
      if (dedup.contains(id) || await shown.contains(id)) {
        return TrayDelivery.duplicate;
      }
      accepted = await ingress.acceptPush(raw);
      if (!accepted) return TrayDelivery.dropped;
      if (userId() != started) return TrayDelivery.accountChanged;

      final server = await reload(id);
      if (userId() != started) return TrayDelivery.accountChanged;
      if (server == null) return TrayDelivery.notFound;
      final owner = server.recipientUserId;
      if (owner != null && owner.isNotEmpty && owner != started) {
        return TrayDelivery.notFound;
      }
      if (server.isRead) return TrayDelivery.read;
      if (userId() != started) return TrayDelivery.accountChanged;
      await _post(server);
      return TrayDelivery.posted;
    } catch (error) {
      if (isUnrecoverableSessionError(error)) return TrayDelivery.sessionEnded;
      if (userId() != started) return TrayDelivery.accountChanged;
      if (_isNotFound(error)) return TrayDelivery.notFound;
      if (!accepted) return TrayDelivery.dropped;
      await _post(_nameless(raw));
      return TrayDelivery.nameless;
    }
  }

  /// Poll rows are already server rows. Other users, read rows, and ids
  /// already in the LRU or the tray store are skipped.
  Future<TrayDelivery> presentPoll(List<AppNotification> rows) async {
    final owner = userId();
    if (owner == null || owner.isEmpty) return TrayDelivery.loggedOut;
    final fresh = ingress.acceptPoll(rows);
    var posted = 0;
    for (final item in fresh) {
      if (userId() != owner) return TrayDelivery.accountChanged;
      if (item.isRead) continue;
      final recipient = item.recipientUserId;
      if (recipient != null && recipient.isNotEmpty && recipient != owner) {
        continue;
      }
      if (await shown.contains(item.notificationId)) continue;
      await _post(item);
      posted++;
    }
    await ingress.deliverFresh(fresh);
    if (userId() != owner) return TrayDelivery.accountChanged;
    return posted == 0 ? TrayDelivery.idle : TrayDelivery.posted;
  }

  Future<void> _post(AppNotification notification) async {
    if (notification.notificationId.isEmpty) return;
    if (await shown.contains(notification.notificationId)) return;
    await shown.add(notification.notificationId);
    await poster.showTray(trayForServer(notification));
  }

  AppNotification _nameless(Map<String, dynamic> raw) {
    final clean = whitelistPushPayload(raw);
    final parsed = AppNotification.fromPushPayload(clean);
    final system = clean['systemName'];
    return AppNotification(
      notificationId: parsed.notificationId,
      systemName: system is String ? system : '',
      employeeName: null,
      operationType: parsed.operationType,
      operationTypeRaw: parsed.operationTypeRaw,
      relatedRef: parsed.relatedRef,
      createdAt: parsed.createdAt,
      readAt: null,
      recipientUserId: parsed.recipientUserId,
    );
  }
}

String _notificationId(Map<String, dynamic> raw) {
  final id = raw['notificationId'] ?? raw['id'];
  if (id == null) return '';
  return '$id'.trim();
}

bool _isNotFound(Object error) => error is NotFoundException;
