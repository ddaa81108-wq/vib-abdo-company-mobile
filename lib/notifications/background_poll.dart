import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/error_mapper.dart';

import 'local_notification_poster.dart';
import 'notification_ingress.dart';
import 'push_payload.dart';

/// Off unless `--dart-define=BACKGROUND_NOTIFICATION_POLL=true`.
const bool kBackgroundNotificationPoll = bool.fromEnvironment(
  'BACKGROUND_NOTIFICATION_POLL',
  defaultValue: false,
);

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
    try {
      final page = await load();
      final fresh = ingress.acceptPoll(page.appNotifications);
      for (final item in fresh) {
        if (item.isRead) continue;
        await poster.showGeneric(genericNotificationText(item));
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
