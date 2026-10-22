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
import 'package:vib_abdo_company_mobile/features/collections/collections_screen.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/features/notifications/foreground_notification_banner.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notification_permission.dart';
import 'package:vib_abdo_company_mobile/notifications/push_providers.dart';
import 'package:vib_abdo_company_mobile/notifications/push_transport.dart';
import 'package:vib_abdo_company_mobile/notifications/unread_badge.dart';
import 'package:vib_abdo_company_mobile/state/notification_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/logout_confirm.dart';

import 'support/phase7_ui.dart';
import 'support/pump_app.dart';

bool get _skipDef019 => false;

void main() {
  testWidgets('the bell shows the server count, 99, and 99+', (tester) async {
    await pumpFakeApp(tester, size: const Size(390, 844));
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '1');

    await _pumpCount(tester, 99);
    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '99');

    await _pumpCount(tester, 100);
    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '99+');

    await _pumpCount(tester, 0);
    expect(find.byKey(UnreadBadge.badgeKey), findsNothing);
    expectQuiet(tester, 'badge');
  });

  testWidgets('a list tap marks that row read and opens its target', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(390, 844));
    final fake = layer.client as FakeApiClient;
    final writes = layer.notifications as RemoteNotificationsRepository;
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/notifications');
    expect(find.byKey(const Key('notice-unread-dot-77')), findsOneWidget);

    await tester.tap(find.byKey(const Key('notice-77')));
    await settle(tester);

    expect(find.byKey(CollectionsScreen.screenKey), findsOneWidget);
    expect(fake.notificationMutationApplies, 1);
    expect(writes.attemptedWriteRequestIds, hasLength(1));
    expect(find.byKey(UnreadBadge.badgeKey), findsNothing);

    await go(tester, '/notifications');
    expect(find.byKey(const Key('notice-77')), findsOneWidget);
    expect(find.byKey(const Key('notice-unread-dot-77')), findsNothing);
    expect(writes.attemptedWriteRequestIds, hasLength(1));
    expectQuiet(tester, 'list tap');
  });

  testWidgets('mark all read clears the server badge', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(390, 844));
    final fake = layer.client as FakeApiClient;
    final writes = layer.notifications as RemoteNotificationsRepository;
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/notifications');
    expect(find.text('${AppStrings.unreadFull} 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mark-all-read')));
    await settle(tester);

    expect(fake.notificationMutationApplies, 1);
    expect(writes.attemptedWriteRequestIds, hasLength(1));
    expect(find.byKey(UnreadBadge.badgeKey), findsNothing);
    expect(find.byKey(const Key('notice-unread-dot-77')), findsNothing);
    expect(find.text('${AppStrings.unreadFull} 0'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('mark-all-read')))
          .onPressed,
      isNull,
    );
    expectQuiet(tester, 'mark all');
  });

  testWidgets('a double tap on mark all sends one request', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(390, 844));
    final writes = layer.notifications as RemoteNotificationsRepository;
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/notifications');

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('mark-all-read')),
    );
    button.onPressed!();
    button.onPressed!();
    await settle(tester);

    expect(writes.attemptedWriteRequestIds, hasLength(1));
    expect((layer.client as FakeApiClient).notificationMutationApplies, 1);
    expectQuiet(tester, 'double mark all');
  });

  testWidgets('a double tap on a row marks it read once', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(390, 844));
    final writes = layer.notifications as RemoteNotificationsRepository;
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/notifications');

    final row = tester.widget<InkWell>(find.byKey(const Key('notice-77')));
    row.onTap!();
    row.onTap!();
    await settle(tester);

    expect(writes.attemptedWriteRequestIds, hasLength(1));
    expect((layer.client as FakeApiClient).notificationMutationApplies, 1);
    expect(find.byKey(CollectionsScreen.screenKey), findsOneWidget);
    expectQuiet(tester, 'double row');
  });

  testWidgets('switching accounts resets the badge and the list', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(390, 844));
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '1');
    await go(tester, '/notifications');
    expect(find.byKey(const Key('notice-77')), findsOneWidget);
    expect(find.byKey(const Key('notice-88')), findsNothing);

    await tester.tap(find.byKey(HomeShell.logoutKey));
    await settle(tester);
    await tester.tap(find.byKey(LogoutConfirmDialog.confirmKey));
    await settle(tester);
    expect(find.byKey(LoginScreen.screenKey), findsOneWidget);

    await signIn(tester, username: 'other.employee', password: 'x');
    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '2');
    await go(tester, '/notifications');
    expect(find.byKey(const Key('notice-77')), findsNothing);
    expect(find.byKey(const Key('notice-88')), findsOneWidget);
    expect(find.byKey(const Key('notice-n_20')), findsOneWidget);
    expect(find.text('${AppStrings.unreadFull} 2'), findsOneWidget);
    expectQuiet(tester, 'account switch');
  });

  testWidgets('a banner tap opens the target and marks the row read', (
    tester,
  ) async {
    final bus = StreamController<AppNotification>.broadcast();
    addTearDown(bus.close);
    final layer = await pumpFakeApp(
      tester,
      size: const Size(390, 844),
      overrides: [
        foregroundNotificationsProvider.overrideWith((ref) => bus.stream),
      ],
    );
    final writes = layer.notifications as RemoteNotificationsRepository;
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '1');

    bus.add(_ownedCollection());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(ForegroundNotificationBanner.bannerKey), findsOneWidget);
    expect(find.textContaining('استلام جديد بانتظار المراجعة'), findsWidgets);

    await tester.tap(find.byKey(ForegroundNotificationBanner.bannerKey));
    await settle(tester);

    expect(find.byKey(CollectionsScreen.screenKey), findsOneWidget);
    expect(writes.attemptedWriteRequestIds, hasLength(1));
    expect((layer.client as FakeApiClient).notificationMutationApplies, 1);
    expect(find.byKey(UnreadBadge.badgeKey), findsNothing);
    expectQuiet(tester, 'banner');
  });

  testWidgets(
    'a granted login does not register again on the first notifications visit',
    (tester) async {
      if (_skipDef019) {
        markTestSkipped('DEF-019 known failure');
        return;
      }
      const token = 'phase7-device-token';
      final transport = FakePushTransport(token: token);
      addTearDown(transport.dispose);
      final log = _DevicePostLog();
      final layer = await pumpFakeApp(
        tester,
        sdkInt: 33,
        size: const Size(390, 844),
        overrides: [pushTransportProvider.overrideWithValue(transport)],
      );
      (layer.client as FakeApiClient).bindGateway(
        _ObservingGateway(layer.client as FakeApiClient, log),
      );

      await signIn(tester, username: 'employee.demo', password: 'demo-only');
      expect(log.devicePosts, [
        {'token': token, 'platform': 'android'},
      ]);

      await go(tester, '/notifications');

      expect(log.devicePosts, [
        {'token': token, 'platform': 'android'},
      ]);
    },
  );

  testWidgets('pumpFakeApp sdkInt 29 does not ask again', (tester) async {
    final permission = FakeNotificationPermissionService(
      initial: NotificationPermissionChoice.denied,
      afterRequest: NotificationPermissionChoice.granted,
    );
    await pumpFakeApp(tester, sdkInt: 29, notificationsPermission: permission);
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/notifications');

    expect(
      find.byKey(const Key('notification-permission-explain')),
      findsNothing,
    );
    expect(permission.requested, isFalse);
    expect(find.byKey(const Key('screen-notifications')), findsOneWidget);
    expectQuiet(tester, 'sdk 29');
  });
}

