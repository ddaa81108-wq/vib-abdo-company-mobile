import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/app.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notification_permission.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notification_permission_registration.dart';
import 'package:vib_abdo_company_mobile/notifications/background_scheduler.dart';
import 'package:vib_abdo_company_mobile/notifications/device_token_registrar.dart';
import 'package:vib_abdo_company_mobile/notifications/device_token_store.dart';
import 'package:vib_abdo_company_mobile/notifications/push_providers.dart';
import 'package:vib_abdo_company_mobile/notifications/shown_notification_store.dart';
import 'package:vib_abdo_company_mobile/state/connectivity.dart';

/// Pumps the app with an injected fake [ApiLayer]. The provider does not build one.
Future<ApiLayer> pumpFakeApp(
  WidgetTester tester, {
  Size size = const Size(800, 1400),
  double textScale = 1,
  List<Override> overrides = const [],
  ConnectivityPort? connectivity,
  NotificationPermissionService? notificationsPermission,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() {
    tester.platformDispatcher.textScaleFactorTestValue = 1;
  });

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();

  final pushGate = PushSessionGate();
  final layer = ApiLayer.create(
    config: const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
    fakeLatency: Duration.zero,
    cleanups: [pushGate.forget],
  );
  addTearDown(layer.dispose);

  await tester.pumpWidget(
    ProviderScope(
      // Failed loads should surface immediately. The app keeps Riverpod's retry.
      retry: (retryCount, error) => null,
      overrides: [
        apiLayerProvider.overrideWithValue(layer),
        pushSessionGateProvider.overrideWithValue(pushGate),
        deviceTokenStoreProvider.overrideWithValue(MemoryDeviceTokenStore()),
        connectivityPortProvider.overrideWithValue(
          connectivity ?? const FixedConnectivity(true),
        ),
        notificationPermissionServiceProvider.overrideWithValue(
          notificationsPermission ?? const GrantedNotificationPermission(),
        ),
        notificationPermissionRegistrarOverride(),
        // Widget tests have no platform channel. Android 13 keeps the dialog.
        notificationSdkIntProvider.overrideWithValue(() async => 33),
        backgroundNotificationSchedulerProvider.overrideWithValue(
          const NoopBackgroundNotificationScheduler(),
        ),
        shownNotificationStoreProvider.overrideWithValue(
          MemoryShownNotificationStore(),
        ),
        ...overrides,
      ],
      child: const CompanyApp(),
    ),
  );
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
  return layer;
}

Future<void> signIn(
  WidgetTester tester, {
  required String username,
  required String password,
}) async {
  await _setText(tester, const Key('username-field'), username);
  await _setText(tester, const Key('password-field'), password);
  await tester.pump();
  final button = await _widget<FilledButton>(tester, const Key('login-button'));
  button.onPressed!.call();
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}

Future<void> _setText(WidgetTester tester, Key key, String value) async {
  final field = await _widget<TextField>(tester, key);
  field.controller!.value = TextEditingValue(
    text: value,
    selection: TextSelection.collapsed(offset: value.length),
  );
}

Future<T> _widget<T extends Widget>(WidgetTester tester, Key key) async {
  final finder = find.byKey(key, skipOffstage: false);
  for (var i = 0; i < 10; i++) {
    if (finder.evaluate().isNotEmpty) {
      return tester.widget<T>(finder);
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  final loc = find.byType(Scaffold).evaluate().isEmpty
      ? 'none'
      : GoRouter.of(tester.element(find.byType(Scaffold).first)).state.uri;
  fail(
    'missing $key at $loc '
    'login=${find.byKey(const Key('login-screen'), skipOffstage: false).evaluate().length}',
  );
}
