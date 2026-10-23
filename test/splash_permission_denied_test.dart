import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/error_handling/error_handler.dart';
import 'package:vib_abdo_company_mobile/features/splash/splash_screen.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';

void main() {
  testWidgets(
    'splash shows the forbidden pane for a fake 403 PERMISSION_DENIED',
    (tester) async {
      await _pumpForbidden(tester, 'PERMISSION_DENIED');

      expect(find.byKey(SplashScreen.screenKey), findsOneWidget);
      expect(find.byKey(ForbiddenPane.paneKey), findsOneWidget);
      expect(find.text('سر الخادم'), findsNothing);
      expect(find.byKey(SplashScreen.retryKey), findsNothing);
    },
  );

  testWidgets(
    'splash still shows the forbidden pane for a fake 403 FORBIDDEN',
    (tester) async {
      await _pumpForbidden(tester, 'FORBIDDEN');

      expect(find.byKey(ForbiddenPane.paneKey), findsOneWidget);
      expect(find.text('سر الخادم'), findsNothing);
    },
  );
}

Future<void> _pumpForbidden(WidgetTester tester, String code) async {
  final layer = ApiLayer.create(
    config: const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
    fakeLatency: Duration.zero,
  );
  addTearDown(layer.dispose);
  // Login runs before the widget clock. Real async lets the fake's zero
  // delay finish without a pump.
  await tester.runAsync(() async {
    await layer.client.post(
      '/api/auth/login',
      body: {'username': 'admin.demo', 'password': 'x'},
    );
  });
  expect(layer.session.state, isA<SessionUnknown>());
  (layer.client as FakeApiClient).failNextResponse = (
    status: 403,
    code: code,
    message: 'سر الخادم',
  );

  await tester.pumpWidget(
    ProviderScope(
      retry: retryUnlessForbidden,
      overrides: [apiLayerProvider.overrideWithValue(layer)],
      child: const MaterialApp(home: SplashScreen()),
    ),
  );
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
}
