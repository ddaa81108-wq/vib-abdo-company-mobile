import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

/// The payment dialog and the ledger stay real. Only [FakeApiClient] stands in.
void main() {
  testWidgets(
    'DEF-031 cancelling the overpayment warning sends nothing and keeps 320',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 2200));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/customers/c_55');
      expect(_header('320 د.ل'), findsOneWidget);

      final fake = layer.client as FakeApiClient;
      final postsBefore = fake.mutationPaths.length;
      await tester.ensureVisible(find.byKey(const Key('add-payment')));
      await tester.tap(find.byKey(const Key('add-payment')));
      await settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('movement-amount')),
          matching: find.byType(TextField),
        ),
        '400',
      );
      await tester.tap(find.byKey(const Key('save-movement')));
      await pumpUntil(tester, find.byKey(const Key('overpayment-warning')));

      expect(find.byKey(const Key('overpayment-warning')), findsOneWidget);
      expect(find.text(AppStrings.amountAboveRemaining), findsNothing);
      expect(find.byKey(const Key('save-movement')), findsOneWidget);
      expect(fake.mutationPaths, hasLength(postsBefore));
      expect(_header('320 د.ل'), findsOneWidget);
      expect(_header('-80 د.ل'), findsNothing);

      await tester.tap(find.byKey(const Key('overpayment-cancel')));
      await settle(tester);
      expect(fake.mutationPaths, hasLength(postsBefore));
      expect(
        fake.mutationPaths.where((path) => path.contains('/transactions')),
        isEmpty,
      );
      final stored = await tester.runAsync(
        () => layer.accounts.get(AccountSection.customers, 'c_55'),
      );
      expect(stored!.balanceUnits?.units, 320);
      expect(stored.version, 4);

      await go(tester, '/customers');
      await go(tester, '/customers/c_55');
      expect(_header('320 د.ل'), findsOneWidget);
      expect(_header('-80 د.ل'), findsNothing);
    },
  );
}

Finder _header(String text) {
  return find.descendant(
    of: find.byKey(const Key('ledger-header-balance')),
    matching: find.text(text),
  );
}

Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
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
