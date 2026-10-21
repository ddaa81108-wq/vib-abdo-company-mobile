import 'package:flutter/foundation.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/error_mapper.dart';

import 'local_notification_poster.dart';
import 'notification_ingress.dart';
import 'tray_notification.dart';

/// Raw `--dart-define=BACKGROUND_NOTIFICATION_POLL`. Unset is not `true`.
const String kBackgroundNotificationPollDefine = String.fromEnvironment(
  'BACKGROUND_NOTIFICATION_POLL',
);

/// True only when the define is explicitly true. Release and production leave
/// it unset, so this constant stays false. [resolveBackgroundNotificationPoll]
/// is what selects the scheduler.
const bool kBackgroundNotificationPoll = bool.fromEnvironment(
  'BACKGROUND_NOTIFICATION_POLL',
  defaultValue: false,
);

/// Off in release and production unless the define is `true`.
///
/// Unset: on in debug, and on when `USE_FAKE_API` is true outside release.
/// Explicit `false` stays off, including in debug. Explicit `true` is how the
/// poll is turned on after question 9, including a release build.
bool resolveBackgroundNotificationPoll({
  String? raw,
  bool? releaseMode,
  bool? debugMode,
  bool? fakeApi,
}) {
  final value = (raw ?? kBackgroundNotificationPollDefine).trim().toLowerCase();
  if (value == 'true') return true;
  if (value == 'false') return false;
  if (releaseMode ?? kReleaseMode) return false;
  if (debugMode ?? kDebugMode) return true;
  if (fakeApi ?? kUseFakeApiFromEnvironment) return true;
  return false;
}

enum BackgroundPollResult {
  disabled,
  noSession,
  completed,
  sessionEnded,
  failed,
}

/// One background tick: `GET /api/notifications`, filter, dedup, generic text.
///
/// Runs only when the flag is on and a user id is already in memory. A 401
/// or 419 cancels the scheduler. The poll does not send CSRF and does not
/// mark rows read.
class BackgroundNotificationPoll {
  BackgroundNotificationPoll({
    required this.enabled,
    required this.userId,
    required this.load,
    required this.ingress,
    required this.poster,
    required this.cancelScheduler,
  });

  final bool enabled;
  final String? Function() userId;
  final Future<NotificationsPage> Function() load;
  final NotificationIngress ingress;
  final LocalNotificationPoster poster;
  final Future<void> Function() cancelScheduler;

  Future<BackgroundPollResult> run() async {
    if (!enabled) return BackgroundPollResult.disabled;
    final id = userId();
    if (id == null || id.isEmpty) return BackgroundPollResult.noSession;
    final owner = id;
    try {
      final page = await load();
      if (userId() != owner) return BackgroundPollResult.noSession;
      final fresh = ingress.acceptPoll(page.appNotifications);
      for (final item in fresh) {
        if (userId() != owner) return BackgroundPollResult.noSession;
        if (item.isRead) continue;
        await poster.showTray(trayForServer(item));
      }
      await ingress.deliverFresh(fresh);
      return BackgroundPollResult.completed;
    } catch (error) {
      if (isUnrecoverableSessionError(error)) {
        await cancelScheduler();
        return BackgroundPollResult.sessionEnded;
      }
      return BackgroundPollResult.failed;
    }
  }
}
