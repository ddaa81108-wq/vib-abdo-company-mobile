@Tags(['permissions-negative'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/notifications/android_notification_controller.dart';
import 'package:vib_abdo_company_mobile/notifications/background_poll.dart';
import 'package:vib_abdo_company_mobile/notifications/background_scheduler.dart';
import 'package:vib_abdo_company_mobile/notifications/device_registration_client.dart';
import 'package:vib_abdo_company_mobile/notifications/device_token_registrar.dart';
import 'package:vib_abdo_company_mobile/notifications/device_token_store.dart';
import 'package:vib_abdo_company_mobile/notifications/local_notification_poster.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_channels.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_dedup.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_ingress.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_permission_service.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_poll_worker.dart';
import 'package:vib_abdo_company_mobile/notifications/push_drop_log.dart';
import 'package:vib_abdo_company_mobile/notifications/push_payload.dart';
import 'package:vib_abdo_company_mobile/notifications/push_providers.dart';
import 'package:vib_abdo_company_mobile/notifications/push_transport.dart';
import 'package:vib_abdo_company_mobile/notifications/shown_notification_store.dart';
import 'package:vib_abdo_company_mobile/notifications/system_tray_platform.dart';
import 'package:vib_abdo_company_mobile/notifications/tray_notification.dart';
import 'package:vib_abdo_company_mobile/notifications/system_tray_presenter.dart';
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
      title: 'عميل سري 0910000001',
      body: '900',
    );
  }

  Map<String, dynamic> pushMap({
    required String id,
    required String recipient,
    String employeeName = 'الاسم السابق',
  }) {
    return {
      'notificationId': id,
      'recipientUserId': recipient,
      'operationType': 'approve',
      'systemName': 'VIB',
      'createdAt': '2026-10-18T12:00:00Z',
      'employeeName': employeeName,
      'title': 'عميل سري 0910000001',
      'body': '900',
      'phone': '0910000001',
      'token': 'secret-token',
      'amount': 900,
    };
  }

  SystemTrayPresenter presenter({
    required String? Function() userId,
    required RecordingLocalNotificationPoster poster,
    required Future<AppNotification?> Function(String id) reload,
    NotificationIdDedup? dedup,
    ShownNotificationStore? shown,
  }) {
    final memory = dedup ?? NotificationIdDedup();
    return SystemTrayPresenter(
      userId: userId,
      dedup: memory,
      shown: shown ?? MemoryShownNotificationStore(),
      poster: poster,
      reload: reload,
      ingress: NotificationIngress(
        userId: userId,
        dedup: memory,
        drops: PushDropLog(),
        ingest: (items, source) async {},
      ),
    );
  }

  test('push whitelist still excludes employeeName', () {
    expect(pushPayloadKeys.contains('employeeName'), isFalse);
    final clean = whitelistPushPayload(pushMap(id: 'n-1', recipient: 'u_12'));
    expect(clean.containsKey('employeeName'), isFalse);
    expect(clean.containsKey('amount'), isFalse);
    expect(clean.containsKey('phone'), isFalse);
    expect(AppNotification.fromPushPayload(clean).employeeName, isNull);
  });

  test('account change before the GET finishes shows nothing', () async {
    final poster = RecordingLocalNotificationPoster();
    var user = 'u_12';
    const previousName = 'الاسم السابق';
    final delivery = await presenter(
      userId: () => user,
      poster: poster,
      reload: (id) async {
        user = 'u_20';
        return row(id: id, recipient: 'u_12', employeeName: previousName);
      },
    ).presentPush(pushMap(id: 'n-1', recipient: 'u_12'));

    expect(delivery, TrayDelivery.accountChanged);
    expect(poster.trays, isEmpty);
    expect(poster.texts.join(), isNot(contains(previousName)));
  });

  test(
    'a failed GET or a 404 shows no name, and a 401 shows nothing',
    () async {
      final failed = RecordingLocalNotificationPoster();
      final failedDelivery = await presenter(
        userId: () => 'u_12',
        poster: failed,
        reload: (_) async => throw const NetworkException(),
      ).presentPush(pushMap(id: 'n-2', recipient: 'u_12'));
      expect(failedDelivery, TrayDelivery.nameless);
      expect(failed.trays, hasLength(1));
      expect(failed.trays.single.body.contains('الاسم'), isFalse);
      expect(failed.trays.single.publicBody.contains('الاسم'), isFalse);
      expect(failed.trays.single.body.contains('900'), isFalse);
      expect(failed.trays.single.publicBody.contains('900'), isFalse);
      expect(failed.trays.single.body.contains('091'), isFalse);

      final missing = RecordingLocalNotificationPoster();
      final missingDelivery = await presenter(
        userId: () => 'u_12',
        poster: missing,
        reload: (_) async => throw const NotFoundException(
          code: 'NOT_FOUND',
          message: 'غير موجود',
        ),
      ).presentPush(pushMap(id: 'n-3', recipient: 'u_12'));
      expect(missingDelivery, TrayDelivery.notFound);
      expect(missing.trays, isEmpty);

      final wrongUser = RecordingLocalNotificationPoster();
      final wrongDelivery = await presenter(
        userId: () => 'u_12',
        poster: wrongUser,
        reload: (id) async =>
            row(id: id, recipient: 'u_20', employeeName: 'موظف آخر'),
      ).presentPush(pushMap(id: 'n-4', recipient: 'u_12'));
      expect(wrongDelivery, TrayDelivery.notFound);
      expect(wrongUser.trays, isEmpty);

      final expired = RecordingLocalNotificationPoster();
      final expiredDelivery = await presenter(
        userId: () => 'u_12',
        poster: expired,
        reload: (_) async => throw const SessionExpiredException(),
      ).presentPush(pushMap(id: 'n-5', recipient: 'u_12'));
      expect(expiredDelivery, TrayDelivery.sessionEnded);
      expect(expired.trays, isEmpty);
      expect(expired.texts, isEmpty);
    },
  );

  test('the lock-screen public version has no name and no amount', () async {
    final note = row(id: 'n-6', recipient: 'u_12', employeeName: 'علي');
    final tray = trayForServer(note);
    expect(tray.publicTitle, 'VIB');
    expect(tray.publicBody, 'إشعار جديد');
    expect(tray.publicTitle.contains('علي'), isFalse);
    expect(tray.publicBody.contains('علي'), isFalse);
    expect(tray.publicBody.contains('900'), isFalse);
    expect(tray.publicTitle.contains('091'), isFalse);
    expect(tray.body.contains('علي'), isTrue);
    expect(tray.body.contains('900'), isFalse);
    expect(tray.body.contains('091'), isFalse);
    expect(tray.tag, 'n-6');
    expect(tray.androidId, stableAndroidNotificationId('n-6'));
    expect(
      tray.channelArguments['channelId'],
      NotificationChannels.collectionsId,
    );
    expect(tray.channelArguments['publicBody'], 'إشعار جديد');

    final platform = RecordingSystemTrayPlatform();
    final controller = AndroidNotificationController(
      platform: _EnabledPlatform(),
      tray: platform,
    );
    expect(await controller.showPrivateAlert(tray), isTrue);
    final sent = platform.posts.single;
    expect(sent.publicBody.contains('علي'), isFalse);
    expect(sent.publicBody.contains('900'), isFalse);
    expect(sent.publicTitle.contains('علي'), isFalse);
  });

  test('logout cancels the work and a later run shows nothing', () async {
    final client = RecordingPeriodicWorkClient();
    final shown = MemoryShownNotificationStore();
    final scheduler = WorkManagerBackgroundScheduler(client: client);
    await shown.add('n-old');
    await shown.writeCursor('cursor-1');
    final registrar = DeviceTokenRegistrar(
      transport: const NoopPushTransport(),
      permission: const StubNotificationPermissionService(),
      store: MemoryDeviceTokenStore(),
      client: RecordingDeviceRegistrationClient(),
      dedup: NotificationIdDedup(),
      onCancelBackground: () async {
        await shown.clear();
        await scheduler.cancel();
      },
    );
    await registrar.forget();
    expect(client.cancelled, [WorkManagerBackgroundScheduler.uniqueName]);
    expect(await shown.contains('n-old'), isFalse);
    expect(await shown.readCursor(), isNull);

    final poster = RecordingLocalNotificationPoster();
    final result = await NotificationPollWorker.run(
      NotificationPollWorkerDeps(
        session: () async => null,
        fetch: (_) async => throw StateError('logged out'),
        poster: poster,
        shown: shown,
        cancelWork: () async {},
      ),
    );
    expect(result, WorkerResult.loggedOut);
    expect(poster.trays, isEmpty);
  });

  test(
    'a 401 in the worker cancels work and keeps the foreground cookie',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) {
        request.response.statusCode = 401;
        request.response.close();
      });
      final cookies = InMemoryCookieStore();
      await cookies.saveFromSetCookie(['session=keep-me; Path=/']);
      final header = await cookies.cookieHeader();
      final fetcher = CookieNotificationPollFetcher(
        baseUrl: 'http://${server.address.host}:${server.port}',
        cookieHeader: header!,
      );
      final shown = MemoryShownNotificationStore();
      await shown.add('n-old');
      await shown.writeCursor('cursor-1');
      final cancelled = <String>[];
      final poster = RecordingLocalNotificationPoster();
      final result = await NotificationPollWorker.run(
        NotificationPollWorkerDeps(
          session: () async {
            final id = await fetcher.currentUserId();
            if (id == null) return null;
            return PollSession(userId: id, cookieHeader: header);
          },
          fetch: (_) => fetcher.fetchNotifications(),
          poster: poster,
          shown: shown,
          cancelWork: () async {
            cancelled.add(WorkManagerBackgroundScheduler.uniqueName);
          },
        ),
      );
      expect(result, WorkerResult.sessionEnded);
      expect(cancelled, [WorkManagerBackgroundScheduler.uniqueName]);
      expect(await shown.contains('n-old'), isFalse);
      expect(await shown.readCursor(), isNull);
      expect(await cookies.cookieHeader(), contains('session=keep-me'));
      expect(poster.trays, isEmpty);
    },
  );

  test(
    'the worker drops other users and posts nothing while logged out',
    () async {
      final poster = RecordingLocalNotificationPoster();
      final shown = MemoryShownNotificationStore();
      final page = NotificationsPage(
        items: const [],
        unreadCount: 2,
        appNotifications: [
          row(id: 'mine', recipient: 'u_12', employeeName: 'علي'),
          row(id: 'theirs', recipient: 'u_20', employeeName: 'اسم الآخر'),
        ],
      );
      final posted = await NotificationPollWorker.run(
        NotificationPollWorkerDeps(
          session: () async =>
              const PollSession(userId: 'u_12', cookieHeader: 'session=a'),
          fetch: (_) async => page,
          poster: poster,
          shown: shown,
          cancelWork: () async {},
        ),
      );
      expect(posted, WorkerResult.posted);
      expect(poster.trays, hasLength(1));
      expect(poster.trays.single.tag, 'mine');
      expect(poster.trays.single.body.contains('علي'), isTrue);
      expect(poster.trays.single.body.contains('اسم الآخر'), isFalse);
      expect(poster.trays.single.publicBody.contains('علي'), isFalse);

      final quiet = RecordingLocalNotificationPoster();
      var fetched = false;
      final loggedOut = await NotificationPollWorker.run(
        NotificationPollWorkerDeps(
          session: () async => null,
          fetch: (_) async {
            fetched = true;
            return page;
          },
          poster: quiet,
          shown: MemoryShownNotificationStore(),
          cancelWork: () async {},
        ),
      );
      expect(loggedOut, WorkerResult.loggedOut);
      expect(fetched, isFalse);
      expect(quiet.trays, isEmpty);
    },
  );

  test('release builds leave the poll off and stay fake-free', () {
    expect(
      resolveBackgroundNotificationPoll(
        releaseMode: true,
        debugMode: false,
        fakeApi: false,
      ),
      isFalse,
    );
    expect(
      resolveBackgroundNotificationPoll(
        releaseMode: true,
        debugMode: false,
        fakeApi: true,
      ),
      isFalse,
    );
    expect(
      resolveBackgroundNotificationPoll(
        raw: 'false',
        releaseMode: false,
        debugMode: true,
        fakeApi: true,
      ),
      isFalse,
    );
    final client = RecordingPeriodicWorkClient();
    final scheduler = buildBackgroundScheduler(
      enabled: resolveBackgroundNotificationPoll(
        releaseMode: true,
        debugMode: false,
        fakeApi: false,
      ),
      client: client,
    );
    expect(scheduler, isA<NoopBackgroundNotificationScheduler>());
    expect(scheduler.enabled, isFalse);
    expect(
      () => rejectFakeApiInRelease(true, releaseMode: true),
      throwsA(isA<StateError>()),
    );
  });

  for (final failure
      in <({String name, void Function(FakeApiClient client) fail})>[
        (
          name: 'a real push ingest that gets 401 posts nothing and does not escape',
          fail: (client) => client.expireSession(),
        ),
        (
          name: 'a real push ingest that gets a non-CSRF 419 posts nothing and does not escape',
          fail: (client) => client.failNextAuthenticatedStatus = 419,
        ),
      ]) {
    test(failure.name, () async {
      final layer = ApiLayer.create(
        config: const ApiConfig(
          baseUrl: 'https://fake.invalid',
          useFakeApi: true,
        ),
        fakeLatency: Duration.zero,
      );
      addTearDown(layer.dispose);
      await layer.session.login(username: 'employee.demo', password: 'x');
      final poster = RecordingLocalNotificationPoster();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          apiLayerProvider.overrideWithValue(layer),
          localNotificationPosterProvider.overrideWithValue(poster),
          shownNotificationStoreProvider.overrideWithValue(
            MemoryShownNotificationStore(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(notificationsProvider.future);

      final reasons = <String>[];
      final states = layer.session.states.listen((state) {
        if (state is SessionUnauthenticated) {
          reasons.add(state.reason ?? '');
        }
      });
      addTearDown(states.cancel);
      failure.fail(layer.client as FakeApiClient);

      final errors = <Object>[];
      final done = Completer<TrayDelivery>();
      runZonedGuarded(
        () {
          unawaited(
            container
                .read(systemTrayPresenterProvider)
                .presentPush(const {
                  'notificationId': 'n-session',
                  'recipientUserId': 'u_12',
                  'operationType': 'approve',
                  'systemName': 'VIB',
                  'createdAt': '2026-10-18T12:00:00Z',
                  'employeeName': 'لا يُعرض',
                })
                .then(done.complete),
          );
        },
        (error, stack) {
          errors.add(error);
          if (!done.isCompleted) done.completeError(error, stack);
        },
      );

      final delivery = await done.future;
      await Future<void>.delayed(Duration.zero);
      expect(errors, isEmpty);
      expect(delivery, TrayDelivery.sessionEnded);
      expect(poster.trays, isEmpty);
      expect(poster.texts, isEmpty);
      expect(reasons, ['session_expired']);
      expect(
        layer.session.state,
        isA<SessionUnauthenticated>().having(
          (state) => state.reason,
          'reason',
          'session_expired',
        ),
      );
    });
  }
}

class _EnabledPlatform implements NotificationPlatform {
  @override
  Future<void> initialize({
    required String androidIcon,
    void Function(String? payload)? onSelect,
  }) async {}

  @override
  Future<void> createAndroidChannel(NotificationChannelSpec channel) async {}

  @override
  Future<bool?> androidNotificationsEnabled() async => true;

  @override
  Future<void> showAndroid(AndroidNotificationRequest request) async {}

  @override
  Future<void> cancel(int id) async {}
}
