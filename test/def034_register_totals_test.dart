import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/features/purchases/purchases_screen.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

const _captureScreenshots = bool.fromEnvironment('CAPTURE_SCREENSHOTS');

const _totalsKey = Key('purchases-lifetime');

void main() {
  for (final dark in [false, true]) {
    for (final size in [const Size(320, 1400), const Size(430, 1400)]) {
      final theme = dark ? 'dark' : 'light';
      testWidgets(
        'DEF-034 $theme ${size.width.toInt()} shows server register totals',
        (tester) async {
          final layer = await pumpFakeApp(tester, size: size);
          if (dark) {
            await tester.tap(find.byKey(LoginScreen.themeKey));
            await settle(tester);
          }
          await signIn(tester, username: 'admin.demo', password: 'demo-only');
          await go(tester, '/purchases');

          final page = await tester.runAsync(
            () => layer.purchases.list(PurchaseBook.alBayan),
          );
          final money = layer.money;
          final totals = page!.registerTotals!;
          final day = page.day!;

          expect(_inside(_totalsKey, AppStrings.registerTotals), findsNothing);
          expect(
            _inside(
              _totalsKey,
              money.formatOrDash(totals.resultUnits, Currency.lyd),
            ),
            findsOneWidget,
          );
          expect(
            _inside(
              _totalsKey,
              money.formatOrDash(totals.paidUnits, Currency.lyd),
            ),
            findsOneWidget,
          );
          expect(
            _inside(
              _totalsKey,
              money.formatOrDash(totals.remainingUnits, Currency.lyd),
            ),
            findsOneWidget,
          );
          expect(
            _inside(
              _totalsKey,
              money.formatOrDash(totals.vodafoneConsumedUnits, Currency.egp),
            ),
            findsWidgets,
          );
          expect(
            _inside(
              _totalsKey,
              money.formatOrDash(totals.vodafoneRemainingUnits, Currency.egp),
            ),
            findsWidgets,
          );
          expect(find.byKey(const Key('register-totals-note')), findsOneWidget);
          expect(find.text(AppStrings.remainingRunningBalance), findsOneWidget);
          // The entry's own remaining is not the register figure.
          expect(
            _inside(
              _totalsKey,
              money.formatOrDash(
                page.entries.single.remainingUnits,
                Currency.lyd,
              ),
            ),
            findsNothing,
          );
          expect(
            _inside(
              const Key('opening-card'),
              money.formatOrDash(day.previousDebtUnits, Currency.lyd),
            ),
            findsOneWidget,
          );
          expect(
            _inside(
              const Key('opening-card'),
              money.formatOrDash(day.previousVodafoneUnits, Currency.egp),
            ),
            findsOneWidget,
          );
          expect(day.correctionOpen, isFalse);
          expect(find.text(AppStrings.correctionClosed), findsOneWidget);
          expect(find.text(AppStrings.correctionOpen), findsNothing);
          expect(_dayCards(), findsOneWidget);
          expect(
            Directionality.of(
              tester.element(find.byKey(PurchasesScreen.screenKey)),
            ),
            TextDirection.rtl,
          );
          expect(
            Theme.of(tester.element(find.byKey(PurchasesScreen.screenKey)))
                .brightness,
            dark ? Brightness.dark : Brightness.light,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'DEF-034 remaining is the server register total, not a sum of rows',
    (tester) async {
      await pumpFakeApp(
        tester,
        size: const Size(430, 1600),
        overrides: [
          purchasesProvider.overrideWith((ref) async {
            return PurchasesPage.fromData({
              'day': {
                'id': 'day-1',
                'dayNumber': 1,
                'status': 'draft',
                'previousDebtUnits': 0,
                'previousVodafoneUnits': 5000,
                'todayResultUnits': 100,
                'todayPaidUnits': 20,
                'totalDebtUnits': 80,
                'vodafoneRemainingUnits': 4900,
                'version': 2,
                'correctionOpen': false,
              },
              'entries': [
                {
                  'id': 'pe_open',
                  'dayNumber': 1,
                  'itemLabel': 'صف اليوم',
                  'remainingUnits': 40,
                  'resultUnits': 1,
                  'paidUnits': 1,
                },
                {
                  'id': 'pe_older',
                  'dayNumber': 4,
                  'itemLabel': 'صف يوم آخر',
                  'remainingUnits': 30,
                  'resultUnits': 2,
                  'paidUnits': 2,
                },
              ],
              'registerTotals': {
                'resultUnits': 100,
                'paidUnits': 20,
                'remainingUnits': 80,
                'vodafoneConsumedUnits': 100,
                'vodafoneRemainingUnits': 4900,
              },
            });
          }),
        ],
      );
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/purchases');

      expect(_inside(_totalsKey, '80 د.ل'), findsOneWidget);
      expect(_inside(_totalsKey, '100 د.ل'), findsOneWidget);
      expect(_inside(_totalsKey, '20 د.ل'), findsOneWidget);
      expect(_inside(_totalsKey, '100 ج.م'), findsOneWidget);
      expect(_inside(_totalsKey, '4,900 ج.م'), findsOneWidget);
      expect(find.text('70 د.ل'), findsNothing);
      expect(_inside(const Key('opening-card'), '0 د.ل'), findsOneWidget);
      expect(_inside(const Key('opening-card'), '5,000 ج.م'), findsOneWidget);
      expect(find.byKey(const Key('purchase-day-1')), findsOneWidget);
      expect(find.byKey(const Key('purchase-day-4')), findsNothing);
      expect(_dayCards(), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('purchase-day-1')),
          matching: find.byKey(const Key('purchase-entry-pe_older')),
        ),
        findsOneWidget,
      );
      expect(find.text(AppStrings.remainingRunningBalance), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('DEF-034 correctionOpen is the boolean, not a status value', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      size: const Size(430, 1200),
      overrides: [
        purchasesProvider.overrideWith((ref) async {
          return PurchasesPage.fromData({
            'day': {
              'id': 'day-9',
              'dayNumber': 9,
              'status': 'correction',
              'version': 1,
              'correctionOpen': false,
              'previousDebtUnits': 0,
              'previousVodafoneUnits': 0,
            },
            'entries': <Map<String, dynamic>>[],
            'registerTotals': {
              'resultUnits': 0,
              'paidUnits': 0,
              'remainingUnits': 0,
              'vodafoneConsumedUnits': 0,
              'vodafoneRemainingUnits': 0,
            },
          });
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');

    expect(find.text(AppStrings.correctionClosed), findsOneWidget);
    expect(find.text(AppStrings.correctionOpen), findsNothing);
    expect(find.byKey(const Key('open-correction-9')), findsNothing);
    expect(find.byKey(const Key('close-correction-9')), findsNothing);
    expect(find.byKey(const Key('finalize-day-9')), findsNothing);

    await pumpFakeApp(
      tester,
      size: const Size(430, 1200),
      overrides: [
        purchasesProvider.overrideWith((ref) async {
          return PurchasesPage.fromData({
            'day': {
              'id': 'day-9',
              'dayNumber': 9,
              'status': 'finalized',
              'version': 4,
              'correctionOpen': true,
              'previousDebtUnits': 1,
              'previousVodafoneUnits': 2,
            },
            'entries': <Map<String, dynamic>>[],
            'registerTotals': {
              'resultUnits': 1,
              'paidUnits': 1,
              'remainingUnits': 1,
              'vodafoneConsumedUnits': 1,
              'vodafoneRemainingUnits': 1,
            },
          });
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');

    expect(find.text(AppStrings.correctionOpen), findsOneWidget);
    expect(find.byKey(const Key('close-correction-9')), findsOneWidget);
    expect(find.byKey(const Key('open-correction-9')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'DEF-034 register totals screenshots',
    (tester) async {
      await tester.runAsync(loadScreenshotFonts);
      for (final dark in [false, true]) {
        for (final width in [320.0, 430.0]) {
          await pumpFakeApp(
            tester,
            size: Size(width, width == 320 ? 780 : 932),
          );
          await tester.pump();
          if (dark) {
            await tester.tap(find.byKey(LoginScreen.themeKey));
            await settle(tester);
          }
          await signIn(tester, username: 'admin.demo', password: 'demo-only');
          await go(tester, '/purchases');
          await tester.ensureVisible(
            find.byKey(const Key('register-totals-note')),
          );
          await tester.pump();
          expect(find.text(AppStrings.remainingRunningBalance), findsOneWidget);
          final theme = dark ? 'dark' : 'light';
          await saveShot(tester, 'purchases-register-$theme-${width.toInt()}');
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

Finder _dayCards() {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('purchase-day-');
  });
}
