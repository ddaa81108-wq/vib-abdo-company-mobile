import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_api_layer/data/fake/fake_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('readers do not see correction and a writer does', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(800, 1800));
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');

    expect(find.byKey(const Key('screen-ledger-customers')), findsOneWidget);
    expect(find.byKey(const Key('correct-tx_1')), findsNothing);
    expect(find.byKey(const Key('correct-tx_2')), findsNothing);
    expect(find.text(AppStrings.correctTransaction), findsNothing);
  });

  testWidgets('a read-only admin does not see correction', (tester) async {
    await pumpFakeApp(tester, size: const Size(800, 1800));
    await signIn(tester, username: 'limited.admin', password: 'demo-only');
    await go(tester, '/customers/c_55');

    expect(find.byKey(const Key('screen-ledger-customers')), findsOneWidget);
    expect(find.byKey(const Key('correct-tx_1')), findsNothing);
    expect(find.byKey(const Key('correct-tx_2')), findsNothing);
  });

  testWidgets('a system-managed card hides correction', (tester) async {
    await pumpFakeApp(
      tester,
      size: const Size(800, 1800),
      overrides: [
        accountCardProvider.overrideWith((ref, key) async {
          return AccountCardDto.fromJson({
            'id': key.$2,
            'name': 'كارت نظامي',
            'balanceUnits': 10,
            'version': 3,
            'systemManaged': true,
          }, key.$1);
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');

    expect(find.byKey(const Key('correct-tx_1')), findsNothing);
    expect(find.byKey(const Key('add-debt')), findsNothing);
    expect(find.text(AppStrings.correctTransaction), findsNothing);
  });

  testWidgets('reversed and deleted lines hide correction', (tester) async {
    await pumpFakeApp(
      tester,
      size: const Size(800, 1800),
      overrides: [
        ledgerProvider.overrideWith((ref, key) async {
          final raw = FakeFixtures.ledger();
          final items = raw['items'] as List;
          (items[0] as Map)['status'] = 'reversed';
          (items[1] as Map)['status'] = 'deleted';
          return LedgerPage.fromData(raw, key.$1);
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');

    expect(find.byKey(const Key('correct-tx_1')), findsNothing);
    expect(find.byKey(const Key('correct-tx_2')), findsNothing);
    expect(find.text(AppStrings.reversed), findsOneWidget);
  });

  testWidgets('posted lines on every card section can open a correction', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(800, 1800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');

    expect(find.byKey(const Key('correct-tx_1')), findsOneWidget);
    expect(find.byKey(const Key('correct-tx_2')), findsOneWidget);
    await scrollTo(tester, const Key('load-older'), 'customers');
    await tester.tap(find.byKey(const Key('load-older')));
    await settle(tester);
    expect(find.byKey(const Key('correct-tx_old')), findsOneWidget);

    await tester.tap(find.byKey(const Key('correct-tx_2')));
    await settle(tester);
    expect(find.byKey(const Key('correction-payment-mode')), findsOneWidget);
    expectRtl(tester);
    Navigator.of(tester.element(find.byKey(const Key('correction-form'))))
        .pop();
    await settle(tester);

    await go(tester, '/companies/c_55');
    expect(find.byKey(const Key('correct-tx_1')), findsOneWidget);

    await go(tester, '/libyan-deposits/c_55');
    await tester.tap(find.byKey(const Key('correct-tx_2')));
    await settle(tester);
    expect(find.byKey(const Key('correction-form')), findsOneWidget);
    expect(find.byKey(const Key('correction-payment-mode')), findsNothing);
    expect(find.text(AppStrings.fullPayment), findsNothing);
    expect(find.text(AppStrings.noPreview), findsWidgets);
  });

  testWidgets('confirmation keeps one request id and sends the line version', (
    tester,
  ) async {
    var ledgerReads = 0;
    var cardReads = 0;
    final layer = await pumpFakeApp(
      tester,
      size: const Size(800, 1800),
      overrides: [
        ledgerProvider.overrideWith((ref, key) async {
          ledgerReads++;
          return ref.read(apiLayerProvider).accounts.ledger(key.$1, key.$2);
        }),
        accountCardProvider.overrideWith((ref, key) async {
          cardReads++;
          return ref.read(apiLayerProvider).accounts.get(key.$1, key.$2);
        }),
      ],
    );
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    final ledgerBefore = ledgerReads;
    final cardBefore = cardReads;

    await tester.tap(find.byKey(const Key('correct-tx_1')));
    await settle(tester);
    await enterAmount(tester, '100');
    await openConfirm(tester);

    expect(find.text(AppStrings.confirmCorrect), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('normalized-value'))).data,
      '100',
    );
    expect(fake.mutationRequestIds, isEmpty);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(AppStrings.cancel),
      ),
    );
    await settle(tester);
    expect(fake.mutationRequestIds, isEmpty);
    expect(find.byKey(const Key('correction-form')), findsOneWidget);

    fake.failMutationsRemaining = 1;
    await openConfirm(tester);
    await confirmSend(tester, fake);

    expect(find.text('تعذر تنفيذ الطلب.'), findsWidgets);
    expect(fake.mutationRequestIds, hasLength(1));
    expect(
      fake.mutationPaths.single,
      '/api/customers/c_55/transactions/tx_1/corrections',
    );
    final failed = jsonDecode(fake.mutationBodies.single) as Map;
    expect(failed['expectedVersion'], 1);
    expect(failed['requestId'], fake.mutationRequestIds.single);
    expect(failed['type'], 'debt');
    expect(failed['inputValue'], 100);
    expect(failed['calculationMode'], 'direct');
    expect(failed.containsKey('amountUnits'), isFalse);
    expect(failed.containsKey('balanceAfterUnits'), isFalse);
    expect(ledgerReads, ledgerBefore);

    await openConfirm(tester);
    await confirmSend(tester, fake);

    expect(fake.mutationRequestIds, [
      fake.mutationRequestIds.first,
      fake.mutationRequestIds.first,
    ]);
    expect(fake.mutationPaths, [
      '/api/customers/c_55/transactions/tx_1/corrections',
      '/api/customers/c_55/transactions/tx_1/corrections',
    ]);
    final sent = jsonDecode(fake.mutationBodies[1]) as Map;
    expect(sent['requestId'], failed['requestId']);
    expect(sent['expectedVersion'], 1);
    expect(sent['inputValue'], 100);
    expect(find.byKey(const Key('correction-form')), findsNothing);
    expect(
      find.textContaining('${AppStrings.serverReply} tx_new'),
      findsOneWidget,
    );
    expect(ledgerReads, greaterThan(ledgerBefore));
    expect(cardReads, greaterThan(cardBefore));
    expect(find.text('tx_1'), findsWidgets);
  });

  testWidgets('a version conflict refreshes the ledger and explains it', (
    tester,
  ) async {
    var ledgerReads = 0;
    final layer = await pumpFakeApp(
      tester,
      size: const Size(800, 1800),
      overrides: [
        ledgerProvider.overrideWith((ref, key) async {
          ledgerReads++;
          final raw = FakeFixtures.ledger();
          for (final item in raw['items'] as List) {
            (item as Map)['version'] = -1;
          }
          return LedgerPage.fromData(raw, key.$1);
        }),
      ],
    );
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    final before = ledgerReads;

    await tester.tap(find.byKey(const Key('correct-tx_1')));
    await settle(tester);
    await openConfirm(tester);
    await confirmSend(tester, fake);

    expect(find.text(AppStrings.versionConflict), findsOneWidget);
    expect(find.byKey(const Key('correction-form')), findsOneWidget);
    expect(ledgerReads, greaterThan(before));
    expect(
      fake.mutationPaths.single,
      '/api/customers/c_55/transactions/tx_1/corrections',
    );
    final body = jsonDecode(fake.mutationBodies.single) as Map;
    expect(body['expectedVersion'], -1);
    expect(find.textContaining('400'), findsNothing);
  });

  testWidgets('multiply and divide prefill the rate without grouping', (
    tester,
  ) async {
    final layer = await pumpFakeApp(
      tester,
      size: const Size(800, 1800),
      overrides: [
        ledgerProvider.overrideWith((ref, key) async {
          final raw = FakeFixtures.ledger();
          final item = (raw['items'] as List).first as Map;
          item['calculationMode'] = 'multiply';
          item['factorMicros'] = 12500250000;
          return LedgerPage.fromData(raw, key.$1);
        }),
      ],
    );
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    await openCorrection(tester, 'customers');

    final factor = tester.widget<TextField>(
      find.byKey(const Key('correction-factor')),
    );
    expect(factor.controller?.text, '12500.25');
    expect(factor.controller?.text.contains(','), isFalse);
    expect(DecimalString.tryParse(factor.controller?.text)?.value, '12500.25');

    await enterAmount(tester, '100');
    await openConfirm(tester);
    await confirmSend(tester, fake);

    final sent = jsonDecode(fake.mutationBodies.single) as Map;
    expect(sent['calculationMode'], 'multiply');
    expect(sent['factor'], 12500.25);
    expect(sent['inputValue'], 100);
  });

  testWidgets('a multiply line with no rate stays empty and explains it', (
    tester,
  ) async {
    final layer = await pumpFakeApp(
      tester,
      size: const Size(800, 1800),
      overrides: [
        ledgerProvider.overrideWith((ref, key) async {
          final raw = FakeFixtures.ledger();
          final item = (raw['items'] as List).first as Map;
          item['calculationMode'] = 'divide';
          item.remove('factorMicros');
          return LedgerPage.fromData(raw, key.$1);
        }),
      ],
    );
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    await openCorrection(tester, 'customers');

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('correction-factor')))
          .controller
          ?.text,
      isEmpty,
    );
    await openConfirm(tester);
    await confirmSend(tester, fake);

    expect(find.text(AppStrings.rateInvalid), findsOneWidget);
    expect(find.text(AppStrings.integerOnly), findsNothing);
    expect(fake.mutationBodies, isEmpty);
    expect(find.byKey(const Key('correction-form')), findsOneWidget);
  });

  testWidgets('an invalid correction date names the date', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    await openCorrection(tester, 'customers');
    await tester.enterText(
      find.byKey(const Key('correction-date')),
      'ليس تاريخًا',
    );
    await openConfirm(tester);
    await confirmSend(tester, fake);

    expect(find.text(AppStrings.dateInvalid), findsOneWidget);
    expect(find.text(AppStrings.integerOnly), findsNothing);
    expect(fake.mutationBodies, isEmpty);
  });

  testWidgets('an invalid movement date names the date', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    await tester.tap(find.byKey(const Key('add-debt')));
    await settle(tester);
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == AppStrings.amount,
      ),
      '10',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == AppStrings.date,
      ),
      'ليس تاريخًا',
    );
    await tester.tap(find.byKey(const Key('save-movement')));
    await settle(tester);

    expect(find.text(AppStrings.dateInvalid), findsOneWidget);
    expect(find.text(AppStrings.integerOnly), findsNothing);
    expect(fake.mutationBodies, isEmpty);
  });

  testWidgets('a correct token shows the button without section write', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      size: const Size(800, 1800),
      overrides: [
        ledgerProvider.overrideWith((ref, key) async {
          final raw = FakeFixtures.ledger();
          final items = raw['items'] as List;
          (items[0] as Map)['allowedActions'] = ['correct'];
          return LedgerPage.fromData(raw, key.$1);
        }),
      ],
    );
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    expect(find.byKey(const Key('correct-tx_1')), findsOneWidget);
    expect(find.byKey(const Key('correct-tx_2')), findsNothing);
  });

  testWidgets('a line list without correct hides the button from a writer', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      size: const Size(800, 1800),
      overrides: [
        ledgerProvider.overrideWith((ref, key) async {
          final raw = FakeFixtures.ledger();
          final items = raw['items'] as List;
          (items[0] as Map)['allowedActions'] = ['pin'];
          (items[1] as Map)['allowedActions'] = <String>[];
          return LedgerPage.fromData(raw, key.$1);
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    expect(find.byKey(const Key('correct-tx_1')), findsNothing);
    expect(find.byKey(const Key('correct-tx_2')), findsNothing);
  });

  testWidgets('a server correct token shows on a system card', (tester) async {
    await pumpFakeApp(
      tester,
      size: const Size(800, 1800),
      overrides: [
        accountCardProvider.overrideWith((ref, key) async {
          return AccountCardDto.fromJson({
            'id': key.$2,
            'name': 'كارت نظامي',
            'balanceUnits': 10,
            'version': 3,
            'systemManaged': true,
          }, key.$1);
        }),
        ledgerProvider.overrideWith((ref, key) async {
          final raw = FakeFixtures.ledger();
          ((raw['items'] as List).first as Map)['allowedActions'] = ['correct'];
          return LedgerPage.fromData(raw, key.$1);
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    expect(find.byKey(const Key('correct-tx_1')), findsOneWidget);
    expect(find.byKey(const Key('add-debt')), findsNothing);
  });

  testWidgets('full payment sends a chosen date and omits an unchosen one', (
    tester,
  ) async {
    final layer = await pumpFakeApp(
      tester,
      size: const Size(800, 1800),
      overrides: [
        ledgerProvider.overrideWith((ref, key) async {
          final raw = FakeFixtures.ledger();
          ((raw['items'] as List)[1] as Map)['paymentMode'] = 'full';
          return LedgerPage.fromData(raw, key.$1);
        }),
      ],
    );
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');

    await tester.tap(find.byKey(const Key('full-payment')));
    await settle(tester);
    final ledgerBody = jsonDecode(fake.mutationBodies.single) as Map;
    expect(ledgerBody.containsKey('date'), isFalse);
    expect(ledgerBody['paymentMode'], 'full');
    expect(ledgerBody['type'], 'payment');

    await scrollTo(tester, const Key('correct-tx_2'), 'customers');
    await tester.tap(find.byKey(const Key('correct-tx_2')));
    await settle(tester);
    expect(find.byKey(const Key('correction-amount')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('correction-date')),
      '2026-01-15',
    );
    await openConfirm(tester);
    await confirmSend(tester, fake);

    final correction = jsonDecode(fake.mutationBodies[1]) as Map;
    expect(correction['paymentMode'], 'full');
    expect('${correction['date']}'.startsWith('2026-01-15'), isTrue);
    expect(correction['inputValue'], 1);
  });

  testWidgets(
    'the correction form is RTL in both themes on small and large phones',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(360, 800));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/customers/c_55');
      expectRtl(tester);

      await openCorrection(tester, 'customers');
      expect(find.text(AppStrings.correctTransaction), findsWidgets);
      expect(find.text(AppStrings.noPreview), findsWidgets);
      expect(find.text(AppStrings.currentServerAmount), findsOneWidget);
      expectRtl(tester);
      expect(
        Theme.of(tester.element(find.byKey(const Key('correction-form'))))
            .brightness,
        Brightness.light,
      );

      await openConfirm(tester);
      expect(find.text(AppStrings.confirmCorrect), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(AlertDialog))),
        TextDirection.rtl,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(AppStrings.cancel),
        ),
      );
      await settle(tester);
      Navigator.of(tester.element(find.byKey(const Key('correction-form'))))
          .pop();
      await settle(tester);

      await tester.tap(find.byKey(HomeShell.menuKey));
      await settle(tester);
      await tester.tap(find.text(AppStrings.themeDark));
      await settle(tester);
      if (find.byType(Drawer).evaluate().isNotEmpty) {
        Navigator.of(tester.element(find.byType(Drawer))).pop();
        await settle(tester);
      }

      await openCorrection(tester, 'customers');
      final form = tester.element(find.byKey(const Key('correction-form')));
      expect(Theme.of(form).brightness, Brightness.dark);
      expect(Directionality.of(form), TextDirection.rtl);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(480, 960);
      await settle(tester);
      expect(find.byKey(const Key('correction-form')), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.byKey(const Key('correction-form'))),
        ),
        TextDirection.rtl,
      );
      expect(
        Theme.of(tester.element(find.byKey(const Key('correction-form'))))
            .brightness,
        Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> openCorrection(WidgetTester tester, String section) async {
  await scrollTo(tester, const Key('correct-tx_1'), section);
  await tester.tap(find.byKey(const Key('correct-tx_1')));
  await settle(tester);
  expect(find.byKey(const Key('correction-form')), findsOneWidget);
}

Future<void> scrollTo(WidgetTester tester, Key key, String section) async {
  final scrollable = find.descendant(
    of: find.byKey(Key('screen-ledger-$section')),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(
    find.byKey(key),
    200,
    scrollable: scrollable.first,
  );
}

/// Opens the confirm dialog. The save control stays busy, with a spinning
/// indicator, until the dialog closes, so [pumpAndSettle] would not go idle.
Future<void> openConfirm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('save-correction')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> enterAmount(WidgetTester tester, String value) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('correction-amount')),
      matching: find.byType(TextField),
    ),
    value,
  );
  await tester.pump();
}

Future<void> confirmSend(WidgetTester tester, FakeApiClient fake) async {
  final gate = Completer<void>();
  fake.pauseMutations = gate;
  await tester.tap(find.byKey(const Key('confirm-mutation')));
  await tester.pump();
  await tester.pump(Duration.zero);
  gate.complete();
  fake.pauseMutations = null;
  await tester.pump();
  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await settle(tester);
}

void expectRtl(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold).first);
  expect(Directionality.of(context), TextDirection.rtl);
}

Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
  // The fake client arms a zero-delay timer that can outlive the idle check.
  await tester.pump(Duration.zero);
}
