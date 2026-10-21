import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('customer debts shows an error and retries the list', (tester) async {
    final gate = _FailGate();
    await pumpFakeApp(
      tester,
      size: const Size(800, 1600),
      overrides: [
        accountsProvider.overrideWith((ref, section) async {
          gate.calls++;
          if (gate.failing) throw const NetworkException();
          return ref.read(apiLayerProvider).accounts.list(section);
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    expect(find.text(AppStrings.retry), findsOneWidget);
    gate.failing = false;
    await tester.tap(find.text(AppStrings.retry));
    await settle(tester);
    expect(find.byKey(const Key('screen-customers')), findsOneWidget);
    expect(gate.calls, greaterThanOrEqualTo(2));
  });

  testWidgets('a ledger shows an error and retries', (tester) async {
    final gate = _FailGate();
    await pumpFakeApp(
      tester,
      size: const Size(800, 1600),
      overrides: [
        ledgerProvider.overrideWith((ref, key) async {
          gate.calls++;
          if (gate.failing) throw const NetworkException();
          return ref.read(apiLayerProvider).accounts.ledger(key.$1, key.$2);
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    expect(find.text(AppStrings.retry), findsOneWidget);
    gate.failing = false;
    await tester.tap(find.text(AppStrings.retry));
    await settle(tester);
    expect(find.byKey(const Key('add-debt')), findsOneWidget);
    expect(gate.calls, greaterThanOrEqualTo(2));
  });

  testWidgets('collections shows an error and retries', (tester) async {
    final gate = _FailGate();
    await pumpFakeApp(
      tester,
      size: const Size(800, 1600),
      overrides: [
        collectionsProvider.overrideWith((ref) async {
          gate.calls++;
          if (gate.failing) throw const NetworkException();
          return ref.read(apiLayerProvider).collections.overview();
        }),
      ],
    );
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/collections');
    expect(find.text(AppStrings.retry), findsOneWidget);
    gate.failing = false;
    await tester.tap(find.text(AppStrings.retry));
    await settle(tester);
    expect(find.byKey(const Key('unlinked-collection')), findsOneWidget);
    expect(gate.calls, greaterThanOrEqualTo(2));
  });

  testWidgets('purchases shows an error and retries', (tester) async {
    final gate = _FailGate();
    await pumpFakeApp(
      tester,
      size: const Size(800, 1600),
      overrides: [
        purchasesProvider.overrideWith((ref) async {
          gate.calls++;
          if (gate.failing) throw const NetworkException();
          return ref.read(apiLayerProvider).purchases.list(ref.read(purchaseBookProvider));
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    expect(find.text(AppStrings.retry), findsOneWidget);
    gate.failing = false;
    await tester.tap(find.text(AppStrings.retry));
    await settle(tester);
    expect(find.byKey(const Key('add-purchase-12')), findsOneWidget);
    expect(gate.calls, greaterThanOrEqualTo(2));
  });

  testWidgets('treasury shows an error and retries', (tester) async {
    final gate = _FailGate();
    await pumpFakeApp(
      tester,
      size: const Size(800, 1600),
      overrides: [
        treasuryProvider.overrideWith((ref) async {
          gate.calls++;
          if (gate.failing) throw const NetworkException();
          return ref.read(apiLayerProvider).treasury.summary();
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/treasury');
    expect(find.text(AppStrings.retry), findsOneWidget);
    gate.failing = false;
    await tester.tap(find.text(AppStrings.retry));
    await settle(tester);
    expect(find.byKey(const Key('cash-in')), findsOneWidget);
    expect(gate.calls, greaterThanOrEqualTo(2));
  });

  testWidgets('reports shows an error and retries', (tester) async {
    final gate = _FailGate();
    await pumpFakeApp(
      tester,
      size: const Size(800, 1600),
      overrides: [
        reportsProvider.overrideWith((ref) async {
          gate.calls++;
          if (gate.failing) throw const NetworkException();
          return ref.read(apiLayerProvider).reports.daily();
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/reports');
    expect(find.text(AppStrings.retry), findsOneWidget);
    gate.failing = false;
    await tester.tap(find.text(AppStrings.retry));
    await settle(tester);
    expect(find.byKey(const Key('reports-refresh')), findsOneWidget);
    expect(gate.calls, greaterThanOrEqualTo(2));
  });

  testWidgets('settings ledger shows an error and retries', (tester) async {
    final gate = _FailGate();
    await pumpFakeApp(
      tester,
      size: const Size(800, 1600),
      overrides: [
        financialLedgerProvider.overrideWith((ref) async {
          gate.calls++;
          if (gate.failing) throw const NetworkException();
          return ref.read(apiLayerProvider).reports.financialLedger();
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/settings');
    expect(find.byKey(const Key('settings-retry')), findsOneWidget);
    gate.failing = false;
    await tester.tap(find.byKey(const Key('settings-retry')));
    await settle(tester);
    expect(find.text(AppStrings.pageTotals), findsOneWidget);
    expect(gate.calls, greaterThanOrEqualTo(2));
  });

  testWidgets('search shows loading, then an error, and retries', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1600));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/search');

    final gate = Completer<void>();
    fake.pauseSuggestions = gate;
    await tester.enterText(find.byKey(const Key('unified-search')), 'عميل');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(find.byKey(const Key('search-loading')), findsOneWidget);
    gate.complete();
    fake.pauseSuggestions = null;
    await settle(tester);

    fake.failSuggestionsRemaining = 1;
    await tester.tap(find.byKey(const Key('unified-search')));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    expect(find.byKey(const Key('search-retry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('search-retry')));
    await settle(tester);
    expect(find.text(AppStrings.noResults), findsOneWidget);
    expect(find.byKey(const Key('search-retry')), findsNothing);
  });

  testWidgets('a string amount is an invalid server response with retry', (
    tester,
  ) async {
    final gate = _FailGate();
    await pumpFakeApp(
      tester,
      size: const Size(800, 1600),
      overrides: [
        accountsProvider.overrideWith((ref, section) async {
          gate.calls++;
          if (gate.failing) {
            return AccountsPage.fromData({
              'items': [
                {'id': 'x', 'name': 'عميل', 'balanceUnits': '125000'},
              ],
            }, section);
          }
          return ref.read(apiLayerProvider).accounts.list(section);
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(find.textContaining('غير صالحة'), findsOneWidget);
    gate.failing = false;
    await tester.tap(find.text(AppStrings.retry));
    await settle(tester);
    expect(find.byKey(const Key('screen-customers')), findsOneWidget);
    expect(find.text(AppStrings.retry), findsNothing);
    expect(gate.calls, greaterThanOrEqualTo(2));
  });

  testWidgets('full access can export PDF; settings.manage alone cannot', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/reports');
    expect(find.byKey(const Key('export-pdf')), findsOneWidget);
    await tester.tap(find.byKey(const Key('export-pdf')));
    await settle(tester);
    expect(find.text(AppStrings.savedReply), findsNothing);
    expect(find.byKey(const Key('export-pdf')), findsOneWidget);
    await go(tester, '/settings');
    expect(find.byKey(const Key('financial-ledger')), findsOneWidget);
    expect(find.byKey(const Key('export-pdf')), findsOneWidget);

    layer.permissions.applyFromServer(
      const ['settings.manage', 'reports.read'],
      role: 'admin',
      sectionAccess: const {'reports': 'manage'},
    );
    await tester.pump();
    await go(tester, '/reports');
    expect(find.byKey(const Key('screen-reports')), findsOneWidget);
    expect(find.byKey(const Key('export-pdf')), findsNothing);
    await go(tester, '/settings');
    expect(find.byKey(const Key('screen-settings')), findsOneWidget);
    expect(find.byKey(const Key('financial-ledger')), findsNothing);
    expect(find.byKey(const Key('export-pdf')), findsNothing);
    expect(find.text(AppStrings.employeesTile), findsOneWidget);
  });
}

class _FailGate {
  var failing = true;
  var calls = 0;
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
