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
