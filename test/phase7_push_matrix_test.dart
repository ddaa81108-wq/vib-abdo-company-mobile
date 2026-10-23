import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_api_layer/core/network/api_client.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_api_layer/data/fake/fake_fixtures.dart';
import 'package:flutter_api_layer/data/repositories/notifications_repository.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_screen.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/notifications/foreground_notification_banner.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notification_open_seam.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notification_permission.dart';
import 'package:vib_abdo_company_mobile/notifications/background_poll.dart';
import 'package:vib_abdo_company_mobile/notifications/device_token_registrar.dart';
import 'package:vib_abdo_company_mobile/notifications/push_providers.dart';
import 'package:vib_abdo_company_mobile/notifications/push_transport.dart';
import 'package:vib_abdo_company_mobile/notifications/system_tray_platform.dart';
import 'package:vib_abdo_company_mobile/notifications/tray_notification.dart';
import 'package:vib_abdo_company_mobile/notifications/unread_badge.dart';

import 'support/phase7_ui.dart';
import 'support/pump_app.dart';

/// Force-stop has no FCM token and no delivery. The phone protocol records
/// this as Not supported. The process is not killed here.
const killedProcessResult = 'Not supported';

void main() {
  testWidgets(
    'P7-16 permission dialog on API 33 posts through the real registrar',
    (tester) async {
      await _agreePostsOnce(tester, sdkInt: 33, token: 'p7-16-dialog-token');
    },
  );

  testWidgets('P7-16 foreground banner, lock-screen text, and tap', (
    tester,
  ) async {
    final transport = FakePushTransport(token: 'p7-16-banner-token');
    addTearDown(transport.dispose);
    final layer = await pumpFakeApp(
      tester,
      size: const Size(390, 844),
      overrides: [pushTransportProvider.overrideWithValue(transport)],
    );
    final posted = _captureTray(tester);
    final fake = layer.client as FakeApiClient;
    final writes = layer.notifications as RemoteNotificationsRepository;
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    _expectRealPushSeam(tester);
    await go(tester, '/notifications');
    expect(find.byKey(const Key('notice-77')), findsOneWidget);

    fake.stageNotification({
      'id': 'n-fg',
      'action': 'collection.submit',
      'title': 'مبلغ 900 دينار',
      'body': 'هاتف 0910000000',
      'section': 'collections',
      'entityId': 'sb_1',
      'readAt': null,
      'createdAt': '2026-10-18T12:00:00+02:00',
      'systemName': 'الاستلامات',
      'employeeName': 'موظف استلام تجريبي',
      'recipientUserId': FakeFixtures.demoEmployeeId,
      'token': 'secret-token',
    }, unreadCount: 2);
    transport.inject({
      'notificationId': 'n-fg',
      'recipientUserId': FakeFixtures.demoEmployeeId,
      'operationType': 'collection.submit',
      'relatedRef': {'type': 'collection', 'id': 'sb_1'},
      'createdAt': '2026-10-18T12:00:00+02:00',
      'systemName': 'الاستلامات',
      'employeeName': 'موظف استلام تجريبي',
      'title': 'مبلغ 900 دينار',
      'amount': '900',
      'phone': '0910000000',
      'token': 'secret-token',
    });
    await settle(tester);

    expect(find.byKey(ForegroundNotificationBanner.bannerKey), findsOneWidget);
    expect(posted, isNotEmpty);
    for (final args in posted) {
      _expectLockScreen(args);
    }
    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '2');

    await tester.tap(find.byKey(ForegroundNotificationBanner.bannerKey));
    await settle(tester);

    expect(find.byKey(CollectionsScreen.screenKey), findsOneWidget);
    expect(writes.attemptedWriteRequestIds, hasLength(1));
    expect(fake.notificationMutationApplies, 1);
    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '1');

    await go(tester, '/notifications');
    expect(find.byKey(const Key('notice-unread-dot-n-fg')), findsNothing);
    expect(find.byKey(const Key('notice-unread-dot-77')), findsOneWidget);
    await tester.tap(find.byKey(const Key('notice-n-fg')));
    await settle(tester);

    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '1');
    expect(find.byKey(CollectionsScreen.screenKey), findsOneWidget);
    expectQuiet(tester, 'P7-16 banner');
  });

  testWidgets('P7-17 background run posts the lock-screen line while paused', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(390, 844));
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '1');
    final posted = _captureTray(tester);

    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    final result = await tester.runAsync(
      () => ProviderScope.containerOf(
        tester.element(find.byKey(HomeShell.shellKey)),
      ).read(backgroundNotificationPollProvider).run(),
    );

    expect(result, BackgroundPollResult.completed);
    expect(posted, hasLength(1));
    _expectLockScreen(posted.single);
    expect(find.byKey(ForegroundNotificationBanner.bannerKey), findsNothing);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);

    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '1');
    expectQuiet(tester, 'P7-17 background');
  });

  test('P7-17 a killed or terminated app is Not supported', () async {
    final transport = const FcmPushTransport();
    expect(await transport.currentToken(), isNull);
    expect(await transport.payloads.isEmpty, isTrue);
    expect(killedProcessResult, 'Not supported');
  });

  testWidgets('P7-18 API 29 opens the list without a permission dialog', (
    tester,
  ) async {
    const token = 'p7-18-api-29-token';
    final permission = FakeNotificationPermissionService(
      initial: NotificationPermissionChoice.denied,
      afterRequest: NotificationPermissionChoice.granted,
    );
    final log = await _watchDevicePosts(
      tester,
      sdkInt: 29,
      token: token,
      permission: permission,
    );
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    _expectRealRegistrar(tester);
    expect(log.devicePosts, [
      {'token': token, 'platform': 'android'},
    ]);

    await go(tester, '/notifications');

    expect(
      find.byKey(const Key('notification-permission-explain')),
      findsNothing,
    );
    expect(permission.requested, isFalse);
    expect(find.byKey(const Key('screen-notifications')), findsOneWidget);
    expect(log.devicePosts, [
      {'token': token, 'platform': 'android'},
    ]);
    expectQuiet(tester, 'P7-18 API 29');
  });

  testWidgets(
    'P7-18 API 33 shows the permission dialog and posts after agree',
    (tester) async {
      await _agreePostsOnce(tester, sdkInt: 33, token: 'p7-18-api-33-token');
    },
  );

  testWidgets(
    'P7-18 API 34 shows the permission dialog and posts after agree',
    (tester) async {
      await _agreePostsOnce(tester, sdkInt: 34, token: 'p7-18-api-34-token');
    },
  );
}