Future<void> _pumpCount(WidgetTester tester, int unread) async {
  final layer = await pumpFakeApp(tester, size: const Size(390, 844));
  (layer.client as FakeApiClient).stageNotification({
    'id': 'bulk-$unread',
    'action': 'collection.submit',
    'title': 'كم',
    'section': 'collections',
    'entityId': 'sb_1',
    'readAt': null,
    'createdAt': '2026-10-18T12:00:00+02:00',
    'systemName': 'الاستلامات',
    'recipientUserId': FakeFixtures.demoEmployeeId,
  }, unreadCount: unread);
  await signIn(tester, username: 'employee.demo', password: 'demo-only');
}

AppNotification _ownedCollection() {
  return AppNotification(
    notificationId: '77',
    systemName: 'الاستلامات',
    employeeName: 'موظف استلام تجريبي',
    operationType: NotificationOperationType.collectionSubmit,
    operationTypeRaw: 'collection.submit',
    relatedRef: const NotificationRelatedRef(type: 'collection', id: 'sb_1'),
    createdAt: DateTime.utc(2026, 10, 18, 12),
    readAt: null,
    recipientUserId: FakeFixtures.demoEmployeeId,
    title: 'استلام جديد بانتظار المراجعة',
    body: 'افتح قسم الاستلامات',
  );
}

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
