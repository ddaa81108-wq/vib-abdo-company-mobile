import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/phase7_ui.dart';
import 'support/pump_app.dart';

void main() {
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets('a 320dp phone does not overflow', (tester) async {
    await _exercise(tester, const Size(320, 568), 1);
  }, timeout: timeout);

  testWidgets('a 390dp phone does not overflow', (tester) async {
    await _exercise(tester, const Size(390, 844), 1);
  }, timeout: timeout);

  testWidgets('a 430dp phone does not overflow', (tester) async {
    await _exercise(tester, const Size(430, 932), 1);
  }, timeout: timeout);

  testWidgets('an 800dp tablet does not overflow', (tester) async {
    await _exercise(tester, const Size(800, 1280), 1);
  }, timeout: timeout);

  testWidgets('landscape does not overflow', (tester) async {
    await _exercise(tester, const Size(844, 390), 1);
  }, timeout: timeout);

  testWidgets('text scale 1.3 does not overflow', (tester) async {
    await _exercise(tester, const Size(390, 844), 1.3);
  }, timeout: timeout);

  testWidgets('text scale 2.0 does not overflow', (tester) async {
    await _exercise(tester, const Size(390, 844), 2);
  }, timeout: timeout);

  testWidgets('a 320dp phone at text scale 2.0 does not overflow', (
    tester,
  ) async {
    await _exercise(tester, const Size(320, 568), 2);
  }, timeout: timeout);

  testWidgets('P7-22 rotation on 320dp does not overflow', (tester) async {
    await _rotate(tester, const Size(320, 568), const Size(568, 320));
  }, timeout: timeout);

  testWidgets('P7-22 rotation on 430dp does not overflow', (tester) async {
    await _rotate(tester, const Size(430, 932), const Size(932, 430));
  }, timeout: timeout);
}

Future<void> _exercise(WidgetTester tester, Size size, double textScale) async {
  await pumpFakeApp(tester, size: size, textScale: textScale);
  expect(
    MediaQuery.textScalerOf(tester.element(find.byType(Scaffold).first))
        .scale(1),
    textScale,
  );
  await visitMainScreens(tester, (path) {
    expectQuiet(tester, '$path ${size.width}x${size.height} x$textScale');
  });
}

const _rotatedScreens = <String, Key>{
  '/': Key('home-dashboard'),
  '/collections': Key('screen-collections'),
  '/customers/c_55': Key('screen-ledger-customers'),
  '/notifications': Key('screen-notifications'),
};

Future<void> _rotate(WidgetTester tester, Size portrait, Size landscape) async {
  await pumpFakeApp(tester, size: portrait);
  _expectScreen(tester, const Key('login-screen'), 'login portrait');
  await _flip(tester, landscape);
  _expectScreen(tester, const Key('login-screen'), 'login landscape');
  await _flip(tester, portrait);

  await signIn(tester, username: 'admin.demo', password: 'demo-only');
  for (final entry in _rotatedScreens.entries) {
    await go(tester, entry.key);
    _expectScreen(tester, entry.value, '${entry.key} portrait');
    await _flip(tester, landscape);
    _expectScreen(tester, entry.value, '${entry.key} landscape');
    await _flip(tester, portrait);
    _expectScreen(tester, entry.value, '${entry.key} portrait again');
  }
}

Future<void> _flip(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await settle(tester);
}

void _expectScreen(WidgetTester tester, Key key, String label) {
  expect(find.byKey(key), findsOneWidget, reason: label);
  expectQuiet(tester, label);
}