Future<void> _agreePostsOnce(
  WidgetTester tester, {
  required int sdkInt,
  required String token,
}) async {
  final permission = FakeNotificationPermissionService(
    initial: NotificationPermissionChoice.denied,
    afterRequest: NotificationPermissionChoice.granted,
  );
  final log = await _watchDevicePosts(
    tester,
    sdkInt: sdkInt,
    token: token,
    permission: permission,
  );
  await signIn(tester, username: 'employee.demo', password: 'demo-only');
  _expectRealRegistrar(tester);
  expect(log.devicePosts, isEmpty);

  await go(tester, '/notifications');
  expect(
    find.byKey(const Key('notification-permission-explain')),
    findsOneWidget,
  );
  expect(permission.requested, isFalse);
  expect(log.devicePosts, isEmpty);

  await tester.tap(find.byKey(const Key('notification-permission-agree')));
  await settle(tester);

  expect(permission.requested, isTrue);
  expect(log.devicePosts, [
    {'token': token, 'platform': 'android'},
  ]);
  expect(
    find.byKey(const Key('notification-permission-explain')),
    findsNothing,
  );
  expect(find.byKey(const Key('screen-notifications')), findsOneWidget);
  expectQuiet(tester, 'P7 dialog API $sdkInt');
}

Future<_DevicePostLog> _watchDevicePosts(
  WidgetTester tester, {
  required int sdkInt,
  required String token,
  required FakeNotificationPermissionService permission,
}) async {
  final transport = FakePushTransport(token: token);
  addTearDown(transport.dispose);
  final log = _DevicePostLog();
  final layer = await pumpFakeApp(
    tester,
    sdkInt: sdkInt,
    size: const Size(390, 844),
    notificationsPermission: permission,
    overrides: [pushTransportProvider.overrideWithValue(transport)],
  );
  final fake = layer.client as FakeApiClient;
  fake.bindGateway(_ObservingGateway(fake.boundGateway!, log));
  return log;
}

void _expectRealRegistrar(WidgetTester tester) {
  final registrar = ProviderScope.containerOf(
    tester.element(find.byType(Scaffold).first),
  ).read(deviceTokenRegistrarProvider);
  expect(registrar.runtimeType, DeviceTokenRegistrar);
}

void _expectRealPushSeam(WidgetTester tester) {
  _expectRealRegistrar(tester);
  final seam = ProviderScope.containerOf(
    tester.element(find.byType(Scaffold).first),
  ).read(notificationOpenSeamProvider);
  expect(seam.runtimeType, OpenerNotificationSeam);
}

List<Map<String, Object?>> _captureTray(WidgetTester tester) {
  // Widget tests do not run the Android plugin registrant. The real poster
  // reads that instance, so register it here instead of substituting a poster.
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  final posted = <Map<String, Object?>>[];
  final tray = const MethodChannel(MethodChannelSystemTray.channelName);
  final plugin = const MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(tray, (
    call,
  ) async {
    if (call.method == 'show') {
      posted.add(Map<String, Object?>.from(call.arguments as Map));
      return true;
    }
    return null;
  });
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(plugin, (
    call,
  ) async {
    if (call.method == 'areNotificationsEnabled') return true;
    return null;
  });
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(tray, null);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      plugin,
      null,
    );
  });
  return posted;
}

void _expectLockScreen(Map<String, Object?> args) {
  expect(args['publicBody'], lockScreenNotificationText);
  final lockScreen = '${args['publicTitle']} ${args['publicBody']}';
  expect(lockScreen.contains('موظف'), isFalse);
  expect(lockScreen.contains('900'), isFalse);
  expect(lockScreen.contains('091'), isFalse);
  expect(lockScreen.contains('secret-token'), isFalse);
}

class _DevicePostLog {
  final List<Map<String, Object?>> devicePosts = [];
}

class _ObservingGateway implements ApiClient {
  _ObservingGateway(this._inner, this._log);

  final ApiClient _inner;
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
    return switch (method) {
      'GET' => _inner.get(path, query: query, options: options),
      'POST' => _inner.post(
        path,
        body: body,
        query: query,
        options: options,
      ),
      'PUT' => _inner.put(path, body: body, options: options),
      'PATCH' => _inner.patch(path, body: body, options: options),
      _ => _inner.delete(path, body: body, options: options),
    };
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
