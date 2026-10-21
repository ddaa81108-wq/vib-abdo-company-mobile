import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_client.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_api_layer/data/fake/fake_fixtures.dart';
import 'package:flutter_api_layer/data/repositories/notifications_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_screen.dart';
import 'package:vib_abdo_company_mobile/main.dart' as app_root;
import 'package:vib_abdo_company_mobile/notifications/background_scheduler.dart';
import 'package:vib_abdo_company_mobile/notifications/shown_notification_store.dart';
import 'package:vib_abdo_company_mobile/state/connectivity.dart';
import 'package:vib_abdo_company_mobile/features/forbidden/forbidden_screen.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/features/notifications/foreground_notification_banner.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notification_permission.dart';
import 'package:vib_abdo_company_mobile/notifications/device_registration_client.dart';
import 'package:vib_abdo_company_mobile/notifications/device_token_registrar.dart';
import 'package:vib_abdo_company_mobile/notifications/device_token_store.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_dedup.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_permission_service.dart';
import 'package:vib_abdo_company_mobile/notifications/push_providers.dart';
import 'package:vib_abdo_company_mobile/notifications/push_transport.dart';
import 'package:vib_abdo_company_mobile/notifications/unread_badge.dart';
import 'package:vib_abdo_company_mobile/state/notification_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('granting permission registers with signedIn true', (
    tester,
  ) async {
    final permission = FakeNotificationPermissionService(
      initial: NotificationPermissionChoice.denied,
      afterRequest: NotificationPermissionChoice.granted,
    );
    final registrar = RecordingDeviceTokenRegistrar();
    await pumpFakeApp(
      tester,
      notificationsPermission: permission,
      overrides: [deviceTokenRegistrarProvider.overrideWithValue(registrar)],
    );
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    registrar.clear();

    await go(tester, '/notifications');
    await tester.tap(find.byKey(const Key('notification-permission-agree')));
    await settle(tester);

    expect(permission.requested, isTrue);
    expect(registrar.registerSignedIn, [true]);
    expect(registrar.forgets, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('denying permission forgets the device', (tester) async {
    final permission = FakeNotificationPermissionService(
      initial: NotificationPermissionChoice.denied,
      afterRequest: NotificationPermissionChoice.denied,
    );
    final registrar = RecordingDeviceTokenRegistrar();
    await pumpFakeApp(
      tester,
      notificationsPermission: permission,
      overrides: [deviceTokenRegistrarProvider.overrideWithValue(registrar)],
    );
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    registrar.clear();

    await go(tester, '/notifications');
    await tester.tap(find.byKey(const Key('notification-permission-later')));
    await settle(tester);

    expect(permission.requested, isFalse);
    expect(registrar.registerSignedIn, isEmpty);
    expect(registrar.forgets, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('revoking permission on resume forgets the device', (
    tester,
  ) async {
    final permission = FakeNotificationPermissionService(
      initial: NotificationPermissionChoice.granted,
    );
    final registrar = RecordingDeviceTokenRegistrar();
    await pumpFakeApp(
      tester,
      notificationsPermission: permission,
      overrides: [deviceTokenRegistrarProvider.overrideWithValue(registrar)],
    );
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    registrar.clear();

    permission.initial = NotificationPermissionChoice.denied;
    await resume(tester);

    expect(registrar.registerSignedIn, isEmpty);
    expect(registrar.forgets, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a grant while signed out registers with signedIn false', (
    tester,
  ) async {
    final permission = FakeNotificationPermissionService(
      initial: NotificationPermissionChoice.granted,
    );
    final registrar = RecordingDeviceTokenRegistrar();
    await pumpFakeApp(
      tester,
      notificationsPermission: permission,
      overrides: [deviceTokenRegistrarProvider.overrideWithValue(registrar)],
    );
    expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
    registrar.clear();

    await resume(tester);

    expect(registrar.registerSignedIn, [false]);
    expect(registrar.forgets, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a list tap marks the row read once', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(320, 568));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/notifications');
    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '1');

    await tester.tap(find.byKey(const Key('notice-77')));
    await until(tester, find.byKey(CollectionsScreen.screenKey));
    await settle(tester);

    expect(find.byKey(CollectionsScreen.screenKey), findsOneWidget);
    expect(fake.notificationMutationApplies, 1);
    expect(find.byKey(UnreadBadge.badgeKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a banner tap marks the row read once', (tester) async {
    final bus = StreamController<AppNotification>.broadcast();
    addTearDown(bus.close);
    final layer = await pumpFakeApp(
      tester,
      size: const Size(320, 568),
      overrides: [
        foregroundNotificationsProvider.overrideWith((ref) => bus.stream),
      ],
    );
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '1');

    bus.add(_ownedCollection());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(ForegroundNotificationBanner.bannerKey));
    await until(tester, find.byKey(CollectionsScreen.screenKey));
    await settle(tester);

    expect(find.byKey(CollectionsScreen.screenKey), findsOneWidget);
    expect(fake.notificationMutationApplies, 1);
    expect(find.byKey(UnreadBadge.badgeKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a banner tap while signed out does not mark read', (
    tester,
  ) async {
    final bus = StreamController<AppNotification>.broadcast();
    addTearDown(bus.close);
    final layer = await pumpFakeApp(
      tester,
      overrides: [
        foregroundNotificationsProvider.overrideWith((ref) => bus.stream),
      ],
    );
    final fake = layer.client as FakeApiClient;
    expect(find.byKey(LoginScreen.screenKey), findsOneWidget);

    bus.add(_ownedCollection());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(ForegroundNotificationBanner.bannerKey));
    await settle(tester);

    expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
    expect(fake.notificationMutationApplies, 0);
    expect(
      (layer.notifications as RemoteNotificationsRepository)
          .attemptedWriteRequestIds,
      isEmpty,
    );
    expect(find.byKey(UnreadBadge.badgeKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a same-user forbidden list tap marks the row read once', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(320, 568));
    final fake = layer.client as FakeApiClient;
    fake.stageNotification({
      'id': 'n-own',
      'action': 'approve',
      'title': 'شركة سرية',
      'section': 'companies',
      'entityId': 'co_1',
      'readAt': null,
      'createdAt': '2026-10-19T12:00:00+02:00',
      'systemName': 'الشركات',
      'recipientUserId': FakeFixtures.demoEmployeeId,
    }, unreadCount: 2);
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/notifications');
    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '2');
    final writes = (layer.notifications as RemoteNotificationsRepository)
        .attemptedWriteRequestIds
        .length;

    await tester.tap(find.byKey(const Key('notice-n-own')));
    await until(tester, find.byKey(ForbiddenScreen.screenKey));
    await settle(tester);

    expect(find.byKey(ForbiddenScreen.screenKey), findsOneWidget);
    expect(find.text(AppStrings.forbidden), findsWidgets);
    expect(find.text('شركة سرية'), findsNothing);
    expect(fake.notificationMutationApplies, 1);
    expect(
      (layer.notifications as RemoteNotificationsRepository)
          .attemptedWriteRequestIds
          .length,
      writes + 1,
    );
    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('another user on the banner is not marked read', (tester) async {
    final bus = StreamController<AppNotification>.broadcast();
    addTearDown(bus.close);
    final layer = await pumpFakeApp(
      tester,
      overrides: [
        foregroundNotificationsProvider.overrideWith((ref) => bus.stream),
      ],
    );
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '1');
    final writes = (layer.notifications as RemoteNotificationsRepository)
        .attemptedWriteRequestIds
        .length;

    bus.add(
      _ownedCollection(id: '88', recipient: FakeFixtures.otherEmployeeId),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(ForegroundNotificationBanner.bannerKey));
    await until(tester, find.byKey(ForbiddenScreen.screenKey));
    await settle(tester);

    expect(find.byKey(ForbiddenScreen.screenKey), findsOneWidget);
    expect(fake.notificationMutationApplies, 0);
    expect(
      (layer.notifications as RemoteNotificationsRepository)
          .attemptedWriteRequestIds
          .length,
      writes,
    );
    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('allow posts the device token once', (tester) async {
    const token = 'qa-device-token';
    final permission = FakeNotificationPermissionService(
      initial: NotificationPermissionChoice.denied,
      afterRequest: NotificationPermissionChoice.granted,
    );
    final log = await _pumpDevicePost(tester, permission, token);
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    expect(log.devicePosts, isEmpty);

    await go(tester, '/notifications');
    await tester.tap(find.byKey(const Key('notification-permission-agree')));
    await settle(tester);

    expect(log.devicePosts, [
      {'token': token, 'platform': 'android'},
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grant then resume posts the device token once', (tester) async {
    const token = 'qa-device-token';
    final permission = FakeNotificationPermissionService(
      initial: NotificationPermissionChoice.denied,
      afterRequest: NotificationPermissionChoice.granted,
    );
    final log = await _pumpDevicePost(tester, permission, token);
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/notifications');
    await tester.tap(find.byKey(const Key('notification-permission-agree')));
    await settle(tester);
    expect(log.devicePosts, hasLength(1));

    await resume(tester);

    expect(log.devicePosts, [
      {'token': token, 'platform': 'android'},
    ]);
    expect(tester.takeException(), isNull);
  });
}

AppNotification _ownedCollection({
  String id = '77',
  String recipient = FakeFixtures.demoEmployeeId,
  String type = 'collection',
  String entityId = 'sb_1',
}) {
  return AppNotification(
    notificationId: id,
    systemName: 'الاستلامات',
    employeeName: 'موظف استلام تجريبي',
    operationType: NotificationOperationType.collectionSubmit,
    operationTypeRaw: 'collection.submit',
    relatedRef: NotificationRelatedRef(type: type, id: entityId),
    createdAt: DateTime.utc(2026, 10, 18, 12),
    readAt: null,
    recipientUserId: recipient,
    title: 'استلام جديد بانتظار المراجعة',
    body: 'افتح قسم الاستلامات',
  );
}

/// Sees the POST the real [HttpDeviceRegistrationClient] sends. The registrar
/// and that client stay on the root scope.
class _DevicePostLog {
  final List<Map<String, Object?>> devicePosts = [];
}

class _ObservingGateway implements ApiClient {
  _ObservingGateway(this._fake, this._log);

  final FakeApiClient _fake;
  final _DevicePostLog _log;

  void _note(String method, String path, Object? body) {
    if (method != 'POST' || path != ApiEndpoints.proposedMobilePushDevices) {
      return;
    }
    final posted = body is Map
        ? Map<String, Object?>.from(body)
        : <String, Object?>{'body': body};
    _log.devicePosts.add(posted);
  }

  Future<ApiResponse> _forward(
    String method,
    String path,
    Object? body,
    ApiRequestOptions options, {
    Map<String, dynamic>? query,
  }) async {
    _note(method, path, body);
    final result = await _fake.serveHttp(
      method: method,
      path: path,
      data: body,
      query: query,
      headers: options.headers,
      authenticated: options.authenticated,
    );
    if (result.status >= 400) {
      throw StateError('fake ${result.status} $path');
    }
    final decoded = jsonDecode(result.body);
    final data = decoded is Map && decoded.containsKey('data')
        ? decoded['data']
        : decoded;
    return ApiResponse(statusCode: result.status, data: data);
  }

  @override
  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? query,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) {
    return _forward('GET', path, null, options, query: query);
  }

  @override
  Future<ApiResponse> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) {
    return _forward('POST', path, body, options, query: query);
  }

  @override
  Future<ApiResponse> put(
    String path, {
    Object? body,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) {
    return _forward('PUT', path, body, options);
  }

  @override
  Future<ApiResponse> patch(
    String path, {
    Object? body,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) {
    return _forward('PATCH', path, body, options);
  }

  @override
  Future<ApiResponse> delete(
    String path, {
    Object? body,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) {
    return _forward('DELETE', path, body, options);
  }
}

Future<_DevicePostLog> _pumpDevicePost(
  WidgetTester tester,
  FakeNotificationPermissionService permission,
  String token,
) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final transport = FakePushTransport(token: token);
  addTearDown(transport.dispose);
  final pushGate = PushSessionGate();
  final layer = ApiLayer.create(
    config: const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
    fakeLatency: Duration.zero,
    cleanups: [pushGate.forget],
  );
  addTearDown(layer.dispose);
  final log = _DevicePostLog();
  (layer.client as FakeApiClient).bindGateway(
    _ObservingGateway(layer.client as FakeApiClient, log),
  );

  await tester.pumpWidget(
    app_root.buildAppRoot(
      layer: layer,
      pushGate: pushGate,
      tokenStore: MemoryDeviceTokenStore(),
      overrides: [
        pushTransportProvider.overrideWithValue(transport),
        notificationPermissionServiceProvider.overrideWithValue(permission),
        connectivityPortProvider.overrideWithValue(
          const FixedConnectivity(true),
        ),
        backgroundNotificationSchedulerProvider.overrideWithValue(
          const NoopBackgroundNotificationScheduler(),
        ),
        shownNotificationStoreProvider.overrideWithValue(
          MemoryShownNotificationStore(),
        ),
      ],
    ),
  );
  await settle(tester);
  return log;
}

class RecordingDeviceTokenRegistrar extends DeviceTokenRegistrar {
  RecordingDeviceTokenRegistrar()
    : super(
        transport: const NoopPushTransport(),
        permission: const StubNotificationPermissionService(),
        store: MemoryDeviceTokenStore(),
        client: RecordingDeviceRegistrationClient(),
        dedup: NotificationIdDedup(),
      );

  final List<bool> registerSignedIn = [];
  var forgets = 0;

  void clear() {
    registerSignedIn.clear();
    forgets = 0;
  }

  @override
  Future<void> registerIfReady({required bool signedIn}) async {
    registerSignedIn.add(signedIn);
  }

  @override
  Future<void> forget() async {
    forgets++;
  }
}

Future<void> go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byKey(HomeShell.shellKey))).go(path);
  await settle(tester);
}

Future<void> resume(WidgetTester tester) async {
  final binding = tester.binding;
  binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  await tester.pump();
  binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
  binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  await tester.pump();
  binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await settle(tester);
}

Future<void> settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}

Future<void> until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 1));
  }
}
