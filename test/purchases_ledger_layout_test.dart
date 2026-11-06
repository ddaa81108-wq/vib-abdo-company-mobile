import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/purchases/purchases_screen.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/state/theme_controller.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  for (final (scale, dark) in const [
    (1.0, false),
    (1.3, false),
    (1.0, true),
  ]) {
    testWidgets(
      'purchase totals and ledger fit 440x956 scale $scale dark $dark',
      (tester) async {
        await pumpFakeApp(
          tester,
          size: const Size(440, 956),
          textScale: scale,
        );
        await signIn(tester, username: 'admin.demo', password: 'demo-only');
        await go(tester, '/purchases');
        if (dark) {
          final container = ProviderScope.containerOf(
            tester.element(find.byKey(HomeShell.shellKey)),
          );
          container.read(themeModeProvider.notifier).toggle();
          await settle(tester);
        }

        expect(
          Directionality.of(
            tester.element(find.byKey(PurchasesScreen.screenKey)),
          ),
          TextDirection.rtl,
        );
        expect(find.byKey(const Key('purchase-ledger')), findsOneWidget);
        expect(
          tester
              .widget<SingleChildScrollView>(
                find.byKey(const Key('purchase-ledger-scroll')),
              )
              .scrollDirection,
          Axis.horizontal,
        );

        final previous = tester.getRect(
          find.byKey(const Key('purchase-total-previous')),
        );
        final work = tester.getRect(
          find.byKey(const Key('purchase-total-work')),
        );
        final paid = tester.getRect(
          find.byKey(const Key('purchase-total-paid')),
        );
        final debt = tester.getRect(
          find.byKey(const Key('purchase-total-debt')),
        );
        for (final rect in [work, paid, debt]) {
          expect(rect.width, closeTo(previous.width, 1));
          expect(rect.height, closeTo(previous.height, 1));
        }
        expect(previous.center.dx, greaterThan(work.center.dx));
        expect(paid.center.dx, greaterThan(debt.center.dx));
        expect(work.top, closeTo(previous.top, 1));
        expect(debt.top, greaterThan(previous.bottom - 1));

        final vodafone = tester.getRect(
          find.byKey(const Key('purchase-vodafone-ours')),
        );
        expect(vodafone.width, greaterThan(previous.width * 1.5));
        expect(vodafone.top, greaterThan(debt.top));

        final add = tester.getRect(find.byKey(const Key('add-purchase-12')));
        final finalize = tester.getRect(
          find.byKey(const Key('finalize-day-12')),
        );
        expect(add.center.dx, greaterThan(finalize.center.dx));
        expect(find.text('إضافة معاملة'), findsOneWidget);
        expect(find.text(AppStrings.finalizeDay), findsOneWidget);

        final oldRow = tester.getRect(
          find.byKey(const Key('purchase-entry-pe_old')),
        );
        final gap = tester.getRect(
          find.byKey(const Key('purchase-rollover-11')),
        );
        final today = tester.getRect(
          find.byKey(const Key('purchase-entry-pe_1')),
        );
        expect(oldRow.bottom, lessThanOrEqualTo(gap.top + 1));
        expect(gap.bottom, lessThanOrEqualTo(today.top + 1));
        expect(
          find.descendant(
            of: find.byKey(const Key('purchase-rollover-11')),
            matching: find.text('آخر باقي'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('purchase-rollover-11')),
            matching: find.textContaining('2,000'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('purchase-entry-pe_1')),
            matching: find.textContaining('1,053'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('purchase-entry-pe_1')),
            matching: find.textContaining('553'),
          ),
          findsOneWidget,
        );
        final entry = find.byKey(const Key('purchase-entry-pe_1'));
        final number = tester.getRect(
          find.descendant(of: entry, matching: find.textContaining('10,000')),
        );
        final symbols = find.descendant(of: entry, matching: find.text('ج.م'));
        final beside = List.generate(symbols.evaluate().length, (index) {
          return tester.getRect(symbols.at(index));
        }).where((rect) => (rect.center.dy - number.center.dy).abs() < 12);
        expect(beside, isNotEmpty);
        expect(beside.first.center.dx, lessThan(number.center.dx));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('each trader ledger stays on its own book', (tester) async {
    await pumpFakeApp(
      tester,
      size: const Size(440, 956),
      overrides: [
        purchasesProvider.overrideWith((ref) async {
          final book = ref.watch(purchaseBookProvider);
          final simsim = book == PurchaseBook.simsim;
          return PurchasesPage.fromData({
            'day': {
              'id': simsim ? 's' : 'b',
              'dayNumber': 1,
              'status': 'draft',
              'version': 1,
              'previousDebtUnits': 1,
              'todayResultUnits': 2,
              'todayPaidUnits': 3,
              'totalDebtUnits': 4,
              'vodafoneRemainingUnits': 5,
            },
            'entries': [
              {
                'id': simsim ? 'sim_only' : 'bay_only',
                'dayId': simsim ? 's' : 'b',
                'sequence': 1,
                'itemCode': 'banks',
                'itemLabel': simsim ? 'صف سمسم' : 'صف البيان',
                'egpValueUnits': 10,
                'calculationMode': 'multiply',
                'exchangeRate': '2',
                'resultUnits': 20,
                'paidUnits': 1,
                'remainingUnits': 19,
                'vodafoneConsumedUnits': 0,
                'version': 1,
                'dayVersion': 1,
              },
            ],
            'registerTotals': {
              'resultUnits': 20,
              'paidUnits': 1,
              'remainingUnits': 19,
              'vodafoneConsumedUnits': 0,
              'vodafoneRemainingUnits': 5,
            },
          });
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');

    expect(find.byKey(const Key('purchase-ledger')), findsOneWidget);
    expect(find.text('صف البيان'), findsOneWidget);
    expect(find.text('صف سمسم'), findsNothing);
    expect(find.byKey(const Key('purchase-entry-bay_only')), findsOneWidget);

    await tester.tap(find.text(AppStrings.simsim));
    await settle(tester);
    expect(find.text('صف سمسم'), findsOneWidget);
    expect(find.text('صف البيان'), findsNothing);
    expect(find.byKey(const Key('purchase-entry-sim_only')), findsOneWidget);
    expect(find.byKey(const Key('purchase-entry-bay_only')), findsNothing);
    expect(find.byKey(const Key('purchase-ledger')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add form keeps the server item codes and divide or multiply', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(440, 956));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await tester.tap(find.byKey(const Key('add-purchase-12')));
    await settle(tester);

    for (final code in PurchaseItemCodes.values) {
      expect(find.byKey(Key('purchase-kind-$code')), findsOneWidget);
    }
    expect(find.text(AppStrings.kindVodafone), findsOneWidget);
    expect(find.text(AppStrings.kindKafr), findsOneWidget);
    expect(find.text(AppStrings.kindCairo), findsOneWidget);
    expect(find.text(AppStrings.kindMansoura), findsOneWidget);
    expect(find.text(AppStrings.kindFawry), findsOneWidget);
    expect(find.text(AppStrings.kindBanks), findsOneWidget);
    expect(find.text(AppStrings.otherKind), findsOneWidget);
    expect(find.text('فورى'), findsNothing);
    expect(find.text(AppStrings.divide), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<CalculationMode>));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.multiply), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await settle(tester);
}

Future<void> settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
