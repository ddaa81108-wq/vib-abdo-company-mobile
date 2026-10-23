import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/accounts/overpayment_warning.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
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
        'DEF-031 $theme ${size.width.toInt()} warns before sending and cancel sends nothing',
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
          final preview = OverpaymentPreview.aboveBalance(
            amountUnits: balance + 80,
            balanceUnits: balance,
          )!;
          final overage = layer.money.format(
            preview.overageUnits,
            card.currency,
          );
          final expected = layer.money.format(
            preview.expectedBalanceUnits,
            card.currency,
          );
          expect(
            _header(layer.money.format(balance, card.currency)),
            findsOneWidget,
          );

          final fake = layer.client as FakeApiClient;
          final postsBefore = fake.mutationPaths.length;
          await _openPayment(tester, '${balance + 80}');

          expect(find.byKey(const Key('overpayment-warning')), findsOneWidget);
          final plain = tester
              .widget<Text>(find.byKey(const Key('overpayment-copy')))
              .textSpan!
              .toPlainText();
          expect(plain, contains(AppStrings.overpaymentLead));
          expect(plain, contains(AppStrings.overpaymentMiddle));
          expect(plain, contains(AppStrings.overpaymentAsk));
          expect(find.text(overage), findsOneWidget);
          final expectedText = tester.widget<MoneyText>(
            find.byKey(const Key('overpayment-expected')),
          );
          expect(expectedText.text, expected);
          final dialog = tester.element(
            find.byKey(const Key('overpayment-warning')),
          );
          expect(expectedText.style?.color, dialog.statusColors.debtText);
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
          expect(
            _header(layer.money.format(balance, card.currency)),
            findsOneWidget,
          );
          expect(_header(expected), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'DEF-031 a confirmed overpayment is sent and a refusal keeps the server balance',
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
      expect(find.text(AppStrings.amountAboveRemaining), findsOneWidget);
      expect(fake.mutationPaths, hasLength(postsBefore + 1));
      final body = jsonDecode(fake.mutationBodies.last) as Map<String, dynamic>;
      expect(body['expectedVersion'], 4);
      expect(body['inputValue'], 400);
      expect(_header('320 د.ل'), findsOneWidget);
      expect(_header('-80 د.ل'), findsNothing);

      final stored = await tester.runAsync(
        () => layer.accounts.get(AccountSection.customers, 'c_55'),
      );
      expect(stored!.balanceUnits?.units, 320);
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
