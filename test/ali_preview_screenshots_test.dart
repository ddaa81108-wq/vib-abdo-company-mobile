import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_design_options.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/pump_app.dart';

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('preview home icon styles on layout 1', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    for (final dark in [false, true]) {
      for (final option in [1, 2, 3, 4]) {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(dark ? Brightness.dark : Brightness.light),
            builder: (context, child) =>
                Directionality(textDirection: TextDirection.rtl, child: child!),
            home: Scaffold(
              body: SizedBox.expand(child: HomeDesignOption(option: option)),
            ),
          ),
        );
        await tester.pump();
        await saveShot(
          tester,
          'home-icon-style-$option-${dark ? 'dark' : 'light'}',
        );
      }
    }
  }, tags: const ['screenshots']);

  testWidgets('preview live sections light and dark', (tester) async {
    await pumpFakeApp(tester, size: const Size(390, 844));
    await tester.runAsync(loadScreenshotFonts);
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    for (final dark in [false, true]) {
      if (dark) {
        await go(tester, '/account');
        await tester.tap(find.byKey(const Key('theme-switch')));
        await tester.pumpAndSettle();
      }
      final theme = dark ? 'dark' : 'light';
      for (final path in [
        '/customers',
        '/companies',
        '/libyan-deposits',
        '/egyptian-deposits',
        '/collections',
        '/purchases',
      ]) {
        await go(tester, path);
        await tester.pump(const Duration(milliseconds: 200));
        await saveShot(tester, 'live-${path.substring(1)}-$theme');
      }
      await go(tester, '/customers/c_55');
      await tester.pump(const Duration(milliseconds: 200));
      await saveShot(tester, 'live-ledger-customers-$theme');
      for (final section in [
        'libyan-deposits',
        'egyptian-deposits',
        'companies',
      ]) {
        await go(tester, '/$section');
        await tester.pump(const Duration(milliseconds: 200));
        final card = find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              '${(widget.key as ValueKey<String>).value}'.startsWith(
                'account-card-',
              ),
        );
        if (card.evaluate().isNotEmpty) {
          await tester.tap(card.first);
          await tester.pumpAndSettle();
          await saveShot(tester, 'live-ledger-$section-$theme');
        }
      }
    }
    await pumpFakeApp(tester, size: const Size(390, 844));
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/collections');
    await tester.pump(const Duration(milliseconds: 300));
    await saveShot(tester, 'live-collections-employee');

    await pumpFakeApp(tester, size: const Size(1280, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    await tester.pump(const Duration(milliseconds: 300));
    await saveShot(tester, 'wide-ledger-customers');
    await go(tester, '/libyan-deposits');
    await tester.pump(const Duration(milliseconds: 200));
    final card = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          '${(widget.key as ValueKey<String>).value}'.startsWith(
            'account-card-',
          ),
    );
    if (card.evaluate().isNotEmpty) {
      await tester.tap(card.first);
      await tester.pumpAndSettle();
      await saveShot(tester, 'wide-ledger-libyan');
    }
    await go(tester, '/purchases');
    await tester.pump(const Duration(milliseconds: 300));
    await saveShot(tester, 'wide-purchases');
    await go(tester, '/collections');
    await tester.pump(const Duration(milliseconds: 200));
    await saveShot(tester, 'wide-collections');
  }, tags: const ['screenshots']);
}
