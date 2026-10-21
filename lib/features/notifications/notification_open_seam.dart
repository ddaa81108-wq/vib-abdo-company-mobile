import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/notification_providers.dart';
import '../../ui/strings.dart';
import 'notification_opener.dart' as opener;

/// Where a tap came from. Same order as [opener.NotificationOpenOrigin].
enum NotificationOpenOrigin { list, banner, systemTray }

/// Result of opening a notification. The UI does not decide the route.
class NotificationOpenResult {
  const NotificationOpenResult({
    this.opened = false,
    this.needsLogin = false,
    this.forbidden = false,
    this.notFound = false,
    this.noTarget = false,
  });

  final bool opened;
  final bool needsLogin;
  final bool forbidden;
  final bool notFound;
  final bool noTarget;
}

/// Tap entry. The list and the banner call this; navigation and the read
/// live in [opener.NotificationOpener].
abstract class NotificationOpenSeam {
  Future<NotificationOpenResult> open(
    AppNotification note, {
    required NotificationOpenOrigin origin,
  });
}

/// Calls [opener.NotificationOpener.open]. That method already marks a row
/// read through [notificationsProvider] for an open, a missing target, and a
/// missing card. This adapter marks read only when [open] did not, and never
/// when the result is [opener.NotificationOpenResult.needsLogin].
class OpenerNotificationSeam implements NotificationOpenSeam {
  OpenerNotificationSeam(this._ref);

  final Ref _ref;

  @override
  Future<NotificationOpenResult> open(
    AppNotification note, {
    required NotificationOpenOrigin origin,
  }) async {
    final result = await _ref
        .read(opener.notificationOpenerProvider)
        .open(note, origin: _origin(origin));
    if (_shouldMark(result)) {
      try {
        await _ref
            .read(notificationsProvider.notifier)
            .markRead(note.notificationId);
      } catch (_) {
        // A failed read must not block the route [open] already chose.
      }
    }
    return _result(result);
  }

  opener.NotificationOpenOrigin _origin(NotificationOpenOrigin origin) {
    return switch (origin) {
      NotificationOpenOrigin.list => opener.NotificationOpenOrigin.list,
      NotificationOpenOrigin.banner => opener.NotificationOpenOrigin.banner,
      NotificationOpenOrigin.systemTray =>
        opener.NotificationOpenOrigin.systemTray,
    };
  }

  bool _shouldMark(opener.NotificationOpenResult result) {
    return switch (result) {
      opener.NotificationOpenResult.needsLogin ||
      opener.NotificationOpenResult.opened ||
      opener.NotificationOpenResult.noTarget ||
      opener.NotificationOpenResult.notFound => false,
      opener.NotificationOpenResult.forbidden => true,
    };
  }

  NotificationOpenResult _result(opener.NotificationOpenResult result) {
    return switch (result) {
      opener.NotificationOpenResult.opened => const NotificationOpenResult(
        opened: true,
      ),
      opener.NotificationOpenResult.needsLogin => const NotificationOpenResult(
        needsLogin: true,
      ),
      opener.NotificationOpenResult.forbidden => const NotificationOpenResult(
        forbidden: true,
      ),
      opener.NotificationOpenResult.notFound => const NotificationOpenResult(
        notFound: true,
      ),
      opener.NotificationOpenResult.noTarget => const NotificationOpenResult(
        noTarget: true,
      ),
    };
  }
}

final notificationOpenSeamProvider = Provider<NotificationOpenSeam>(
  (ref) => OpenerNotificationSeam(ref),
);

void showNotificationOpenResult(
  BuildContext context,
  NotificationOpenResult result,
) {
  final message = result.notFound
      ? AppStrings.notificationNotFound
      : result.noTarget
      ? AppStrings.notificationNoTarget
      : null;
  if (message == null) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
