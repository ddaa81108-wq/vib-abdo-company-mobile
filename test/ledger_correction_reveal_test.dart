import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';

import 'support/pump_app.dart';
import 'support/phase7_ui.dart';

void main() {
  for (final route in [
    '/customers/c_55',
    '/companies/c_co_02',
    '/libyan-deposits/c_55',
    '/egyptian-deposits/c_eg_08',
  ]) {
    for (final long in [false, true]) {
      for (final dark in [false, true]) {
        for (final width in [360.0, 430.0]) {
          testWidgets(
            '$route pencil reveals the form without manual scroll long=$long dark=$dark width=$width',
            (tester) async {
              await pumpFakeApp(
                tester,
                size: Size(width, 900),
                overrides: [
                  if (long)
                    ledgerProvider.overrideWith((ref, key) async {
                      final raw = FakeFixtures.ledger();
                      final sample = Map<String, dynamic>.from(
                        (raw['items'] as List).first as Map,
                      );
                      return LedgerPage.fromData({
                        ...raw,
                        'nextCursor': null,
                        'items': [
                          for (var i = 0; i < 28; i++)
                            {
                              ...sample,
                              'id': 'long_$i',
                              'sequence': i + 1,
                              'type': 'debt',
                              'paymentMode': null,
                              'date': '2026-11-18',
                              'amountUnits': 10,
                              'inputValue': 10,
                            },
                        ],
                      }, key.$1);
                    }),
                ],
              );
              if (dark) {
                await tester.tap(find.byKey(LoginScreen.themeKey));
                await settle(tester);
              }
              await signIn(
                tester,
                username: 'admin.demo',
                password: 'demo-only',
              );
              await go(tester, route);
              final rows = tester
                  .widget<SingleChildScrollView>(
                    find.byKey(const Key('ledger-columns-scroll')),
                  )
                  .controller!;
              rows.jumpTo(rows.position.maxScrollExtent);
              await settle(tester);
              final entry = long ? 'long_27' : 'tx_1';
              final pencil = find.byKey(Key('correct-$entry'));
              expect(pencil.hitTestable(), findsOneWidget);
              await tester.tap(pencil);
              await settle(tester);
              final amount = find.byKey(const Key('correction-amount'));
              expect(
                amount.hitTestable(),
                findsOneWidget,
                reason: 'opening must reveal the amount field without ensureVisible in the test',
              );
              final rect = tester.getRect(amount);
              final editedRow = tester.getRect(
                find.byKey(Key('ledger-row-$entry')),
              );
              expect(
                editedRow.height,
                lessThan(150),
                reason: 'editing replaces the row instead of opening a form below it',
              );
              expect(rect.center.dy, greaterThanOrEqualTo(editedRow.top));
              expect(rect.center.dy, lessThanOrEqualTo(editedRow.bottom));
              final tableTop = tester
                  .getRect(find.byKey(const Key('ledger-column-header')))
                  .bottom;
              final footerTop = tester
                  .getRect(find.byKey(const Key('ledger-header')))
                  .top;
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(width));
              expect(rect.top, greaterThanOrEqualTo(tableTop));
              expect(rect.bottom, lessThanOrEqualTo(footerTop));
              expect(find.byKey(const Key('correction-form')), findsOneWidget);
              final close = find.byKey(Key('close-inline-edit-$entry'));
              await tester.ensureVisible(close);
              await settle(tester);
              expect(close.hitTestable(), findsOneWidget);
              await tester.tap(close);
              await settle(tester);
              expect(find.byKey(const Key('correction-form')), findsNothing);
              expect(tester.takeException(), isNull);
              await tester.pump(const Duration(seconds: 1));
            },
          );
        }
      }
    }
  }
}
