import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/strings.dart';
import 'notification_opener.dart' as gate;

/// Where a tap came from. Matches the opener the API engineer will add.
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

/// Tap entry for the list and the banner.
///
/// The default calls [gate.NotificationOpener.open]. List taps use origin
/// `list`. The system tray calls the opener itself with origin `systemTray`.
/// Do not call `markRead` from the list or the banner.
abstract class NotificationOpenSeam {
  Future<NotificationOpenResult> open(
    AppNotification note, {
    required NotificationOpenOrigin origin,
  });
}

/// Placeholder. It does not mark the row read and does not navigate.
class PlaceholderNotificationOpenSeam implements NotificationOpenSeam {
  const PlaceholderNotificationOpenSeam();

  @override
  Future<NotificationOpenResult> open(
    AppNotification note, {
    required NotificationOpenOrigin origin,
  }) async {
    return const NotificationOpenResult();
  }
}

class OpenerNotificationSeam implements NotificationOpenSeam {
  OpenerNotificationSeam(this._ref);

  final Ref _ref;

  @override
  Future<NotificationOpenResult> open(
    AppNotification note, {
    required NotificationOpenOrigin origin,
  }) async {
    final result = await _ref
        .read(gate.notificationOpenerProvider)
        .open(
          note,
          origin: switch (origin) {
            NotificationOpenOrigin.list => gate.NotificationOpenOrigin.list,
            NotificationOpenOrigin.banner => gate.NotificationOpenOrigin.banner,
            NotificationOpenOrigin.systemTray =>
              gate.NotificationOpenOrigin.systemTray,
          },
        );
    return switch (result) {
      gate.NotificationOpenResult.opened => const NotificationOpenResult(
        opened: true,
      ),
      gate.NotificationOpenResult.needsLogin => const NotificationOpenResult(
        needsLogin: true,
      ),
      gate.NotificationOpenResult.forbidden => const NotificationOpenResult(
        forbidden: true,
      ),
      gate.NotificationOpenResult.notFound => const NotificationOpenResult(
        notFound: true,
      ),
      gate.NotificationOpenResult.noTarget => const NotificationOpenResult(
        noTarget: true,
      ),
    };
  }
}

final notificationOpenSeamProvider = Provider<NotificationOpenSeam>(
  OpenerNotificationSeam.new,
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
