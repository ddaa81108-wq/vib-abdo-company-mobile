import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets(
    'an entry from another day has no edit or delete, and the write uses its dayVersion',
    (tester) async {
      final layer = await pumpFakeApp(
        tester,
        size: const Size(800, 1800),
        overrides: [purchasesProvider.overrideWith((ref) async => _page())],
      );
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/purchases');

      expect(find.byKey(const Key('purchase-entry-pe_today')), findsOneWidget);
      expect(find.byKey(const Key('purchase-entry-pe_other')), findsOneWidget);
      expect(find.byKey(const Key('edit-pe_today')), findsOneWidget);
      expect(find.byKey(const Key('delete-pe_today')), findsOneWidget);
      expect(find.byKey(const Key('edit-pe_other')), findsNothing);
      expect(find.byKey(const Key('delete-pe_other')), findsNothing);

      await tester.tap(find.byKey(const Key('delete-pe_today')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(AppStrings.confirmDelete), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-mutation')));
      await finishSend(tester);

      final body = jsonDecode(fake.mutationBodies.last) as Map<String, dynamic>;
      expect(body['expectedDayVersion'], 4);
      expect(
        fake.mutationPaths.last,
        '/api/purchases/al_bayan/entries/pe_today',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('opening is hidden with no day and on a locked day', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      size: const Size(800, 1400),
      overrides: [
        purchasesProvider.overrideWith((ref) async {
          return PurchasesPage.fromData({
            'entries': <Object>[],
            'registerTotals': {
              'resultUnits': 0,
              'paidUnits': 0,
              'remainingUnits': 0,
              'vodafoneConsumedUnits': 0,
              'vodafoneRemainingUnits': 0,
            },
          });
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    expect(find.byKey(const Key('opening-card')), findsOneWidget);
    expect(find.byKey(const Key('set-opening')), findsNothing);

    await pumpFakeApp(
      tester,
      size: const Size(800, 1400),
      overrides: [
        purchasesProvider.overrideWith((ref) async => _day(status: 'draft')),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    expect(find.byKey(const Key('set-opening')), findsOneWidget);

    await pumpFakeApp(
      tester,
      size: const Size(800, 1400),
      overrides: [
        purchasesProvider.overrideWith(
          (ref) async => _day(status: 'finalized'),
        ),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    expect(find.byKey(const Key('open-correction-12')), findsOneWidget);
    expect(find.byKey(const Key('set-opening')), findsNothing);

    await pumpFakeApp(
      tester,
      size: const Size(800, 1400),
      overrides: [
        purchasesProvider.overrideWith(
          (ref) async => _day(status: 'finalized', correctionOpen: true),
        ),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    expect(find.byKey(const Key('set-opening')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

PurchasesPage _page() {
  return PurchasesPage.fromData({
    'day': {
      'id': '12',
      'dayNumber': 12,
      'status': 'draft',
      'version': 9,
      'correctionOpen': false,
      'previousDebtUnits': 0,
      'previousVodafoneUnits': 0,
    },
    'entries': [
      {
        'id': 'pe_today',
        'dayId': '12',
        'itemCode': 'fawry',
        'itemLabel': 'اليوم',
        'version': 1,
        'dayVersion': 4,
      },
      {
        'id': 'pe_other',
        'dayId': '11',
        'itemCode': 'fawry',
        'itemLabel': 'أمس',
        'version': 1,
        'dayVersion': 1,
      },
    ],
  });
}

PurchasesPage _day({required String status, bool correctionOpen = false}) {
  return PurchasesPage.fromData({
    'day': {
      'id': '12',
      'dayNumber': 12,
      'status': status,
      'version': 3,
      'correctionOpen': correctionOpen,
      'previousDebtUnits': 1,
      'previousVodafoneUnits': 2,
    },
    'entries': <Object>[],
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

Future<void> finishSend(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(milliseconds: 400));
}
