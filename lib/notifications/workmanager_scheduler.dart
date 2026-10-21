import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:workmanager/workmanager.dart';

import 'background_scheduler.dart';
import 'local_notification_poster.dart';
import 'notification_poll_worker.dart';
import 'shown_notification_store.dart';
import 'system_tray_platform.dart';
import 'tray_notification.dart';

/// What [WorkManagerBackgroundScheduler] asks the platform to register.
class PeriodicWorkRegistration {
  const PeriodicWorkRegistration({
    required this.uniqueName,
    required this.frequency,
    required this.requiresConnectedNetwork,
    required this.keepExisting,
  });

  final String uniqueName;
  final Duration frequency;
  final bool requiresConnectedNetwork;
  final bool keepExisting;
}

abstract interface class PeriodicWorkClient {
  Future<void> registerPeriodic(PeriodicWorkRegistration registration);
  Future<void> cancelByUniqueName(String uniqueName);
}

class RecordingPeriodicWorkClient implements PeriodicWorkClient {
  final List<PeriodicWorkRegistration> registrations = [];
  final List<String> cancelled = [];

  @override
  Future<void> registerPeriodic(PeriodicWorkRegistration registration) async {
    registrations.add(registration);
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    cancelled.add(uniqueName);
  }
}

class WorkmanagerPeriodicWorkClient implements PeriodicWorkClient {
  const WorkmanagerPeriodicWorkClient();

  @override
  Future<void> registerPeriodic(PeriodicWorkRegistration registration) async {
    if (!registration.keepExisting) {
      throw StateError('Notification poll uses the keep policy.');
    }
    if (!registration.requiresConnectedNetwork) {
      throw StateError('Notification poll requires a network connection.');
    }
    await Workmanager().initialize(notificationPollCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      registration.uniqueName,
      registration.uniqueName,
      frequency: registration.frequency,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) {
    return Workmanager().cancelByUniqueName(uniqueName);
  }
}

/// Periodic `GET /api/notifications` via WorkManager.
///
/// The period cannot be under 15 minutes. Existing work is kept. The worker
/// runs only when a network is connected.
class WorkManagerBackgroundScheduler
    implements BackgroundNotificationScheduler {
  WorkManagerBackgroundScheduler({
    PeriodicWorkClient? client,
    this.minInterval = kMinBackgroundPollInterval,
  }) : client = client ?? const WorkmanagerPeriodicWorkClient();

  static const uniqueName = 'vib.notification.poll';

  final PeriodicWorkClient client;

  @override
  final Duration minInterval;

  @override
  bool get enabled => true;

  @override
  Future<void> start() async {
    if (minInterval < kMinBackgroundPollInterval) {
      throw StateError('Background poll interval is below 15 minutes.');
    }
    await client.registerPeriodic(
      PeriodicWorkRegistration(
        uniqueName: uniqueName,
        frequency: minInterval,
        requiresConnectedNetwork: true,
        keepExisting: true,
      ),
    );
  }

  @override
  Future<void> cancel() => client.cancelByUniqueName(uniqueName);
}

BackgroundNotificationScheduler buildBackgroundScheduler({
  required bool enabled,
  PeriodicWorkClient? client,
  Duration minInterval = kMinBackgroundPollInterval,
}) {
  if (!enabled) return const NoopBackgroundNotificationScheduler();
  return WorkManagerBackgroundScheduler(
    client: client,
    minInterval: minInterval,
  );
}

@pragma('vm:entry-point')
void notificationPollCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final result = await runNotificationPollWorker();
      return result != WorkerResult.failed;
    } catch (_) {
      return true;
    }
  });
}

/// Production worker body. Fake mode has no persisted cookie, so it posts nothing.
Future<WorkerResult> runNotificationPollWorker() async {
  final config = ApiConfig.fromEnvironment();
  if (config.useFakeApi || config.baseUrl.isEmpty) {
    return WorkerResult.loggedOut;
  }
  final cookies = SecureCookieStore();
  final header = await cookies.cookieHeader();
  if (header == null || header.isEmpty) return WorkerResult.loggedOut;
  final fetcher = CookieNotificationPollFetcher(
    baseUrl: config.baseUrl,
    cookieHeader: header,
  );
  return NotificationPollWorker.run(
    NotificationPollWorkerDeps(
      session: () async {
        final id = await fetcher.currentUserId();
        if (id == null || id.isEmpty) return null;
        return PollSession(userId: id, cookieHeader: header);
      },
      fetch: (_) => fetcher.fetchNotifications(),
      poster: ResilientTrayPoster(),
      shown: PreferencesShownNotificationStore(),
      cancelWork: () => Workmanager().cancelByUniqueName(
        WorkManagerBackgroundScheduler.uniqueName,
      ),
    ),
  );
}

/// Activity channel when this isolate has one, otherwise the plugin.
class ResilientTrayPoster implements LocalNotificationPoster {
  ResilientTrayPoster({SystemTrayPlatform? tray})
    : _tray = tray ?? FallbackSystemTray();

  final SystemTrayPlatform _tray;

  @override
  Future<void> showGeneric(String text) async {}

  @override
  Future<void> showTray(TrayNotification notification) async {
    await _tray.show(notification);
  }
}
