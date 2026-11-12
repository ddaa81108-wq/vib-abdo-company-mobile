import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/accounts/website_ledger_tone.dart';
import 'package:vib_abdo_company_mobile/features/masraweya/masraweya_autosave.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'package:flutter/rendering.dart';

import 'support/phase7_ui.dart' show go;
import 'support/pump_app.dart';

double _columnWidth(WidgetTester tester, String label) {
  RenderObject? node = tester.renderObject(find.text(label));
  while (node != null) {
    final parent = node.parent;
    if (parent is RenderFlex && node is RenderBox) return node.size.width;
    node = parent;
  }
  throw StateError(label);
}

void main() {
  test('each ledger total uses that section website label', () {
    expect(
      websiteLedgerTotalLabel(AccountSection.customers, 320),
      AppStrings.ledgerTotal,
    );
    expect(
      websiteLedgerTotalLabel(AccountSection.customers, -20),
      AppStrings.trustCustomer,
    );
    expect(
      websiteLedgerTotalLabel(AccountSection.companies, -20),
      AppStrings.companyTrust,
    );
    expect(
      websiteLedgerTotalLabel(AccountSection.libyanDeposits, 40),
      'أمانة للعميل',
    );
    expect(
      websiteLedgerTotalLabel(AccountSection.libyanDeposits, -5),
      'دين على العميل',
    );
    expect(
      websiteLedgerTotalLabel(AccountSection.libyanDeposits, 0),
      'الحساب صفر',
    );
    expect(
      websiteLedgerTotalLabel(AccountSection.egyptianDeposits, 8),
      'لصالح المنظومة — دين على العميل',
    );
    expect(
      websiteLedgerTotalLabel(AccountSection.egyptianDeposits, -8),
      'دين علينا للعميل',
    );
    expect(
      depositLedgerKindWord(AccountSection.libyanDeposits, 40),
      AppStrings.customerCreditWord,
    );
    expect(
      depositLedgerKindWord(AccountSection.egyptianDeposits, 8),
      AppStrings.customerDebtWord,
    );
    expect(depositLedgerKindWord(AccountSection.libyanDeposits, 0), isNull);
  });

  test('a saved masraweya day adopts a remote edit unless a field is busy', () {
    expect(
      masraweyaRemoteReplacesDraft(
        phase: MasraweyaSavePhase.saved,
        fieldFocused: false,
      ),
      isTrue,
    );
    expect(
      masraweyaRemoteReplacesDraft(
        phase: MasraweyaSavePhase.saved,
        fieldFocused: true,
      ),
      isFalse,
    );
    expect(
      masraweyaRemoteReplacesDraft(
        phase: MasraweyaSavePhase.dirty,
        fieldFocused: false,
      ),
      isFalse,
    );
    expect(
      masraweyaRemoteReplacesDraft(
        phase: MasraweyaSavePhase.saving,
        fieldFocused: false,
      ),
      isFalse,
    );
  });

  testWidgets('purchase edit and delete share one centered line', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(1280, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await tester.scrollUntilVisible(
      find.byKey(const Key('edit-pe_1')),
      40,
      scrollable: find.descendant(
        of: find.byKey(const Key('screen-purchases')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
        ),
      ),
    );
    final edit = tester.getRect(find.byKey(const Key('edit-pe_1')));
    final remove = tester.getRect(find.byKey(const Key('delete-pe_1')));
    expect((edit.center.dy - remove.center.dy).abs(), lessThan(2));
    final row = tester.getRect(find.byKey(const Key('purchase-entry-pe_1')));
    final pair = (edit.center.dy + remove.center.dy) / 2;
    expect((pair - row.center.dy).abs(), lessThan(8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('masraweya القيمة stays wider than العمولة for a long number', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/masraweya');
    final value = _columnWidth(tester, 'القيمة');
    final commission = _columnWidth(tester, 'العمولة');
    expect(value, greaterThan(commission * 2));
    await tester.enterText(
      find.byKey(const Key('masraweya-entry-value-field-0')),
      '999999999999',
    );
    await tester.pump();
    expect(find.text('999999999999'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the ledger name, edit, and close are stacked and clear the nav',
    (tester) async {
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetViewPadding);
      await pumpFakeApp(tester, size: const Size(360, 800));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/customers/c_55');
      final name = tester.getRect(find.byKey(const Key('ledger-top-bar')));
      final edit = tester.getRect(find.byKey(const Key('edit-account-card')));
      final close = tester.getRect(find.byKey(const Key('ledger-close')));
      expect(edit.top, greaterThan(name.top + 20));
      expect(close.top, greaterThan(edit.bottom - 1));
      expect((edit.center.dx - 180).abs(), lessThan(40));
      final pinned = tester.getRect(find.byKey(const Key('ledger-pinned')));
      expect(pinned.bottom, lessThanOrEqualTo(800));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    },
  );
}
