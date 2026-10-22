import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

/// P7-10. The payment dialog and the ledger controller stay real. The balance
/// on screen is the next fetch. The app does not cap or recompute it.
void main() {
  testWidgets('P7-10 a partial payment then a full payment on the same card', (
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

    final fake = layer.client as FakeApiClient;
    final gate = Completer<void>();
    fake.pauseMutations = gate;
    await tester.tap(find.byKey(const Key('save-movement')));
    await pumpUntilFound(tester, find.byType(CircularProgressIndicator));
    expect(fake.mutationRequestIds, hasLength(1));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('save-movement')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('save-movement')));
    await tester.pump();
    expect(fake.mutationRequestIds, hasLength(1));

    gate.complete();
    fake.pauseMutations = null;
    await settle(tester);
    expect(_header('220 د.ل'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('full-payment')));
    await tester.tap(find.byKey(const Key('full-payment')));
    await settle(tester);
    expect(_header('0 د.ل'), findsOneWidget);
    final partial = find.byKey(
      const Key('ledger-amount-tx_partial_5'),
      skipOffstage: false,
    );
    await tester.ensureVisible(partial);
    expect(
      _inside(const Key('ledger-amount-tx_partial_5'), '100 د.ل'),
      findsOneWidget,
    );
  });

  testWidgets('P7-10 libyan deposits have no full-payment button', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(800, 1800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/libyan-deposits/c_55');

    expect(find.byKey(const Key('add-payment')), findsOneWidget);
    expect(find.byKey(const Key('full-payment')), findsNothing);
  });

  testWidgets(
    'DEF-020 a partial payment above the remaining balance is stored',
    (tester) async {
      // The app sends the integer. The fake stores previous - entered and
      // does not reject it. 400 on c_55 (320) comes back as -80. This does
      // not close a cap that the product does not have.
      await pumpFakeApp(tester, size: const Size(800, 2200));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/customers/c_55');
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
      await settle(tester);

      expect(_header('-80 د.ل'), findsOneWidget);
      expect(find.text(AppStrings.versionConflict), findsNothing);
    },
    tags: ['known-bug'],
  );

  test(
    'a stale expectedVersion is rejected and the balance stays 320',
    () async {
      final layer = ApiLayer.create(
        config: const ApiConfig(
          baseUrl: 'https://fake.invalid',
          useFakeApi: true,
        ),
        fakeLatency: Duration.zero,
      );
      addTearDown(layer.dispose);
      await layer.session.login(username: 'admin.demo', password: 'x');

      await expectLater(
        layer.accounts.addTransaction(
          AccountSection.customers,
          'c_55',
          AccountTransactionRequest.partialPayment(
            inputValue: 100,
            date: DateTime.utc(2026, 10, 22),
          ),
          MutationMeta(expectedVersion: 3),
        ),
        throwsA(
          isA<ConflictException>().having(
            (error) => error.code,
            'code',
            'VERSION_CONFLICT',
          ),
        ),
      );
      final card = await layer.accounts.get(AccountSection.customers, 'c_55');
      expect(card.balanceUnits, 320);
    },
  );

  testWidgets(
    'DEF-022 the payment dialog shows the server conflict sentence and does not refetch',
    (tester) async {
      // The collections buttons throw, so GuardedMutation shows
      // AppStrings.versionConflict and refetches. This dialog catches the
      // error and returns the server sentence. It does not invalidate
      // accountCardProvider, so the header stays on the card loaded at 320
      // even after the ledger is left and opened again. The stored card is
      // 319 because the concurrent partial of 1 was accepted.
      final layer = await pumpFakeApp(tester, size: const Size(800, 2200));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/customers/c_55');
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

      expect(find.text('تم تعديل البيانات من مستخدم آخر'), findsWidgets);
      expect(find.text(AppStrings.versionConflict), findsNothing);
      expect(_header('320 د.ل'), findsOneWidget);

      Navigator.of(tester.element(find.byType(Dialog))).pop();
      await settle(tester);
      final stored = await tester.runAsync(
        () => layer.accounts.get(AccountSection.customers, 'c_55'),
      );
      expect(stored!.balanceUnits, 319);

      await go(tester, '/customers');
      await go(tester, '/customers/c_55');
      expect(_header('320 د.ل'), findsOneWidget);
      expect(_header('319 د.ل'), findsNothing);
    },
    tags: ['known-bug'],
  );
}

Finder _header(String text) {
  return find.descendant(
    of: find.byKey(const Key('ledger-header-balance')),
    matching: find.text(text),
  );
}

Finder _inside(Key key, String text) {
  return find.descendant(of: find.byKey(key), matching: find.text(text));
}
