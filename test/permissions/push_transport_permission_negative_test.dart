@Tags(['permissions-negative'])
library;

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/notifications/device_registration_client.dart';
import 'package:vib_abdo_company_mobile/notifications/device_token_registrar.dart';
import 'package:vib_abdo_company_mobile/notifications/device_token_store.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_dedup.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_ingress.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_permission_service.dart';
import 'package:vib_abdo_company_mobile/notifications/push_drop_log.dart';
import 'package:vib_abdo_company_mobile/notifications/push_transport.dart';
import 'package:vib_abdo_company_mobile/state/notification_merge.dart';

void main() {
  Future<ApiLayer> layerWith(PushSessionGate gate) async {
    final layer = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
      fakeLatency: Duration.zero,
      cleanups: [gate.forget],
    );
    addTearDown(layer.dispose);
    return layer;
  }

  DeviceTokenRegistrar registrar({
    required PushTransport transport,
    required DeviceTokenStore store,
    required RecordingDeviceRegistrationClient devices,
    required NotificationIdDedup dedup,
    bool granted = true,
  }) {
    return DeviceTokenRegistrar(
      transport: transport,
      permission: StubNotificationPermissionService(grantedValue: granted),
      store: store,
      client: devices,
      dedup: dedup,
    );
  }

  Map<String, dynamic> payload({
    required String id,
    required String recipient,
  }) {
    return {
      'notificationId': id,
      'recipientUserId': recipient,
      'operationType': 'approve',
      'systemName': 'VIB',
      'createdAt': '2026-10-18T12:00:00Z',
      'title': 'must-not-leak',
      'phone': '0910000001',
      'token': 'secret-token',
    };
  }

  test('logout unregisters and clears the device token', () async {
    final gate = PushSessionGate();
    final store = MemoryDeviceTokenStore();
    final devices = RecordingDeviceRegistrationClient();
    final transport = FakePushTransport(token: 'device-token');
    final dedup = NotificationIdDedup();
    final registered = registrar(
      transport: transport,
      store: store,
      devices: devices,
      dedup: dedup,
    );
    gate.onForget = registered.forget;
    final layer = await layerWith(gate);

    await layer.session.login(username: 'employee.demo', password: 'x');
    await registered.registerIfReady(signedIn: true);
    expect(devices.registered, ['device-token']);
    expect(await store.read(), 'device-token');

    await layer.session.logout();

    expect(layer.session.state, isA<SessionUnauthenticated>());
    expect(await store.read(), isNull);
    expect(devices.unregistered, ['device-token']);
    expect(transport.deleted, isTrue);
    expect(dedup.length, 0);
  });

  test(
    'a failed unregister still clears the token and finishes logout',
    () async {
      final gate = PushSessionGate();
      final store = MemoryDeviceTokenStore();
      final devices = RecordingDeviceRegistrationClient()
        ..unregisterError = StateError('down');
      final transport = FakePushTransport(token: 'device-token');
      final registered = registrar(
        transport: transport,
        store: store,
        devices: devices,
        dedup: NotificationIdDedup(),
      );
      gate.onForget = registered.forget;
      final layer = await layerWith(gate);
      await layer.session.login(username: 'employee.demo', password: 'x');
      await store.write('device-token');

      await layer.session.logout();

      expect(layer.session.state, isA<SessionUnauthenticated>());
      expect(await store.read(), isNull);
      expect(devices.unregistered, isEmpty);
    },
  );

  test(
    'a payload for the previous user is dropped after an account switch',
    () async {
      final store = MemoryDeviceTokenStore();
      final devices = RecordingDeviceRegistrationClient();
      final dedup = NotificationIdDedup();
      final drops = PushDropLog();
      final transport = FakePushTransport(token: 'device-token');
      final registered = registrar(
        transport: transport,
        store: store,
        devices: devices,
        dedup: dedup,
      );
      final layer = ApiLayer.create(
        config: const ApiConfig(
          baseUrl: 'https://fake.invalid',
          useFakeApi: true,
        ),
        fakeLatency: Duration.zero,
      );
      addTearDown(layer.dispose);
      final ingested = <AppNotification>[];
      final ingress = NotificationIngress(
        userId: () => layer.session.currentUser?.id,
        dedup: dedup,
        drops: drops,
        ingest: (items, source) async => ingested.addAll(items),
      );

      await layer.session.login(username: 'employee.demo', password: 'x');
      expect(layer.session.currentUser?.id, 'u_12');
      await registered.registerIfReady(signedIn: true);
      expect(
        await ingress.acceptPush(payload(id: 'n-a', recipient: 'u_12')),
        isTrue,
      );

      await layer.session.login(username: 'other.employee', password: 'x');
      await syncPushRegistration(
        previous: const SessionPhase(userId: 'u_12'),
        next: const SessionPhase(userId: 'u_20'),
        registrar: registered,
      );

      expect(layer.session.currentUser?.id, 'u_20');
      expect(await store.read(), isNull);
      expect(devices.unregistered, ['device-token']);
      expect(
        await ingress.acceptPush(payload(id: 'n-b', recipient: 'u_12')),
        isFalse,
      );
      expect(drops.wrongUser, 1);
      expect(ingested.map((item) => item.notificationId), ['n-a']);
      expect(ingested.single.recipientUserId, 'u_12');
    },
  );

  test('a push with no recipientUserId is dropped', () async {
    final drops = PushDropLog();
    final ingested = <AppNotification>[];
    final ingress = NotificationIngress(
      userId: () => 'u_12',
      dedup: NotificationIdDedup(),
      drops: drops,
      ingest: (items, source) async {
        expect(source, NotificationSource.push);
        ingested.addAll(items);
      },
    );

    final kept = await ingress.acceptPush({
      'notificationId': 'n-missing',
      'operationType': 'approve',
      'systemName': 'VIB',
      'createdAt': '2026-10-18T12:00:00Z',
      'customerName': 'سر',
      'amount': 900,
    });

    expect(kept, isFalse);
    expect(drops.missingRecipient, 1);
    expect(ingested, isEmpty);
    expect(drops.wrongUser, 0);
  });

  test('the noop transport does not call the device endpoint', () async {
    final devices = RecordingDeviceRegistrationClient();
    final registered = registrar(
      transport: const NoopPushTransport(),
      store: MemoryDeviceTokenStore(),
      devices: devices,
      dedup: NotificationIdDedup(),
    );

    await registered.registerIfReady(signedIn: true);

    expect(devices.registered, isEmpty);
    expect(devices.unregistered, isEmpty);
  });
}
