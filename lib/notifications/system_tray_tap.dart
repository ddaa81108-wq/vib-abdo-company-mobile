import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/notifications/notification_opener.dart';
import '../state/notification_providers.dart';
import '../state/router_provider.dart';
import '../state/session_providers.dart';

/// Notification id from a system-tray tap, kept until the session can open it.
class PendingTraySelection {
  String? notificationId;
}

final pendingTraySelectionProvider = Provider<PendingTraySelection>(
  (ref) => PendingTraySelection(),
);

/// Cold start and a later tap. The payload is the notification id.
class SystemTrayTapHandler {
  SystemTrayTapHandler(this._ref);

  final Ref _ref;

  Future<void> openPayload(String? payload) async {
    final id = payload?.trim();
    if (id == null || id.isEmpty) return;
    _ref.read(pendingTraySelectionProvider).notificationId = id;
    await resume();
  }

  Future<void> resume() async {
    final pending = _ref.read(pendingTraySelectionProvider);
    final id = pending.notificationId;
    if (id == null || id.isEmpty) return;
    final session = _ref.read(sessionStateProvider);
    if (session is SessionUnknown) return;
    if (session is! SessionAuthenticated) {
      _ref.read(routerProvider).go('/login');
      return;
    }
    var match = _find(id);
    if (match == null) {
      try {
        await _ref.read(notificationsProvider.notifier).refresh();
      } catch (_) {}
      match = _find(id);
    }
    if (match == null) {
      pending.notificationId = null;
      return;
    }
    pending.notificationId = null;
    await _ref
        .read(notificationOpenerProvider)
        .open(match, origin: NotificationOpenOrigin.systemTray);
  }

  AppNotification? _find(String id) {
    final items =
        _ref.read(notificationsProvider).value?.appNotifications ??
        const <AppNotification>[];
    for (final item in items) {
      if (item.notificationId == id) return item;
    }
    return null;
  }
}

final systemTrayTapHandlerProvider = Provider<SystemTrayTapHandler>(
  SystemTrayTapHandler.new,
);
