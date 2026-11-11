import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/login/login_design_options.dart';
import 'package:vib_abdo_company_mobile/features/login/login_preview_045.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;

Future<void> _loadCairo() async {
  await loadScreenshotFonts();
  for (final name in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final file = File('assets/fonts/Cairo-$name.ttf');
    await ui.loadFontFromList(await file.readAsBytes(), fontFamily: 'Cairo');
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required int option,
  required bool showError,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: Scaffold(
        body: LoginPreview045(
          key: ValueKey('$option-$showError'),
          option: option,
          showError: showError,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('designs 5 to 8 are previews and leave the live login alone', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const LoginDesignGallery(),
      ),
    );
    await tester.pump();
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('طلب حساب'), findsNothing);
    expect(find.text('إنشاء حساب'), findsNothing);
  });

  testWidgets('each new gateway has username, password, and an Arabic error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final option in [5, 6, 7, 8]) {
      await _pump(tester, option: option, showError: false);
      expect(find.byKey(Key('login-preview-number-$option')), findsOneWidget);
      expect(find.text('$option'), findsOneWidget);
      expect(find.text('اسم المستخدم'), findsOneWidget);
      expect(find.text('كلمة المرور'), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsOneWidget);
      expect(find.text('طلب حساب'), findsNothing);
      expect(find.text('إنشاء حساب'), findsNothing);
      expect(find.text('نسيت كلمة المرور'), findsNothing);
      expect(find.byIcon(Icons.fingerprint), findsNothing);
      expect(find.byKey(Key('login-preview-$option-error')), findsNothing);

      final before = tester.widget<TextField>(
        find.byKey(Key('login-preview-$option-password')),
      );
      expect(before.obscureText, isTrue);
      await tester.tap(find.byKey(Key('login-preview-$option-toggle')));
      await tester.pump();
      final after = tester.widget<TextField>(
        find.byKey(Key('login-preview-$option-password')),
      );
      expect(after.obscureText, isFalse);
      expect(tester.takeException(), isNull);

      await _pump(tester, option: option, showError: true);
      expect(find.text('بيانات الدخول غير صحيحة'), findsOneWidget);
      expect(find.byKey(Key('login-preview-$option-error')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('phone previews of login designs 5 to 8', (tester) async {
    await tester.runAsync(_loadCairo);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final option in [5, 6, 7, 8]) {
      for (final error in [false, true]) {
        await _pump(tester, option: option, showError: error);
        await saveShot(tester, 'login-design-$option${error ? '-error' : ''}');
      }
    }
  }, tags: const ['screenshots']);
}
