import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/purchases/purchases_screen.dart';
import 'package:vib_abdo_company_mobile/state/theme_controller.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('purchases add, edit, delete, and totals stay consistent', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(360, 800), textScale: 1.3);
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    expect(find.byType(PurchasesScreen), findsOneWidget);
    expect(_tile(tester, 'purchase-total-work'), contains('1,053'));
    expect(find.byKey(const Key('edit-pe_1')), findsOneWidget);
    expect(find.byKey(const Key('delete-pe_1')), findsOneWidget);
    expect(find.byKey(const Key('purchase-saved-mark-pe_old')), findsOneWidget);
    expect(find.byKey(const Key('purchase-rollover-11')), findsOneWidget);

    await _show(tester, find.byKey(const Key('save-purchase')));
    await tester.tap(find.byKey(const Key('save-purchase')));
    await tester.pump();
    expect(find.text(AppStrings.chooseKind), findsOneWidget);

    await _show(tester, find.byKey(const Key('purchase-kind-fawry')));
    await tester.tap(find.byKey(const Key('purchase-kind-fawry')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('purchase-field-value')),
      'abc',
    );
    await tester.enterText(find.byKey(const Key('purchase-field-rate')), '10');
    await tester.enterText(find.byKey(const Key('purchase-field-paid')), '0');
    await _show(tester, find.byKey(const Key('save-purchase')));
    await tester.tap(find.byKey(const Key('save-purchase')));
    await tester.pump();
    expect(find.text(AppStrings.integerOnly), findsOneWidget);

    await _saveRow(tester, '100', paid: '0');
    expect(find.byKey(const Key('edit-pe_new_1')), findsOneWidget);
    expect(find.byKey(const Key('delete-pe_new_1')), findsOneWidget);
    expect(find.byKey(const Key('purchase-saved-mark-pe_new_1')), findsNothing);
    expect(find.byKey(const Key('edit-pe_1')), findsOneWidget);
    expect(_tile(tester, 'purchase-total-work'), contains('1,063'));
    expect(_tile(tester, 'purchase-total-debt'), contains('2,563'));

    await tester.ensureVisible(find.byKey(const Key('edit-pe_new_1')));
    await tester.tap(find.byKey(const Key('edit-pe_new_1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('save-purchase')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('purchase-field-value')),
      '200',
    );
    await tester.tap(find.byKey(const Key('save-purchase')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('edit-pe_new_1')), findsOneWidget);
    expect(_tile(tester, 'purchase-total-work'), contains('1,073'));

    await tester.ensureVisible(find.byKey(const Key('delete-pe_new_1')));
    await tester.tap(find.byKey(const Key('delete-pe_new_1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(AppStrings.confirmDelete), findsOneWidget);
    await tester.tap(find.text(AppStrings.cancel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('edit-pe_new_1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete-pe_new_1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('confirm-mutation')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('edit-pe_new_1')), findsNothing);
    expect(_tile(tester, 'purchase-total-work'), contains('1,053'));
    expect(find.byKey(const Key('edit-pe_1')), findsOneWidget);

    await _saveRow(tester, '100', paid: '0');
    await _saveRow(tester, '100', paid: '0');
    for (final id in ['pe_1', 'pe_new_2', 'pe_new_3']) {
      expect(find.byKey(Key('edit-$id')), findsOneWidget, reason: id);
      expect(find.byKey(Key('delete-$id')), findsOneWidget, reason: id);
    }
    expect(_tile(tester, 'purchase-total-work'), contains('1,073'));

    await tester.tap(find.text('سمسم'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('سمسم'), findsWidgets);
    expect(tester.takeException(), isNull);

    final scroll = find.byKey(const Key('purchase-ledger-scroll'));
    await tester.drag(scroll, const Offset(0, -240));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('purchases stay on screen at 360 scale 1.3 dark=$dark', (
      tester,
    ) async {
      await pumpFakeApp(tester, size: const Size(360, 800), textScale: 1.3);
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/purchases');
      if (dark) {
        final context = tester.element(find.byType(PurchasesScreen));
        ProviderScope.containerOf(context)
            .read(themeModeProvider.notifier)
            .toggle();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          Theme.of(tester.element(find.byType(PurchasesScreen))).brightness,
          Brightness.dark,
        );
      }
      await _saveRow(tester, '50', paid: '0');
      final edit = find.byKey(const Key('edit-pe_new_1'));
      expect(edit, findsOneWidget);
      final box = tester.getRect(edit);
      expect(box.left, greaterThanOrEqualTo(0));
      expect(box.right, lessThanOrEqualTo(360));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a carried purchases day shows the check until it is reopened', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(360, 900));
    (layer.client as FakeApiClient).purchaseFixtureStatus = 'finalized';
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    expect(find.byKey(const Key('purchase-saved-mark-pe_1')), findsOneWidget);
    expect(find.byKey(const Key('edit-pe_1')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('open-correction-12')));
    await tester.tap(find.byKey(const Key('open-correction-12')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('confirm-mutation')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('edit-pe_1')), findsOneWidget);
    expect(find.byKey(const Key('delete-pe_1')), findsOneWidget);
    expect(find.byKey(const Key('purchase-saved-mark-pe_1')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

String _tile(WidgetTester tester, String key) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)),
  );
  return texts.map((text) => text.data ?? '').join(' ');
}

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
}

Future<void> _saveRow(
  WidgetTester tester,
  String amount, {
  required String paid,
}) async {
  await _show(tester, find.byKey(const Key('purchase-kind-fawry')));
  await tester.tap(find.byKey(const Key('purchase-kind-fawry')));
  await tester.pump();
  await tester.enterText(find.byKey(const Key('purchase-field-value')), amount);
  await tester.enterText(find.byKey(const Key('purchase-field-rate')), '10');
  await tester.enterText(find.byKey(const Key('purchase-field-paid')), paid);
  await _show(tester, find.byKey(const Key('save-purchase')));
  await tester.tap(find.byKey(const Key('save-purchase')));
  await tester.pumpAndSettle();
}
