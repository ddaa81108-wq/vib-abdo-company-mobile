import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:vib_abdo_company_mobile/features/accounts/website_account_card.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';
import 'support/phase7_ui.dart';
import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;

void main() {
  // Start with customers; the same acceptance checks then cover the other
  // sections without sharing balances, currencies, or transaction providers.
  for (final section in [
    'customers',
    'companies',
    'libyan-deposits',
    'egyptian-deposits',
  ]) {
    for (final dark in [false, true]) {
      for (final width in [320.0, 390.0, 800.0]) {
        testWidgets('$section frame03 dark=$dark width=$width', (tester) async {
          await pumpFakeApp(tester, size: Size(width, 1000));
          if (width == 390) await tester.runAsync(loadScreenshotFonts);
          if (dark) {
            await tester.tap(find.byKey(LoginScreen.themeKey));
            await settle(tester);
          }
          await signIn(tester, username: 'admin.demo', password: 'demo-only');
          await go(tester, '/$section');
          expect(find.byIcon(Icons.push_pin), findsNothing);
          expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
          expect(find.text(AppStrings.pinnedTab), findsNothing);
          final frame = tester.widget<CustomPaint>(
            find.byKey(const Key('account-frame-c_55')),
          );
          expect(frame.painter, isA<AccountCardFrame03>());
          final body = tester.widget<WebsiteAccountCardBody>(
            find.descendant(
              of: find.byKey(const Key('account-card-c_55')),
              matching: find.byType(WebsiteAccountCardBody),
            ),
          );
          final amount = body.amount;
          final status = body.status;
          final expectedInk = body.card.balanceUnits?.asInt == 0
              ? websiteCardZeroInk(light: !dark)
              : dark
              ? Colors.white
              : websiteCardNatureInk(
                  AccountSection.values.firstWhere(
                    (value) => value.path == section,
                  ),
                  body.card.balanceUnits?.asInt,
                );
          expect(body.ink, expectedInk);
          expect(amount, isNotEmpty);
          expect(status, isNotEmpty);
          expect(
            tester.getSize(find.byKey(const Key('account-card-c_55'))).width,
            lessThanOrEqualTo(width),
          );
          if (width == 390) {
            await saveShot(
              tester,
              'frame03-$section-${dark ? "night" : "day"}',
            );
            await settle(tester);
          }
          // The painted border cannot intercept opening the original ledger.
          await tester.tap(find.byKey(const Key('account-amount-c_55')));
          await settle(tester);
          expect(find.byKey(const Key('ledger-pinned')), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pump(const Duration(seconds: 1));
        });
      }
    }
  }
}
