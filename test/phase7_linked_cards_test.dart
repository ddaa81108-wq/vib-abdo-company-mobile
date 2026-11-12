import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/accounts/account_list_logic.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

/// P7-14. The link decision uses the real collections controller.
/// Link state is read from the next overview. An empty onSubmit is not used.
///
/// A real submit for a linked card and an unlinked card, and the refreshed
/// overview, are covered by the tests merged with DEF-021:
/// `test/def021_collection_submit_test.dart` and
/// `packages/api_layer/test/def021_collection_submit_test.dart`.
/// Those are not repeated here.
void main() {
  testWidgets(
    'P7-14 linking ur_1 to a found card approves it and posts the payment',
    (tester) async {
      // 537f073: approving a standalone receipt links it to the chosen card
      // and posts it with the chosen entry type (payment by default).
      final layer = await pumpFakeApp(tester, size: const Size(800, 2400));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/collections');

      expect(find.text('اسم غير مربوط تجريبي'), findsOneWidget);
      final link = find.byKey(const Key('unlinked-link-ur_1'));
      expect(link, findsOneWidget);
      expect(find.byKey(const Key('unlinked-new-ur_1')), findsOneWidget);
      await tester.ensureVisible(link);
      await tester.tap(link);
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('link-customer')),
        'عميل تجريبي',
      );
      await tester.tap(find.byKey(const Key('link-search')));
      await settle(tester);
      final candidate = find.byKey(const Key('link-candidate-c_55'));
      await tester.ensureVisible(candidate);
      await tester.tap(candidate);
      await settle(tester);
      final save = find.byKey(const Key('save-link'));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.ensureVisible(save);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(save);
      await settle(tester);

      expect(find.byKey(const Key('unlinked-link-ur_1')), findsNothing);
      expect(find.byKey(const Key('unlinked-new-ur_1')), findsNothing);

      final overview = await tester.runAsync(
        () => layer.collections.overview(),
      );
      final receipt = overview!.unlinkedReceipts.firstWhere(
        (row) => row.id == 'ur_1',
      );
      expect(receipt.status, 'approved');
      expect(receipt.raw['linkedCustomerId'], 'c_55');
      expect(receipt.raw['entryType'], 'payment');

      await go(tester, '/customers/c_55');
      expect(_header('270 د.ل'), findsOneWidget);
      final card = await tester.runAsync(
        () => layer.accounts.get(AccountSection.customers, 'c_55'),
      );
      expect(card!.balanceUnits?.units, 270);
    },
  );

  testWidgets(
    'a system-managed card shows its stored balance and hides writes',
    (tester) async {
      // 🔶 systemKind is not on the fixture and is not inferred from
      // systemLinkKey. The write gate reads systemManaged only.
      final layer = await pumpFakeApp(tester, size: const Size(800, 2200));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/customers');

      expect(find.text('متبقي المصراوية تجريبي'), findsOneWidget);
      expect(find.text('مرتبط تلقائيًا'), findsWidgets);

      final card = await tester.runAsync(
        () => layer.accounts.get(
          AccountSection.customers,
          'c_masraweya_remainder',
        ),
      );
      expect(card!.systemManaged, isTrue);
      expect(card.systemLinkKey, 'masraweya_remainder');
      expect(card.systemKind, isNull);
      expect(card.balanceUnits?.units, 8950);
      expect(canSelectAccountForAssignment(card), isFalse);

      await go(tester, '/customers/c_masraweya_remainder');
      expect(_header('8,950 د.ل'), findsOneWidget);
      expect(find.byKey(const Key('add-payment')), findsNothing);
      expect(find.text(AppStrings.systemCard), findsWidgets);

      await go(tester, '/customers/c_55');
      expect(_header('320 د.ل'), findsOneWidget);
      final payment = find.byKey(const Key('add-payment'), skipOffstage: false);
      await tester.ensureVisible(payment);
      expect(payment, findsOneWidget);
    },
  );

  testWidgets('P7-14 cash buttons follow the stored cash status', (
    tester,
  ) async {
    // 🔶 cashStatus / cashPending. ur_1 is not_applicable, so cash stays
    // hidden. ur_2 is rejected with cash pending, so decide and cash both
    // stay hidden. A linked submission still shows cash from its own flag.
    await pumpFakeApp(tester, size: const Size(800, 2400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');

    expect(find.byKey(const Key('unlinked-cash-ur_1')), findsNothing);
    expect(find.byKey(const Key('unlinked-reject-ur_2')), findsNothing);
    expect(find.byKey(const Key('unlinked-cash-ur_2')), findsNothing);
    expect(find.byKey(const Key('cash-sb_2')), findsOneWidget);
    expect(find.byKey(const Key('approve-sb_2')), findsNothing);
  }, tags: ['pending-decision']);
}

Finder _header(String text) {
  return find.descendant(
    of: find.byKey(const Key('ledger-header-balance')),
    matching: find.text(text),
  );
}
