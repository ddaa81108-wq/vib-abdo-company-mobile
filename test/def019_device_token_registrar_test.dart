import 'dart:convert';

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/notifications/device_registration_client.dart';
import 'package:vib_abdo_company_mobile/notifications/device_token_registrar.dart';
import 'package:vib_abdo_company_mobile/notifications/device_token_store.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_dedup.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_permission_service.dart';
import 'package:vib_abdo_company_mobile/notifications/push_transport.dart';

void main() {
  Future<_Rig> start({String token = 'tok-a'}) async {
    final layer = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
      fakeLatency: Duration.zero,
    );
    addTearDown(layer.dispose);
    final transport = FakePushTransport(token: token);
    addTearDown(transport.dispose);
    final store = MemoryDeviceTokenStore();
    final registrar = DeviceTokenRegistrar(
      transport: transport,
      permission: const StubNotificationPermissionService(grantedValue: true),
      store: store,
      client: HttpDeviceRegistrationClient(layer.client),
      dedup: NotificationIdDedup(),
      currentUserId: () => layer.session.currentUser?.id,
    );
    addTearDown(registrar.dispose);
    await layer.session.login(username: 'employee.demo', password: 'x');
    return _Rig(
      layer: layer,
      transport: transport,
      store: store,
      registrar: registrar,
    );
  }

  test('DEF-019 same token twice posts once', () async {
    final rig = await start();
    await rig.registrar.registerIfReady(signedIn: true);
    await rig.registrar.registerIfReady(signedIn: true);

    expect(rig.fake.mobilePushRegisterPosts, 1);
    expect(_postedToken(rig.fake), 'tok-a');

    rig.registrar.dispose();
    final again = DeviceTokenRegistrar(
      transport: rig.transport,
      permission: const StubNotificationPermissionService(grantedValue: true),
      store: rig.store,
      client: HttpDeviceRegistrationClient(rig.layer.client),
      dedup: NotificationIdDedup(),
      currentUserId: () => rig.layer.session.currentUser?.id,
    );
    addTearDown(again.dispose);
    await again.registerIfReady(signedIn: true);

    expect(rig.fake.mobilePushRegisterPosts, 1);
    final saved = await rig.store.readSuccessfulRegistration();
    expect(saved?.userId, 'u_12');
    expect(saved?.token, 'tok-a');
  });

  test('DEF-019 token change posts the new token', () async {
    final rig = await start();
    await rig.registrar.registerIfReady(signedIn: true);
    expect(rig.fake.mobilePushRegisterPosts, 1);

    rig.transport.setToken('tok-b');
    await _until(() => rig.fake.mobilePushRegisterPosts >= 2);

    expect(rig.fake.mobilePushRegisterPosts, 2);
    expect(_postedToken(rig.fake), 'tok-b');
  });

  test('DEF-019 user switch posts again', () async {
    final rig = await start();
    await rig.registrar.registerIfReady(signedIn: true);
    expect(rig.fake.mobilePushRegisterPosts, 1);

    await rig.layer.session.login(username: 'other.employee', password: 'x');
    await rig.registrar.registerIfReady(signedIn: true);

    expect(rig.layer.session.currentUser?.id, 'u_20');
    expect(rig.fake.mobilePushRegisterPosts, 2);
    expect(_postedToken(rig.fake), 'tok-a');
    expect((await rig.store.readSuccessfulRegistration())?.userId, 'u_20');
  });

  test('DEF-019 failed post is retried', () async {
    final rig = await start();
    rig.fake.failMobilePushDevicesRemaining = 1;

    await rig.registrar.registerIfReady(signedIn: true);
    expect(rig.fake.mobilePushRegisterPosts, 1);
    expect(await rig.store.readSuccessfulRegistration(), isNull);

    await rig.registrar.registerIfReady(signedIn: true);
    expect(rig.fake.mobilePushRegisterPosts, 2);
    expect(_postedToken(rig.fake), 'tok-a');

    await rig.registrar.registerIfReady(signedIn: true);
    expect(rig.fake.mobilePushRegisterPosts, 2);
  });

  test('DEF-019 forget then registerIfReady posts again', () async {
    final rig = await start();
    await rig.registrar.registerIfReady(signedIn: true);
    expect(rig.fake.mobilePushRegisterPosts, 1);

    await rig.registrar.forget();
    expect(await rig.store.read(), isNull);
    expect(await rig.store.readSuccessfulRegistration(), isNull);

    rig.transport.setToken('tok-a');
    await pumpEventQueue();
    expect(rig.fake.mobilePushRegisterPosts, 1);

    await rig.registrar.registerIfReady(signedIn: true);
    expect(rig.fake.mobilePushRegisterPosts, 2);
    expect(_postedToken(rig.fake), 'tok-a');
  });
}

class _Rig {
  _Rig({
    required this.layer,
    required this.transport,
    required this.store,
    required this.registrar,
  });

  final ApiLayer layer;
  final FakePushTransport transport;
  final MemoryDeviceTokenStore store;
  final DeviceTokenRegistrar registrar;

  FakeApiClient get fake => layer.client as FakeApiClient;
}

String? _postedToken(FakeApiClient fake) {
  final raw = fake.lastWireBody;
  if (raw == null || raw.isEmpty) return null;
  final decoded = jsonDecode(raw);
  if (decoded is! Map) return null;
  final token = decoded['token'];
  if (token is! String) return null;
  return token;
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 40; i++) {
    if (done()) return;
    await pumpEventQueue();
  }
}
