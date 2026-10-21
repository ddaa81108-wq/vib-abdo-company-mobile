import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/notifications/background_poll.dart';
import 'package:vib_abdo_company_mobile/notifications/background_scheduler.dart';
import 'package:vib_abdo_company_mobile/notifications/device_registration_client.dart';
import 'package:vib_abdo_company_mobile/notifications/device_token_registrar.dart';
import 'package:vib_abdo_company_mobile/notifications/device_token_store.dart';
import 'package:vib_abdo_company_mobile/notifications/local_notification_poster.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_permission_service.dart';
import 'package:vib_abdo_company_mobile/notifications/push_transport.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_dedup.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_ingress.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_poll_worker.dart';
import 'package:vib_abdo_company_mobile/notifications/push_drop_log.dart';
import 'package:vib_abdo_company_mobile/notifications/shown_notification_store.dart';
import 'package:vib_abdo_company_mobile/notifications/system_tray_presenter.dart';
import 'package:vib_abdo_company_mobile/notifications/tray_notification.dart';
import 'package:vib_abdo_company_mobile/notifications/workmanager_scheduler.dart';
import 'package:vib_abdo_company_mobile/state/notification_providers.dart';

void main() {
  AppNotification row({
    required String id,
    String? recipient,
    String? employeeName,
    String systemName = 'VIB',
    bool read = false,
  }) {
    return AppNotification(
      notificationId: id,
      systemName: systemName,
      employeeName: employeeName,
      operationType: NotificationOperationType.approve,
      operationTypeRaw: 'approve',
      relatedRef: const NotificationRelatedRef(type: 'collection', id: 'sb_1'),
      createdAt: DateTime.utc(2026, 10, 18, 12),
      readAt: read ? DateTime.utc(2026, 10, 18, 13) : null,
      recipientUserId: recipient,
    );
  }

  Map<String, dynamic> pushMap({
    required String id,
    required String recipient,
  }) {
    return {
      'notificationId': id,
      'recipientUserId': recipient,
      'operationType': 'approve',
      'systemName': 'VIB',
      'createdAt': '2026-10-18T12:00:00Z',
      'employeeName': 'من الإشعار الفوري',
      'amount': 900,
    };
  }

  test('scheduling uses at least 15 minutes, the network, and keep', () async {
    final client = RecordingPeriodicWorkClient();
    final scheduler = WorkManagerBackgroundScheduler(client: client);
    await scheduler.start();
    final registration = client.registrations.single;
    expect(
      registration.frequency,
      greaterThanOrEqualTo(kMinBackgroundPollInterval),
    );
    expect(registration.frequency, const Duration(minutes: 15));
    expect(registration.requiresConnectedNetwork, isTrue);
    expect(registration.keepExisting, isTrue);
    expect(registration.uniqueName, WorkManagerBackgroundScheduler.uniqueName);

    final tooSoon = WorkManagerBackgroundScheduler(
      client: client,
      minInterval: const Duration(minutes: 14),
    );
    await expectLater(tooSoon.start(), throwsA(isA<StateError>()));
  });

  test('account switch cancels the periodic work', () async {
    final client = RecordingPeriodicWorkClient();
    final shown = MemoryShownNotificationStore();
    final dedup = NotificationIdDedup()..add('n-old');
    await shown.add('n-old');
    await shown.writeCursor('before-1');
    final scheduler = WorkManagerBackgroundScheduler(client: client);
    await scheduler.start();
    final registrar = DeviceTokenRegistrar(
      transport: const NoopPushTransport(),
      permission: const StubNotificationPermissionService(),
      store: MemoryDeviceTokenStore(),
      client: RecordingDeviceRegistrationClient(),
      dedup: dedup,
      onCancelBackground: () async {
        await shown.clear();
        await scheduler.cancel();
      },
    );
    await syncPushRegistration(
      previous: const SessionPhase(userId: 'u_12'),
      next: const SessionPhase(userId: 'u_20'),
      registrar: registrar,
    );
    expect(client.cancelled, [WorkManagerBackgroundScheduler.uniqueName]);
    expect(dedup.contains('n-old'), isFalse);
    expect(await shown.contains('n-old'), isFalse);
    expect(await shown.readCursor(), isNull);
  });

  test('tray dedup is shared by push, poll, and the worker', () async {
    final poster = RecordingLocalNotificationPoster();
    final shown = MemoryShownNotificationStore();
    final dedup = NotificationIdDedup();
    final server = row(id: 'n-9', recipient: 'u_12', employeeName: 'علي');
    final door = SystemTrayPresenter(
      userId: () => 'u_12',
      dedup: dedup,
      shown: shown,
      poster: poster,
      reload: (_) async => server,
      ingress: NotificationIngress(
        userId: () => 'u_12',
        dedup: dedup,
        drops: PushDropLog(),
        ingest: (items, source) async {},
      ),
    );
    expect(
      await door.presentPush(pushMap(id: 'n-9', recipient: 'u_12')),
      TrayDelivery.posted,
    );
    expect(await door.presentPoll([server]), TrayDelivery.idle);
    expect(poster.trays, hasLength(1));
    expect(poster.trays.single.tag, 'n-9');
    expect(poster.trays.single.androidId, stableAndroidNotificationId('n-9'));
    expect(poster.trays.single.body.contains('من الإشعار'), isFalse);
    expect(poster.trays.single.body.contains('علي'), isTrue);

    final workerPoster = RecordingLocalNotificationPoster();
    final worker = await NotificationPollWorker.run(
      NotificationPollWorkerDeps(
        session: () async =>
            const PollSession(userId: 'u_12', cookieHeader: 'session=a'),
        fetch: (_) async => NotificationsPage(
          items: const [],
          unreadCount: 1,
          appNotifications: [server],
        ),
        poster: workerPoster,
        shown: shown,
        cancelWork: () async {},
      ),
    );
    expect(worker, WorkerResult.idle);
    expect(workerPoster.trays, isEmpty);
  });

  test('the unread count does not increase twice for the same id', () async {
    final layer = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
      fakeLatency: Duration.zero,
    );
    addTearDown(layer.dispose);
    await layer.session.login(username: 'employee.demo', password: 'x');
    final container = ProviderContainer(
      overrides: [apiLayerProvider.overrideWithValue(layer)],
    );
    addTearDown(container.dispose);

    expect(await container.read(unreadNotificationsCountProvider.future), 1);
    final poster = RecordingLocalNotificationPoster();
    final dedup = NotificationIdDedup();
    final door = SystemTrayPresenter(
      userId: () => 'u_12',
      dedup: dedup,
      shown: MemoryShownNotificationStore(),
      poster: poster,
      reload: (id) async {
        await container.read(notificationsProvider.notifier).refresh();
        final items =
            container.read(notificationsProvider).value?.appNotifications ??
            const <AppNotification>[];
        for (final item in items) {
          if (item.notificationId == id) return item;
        }
        return null;
      },
      ingress: NotificationIngress(
        userId: () => 'u_12',
        dedup: dedup,
        drops: PushDropLog(),
        ingest: (items, source) => container
            .read(notificationsProvider.notifier)
            .ingest(items, source: source),
      ),
    );

    await door.presentPush(pushMap(id: '77', recipient: 'u_12'));
    await door.presentPush(pushMap(id: '77', recipient: 'u_12'));

    expect(container.read(unreadNotificationsCountProvider).value, 1);
    final page = container.read(notificationsProvider).value!;
    expect(
      page.appNotifications.where((item) => item.notificationId == '77'),
      hasLength(1),
    );
    expect(poster.trays, hasLength(1));
    expect(poster.trays.single.publicBody.contains('موظف'), isFalse);
  });

  test(
    'fake and debug default the poll on, and an explicit false stays off',
    () {
      expect(kBackgroundNotificationPoll, isFalse);
      expect(
        resolveBackgroundNotificationPoll(
          releaseMode: false,
          debugMode: true,
          fakeApi: false,
        ),
        isTrue,
      );
      expect(
        resolveBackgroundNotificationPoll(
          releaseMode: false,
          debugMode: false,
          fakeApi: true,
        ),
        isTrue,
      );
      expect(
        resolveBackgroundNotificationPoll(
          releaseMode: false,
          debugMode: false,
          fakeApi: false,
        ),
        isFalse,
      );
      expect(
        resolveBackgroundNotificationPoll(raw: 'true', releaseMode: true),
        isTrue,
      );
    },
  );
}
