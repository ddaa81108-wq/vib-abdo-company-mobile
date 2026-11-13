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
  for (final (scale, dark) in const [(1.0, false), (1.3, false), (1.0, true)]) {
    testWidgets(
      'purchase totals and ledger fit 440x956 scale $scale dark $dark',
      (tester) async {
        await pumpFakeApp(tester, size: const Size(440, 956), textScale: scale);
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
        final wideScroll = find.byKey(const Key('purchase-ledger-scroll'));
        if (wideScroll.evaluate().isNotEmpty) {
          expect(
            tester.widget<SingleChildScrollView>(wideScroll).scrollDirection,
            Axis.horizontal,
          );
        }

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
            matching: find.text('الباقي المرحّل من اليوم السابق'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('purchase-rollover-11')),
            matching: find.text('الباقي المُرحّل لليوم التالي — يوم #11'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('purchase-rollover-11')),
            matching: find.text('2026-10-19'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('purchase-rollover-11')),
            matching: find.text('2026-10-18'),
          ),
          findsNothing,
        );
        final booksTop = tester
            .getRect(find.byKey(const Key('purchase-books')))
            .top;
        final vodafoneBottom = tester
            .getRect(find.byKey(const Key('purchase-vodafone-ours')))
            .bottom;
        final textScale = MediaQuery.textScalerOf(
          tester.element(find.byKey(PurchasesScreen.screenKey)),
        ).scale(1);
        expect(vodafoneBottom - booksTop, lessThan(textScale <= 1 ? 400 : 480));
        expect(previous.height, lessThan(80));
        final previousLabel = tester.getRect(
          find.descendant(
            of: find.byKey(const Key('purchase-total-previous')),
            matching: find.text('القيمة السابقة'),
          ),
        );
        expect(
          (previousLabel.center.dx - previous.center.dx).abs(),
          lessThan(16),
        );
        final addSize = tester.getSize(
          find.byKey(const Key('add-purchase-12')),
        );
        final finalizeSize = tester.getSize(
          find.byKey(const Key('finalize-day-12')),
        );
        expect(addSize.width, closeTo(finalizeSize.width, 12));
        expect(
          tester.getRect(find.text('البيان')).center.dx,
          greaterThan(tester.getRect(find.text('سمسم')).center.dx),
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('purchase-rollover-11')),
            matching: find.textContaining('2,000'),
            skipOffstage: false,
          ),
          findsNWidgets(2),
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
            matching: find.textContaining('2,553'),
          ),
          findsOneWidget,
        );
        if (wideScroll.evaluate().isNotEmpty) {
          final entry = find.byKey(const Key('purchase-entry-pe_1'));
          expect(
            find.descendant(of: entry, matching: find.textContaining('10,000')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: entry, matching: find.text('ج.م')),
            findsNothing,
          );
        }
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
    expect(find.text('\u00F7'), findsWidgets);
    expect(find.bySemanticsLabel(AppStrings.divide), findsWidgets);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    final menu = find.byType(DropdownButton<CalculationMode>);
    await tester.ensureVisible(menu);
    await tester.pump();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.text('\u00D7'), findsWidgets);
    expect(find.bySemanticsLabel(AppStrings.multiply), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'writing stays in the ledger and the focused cell stays visible',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(440, 956));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/purchases');
      await tester.tap(find.byKey(const Key('add-purchase-12')));
      await settle(tester);

      expect(find.byKey(const Key('purchase-inline-row')), findsOneWidget);
      expect(find.byKey(const Key('purchase-ledger')), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);

      final value = find.descendant(
        of: find.byKey(const Key('purchase-field-value')),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(value).focusNode.hasFocus, isTrue);

      final gridLine =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const Key('purchase-grid-cell-pe_old')),
                  )
                  .decoration
              as BoxDecoration;
      final side = (gridLine.border! as Border).top;
      expect(side.width, 1);
      expect((gridLine.border! as Border).left.width, 1);
      expect((gridLine.border! as Border).right.width, 1);
      expect((gridLine.border! as Border).bottom.width, 1);

      Future<void> next() async {
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));
      }

      bool inside(Finder field) {
        final item = tester.getRect(field);
        final port = tester.getRect(
          find.byKey(const Key('purchase-ledger-scroll')),
        );
        return item.left >= port.left - 8 && item.right <= port.right + 8;
      }

      expect(inside(find.byKey(const Key('purchase-field-value'))), isTrue);
      await next();
      final rate = find.descendant(
        of: find.byKey(const Key('purchase-field-rate')),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(rate).focusNode.hasFocus, isTrue);
      expect(inside(find.byKey(const Key('purchase-field-rate'))), isTrue);
      await next();
      await next();
      final vodafone = find.descendant(
        of: find.byKey(const Key('purchase-field-vodafone')),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(vodafone).focusNode.hasFocus, isTrue);
      expect(inside(find.byKey(const Key('purchase-field-vodafone'))), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
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
