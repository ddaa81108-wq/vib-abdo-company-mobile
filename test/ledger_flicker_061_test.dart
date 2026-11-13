import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_large_catalog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/masraweya/masraweya_autosave.dart';
import 'package:vib_abdo_company_mobile/features/purchases/purchases_screen.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';

import 'support/phase7_ui.dart' show go;
import 'support/pump_app.dart';

void main() {
  test('a finger that moved the purchases list is not pulled back', () {
    expect(purchaseAutoScroll(openedAt: 0, offset: 0), isTrue);
    expect(purchaseAutoScroll(openedAt: 0, offset: 48), isFalse);
  });

  test('a remote masraweya digit edits the existing controller', () {
    final controller = TextEditingController(text: '10');
    addTearDown(controller.dispose);
    expect(masraweyaWriteDigits(controller, '10'), isFalse);
    expect(masraweyaWriteDigits(controller, '9999999'), isTrue);
    expect(controller.text, '9999999');
  });

  testWidgets('a live ledger refresh keeps the scroll and the list', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      fakeDataset: FakeDataset.large,
      size: const Size(390, 844),
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/${FakeLargeCatalog.longLedgerAccountId}');
    await tester.pump(const Duration(milliseconds: 200));
    final scrollable = find.descendant(
      of: find.byKey(const Key('ledger-entries-list')),
      matching: find.byType(Scrollable),
    );
    final state = tester.state<ScrollableState>(scrollable);
    state.position.jumpTo(40);
    await tester.pump();
    final held = state.position.pixels;
    ProviderScope.containerOf(
      tester.element(find.byKey(const Key('screen-ledger-customers'))),
    ).invalidate(
      ledgerProvider((
        AccountSection.customers,
        FakeLargeCatalog.longLedgerAccountId,
      )),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.state<ScrollableState>(scrollable), same(state));
    expect(state.position.pixels, held);
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(tester.state<ScrollableState>(scrollable), same(state));
    expect(state.position.pixels, held);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a live purchases refresh keeps the row and the scroll', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(390, 844));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    final row = find.byKey(const Key('purchase-entry-pe_1'));
    final before = tester.element(row);
    final scroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('screen-purchases')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    if (scroll.position.maxScrollExtent > 20) {
      scroll.position.jumpTo(20);
    }
    final held = scroll.position.pixels;
    await tester.pump();
    ProviderScope.containerOf(before).invalidate(purchasesProvider);
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(tester.element(row), same(before));
    expect(scroll.position.pixels, held);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a live collections refresh keeps the scroll', (tester) async {
    await pumpFakeApp(tester, size: const Size(390, 844));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');
    final scrollable = find.descendant(
      of: find.byKey(const Key('screen-collections')),
      matching: find.byType(Scrollable),
    );
    final state = tester.state<ScrollableState>(scrollable.first);
    if (state.position.maxScrollExtent > 30) {
      state.position.jumpTo(30);
    }
    final held = state.position.pixels;
    await tester.pump();
    ProviderScope.containerOf(
      tester.element(find.byKey(const Key('screen-collections'))),
    ).invalidate(collectionsProvider);
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(tester.state<ScrollableState>(scrollable.first), same(state));
    expect(state.position.pixels, held);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a live masraweya refresh keeps the value field', (tester) async {
    await pumpFakeApp(tester, size: const Size(390, 844));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/masraweya');
    final field = find.byKey(const Key('masraweya-entry-value-field-0'));
    final before = tester.element(field);
    ProviderScope.containerOf(before).invalidate(masraweyaProvider);
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(tester.element(field), same(before));
    expect(tester.takeException(), isNull);
  });
}
