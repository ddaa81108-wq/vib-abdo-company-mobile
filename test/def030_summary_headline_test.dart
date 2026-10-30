import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

const _captureScreenshots = bool.fromEnvironment('CAPTURE_SCREENSHOTS');

void main() {
  for (final section in AccountSection.values) {
    testWidgets(
      'DEF-030 ${section.path} headline is the server summary field',
      (tester) async {
        final layer = await pumpFakeApp(tester, size: const Size(430, 932));
        await signIn(tester, username: 'admin.demo', password: 'demo-only');
        await go(tester, '/${section.path}');

        final page = await tester.runAsync(() => layer.accounts.list(section));
        final deposits =
            section == AccountSection.libyanDeposits ||
            section == AccountSection.egyptianDeposits;
        final headline = deposits
            ? page!.summary.netBalanceUnits
            : page!.summary.totalDebtUnits;
        final label = deposits ? AppStrings.netBalance : AppStrings.totalDebt;
        final text = layer.money.formatOrDash(headline, section.currency);
        expect(_inside(const Key('summary-headline'), label), findsOneWidget);
        expect(_inside(const Key('summary-headline'), text), findsOneWidget);
        final shown = tester.widget<MoneyText>(
          find.descendant(
            of: find.byKey(const Key('summary-headline')),
            matching: find.byType(MoneyText),
          ),
        );
        expect(shown.text, text);
        expect(
          Directionality.of(
            tester.element(find.byKey(const Key('account-summary'))),
          ),
          TextDirection.rtl,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'DEF-030 summary headline screenshots',
    (tester) async {
      await tester.runAsync(loadScreenshotFonts);
      const paths = ['/customers', '/libyan-deposits'];
      for (final dark in [false, true]) {
        for (final size in [const Size(320, 780), const Size(430, 932)]) {
          await pumpFakeApp(tester, size: size);
          await tester.pump();
          if (dark) {
            await tester.tap(find.byKey(LoginScreen.themeKey));
            await settle(tester);
          }
          await signIn(tester, username: 'admin.demo', password: 'demo-only');
          for (final path in paths) {
            await go(tester, path);
            expect(find.byKey(const Key('summary-headline')), findsOneWidget);
            final theme = dark ? 'dark' : 'light';
            final name = path.replaceAll('/', '');
            await saveShot(
              tester,
              'summary-$name-$theme-${size.width.toInt()}',
            );
          }
        }
      }
    },
    tags: const ['screenshots'],
    skip: !_captureScreenshots,
  );
}

Finder _inside(Key key, String text) {
  return find.descendant(of: find.byKey(key), matching: find.text(text));
}
