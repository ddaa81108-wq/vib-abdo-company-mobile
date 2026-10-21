import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/purchases/purchases_screen.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  const message = FakeApiClient.dayFinalizedMessage;

  testWidgets('a finalized purchases day hides add edit and delete', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
    (layer.client as FakeApiClient).purchaseFixtureStatus = 'finalized';
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');

    expect(find.byKey(const Key('purchase-day-12')), findsOneWidget);
    expect(find.text('فودافون كاش'), findsOneWidget);
    expect(find.byKey(const Key('add-purchase-12')), findsNothing);
    expect(find.byKey(const Key('edit-pe_1')), findsNothing);
    expect(find.byKey(const Key('delete-pe_1')), findsNothing);
    expect(find.text(AppStrings.add), findsNothing);
    expect(find.text(AppStrings.edit), findsNothing);
    expect(find.text(AppStrings.delete), findsNothing);
    expect(find.byKey(const Key('finalize-day-12')), findsNothing);
    expect(find.byKey(const Key('open-correction-12')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a finalized-day save shows the server message', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await tester.tap(find.byKey(const Key('add-purchase-12')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('purchase-kind-vodafone_cash')));
    await tester.pump();
    await fillLabeled(tester, AppStrings.egpValue, '10000');
    await fillLabeled(tester, AppStrings.exchangeRate, '9.5');
    await fillLabeled(tester, AppStrings.paid, '500');

    await tester.runAsync(
      () => layer.purchases.finalizeDay(
        PurchaseBook.alBayan,
        MutationMeta(expectedVersion: 3, requestId: 'finalize-before-save'),
      ),
    );
    await tester.tap(find.byKey(const Key('save-purchase')));
    await settle(tester);

    expect(find.byKey(const Key('mutation-error')), findsOneWidget);
    expect(find.text(message), findsOneWidget);
    expect(find.text(AppStrings.versionConflict), findsNothing);
    final page = (await tester.runAsync(
      () => layer.purchases.list(PurchaseBook.alBayan),
    ))!;
    expect(page.page.items.single.status, 'finalized');
    expect(page.page.items.single.version, 4);
    expect(page.page.items.single.entries.single.id, 'pe_1');
    expect(page.page.items.single.entries.single.paidUnits, 500);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a finalized-day delete shows the server message', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await show(tester, find.byKey(const Key('delete-pe_1')));
    await tester.tap(find.byKey(const Key('delete-pe_1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(AppStrings.confirmDelete), findsOneWidget);

    await tester.runAsync(
      () => layer.purchases.finalizeDay(
        PurchaseBook.alBayan,
        MutationMeta(expectedVersion: 3, requestId: 'finalize-before-delete'),
      ),
    );
    await tester.tap(find.byKey(const Key('confirm-mutation')));
    await settle(tester);

    expect(find.byKey(const Key('mutation-error')), findsOneWidget);
    expect(find.text(message), findsOneWidget);
    expect(find.text(AppStrings.versionConflict), findsNothing);
    final page = (await tester.runAsync(
      () => layer.purchases.list(PurchaseBook.alBayan),
    ))!;
    expect(page.page.items.single.status, 'finalized');
    expect(page.page.items.single.version, 4);
    expect(page.page.items.single.entries, hasLength(1));
    expect(page.page.items.single.entries.single.id, 'pe_1');
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

Future<void> fillLabeled(
  WidgetTester tester,
  String label,
  String value,
) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  await tester.enterText(field.hitTestable(), value);
  await tester.pump();
}

Future<void> show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.descendant(
      of: find.byKey(PurchasesScreen.screenKey),
      matching: find.byWidgetPredicate(
        (widget) => widget is Scrollable && widget.axis == Axis.vertical,
      ),
    ),
  );
  await tester.pump();
}
