import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_api_layer/data/fake/fake_fixtures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/app.dart';
import 'package:vib_abdo_company_mobile/features/accounts/account_list_screen.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_screen.dart';
import 'package:vib_abdo_company_mobile/features/forbidden/forbidden_screen.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notification_open_seam.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notification_permission.dart';
import 'package:vib_abdo_company_mobile/notifications/device_registration_client.dart';
import 'package:vib_abdo_company_mobile/notifications/push_providers.dart';
import 'package:vib_abdo_company_mobile/notifications/push_transport.dart';
import 'package:vib_abdo_company_mobile/notifications/unread_badge.dart';
import 'package:vib_abdo_company_mobile/state/theme_controller.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  AppNotification trayNotice({
    required String recipient,
    String id = '77',
    String type = 'collection',
    String entityId = 'sb_1',
    String title = 'استلام جديد بانتظار المراجعة',
    String? employeeName = 'موظف استلام تجريبي',
  }) {
    return AppNotification(
      notificationId: id,
      systemName: 'الاستلامات',
      employeeName: employeeName,
      operationType: NotificationOperationType.collectionSubmit,
      operationTypeRaw: 'collection.submit',
      relatedRef: NotificationRelatedRef(type: type, id: entityId),
      createdAt: DateTime.utc(2026, 10, 18, 12),
      readAt: null,
      recipientUserId: recipient,
      title: title,
      body: 'افتح قسم الاستلامات',
    );
  }

  NotificationOpenSeam seamOf(WidgetTester tester) {
    final context = tester.element(find.byType(CompanyApp));
    return ProviderScope.containerOf(
      context,
      listen: false,
    ).read(notificationOpenSeamProvider);
  }

  Future<T> finish<T>(WidgetTester tester, Future<T> future) async {
    late T value;
    Object? error;
    StackTrace? stack;
    var done = false;
    future.then(
      (result) {
        value = result;
        done = true;
      },
      onError: (Object e, StackTrace s) {
        error = e;
        stack = s;
        done = true;
      },
    );
    for (var i = 0; i < 40 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    if (!done) fail('open did not finish');
    if (error != null) Error.throwWithStackTrace(error!, stack!);
    return value;
  }

  Future<void> logOut(WidgetTester tester) async {
    await tester.tap(find.byKey(HomeShell.logoutKey));
    await settle(tester);
    expect(find.text(AppStrings.logoutConfirm), findsOneWidget);
    await tester.tap(find.byKey(const Key('logout-confirm')));
    await settle(tester);
    expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
  }

  testWidgets(
    'P6-34 a tray tap after an account switch does not open the previous employee',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(320, 568));
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'employee.demo', password: 'demo-only');
      await logOut(tester);
      expect(find.textContaining('انتهت الجلسة'), findsNothing);
      expect(find.byKey(UnreadBadge.badgeKey), findsNothing);

      final result = await finish(
        tester,
        seamOf(tester).open(
          trayNotice(recipient: FakeFixtures.demoEmployeeId),
          origin: NotificationOpenOrigin.systemTray,
        ),
      );
      expect(result.needsLogin, isTrue);
      expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
      expect(fake.notificationMutationApplies, 0);

      await signIn(tester, username: 'other.employee', password: 'x');
      await settle(tester);

      expect(find.byKey(ForbiddenScreen.screenKey), findsOneWidget);
      expect(find.text(AppStrings.forbidden), findsWidgets);
      expect(find.byKey(CollectionsScreen.screenKey), findsNothing);
      expect(find.text('استلام جديد بانتظار المراجعة'), findsNothing);
      expect(find.text('موظف استلام تجريبي'), findsNothing);
      expect(fake.notificationMutationApplies, 0);
      expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '2');
      final context = tester.element(find.byKey(ForbiddenScreen.screenKey));
      expect(Directionality.of(context), TextDirection.rtl);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'P6-36 a tray tap after logout stays on login and opens once after sign-in',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(320, 568));
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'employee.demo', password: 'demo-only');
      await logOut(tester);
      expect(find.textContaining('انتهت الجلسة'), findsNothing);
      expect(find.byKey(UnreadBadge.badgeKey), findsNothing);
      expect(find.byKey(CollectionsScreen.screenKey), findsNothing);

      final result = await finish(
        tester,
        seamOf(tester).open(
          trayNotice(recipient: FakeFixtures.demoEmployeeId),
          origin: NotificationOpenOrigin.systemTray,
        ),
      );
      expect(result.needsLogin, isTrue);
      expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
      expect(fake.notificationMutationApplies, 0);

      await signIn(tester, username: 'employee.demo', password: 'demo-only');
      await settle(tester);

      expect(find.byKey(CollectionsScreen.screenKey), findsOneWidget);
      expect(find.byKey(LoginScreen.screenKey), findsNothing);
      expect(find.textContaining('انتهت الجلسة'), findsNothing);
      expect(fake.notificationMutationApplies, 1);
      expect(find.byKey(UnreadBadge.badgeKey), findsNothing);
      final context = tester.element(find.byKey(CollectionsScreen.screenKey));
      expect(Directionality.of(context), TextDirection.rtl);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'P6-39 an employee tap on a closed section opens forbidden and marks read once',
    (tester) async {
      for (final dark in [false, true]) {
        final layer = await pumpFakeApp(
          tester,
          size: const Size(320, 568),
          overrides: [if (dark) themeModeProvider.overrideWith(_DarkTheme.new)],
        );
        final fake = layer.client as FakeApiClient;
        await signIn(tester, username: 'employee.demo', password: 'demo-only');
        fake.stageNotification({
          'id': 'co_secret',
          'action': 'collection.submit',
          'title': 'شركة سرية',
          'body': 'بيانات شركة',
          'section': 'companies',
          'entityId': 'co_1',
          'readAt': null,
          'createdAt': '2026-10-19T12:00:00+02:00',
          'systemName': 'الشركات',
          'employeeName': 'اسم الشركة السري',
          'recipientUserId': FakeFixtures.demoEmployeeId,
        }, unreadCount: 1);
        await go(tester, '/notifications');
        final list = tester.element(find.byKey(const Key('notice-co_secret')));
        expect(Directionality.of(list), TextDirection.rtl);
        expect(
          Theme.of(list).brightness,
          dark ? Brightness.dark : Brightness.light,
        );
        expect(find.text('شركة سرية'), findsOneWidget);

        await tester.tap(find.byKey(const Key('notice-co_secret')));
        await settle(tester);

        expect(find.byKey(ForbiddenScreen.screenKey), findsOneWidget);
        expect(find.text(AppStrings.forbidden), findsWidgets);
        expect(find.text('شركة سرية'), findsNothing);
        expect(find.text('اسم الشركة السري'), findsNothing);
        expect(find.byKey(const Key('screen-companies')), findsNothing);
        expect(find.byType(AccountListScreen), findsNothing);
        expect(fake.notificationMutationApplies, 1);
        expect(find.byKey(UnreadBadge.badgeKey), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('granting permission registers the device token', (tester) async {
    final devices = RecordingDeviceRegistrationClient();
    final transport = FakePushTransport(token: 'tok-1');
    addTearDown(transport.dispose);
    final permission = FakeNotificationPermissionService(
      initial: NotificationPermissionChoice.denied,
      afterRequest: NotificationPermissionChoice.granted,
    );
    await pumpFakeApp(
      tester,
      notificationsPermission: permission,
      overrides: [
        pushTransportProvider.overrideWithValue(transport),
        deviceRegistrationClientProvider.overrideWithValue(devices),
      ],
    );
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await settle(tester);
    expect(devices.registered, isEmpty);

    await go(tester, '/notifications');
    expect(
      find.byKey(const Key('notification-permission-explain')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('notification-permission-agree')));
    await settle(tester);

    expect(permission.requested, isTrue);
    expect(devices.registered, ['tok-1']);
    expect(devices.unregistered, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('denying permission does not register the device', (
    tester,
  ) async {
    final devices = RecordingDeviceRegistrationClient();
    final transport = FakePushTransport(token: 'tok-1');
    addTearDown(transport.dispose);
    final permission = FakeNotificationPermissionService(
      initial: NotificationPermissionChoice.denied,
      afterRequest: NotificationPermissionChoice.denied,
    );
    await pumpFakeApp(
      tester,
      notificationsPermission: permission,
      overrides: [
        pushTransportProvider.overrideWithValue(transport),
        deviceRegistrationClientProvider.overrideWithValue(devices),
      ],
    );
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/notifications');
    await tester.tap(find.byKey(const Key('notification-permission-later')));
    await settle(tester);

    expect(permission.requested, isFalse);
    expect(devices.registered, isEmpty);
    expect(devices.unregistered, isEmpty);
    expect(
      find.byKey(const Key('notification-permission-denied')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('revoking permission unregisters the device', (tester) async {
    final devices = RecordingDeviceRegistrationClient();
    final transport = FakePushTransport(token: 'tok-1');
    addTearDown(transport.dispose);
    final permission = FakeNotificationPermissionService(
      initial: NotificationPermissionChoice.granted,
    );
    await pumpFakeApp(
      tester,
      notificationsPermission: permission,
      overrides: [
        pushTransportProvider.overrideWithValue(transport),
        deviceRegistrationClientProvider.overrideWithValue(devices),
      ],
    );
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await settle(tester);
    expect(devices.registered, ['tok-1']);
    expect(devices.unregistered, isEmpty);

    permission.initial = NotificationPermissionChoice.denied;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);

    expect(devices.registered, ['tok-1']);
    expect(devices.unregistered, ['tok-1']);
    expect(tester.takeException(), isNull);
  });
}

Future<void> go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byKey(HomeShell.shellKey))).go(path);
  await settle(tester);
}

Future<void> settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}

class _DarkTheme extends ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.dark;
}
