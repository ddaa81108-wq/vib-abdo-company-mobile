import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/accounts/account_list_logic.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

/// P7-14. Submits and the link decision use the real collections controller.
/// Link state is read from the next overview. An empty onSubmit is not used.
void main() {
  testWidgets(
    'DEF-021 a real submit for a linked card and an unlinked card is not on the next overview',
    (tester) async {
      // POST /api/collections/assignments/{id}/submissions and
      // POST /api/collections/unlinked-receipts return {id: ok, version: 1}
      // and the next GET /api/collections does not contain the new row.
      final layer = await pumpFakeApp(tester, size: const Size(800, 2400));
      await signIn(tester, username: 'employee.demo', password: 'demo-only');
      await go(tester, '/collections');

      await tester.ensureVisible(find.byKey(const Key('submit-as_1')));
      await tester.tap(find.byKey(const Key('submit-as_1')));
      await settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        '40',
      );
      await tester.tap(find.byKey(const Key('save-assignment')));
      await settle(tester);

      await tester.ensureVisible(find.byKey(const Key('unlinked-collection')));
      await tester.tap(find.byKey(const Key('unlinked-collection')));
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('unlinked-name')),
        'زبون جديد',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('unlinked-amount')),
          matching: find.byType(TextField),
        ),
        '25',
      );
      await tester.tap(find.byKey(const Key('save-unlinked')));
      await settle(tester);

      final fake = layer.client as FakeApiClient;
      expect(
        fake.mutationPaths,
        contains('/api/collections/assignments/as_1/submissions'),
      );
      expect(
        fake.mutationPaths,
        contains('/api/collections/unlinked-receipts'),
      );
      expect(fake.mutationBodies.join('\n'), contains('"amountUnits":40'));
      expect(fake.mutationBodies.join('\n'), contains('"amountUnits":25'));

      final overview = await tester.runAsync(
        () => layer.collections.overview(),
      );
      expect(overview!.submissions.map((row) => row.id).toList(), [
        'sb_1',
        'sb_2',
      ]);
      expect(overview.unlinkedReceipts.map((row) => row.id).toList(), [
        'ur_1',
        'ur_2',
      ]);
    },
    tags: ['known-bug'],
  );

  testWidgets(
    'P7-14 linking ur_1 approves it, stores customerId, and does not move money',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 2400));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/collections');

      expect(find.text('اسم غير مربوط تجريبي'), findsOneWidget);
      expect(find.text(AppStrings.unlinked), findsWidgets);
      final link = find.byKey(const Key('unlinked-link-ur_1'));
      expect(link, findsOneWidget);
      expect(find.byKey(const Key('unlinked-approve-ur_1')), findsOneWidget);
      await tester.ensureVisible(link);
      await tester.tap(link);
      await settle(tester);
      await tester.enterText(find.byKey(const Key('link-customer')), 'c_55');
      await tester.tap(find.byKey(const Key('save-link')));
      await settle(tester);

      expect(find.byKey(const Key('unlinked-link-ur_1')), findsNothing);
      expect(find.byKey(const Key('unlinked-approve-ur_1')), findsNothing);
      expect(find.text(AppStrings.approved), findsWidgets);

      final overview = await tester.runAsync(
        () => layer.collections.overview(),
      );
      final receipt = overview!.unlinkedReceipts.firstWhere(
        (row) => row.id == 'ur_1',
      );
      expect(receipt.status, 'approved');
      expect(receipt.raw['customerId'], 'c_55');

      await go(tester, '/customers/c_55');
      expect(_header('320 د.ل'), findsOneWidget);
      final card = await tester.runAsync(
        () => layer.accounts.get(AccountSection.customers, 'c_55'),
      );
      expect(card!.balanceUnits, 320);
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
      expect(find.text(AppStrings.systemCard), findsWidgets);

      final card = await tester.runAsync(
        () => layer.accounts.get(
          AccountSection.customers,
          'c_masraweya_remainder',
        ),
      );
      expect(card!.systemManaged, isTrue);
      expect(card.systemLinkKey, 'masraweya_remainder');
      expect(card.systemKind, isNull);
      expect(card.balanceUnits, 8950);
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
    // hidden. ur_2 is rejected and cash pending, so decide stays hidden and
    // cash is shown.
    await pumpFakeApp(tester, size: const Size(800, 2400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');

    expect(find.byKey(const Key('unlinked-cash-ur_1')), findsNothing);
    expect(find.byKey(const Key('unlinked-reject-ur_2')), findsNothing);
    expect(find.byKey(const Key('unlinked-cash-ur_2')), findsOneWidget);
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
