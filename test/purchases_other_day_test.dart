import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/purchases/purchases_screen.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets(
    'an entry from another day has no edit or delete, and the write uses its dayVersion',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/purchases');

      expect(find.byKey(const Key('purchase-entry-pe_1')), findsOneWidget);
      expect(find.byKey(const Key('purchase-entry-pe_old')), findsOneWidget);
      await show(tester, find.byKey(const Key('edit-pe_1')));
      expect(find.byKey(const Key('edit-pe_1')), findsOneWidget);
      expect(find.byKey(const Key('delete-pe_1')), findsOneWidget);
      expect(find.byKey(const Key('edit-pe_old')), findsNothing);
      expect(find.byKey(const Key('delete-pe_old')), findsNothing);

      await tester.tap(find.byKey(const Key('delete-pe_1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(AppStrings.confirmDelete), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-mutation')));
      await finishSend(tester);

      final body = jsonDecode(fake.mutationBodies.last) as Map<String, dynamic>;
      expect(body['expectedDayVersion'], 3);
      expect(fake.mutationPaths.last, '/api/purchases/al_bayan/entries/pe_1');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('opening is hidden with no day and on a locked day', (
    tester,
  ) async {
    final missing = await pumpFakeApp(tester, size: const Size(800, 1400));
    _scriptPurchases(missing.client as FakeApiClient, _page(day: null));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    expect(find.byKey(const Key('opening-card')), findsOneWidget);
    expect(find.byKey(const Key('set-opening')), findsNothing);

    await pumpFakeApp(tester, size: const Size(800, 1400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    expect(find.byKey(const Key('set-opening')), findsOneWidget);

    final finalized = await pumpFakeApp(tester, size: const Size(800, 1400));
    (finalized.client as FakeApiClient).purchaseFixtureStatus = 'finalized';
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    expect(find.byKey(const Key('open-correction-12')), findsOneWidget);
    expect(find.byKey(const Key('set-opening')), findsNothing);

    final correction = await pumpFakeApp(tester, size: const Size(800, 1400));
    (correction.client as FakeApiClient).purchaseFixtureStatus = 'correction';
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    expect(find.byKey(const Key('set-opening')), findsOneWidget);

    final unversioned = await pumpFakeApp(tester, size: const Size(800, 1400));
    _scriptPurchases(
      unversioned.client as FakeApiClient,
      _page(
        day: _day(version: null),
        entries: [
          {
            'id': 'pe_1',
            'dayId': '12',
            'dayVersion': null,
            'itemLabel': 'فودافون كاش',
          },
        ],
      ),
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    expect(find.byKey(const Key('purchase-day-12')), findsOneWidget);
    expect(find.byKey(const Key('purchase-entry-pe_1')), findsOneWidget);
    expect(find.byKey(const Key('add-purchase-12')), findsNothing);
    expect(find.byKey(const Key('edit-pe_1')), findsNothing);
    expect(find.byKey(const Key('delete-pe_1')), findsNothing);
    expect(find.byKey(const Key('finalize-day-12')), findsNothing);
    expect(find.byKey(const Key('set-opening')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a finalized day with no version hides correction', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1400));
    _scriptPurchases(
      layer.client as FakeApiClient,
      _page(
        day: {
          'id': '12',
          'dayNumber': 12,
          'status': 'finalized',
          'version': null,
          'correctionOpen': false,
        },
      ),
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');

    expect(find.byKey(const Key('purchase-day-12')), findsOneWidget);
    expect(find.text(AppStrings.correctionClosed), findsOneWidget);
    expect(find.byKey(const Key('open-correction-12')), findsNothing);
    expect(find.byKey(const Key('close-correction-12')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a correction-open day with no version hides correction', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1400));
    _scriptPurchases(
      layer.client as FakeApiClient,
      _page(
        day: {
          'id': '12',
          'dayNumber': 12,
          'status': 'finalized',
          'version': null,
          'correctionOpen': true,
        },
      ),
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');

    expect(find.byKey(const Key('purchase-day-12')), findsOneWidget);
    expect(find.text(AppStrings.correctionOpen), findsOneWidget);
    expect(find.byKey(const Key('open-correction-12')), findsNothing);
    expect(find.byKey(const Key('close-correction-12')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

void _scriptPurchases(FakeApiClient fake, Map<String, Object?> body) {
  fake.scriptedGetJson[ApiEndpoints.purchases(PurchaseBook.alBayan.path)] =
      jsonEncode(body);
}

Map<String, Object?> _page({
  Map<String, Object?>? day,
  List<Map<String, Object?>> entries = const [],
}) {
  return {
    'merchant': {'key': 'al_bayan', 'name': 'البيان'},
    'day': ?day,
    'entries': entries,
    'registerTotals': {
      'resultUnits': 0,
      'paidUnits': 0,
      'remainingUnits': 0,
      'vodafoneConsumedUnits': 0,
      'vodafoneRemainingUnits': 0,
    },
  };
}

Map<String, Object?> _day({required int? version}) {
  return {
    'id': '12',
    'dayNumber': 12,
    'status': 'draft',
    'version': version,
    'correctionOpen': false,
    'previousDebtUnits': 1,
    'previousVodafoneUnits': 2,
  };
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

Future<void> finishSend(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(milliseconds: 400));
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
