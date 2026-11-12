import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

/// توجيه exists on customers and companies only (website toolbar and
/// `_canAssign`). Deposits have no توجيه button.
void main() {
  final cards = [
    _card('debt', 'دين قابل', 100),
    _card('held', 'موجّه', 100, assignee: 'الصفير'),
    _card('zero', 'صفر', 0),
    _card('trust', 'أمانة', -20),
  ];

  Future<void> open(WidgetTester tester, String path) async {
    await pumpFakeApp(
      tester,
      size: const Size(800, 1600),
      overrides: [
        accountsProvider.overrideWith(
          (ref, section) async => AccountsPage(
            page: Paged(items: cards),
            summary: const AccountsSummaryDto(activeCards: 4),
          ),
        ),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, path);
  }

  for (final path in ['/customers', '/companies']) {
    testWidgets('whole card toggles in توجيه mode on $path', (tester) async {
      await open(tester, path);
      expect(find.byType(Checkbox), findsNothing);
      await tester.tap(find.byKey(const Key('assign-mode')));
      await settle(tester);

      expect(find.byType(Checkbox), findsNothing);
      expect(find.byKey(const ValueKey('assign-select-debt')), findsOneWidget);
      expect(find.byKey(const Key('account-card-debt')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('account-card-debt')),
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
      );
      for (final id in ['held', 'zero', 'trust']) {
        expect(find.byKey(ValueKey('assign-select-$id')), findsNothing);
      }

      await tester.tap(find.byKey(const ValueKey('assign-select-debt')));
      await tester.pump();
      expect(find.byKey(const ValueKey('assign-check-debt')), findsOneWidget);
      expect(
        find.byKey(Key('screen-ledger-${path.substring(1)}')),
        findsNothing,
      );

      await tester.longPress(find.byKey(const Key('account-card-debt')));
      await tester.pump();
      // The card ignores a repeated delivery of the same tap for a few
      // milliseconds. Real time, because the guard uses DateTime.now.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      expect(
        find.byKey(Key('screen-ledger-${path.substring(1)}')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('assign-check-debt')), findsOneWidget);

      await tester.tap(find.byKey(const Key('account-card-held')));
      await tester.pump();
      expect(find.byKey(const ValueKey('assign-check-held')), findsNothing);
      expect(
        find.byKey(Key('screen-ledger-${path.substring(1)}')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('account-card-debt')));
      await tester.pump();
      expect(find.byKey(const ValueKey('assign-check-debt')), findsNothing);

      await tester.tap(find.byKey(const Key('assign-mode')));
      await settle(tester);
      expect(find.byKey(const ValueKey('assign-select-debt')), findsNothing);
      await tester.tap(find.byKey(const Key('account-card-debt')));
      await settle(tester);
      expect(
        find.byKey(Key('screen-ledger-${path.substring(1)}')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final path in ['/libyan-deposits', '/egyptian-deposits']) {
    testWidgets('no توجيه mode on $path', (tester) async {
      await open(tester, path);
      expect(find.byKey(const Key('assign-mode')), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      await tester.tap(find.byKey(const Key('account-card-debt')));
      await settle(tester);
      expect(
        find.byKey(Key('screen-ledger-${path.substring(1)}')),
        findsOneWidget,
      );
    });
  }
}

AccountCardDto _card(String id, String name, int balance, {String? assignee}) {
  return AccountCardDto(
    id: id,
    name: name,
    balanceUnits: MoneyValue.known(balance),
    currency: Currency.lyd,
    activeAssigneeName: assignee,
    version: 1,
  );
}
