import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

/// The payment dialog stays real. The only stand-in is the fake client.
void main() {
  testWidgets('DEF-022 a payment conflict refetches the card and the ledger', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2200));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    expect(_header('320 د.ل'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('add-payment')));
    await tester.tap(find.byKey(const Key('add-payment')));
    await settle(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('movement-amount')),
        matching: find.byType(TextField),
      ),
      '100',
    );

    await tester.runAsync(
      () => layer.accounts.addTransaction(
        AccountSection.customers,
        'c_55',
        AccountTransactionRequest.partialPayment(
          inputValue: 1,
          date: DateTime.utc(2026, 10, 22),
        ),
        MutationMeta(expectedVersion: 4),
      ),
    );
    await tester.tap(find.byKey(const Key('save-movement')));
    await settle(tester);

    expect(find.text(AppStrings.versionConflict), findsWidgets);
    expect(find.text('تم تعديل البيانات من مستخدم آخر'), findsNothing);
    expect(_header('319 د.ل'), findsOneWidget);
    expect(_header('320 د.ل'), findsNothing);

    Navigator.of(tester.element(find.byType(Dialog))).pop();
    await settle(tester);
    final stored = await tester.runAsync(
      () => layer.accounts.get(AccountSection.customers, 'c_55'),
    );
    expect(stored!.balanceUnits?.units, 319);
    expect(stored.version, 5);

    await go(tester, '/customers');
    await go(tester, '/customers/c_55');
    expect(_header('319 د.ل'), findsOneWidget);
    expect(_header('320 د.ل'), findsNothing);
    expect(_header('220 د.ل'), findsNothing);
  });
}

Finder _header(String text) {
  return find.descendant(
    of: find.byKey(const Key('ledger-header-balance')),
    matching: find.text(text),
  );
}

Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(Duration.zero);
    if (!tester.binding.hasScheduledFrame) return;
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );
  }
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await settle(tester);
}
