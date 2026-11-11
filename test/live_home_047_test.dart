import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/home/home_design_options.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/pump_app.dart';

void main() {
  testWidgets('live home uses icon set 1 for admin and employee', (
    tester,
  ) async {
    await tester.runAsync(loadScreenshotFonts);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    expect(find.byType(HomeIconMark), findsWidgets);
    await saveShot(tester, 'live-home-icons-admin-light');
    await _toggleTheme(tester);
    await saveShot(tester, 'live-home-icons-admin-dark');

    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    expect(find.byType(HomeIconMark), findsWidgets);
    expect(find.text('استلامات الديون'), findsOneWidget);
    expect(find.text('الإعدادات'), findsNothing);
    await saveShot(tester, 'live-home-icons-employee-light');
    await _toggleTheme(tester);
    await saveShot(tester, 'live-home-icons-employee-dark');
  }, tags: const ['screenshots']);
}

Future<void> _toggleTheme(WidgetTester tester) async {
  await tester.tap(find.byKey(HomeShell.menuKey));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text(AppStrings.themeDark));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  Scaffold.of(tester.element(find.byKey(HomeShell.menuKey))).closeDrawer();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
