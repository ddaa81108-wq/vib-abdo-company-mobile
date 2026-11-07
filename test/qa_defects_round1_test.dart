import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets(
    'DEF-002 limited admin can approve because the server grants decide',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(800, 2400));
      await signIn(
        tester,
        username: 'limited.admin.demo',
        password: 'demo-only',
      );
      await go(tester, '/collections');

      final approve = find.byKey(const Key('approve-sb_1'));
      expect(approve, findsOneWidget);
      expect(find.byKey(const Key('cash-sb_2')), findsNothing);
      await tester.ensureVisible(approve);
      await tester.tap(approve);
      await settle(tester);

      expect(find.text('هذا الإجراء للإدارة فقط'), findsNothing);
      expect(find.byKey(const Key('approve-sb_1')), findsNothing);
      // 537f073 history: an approved receipt waits for its cash.
      expect(find.byKey(const ValueKey('awaiting-cash-sb_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('awaiting-cash-sb_2')), findsOneWidget);
    },
  );

  testWidgets('DEF-003 full payment refreshes the ledger header and the list', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(800, 2200));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');

    expect(_headerAmount('320 د.ل'), findsOneWidget);
    // The add row: choose دفع كلي, then its save button.
    await tester.ensureVisible(find.byKey(const Key('composer-full')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.byKey(const Key('composer-full')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('composer-full')));
    await tester.pump();
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('full-payment')));
    await tester.pump(const Duration(milliseconds: 400));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('full-payment')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('full-payment')));
    await settle(tester);

    expect(_headerAmount('0 د.ل'), findsOneWidget);
    expect(_headerAmount('320 د.ل'), findsNothing);

    await go(tester, '/customers');
    expect(find.text('0 د.ل'), findsWidgets);
    expect(find.text('320 د.ل'), findsNothing);
  });

  testWidgets('DEF-004 cancel refreshes the header and the card list', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2200));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');

    expect(_headerAmount('320 د.ل'), findsOneWidget);
    final cancel = find.byKey(const Key('cancel-tx_2'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('confirm-mutation')));
    await settle(tester);

    // Cancel sends the CARD version (c_55 is 4), as production requires.
    final fake = layer.client as FakeApiClient;
    expect(
      fake.mutationPaths.last,
      '/api/customers/c_55/transactions/tx_2/cancel',
    );
    expect((jsonDecode(fake.mutationBodies.last) as Map)['expectedVersion'], 4);
    expect(_headerAmount('320 د.ل'), findsNothing);
    expect(_headerAmount('500 د.ل'), findsOneWidget);

    await go(tester, '/customers');
    expect(find.text('500 د.ل'), findsWidgets);
    expect(find.text('320 د.ل'), findsNothing);
  });

  testWidgets('DEF-005 approval changes status', (tester) async {
    await pumpFakeApp(tester, size: const Size(800, 2400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');

    // 537f073: approved and no cash yet is «ينتظر استلام النقدية».
    expect(find.byKey(const ValueKey('awaiting-cash-sb_2')), findsOneWidget);
    expect(find.byKey(const ValueKey('awaiting-cash-sb_1')), findsNothing);
    final approve = find.byKey(const Key('approve-sb_1'));
    await tester.ensureVisible(approve);
    await tester.tap(approve);
    await settle(tester);

    expect(find.byKey(const Key('approve-sb_1')), findsNothing);
    expect(find.byKey(const ValueKey('awaiting-cash-sb_1')), findsOneWidget);
  });

  testWidgets(
    'DEF-005 a stale approval refetches and shows the conflict message',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 2400));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/collections');

      // The fake client waits on a timer. Run it off the widget clock so the
      // overview stays on the stale version until the button sends.
      await tester.runAsync(
        () => layer.collections.decide(
          'sb_1',
          CollectionDecision.approve,
          meta: MutationMeta(expectedVersion: 1),
        ),
      );
      final approve = find.byKey(const Key('approve-sb_1'));
      expect(approve, findsOneWidget);
      await tester.ensureVisible(approve);
      await tester.tap(approve);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find
                .text(FakeApiClient.submissionAlreadyDecidedMessage)
                .evaluate()
                .isNotEmpty &&
            find.byKey(const Key('approve-sb_1')).evaluate().isEmpty) {
          break;
        }
      }

      expect(
        find.text(FakeApiClient.submissionAlreadyDecidedMessage),
        findsWidgets,
      );
      expect(find.byKey(const Key('approve-sb_1')), findsNothing);
      expect(find.byKey(const ValueKey('awaiting-cash-sb_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('awaiting-cash-sb_2')), findsOneWidget);
      await settle(tester);
    },
  );

  testWidgets('DEF-016 full payment no longer shows the 320 home debt row', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2200));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    // Home has no debt bulletin now (icon grid only); the server value is
    // checked below.
    expect(_debtAmount('320 د.ل'), findsNothing);

    await go(tester, '/customers/c_55');
    // The add row: choose دفع كلي, then its save button.
    await tester.ensureVisible(find.byKey(const Key('composer-full')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.byKey(const Key('composer-full')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('composer-full')));
    await tester.pump();
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('full-payment')));
    await tester.pump(const Duration(milliseconds: 400));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('full-payment')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('full-payment')));
    await settle(tester);

    await go(tester, '/');
    final card = await tester.runAsync(
      () => layer.accounts.get(AccountSection.customers, 'c_55'),
    );
    final shown = layer.money.format(card!.balanceUnits!.units!, Currency.lyd);
    expect(card.balanceUnits?.units, 0);
    expect(_debtAmount('320 د.ل'), findsNothing);
    expect(_debtAmount(shown), findsNothing);
  });

  testWidgets('DEF-016 a partial payment shows the stored home balance', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2200));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    await tester.ensureVisible(find.byKey(const Key('add-payment')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.byKey(const Key('add-payment')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('add-payment')));
    await settle(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('movement-amount')),
        matching: find.byType(TextField),
      ),
      '100',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('save-movement')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('save-movement')));
    await settle(tester);

    await go(tester, '/');
    final card = await tester.runAsync(
      () => layer.accounts.get(AccountSection.customers, 'c_55'),
    );
    final shown = layer.money.format(card!.balanceUnits!.units!, Currency.lyd);
    expect(card.balanceUnits?.units, isNot(320));
    expect(_debtAmount(shown), findsNothing);
    expect(_debtAmount('320 د.ل'), findsNothing);
  });

  testWidgets('DEF-016 cancel refreshes the home debt row from the server', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2200));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    final cancel = find.byKey(const Key('cancel-tx_2'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('confirm-mutation')));
    await settle(tester);

    await go(tester, '/');
    final card = await tester.runAsync(
      () => layer.accounts.get(AccountSection.customers, 'c_55'),
    );
    final shown = layer.money.format(card!.balanceUnits!.units!, Currency.lyd);
    expect(card.balanceUnits?.units, isNot(320));
    expect(_debtAmount(shown), findsNothing);
    expect(_debtAmount('320 د.ل'), findsNothing);
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

/// The polished ledger also prints a line's balance-after as its own amount,
/// so the card balance is read from the header.
Finder _headerAmount(String text) {
  return find.descendant(
    of: find.byKey(const Key('ledger-header-balance')),
    matching: find.text(text),
  );
}

/// Amount text inside the home bulletin row, not a separate money widget.
Finder _debtAmount(String text) {
  return find.descendant(
    of: find.byKey(const Key('old-debt-c_55')),
    matching: find.textContaining(text),
  );
}
