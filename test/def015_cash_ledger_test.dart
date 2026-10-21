import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/treasury/treasury_screen.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets(
    'DEF-015 cash in and cash out refresh the ledger and the summaries',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(800, 2400));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');

      final homeCash = HomeShell.summaryKey('treasury.activeCash');
      await tester.ensureVisible(find.byKey(homeCash));
      expect(_inside(homeCash, '8,000 د.ل'), findsOneWidget);

      await go(tester, '/treasury');
      expect(find.byKey(const Key('cash-entry-ce_1')), findsOneWidget);
      expect(
        _inside(const Key('active-cash-card'), '8,000 د.ل'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('cash-in')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _submit(tester, '1250');

      expect(find.byKey(const Key('cash-entry-ce_8')), findsOneWidget);
      expect(find.byKey(const Key('cash-entry-ce_1')), findsOneWidget);
      expect(
        _inside(const Key('cash-entry-ce_8'), '1,250 د.ل'),
        findsOneWidget,
      );
      expect(
        _inside(const Key('cash-entry-ce_8'), '9,250 د.ل'),
        findsOneWidget,
      );
      expect(
        _inside(const Key('cash-entry-ce_8'), AppStrings.cashIn),
        findsOneWidget,
      );
      expect(
        _inside(const Key('active-cash-card'), '9,250 د.ل'),
        findsOneWidget,
      );
      expect(find.text('52,250 د.ل'), findsOneWidget);
      _expectAmountColor(
        tester,
        'ce_8',
        '1,250 د.ل',
        AppStatusColors.light.cashPositive,
      );
      _expectAmountColor(
        tester,
        'ce_1',
        '1,000 د.ل',
        AppStatusColors.light.cashPositive,
      );

      await tester.tap(find.byKey(const Key('cash-out')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _submit(tester, '200');

      expect(find.byKey(const Key('cash-entry-ce_9')), findsOneWidget);
      expect(_inside(const Key('cash-entry-ce_9'), '200 د.ل'), findsOneWidget);
      expect(
        _inside(const Key('cash-entry-ce_9'), '9,050 د.ل'),
        findsOneWidget,
      );
      expect(
        _inside(const Key('cash-entry-ce_9'), AppStrings.cashOut),
        findsOneWidget,
      );
      expect(
        _inside(const Key('cash-entry-ce_8'), '1,250 د.ل'),
        findsOneWidget,
      );
      expect(
        _inside(const Key('cash-entry-ce_8'), '9,250 د.ل'),
        findsOneWidget,
      );
      expect(
        _inside(const Key('active-cash-card'), '9,050 د.ل'),
        findsOneWidget,
      );
      expect(find.text('52,050 د.ل'), findsOneWidget);
      expect(find.text('52,250 د.ل'), findsNothing);
      _expectAmountColor(
        tester,
        'ce_9',
        '200 د.ل',
        AppStatusColors.light.cashNegative,
      );
      _expectAmountColor(
        tester,
        'ce_8',
        '1,250 د.ل',
        AppStatusColors.light.cashPositive,
      );

      await go(tester, '/');
      await tester.ensureVisible(find.byKey(homeCash));
      expect(_inside(homeCash, '9,050 د.ل'), findsOneWidget);
      expect(_inside(homeCash, '8,000 د.ل'), findsNothing);
      expect(find.byKey(TreasuryScreen.screenKey), findsNothing);
    },
  );
}

Finder _inside(Key key, String text) {
  return find.descendant(of: find.byKey(key), matching: find.text(text));
}

void _expectAmountColor(
  WidgetTester tester,
  String id,
  String amount,
  Color color,
) {
  final text = tester.widget<Text>(_inside(Key('cash-entry-$id'), amount));
  expect(text.style?.color, color);
}

Future<void> _submit(WidgetTester tester, String amount) async {
  await tester.enterText(
    find
        .descendant(of: find.byType(Dialog), matching: find.byType(TextField))
        .first,
    amount,
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('save-cash')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byKey(const Key('confirm-mutation')));
  await settle(tester);
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
