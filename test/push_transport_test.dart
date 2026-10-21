import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/notifications/background_poll.dart';
import 'package:vib_abdo_company_mobile/notifications/background_scheduler.dart';
import 'package:vib_abdo_company_mobile/notifications/device_registration_client.dart';
import 'package:vib_abdo_company_mobile/notifications/device_token_registrar.dart';
import 'package:vib_abdo_company_mobile/notifications/device_token_store.dart';
import 'package:vib_abdo_company_mobile/notifications/local_notification_poster.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_dedup.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_ingress.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_permission_service.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_signal_bridge.dart';
import 'package:vib_abdo_company_mobile/notifications/push_drop_log.dart';
import 'package:vib_abdo_company_mobile/notifications/push_payload.dart';
import 'package:vib_abdo_company_mobile/notifications/push_transport.dart';
import 'package:vib_abdo_company_mobile/state/notification_merge.dart';

void main() {
  AppNotification row({
    required String id,
    String? recipient,
    String? title,
    String systemName = 'VIB',
    bool read = false,
  }) {
    return AppNotification(
      notificationId: id,
      systemName: systemName,
      employeeName: 'موظف سري',
      operationType: NotificationOperationType.approve,
      operationTypeRaw: 'approve',
      relatedRef: const NotificationRelatedRef(type: 'collection', id: 'sb_1'),
      createdAt: DateTime.utc(2026, 10, 18, 12),
      readAt: read ? DateTime.utc(2026, 10, 18, 13) : null,
      recipientUserId: recipient,
      title: title,
      body: '900',
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
      'relatedRef': {
        'type': 'collection',
        'id': 'sb_1',
        'name': 'عميل سري',
        'units': 900,
      },
      'title': 'عميل سري 0910000001',
      'body': '900',
      'employeeName': 'موظف سري',
      'phone': '0910000001',
      'token': 'secret-token',
      'amount': 900,
    };
  }

  NotificationIngress ingress({
    required List<AppNotification> ingested,
    required List<NotificationSource> sources,
    String? user = 'u_12',
    NotificationIdDedup? dedup,
    PushDropLog? drops,
  }) {
    return NotificationIngress(
      userId: () => user,
      dedup: dedup ?? NotificationIdDedup(),
      drops: drops ?? PushDropLog(),
      ingest: (items, source) async {
        sources.add(source);
        ingested.addAll(items);
      },
    );
  }

  test(
    'push transport defaults to noop and fcm is a token-less stub',
    () async {
      expect(parsePushTransport(''), PushTransportKind.noop);
      expect(parsePushTransport('fake'), PushTransportKind.fake);
      expect(parsePushTransport('fcm'), PushTransportKind.fcm);
      expect(createPushTransport(''), isA<NoopPushTransport>());

      const fcm = FcmPushTransport();
      expect(await fcm.currentToken(), isNull);
      expect(fcm.registersDevices, isTrue);
      final devices = RecordingDeviceRegistrationClient();
      final registered = DeviceTokenRegistrar(
        transport: fcm,
        permission: const StubNotificationPermissionService(grantedValue: true),
        store: MemoryDeviceTokenStore(),
        client: devices,
        dedup: NotificationIdDedup(),
      );
      await registered.registerIfReady(signedIn: true);
      expect(devices.registered, isEmpty);
    },
  );

  test('a duplicate id from push and poll is ingested once', () async {
    final ingested = <AppNotification>[];
    final sources = <NotificationSource>[];
    final door = ingress(ingested: ingested, sources: sources);

    expect(
      await door.acceptPush(pushMap(id: 'n-1', recipient: 'u_12')),
      isTrue,
    );
    await door.deliverPoll([
      row(id: 'n-1', recipient: 'u_12', title: 'عميل سري'),
    ]);

    expect(door.ingestCalls, 1);
    expect(ingested, hasLength(1));
    expect(sources, [NotificationSource.push]);
    expect(ingested.single.title, isNull);
    expect(ingested.single.body, isNull);
    expect(ingested.single.employeeName, isNull);
  });

  test('non-whitelisted keys never reach the notification text', () {
    final clean = whitelistPushPayload(pushMap(id: 'n-1', recipient: 'u_12'));
    expect(clean.keys, isNot(contains('title')));
    expect(clean.keys, isNot(contains('body')));
    expect(clean.keys, isNot(contains('phone')));
    expect(clean.keys, isNot(contains('token')));
    expect(clean.keys, isNot(contains('amount')));
    expect(clean.keys, isNot(contains('employeeName')));
    expect(clean['relatedRef'], {'type': 'collection', 'id': 'sb_1'});

    final item = AppNotification.fromPushPayload(clean);
    final text = genericNotificationText(item);
    expect(text, 'VIB · اعتماد');
    expect(text.contains('سر'), isFalse);
    expect(text.contains('900'), isFalse);
    expect(text.contains('091'), isFalse);
    expect(text.contains('secret'), isFalse);
    expect(text.contains('sb_1'), isFalse);
    expect(item.title, isNull);
    expect(item.body, isNull);
  });

  test('logged-out push and poll rows are dropped', () async {
    final drops = PushDropLog();
    final door = ingress(ingested: [], sources: [], user: null, drops: drops);

    expect(
      await door.acceptPush(pushMap(id: 'n-1', recipient: 'u_12')),
      isFalse,
    );
    expect(door.acceptPoll([row(id: 'n-2')]), isEmpty);
    expect(drops.loggedOut, 2);
    expect(door.ingestCalls, 0);
  });

  test('the connect resync does not refresh, and a later signal does', () {
    var calls = 0;
    final clock = _ManualClock();
    final bridge = NotificationSignalBridge(
      refresh: () async {
        calls++;
      },
      wait: const Duration(milliseconds: 400),
      startDelay: clock.schedule,
    );
    bridge.onSignal(RealtimeSignal.resync);
    clock.elapse(const Duration(seconds: 1));
    expect(calls, 0);

    bridge.onSignal(
      const RealtimeSignal(sequence: 4, topic: 'collection.changed'),
    );
    bridge.onSignal(
      const RealtimeSignal(sequence: 5, topic: 'customer.changed'),
    );
    clock.elapse(const Duration(milliseconds: 399));
    expect(calls, 0);
    clock.elapse(const Duration(milliseconds: 1));
    expect(calls, 1);
    expect(bridge.refreshCalls, 1);
  });

  test('background poll is off by default and release stays fake-free', () {
    expect(kBackgroundNotificationPoll, isFalse);
    const scheduler = NoopBackgroundNotificationScheduler();
    expect(scheduler.enabled, isFalse);
    expect(scheduler.minInterval, const Duration(minutes: 15));
    expect(
      () => rejectFakeApiInRelease(true, releaseMode: true),
      throwsA(isA<StateError>()),
    );
    rejectFakeApiInRelease(false, releaseMode: true);
    const ReleaseFakeApiGuard();
  });

  test(
    'an enabled poll shows generic text and stops on session expiry',
    () async {
      final poster = RecordingLocalNotificationPoster();
      final ingested = <AppNotification>[];
      final sources = <NotificationSource>[];
      final door = ingress(ingested: ingested, sources: sources);
      var cancelled = false;
      final poll = BackgroundNotificationPoll(
        enabled: true,
        userId: () => 'u_12',
        load: () async => NotificationsPage(
          items: const [],
          unreadCount: 1,
          appNotifications: [row(id: 'n-9', title: 'عميل سري 0910000001')],
        ),
        ingress: door,
        poster: poster,
        cancelScheduler: () async => cancelled = true,
      );

      expect(await poll.run(), BackgroundPollResult.completed);
      expect(poster.texts, ['VIB · اعتماد']);
      expect(poster.texts.single.contains('سر'), isFalse);
      expect(poster.texts.single.contains('091'), isFalse);
      expect(sources, [NotificationSource.poll]);
      expect(cancelled, isFalse);

      final expired = BackgroundNotificationPoll(
        enabled: true,
        userId: () => 'u_12',
        load: () async => throw const SessionExpiredException(),
        ingress: door,
        poster: poster,
        cancelScheduler: () async => cancelled = true,
      );
      expect(await expired.run(), BackgroundPollResult.sessionEnded);
      expect(cancelled, isTrue);

      final disabled = BackgroundNotificationPoll(
        enabled: false,
        userId: () => 'u_12',
        load: () async => throw StateError('should not load'),
        ingress: door,
        poster: poster,
        cancelScheduler: () async {},
      );
      expect(await disabled.run(), BackgroundPollResult.disabled);
    },
  );

  test(
    'the in-process scheduler refuses an interval under 15 minutes',
    () async {
      final scheduler = InProcessBackgroundNotificationScheduler(
        minInterval: const Duration(minutes: 14),
        poll: () async {},
      );
      await expectLater(scheduler.start(), throwsA(isA<StateError>()));
    },
  );
}

class _ManualClock {
  var elapsed = Duration.zero;
  final _jobs = <_ClockJob>[];

  DelayHandle schedule(Duration delay, void Function() callback) {
    final job = _ClockJob(elapsed + delay, callback);
    _jobs.add(job);
    return job;
  }

  void elapse(Duration delta) {
    elapsed += delta;
    final due = [
      for (final job in _jobs)
        if (!job.cancelled && job.at <= elapsed) job,
    ];
    for (final job in due) {
      _jobs.remove(job);
      if (!job.cancelled) job.callback();
    }
  }
}

class _ClockJob implements DelayHandle {
  _ClockJob(this.at, this.callback);

  final Duration at;
  final void Function() callback;
  var cancelled = false;

  @override
  void cancel() => cancelled = true;
}
