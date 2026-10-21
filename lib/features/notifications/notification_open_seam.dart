import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/strings.dart';

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

/// Tap entry used until `notification_opener.dart` exists.
///
/// TODO(notifications): when
/// `lib/features/notifications/notification_opener.dart` lands, replace this
/// provider with `notificationOpenerProvider` and call
/// `NotificationOpener.open(note, origin: origin)`. Do not call `markRead`
/// from the list or the banner. `open()` owns the read call and navigation.
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

final notificationOpenSeamProvider = Provider<NotificationOpenSeam>(
  (ref) => const PlaceholderNotificationOpenSeam(),
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
