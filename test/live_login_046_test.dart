import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/pump_app.dart';

Future<void> _noOverflow(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  expect(find.byType(FlutterError), findsNothing);
}

void main() {
  testWidgets('live login is design 8 and stays inside a short phone', (
    tester,
  ) async {
    addTearDown(tester.view.resetViewInsets);
    await pumpFakeApp(tester, size: const Size(360, 640), textScale: 1.3);
    expect(find.text('أهلًا بك'), findsOneWidget);
    expect(find.text('اسم المستخدم'), findsOneWidget);
    expect(find.text(AppStrings.password), findsOneWidget);
    expect(find.text(AppStrings.signIn), findsOneWidget);
    expect(find.text('8'), findsNothing);
    expect(find.text('طلب حساب'), findsNothing);
    await _noOverflow(tester);

    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(LoginScreen.submitKey),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.byKey(LoginScreen.submitKey), findsOneWidget);
    await _noOverflow(tester);
  });

  testWidgets('live login and home icon set 1 on a phone', (tester) async {
    await tester.runAsync(() async {
      await loadScreenshotFonts();
      for (final name in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        final file = File('assets/fonts/Cairo-$name.ttf');
        await ui.loadFontFromList(
          await file.readAsBytes(),
          fontFamily: 'Cairo',
        );
      }
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    tester.view.physicalSize = const Size(360, 800);
    await pumpFakeApp(tester, size: const Size(360, 800));
    await saveShot(tester, 'live-login-design8');

    tester.view.physicalSize = const Size(360, 640);
    await tester.pump();
    await saveShot(tester, 'live-login-design8-360x640');
    tester.view.physicalSize = const Size(360, 800);
    await tester.pump();

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(LoginScreen.submitKey),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await saveShot(tester, 'live-login-design8-keyboard');
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();

    await signIn(tester, username: 'employee.demo', password: 'wrong');
    expect(find.text('بيانات الدخول غير صحيحة'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(LoginScreen.errorKey),
        matching: find.text('بيانات الدخول غير صحيحة'),
      ),
      findsOneWidget,
    );
    await saveShot(tester, 'live-login-design8-error');
  }, tags: const ['screenshots']);
}
