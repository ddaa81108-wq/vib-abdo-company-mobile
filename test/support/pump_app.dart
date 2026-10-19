import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/app.dart';
import 'package:vib_abdo_company_mobile/state/connectivity.dart';

/// Pumps the app with an injected fake [ApiLayer]. The provider does not build one.
Future<ApiLayer> pumpFakeApp(
  WidgetTester tester, {
  Size size = const Size(800, 1400),
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final layer = ApiLayer.create(
    config: const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
    fakeLatency: Duration.zero,
  );
  addTearDown(layer.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiLayerProvider.overrideWithValue(layer),
        connectivityPortProvider.overrideWithValue(const FixedConnectivity(true)),
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
  await tester.enterText(find.byKey(const Key('username-field')), username);
  await tester.enterText(find.byKey(const Key('password-field')), password);
  await tester.tap(find.byKey(const Key('login-button')));
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
