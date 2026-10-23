import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveBoundaryShot;
import 'support/pump_app.dart';

const _captureScreenshots = bool.fromEnvironment('CAPTURE_SCREENSHOTS');

void main() {
  for (final dark in [false, true]) {
    for (final size in [const Size(320, 780), const Size(430, 932)]) {
      final theme = dark ? 'dark' : 'light';
      testWidgets(
        'DEF-031 $theme ${size.width.toInt()} names the balance and the amount, and cancel sends nothing',
        (tester) async {
          final layer = await pumpFakeApp(tester, size: size);
          if (dark) {
            await tester.tap(find.byKey(LoginScreen.themeKey));
            await settle(tester);
          }
          await signIn(tester, username: 'admin.demo', password: 'demo-only');
          await go(tester, '/customers/c_55');

          final card = await tester.runAsync(
            () => layer.accounts.get(AccountSection.customers, 'c_55'),
          );
          final balance = card!.balanceUnits!.units!;
          final current = layer.money.format(balance, card.currency);
          final entered = layer.money.format(balance + 80, card.currency);
          expect(_header(current), findsOneWidget);

          final fake = layer.client as FakeApiClient;
          final postsBefore = fake.mutationPaths.length;
          await _openPayment(tester, '${balance + 80}');

          expect(find.byKey(const Key('overpayment-warning')), findsOneWidget);
          final plain = tester
              .widget<Text>(find.byKey(const Key('overpayment-copy')))
              .textSpan!
              .toPlainText();
          expect(plain, contains(AppStrings.overpaymentCurrent));
          expect(plain, contains(AppStrings.overpaymentEntered));
          expect(plain, contains(AppStrings.overpaymentAsk));
          expect(plain.contains('سيصبح'), isFalse);
          expect(
            tester
                .widget<MoneyText>(find.byKey(const Key('overpayment-current')))
                .text,
            current,
          );
          expect(
            tester
                .widget<MoneyText>(find.byKey(const Key('overpayment-entered')))
                .text,
            entered,
          );
          expect(find.text('-80 د.ل'), findsNothing);
          expect(find.text('80 د.ل'), findsNothing);
          final dialog = tester.element(
            find.byKey(const Key('overpayment-warning')),
          );
          expect(Directionality.of(dialog), TextDirection.rtl);
          expect(
            Theme.of(dialog).brightness,
            dark ? Brightness.dark : Brightness.light,
          );
          expect(find.text(AppStrings.amountAboveRemaining), findsNothing);
          expect(fake.mutationPaths, hasLength(postsBefore));

          await tester.tap(find.byKey(const Key('overpayment-cancel')));
          await settle(tester);
          expect(find.byKey(const Key('overpayment-warning')), findsNothing);
          expect(fake.mutationPaths, hasLength(postsBefore));
          expect(
            fake.mutationPaths.where((path) => path.contains('/transactions')),
            isEmpty,
          );
          expect(_header(current), findsOneWidget);
          expect(_header('-80 د.ل'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'DEF-031 a confirmed overpayment is sent and the header shows the server balance',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(430, 932));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/customers/c_55');
      final fake = layer.client as FakeApiClient;
      final postsBefore = fake.mutationPaths.length;
      await _openPayment(tester, '400');
      expect(fake.mutationPaths, hasLength(postsBefore));

      await tester.tap(find.byKey(const Key('overpayment-continue')));
      await settle(tester);

      expect(find.byKey(const Key('overpayment-warning')), findsNothing);
      expect(find.text(AppStrings.amountAboveRemaining), findsNothing);
      expect(fake.mutationPaths, hasLength(postsBefore + 1));
      final body = jsonDecode(fake.mutationBodies.last) as Map<String, dynamic>;
      expect(body['expectedVersion'], 4);
      expect(body['inputValue'], 400);
      expect(_header('-80 د.ل'), findsOneWidget);
      expect(_header('320 د.ل'), findsNothing);
      final balance = find.byKey(
        const Key('ledger-header-balance'),
        skipOffstage: false,
      );
      final shown = tester.widget<MoneyText>(balance);
      expect(
        shown.style?.color,
        isNot(tester.element(balance).statusColors.debtText),
      );

      final stored = await tester.runAsync(
        () => layer.accounts.get(AccountSection.customers, 'c_55'),
      );
      expect(stored!.balanceUnits?.units, -80);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('DEF-031 after a 200 the header shows the server balanceUnits', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(430, 932));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    final before = await tester.runAsync(
      () => layer.accounts.get(AccountSection.customers, 'c_55'),
    );
    expect(before!.balanceUnits?.units, 320);

    final fake = layer.client as FakeApiClient;
    await _openPayment(tester, '20');
    expect(find.byKey(const Key('overpayment-warning')), findsNothing);
    expect(
      fake.mutationPaths.where((path) => path.contains('/transactions')),
      isNotEmpty,
    );

    final stored = await tester.runAsync(
      () => layer.accounts.get(AccountSection.customers, 'c_55'),
    );
    expect(stored!.version, isNot(before.version));
    final shown = layer.money.format(
      stored.balanceUnits!.units!,
      stored.currency,
    );
    expect(_header(shown), findsOneWidget);
    expect(shown, isNot('20 د.ل'));
    expect(_header('-80 د.ل'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'DEF-031 a missing acknowledgement balance is not the old balance',
    (tester) async {
      final hold = _Hold();
      final layer = await pumpFakeApp(
        tester,
        size: const Size(430, 932),
        overrides: [_cardOverride(hold)],
      );
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/customers/c_55');
      final before = await tester.runAsync(
        () => layer.accounts.get(AccountSection.customers, 'c_55'),
      );
      await _openPayment(tester, '400');
      hold.on = true;
      (layer.client as FakeApiClient)
          .scriptedMutationJson[ApiEndpoints.accountTransactions(
        'customers',
        'c_55',
      )] = jsonEncode({
        'id': 'tx_script',
        'version': 9,
      });

      await tester.tap(find.byKey(const Key('overpayment-continue')));
      await _pumpUntilHeader(tester, '—');

      expect(_header('—'), findsOneWidget);
      expect(_header('320 د.ل'), findsNothing);
      expect(_header('-80 د.ل'), findsNothing);

      hold.gate.complete(_withBalance(before!, MoneyValue.known(50)));
      await settle(tester);
      expect(_header('50 د.ل'), findsOneWidget);
      expect(_header('—'), findsNothing);
      expect(_header('320 د.ل'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'DEF-031 an invalid acknowledgement balance is not the old balance',
    (tester) async {
      final hold = _Hold();
      final layer = await pumpFakeApp(
        tester,
        size: const Size(430, 932),
        overrides: [_cardOverride(hold)],
      );
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/customers/c_55');
      final before = await tester.runAsync(
        () => layer.accounts.get(AccountSection.customers, 'c_55'),
      );
      await _openPayment(tester, '400');
      hold.on = true;
      (layer.client as FakeApiClient)
          .scriptedMutationJson[ApiEndpoints.accountTransactions(
        'customers',
        'c_55',
      )] = jsonEncode({
        'id': 'tx_script',
        'version': 9,
        'balanceUnits': 'bad',
      });

      await tester.tap(find.byKey(const Key('overpayment-continue')));
      await _pumpUntilHeader(tester, MoneyValue.invalidLabel);

      expect(_header(MoneyValue.invalidLabel), findsOneWidget);
      expect(_header('320 د.ل'), findsNothing);
      expect(_header('-80 د.ل'), findsNothing);

      hold.gate.complete(_withBalance(before!, MoneyValue.known(50)));
      await settle(tester);
      expect(_header('50 د.ل'), findsOneWidget);
      expect(_header(MoneyValue.invalidLabel), findsNothing);
      expect(_header('320 د.ل'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'DEF-031 the acknowledgement balance is cleared when the card reloads',
    (tester) async {
      final hold = _Hold();
      final layer = await pumpFakeApp(
        tester,
        size: const Size(430, 932),
        overrides: [_cardOverride(hold)],
      );
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/customers/c_55');
      final before = await tester.runAsync(
        () => layer.accounts.get(AccountSection.customers, 'c_55'),
      );
      await _openPayment(tester, '400');
      hold.on = true;

      await tester.tap(find.byKey(const Key('overpayment-continue')));
      await _pumpUntilHeader(tester, '-80 د.ل');

      expect(_header('-80 د.ل'), findsOneWidget);
      expect(_header('320 د.ل'), findsNothing);

      hold.gate.complete(_withBalance(before!, MoneyValue.known(15)));
      await settle(tester);
      expect(_header('15 د.ل'), findsOneWidget);
      expect(_header('-80 د.ل'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'DEF-031 overpayment warning screenshots',
    (tester) async {
      await tester.runAsync(loadScreenshotFonts);
      for (final dark in [false, true]) {
        for (final size in [const Size(320, 780), const Size(430, 932)]) {
          await pumpFakeApp(tester, size: size);
          await tester.pump();
          if (dark) {
            await tester.tap(find.byKey(LoginScreen.themeKey));
            await settle(tester);
          }
          await signIn(tester, username: 'admin.demo', password: 'demo-only');
          await go(tester, '/customers/c_55');
          await _openPayment(tester, '400');
          expect(find.byKey(const Key('overpayment-warning')), findsOneWidget);
          expect(find.textContaining('سيصبح'), findsNothing);
          final theme = dark ? 'dark' : 'light';
          await saveBoundaryShot(
            tester,
            find.byKey(const Key('overpayment-boundary')),
            'overpayment-warning-$theme-${size.width.toInt()}',
          );
          await tester.tap(find.byKey(const Key('overpayment-cancel')));
          await settle(tester);
        }
      }
    },
    tags: const ['screenshots'],
    skip: !_captureScreenshots,
  );
}

class _Hold {
  var on = false;
  final gate = Completer<AccountCardDto>();
}

Override _cardOverride(_Hold hold) {
  return accountCardProvider.overrideWith((ref, key) async {
    if (hold.on && key == (AccountSection.customers, 'c_55')) {
      return hold.gate.future;
    }
    return ref.read(apiLayerProvider).accounts.get(key.$1, key.$2);
  });
}

AccountCardDto _withBalance(AccountCardDto card, MoneyValue balance) {
  return AccountCardDto(
    id: card.id,
    name: card.name,
    phone: card.phone,
    balanceUnits: balance,
    currency: card.currency,
    activeAssigneeName: card.activeAssigneeName,
    lastActivityAt: card.lastActivityAt,
    pinned: card.pinned,
    version: card.version,
    nextSequence: card.nextSequence,
    debtAgeDays: card.debtAgeDays,
    ageStatus: card.ageStatus,
    ageStatusLabel: card.ageStatusLabel,
    zeroReview: card.zeroReview,
    allowedActions: card.allowedActions,
    systemManaged: card.systemManaged,
    systemLinkKey: card.systemLinkKey,
    systemKind: card.systemKind,
  );
}

Future<void> _openPayment(WidgetTester tester, String amount) async {
  await tester.ensureVisible(find.byKey(const Key('add-payment')));
  await tester.tap(find.byKey(const Key('add-payment')));
  await settle(tester);
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('movement-amount')),
      matching: find.byType(TextField),
    ),
    amount,
  );
  final save = find.byKey(const Key('save-movement'));
  await tester.ensureVisible(save);
  await tester.tap(save);
  const warning = Key('overpayment-warning');
  for (var i = 0; i < 30; i++) {
    if (find.byKey(warning).evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
  await settle(tester);
}

Future<void> _pumpUntilHeader(WidgetTester tester, String text) async {
  for (var i = 0; i < 40; i++) {
    if (_header(text).evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder _header(String text) {
  return find.descendant(
    of: find.byKey(const Key('ledger-header-balance'), skipOffstage: false),
    matching: find.text(text, skipOffstage: false),
    skipOffstage: false,
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
