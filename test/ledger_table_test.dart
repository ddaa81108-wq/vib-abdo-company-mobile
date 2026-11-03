import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_large_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/phase7_ui.dart';
import 'support/pump_app.dart';

/// Ali, 2026-11-03: the ledger is the website's table. Oldest row on top,
/// one continuous record, the total card pinned, the screen opens at the
/// entry buttons, and a correction opens in its own row.
void main() {
  testWidgets('columns carry the website labels', (tester) async {
    await pumpFakeApp(tester, size: const Size(430, 932));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    final header = find.byKey(const Key('ledger-column-header'));
    for (final label in [
      AppStrings.ledgerColSeq,
      AppStrings.ledgerColWhen,
      AppStrings.ledgerColType,
      AppStrings.ledgerColNote,
      AppStrings.ledgerColValue,
      AppStrings.ledgerColOperation,
      AppStrings.ledgerColRate,
      AppStrings.ledgerColDebt,
      AppStrings.ledgerColPaid,
      AppStrings.ledgerColEdit,
      AppStrings.ledgerColCancel,
    ]) {
      expect(
        find.descendant(of: header, matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }
    expect(tester.takeException(), isNull);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('rows run oldest first by server sequence', (tester) async {
    await pumpFakeApp(tester, size: const Size(430, 1600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    final ids = [
      for (final element
          in find
              .byWidgetPredicate(
                (w) =>
                    w.key is ValueKey<String> &&
                    (w.key! as ValueKey<String>).value.startsWith(
                      'ledger-row-',
                    ),
              )
              .evaluate())
        (element.widget.key! as ValueKey<String>).value,
    ];
    expect(ids.length, greaterThanOrEqualTo(2));
    final tops = [
      for (final id in ids) tester.getTopLeft(find.byKey(ValueKey(id))).dy,
    ];
    final sequences = <int>[];
    for (final id in ids) {
      final mark = find.byKey(
        Key('ledger-sequence-${id.substring('ledger-row-'.length)}'),
      );
      final text = find.descendant(of: mark, matching: find.byType(Text));
      sequences.add(int.parse(tester.widget<Text>(text).data!));
    }
    final order = [for (var i = 0; i < ids.length; i++) i]
      ..sort((a, b) => tops[a].compareTo(tops[b]));
    final shown = [for (final i in order) sequences[i]];
    expect(shown, [...shown]..sort());
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a long ledger opens at the entry buttons, card pinned', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      fakeDataset: FakeDataset.large,
      size: const Size(430, 932),
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/${FakeLargeCatalog.longLedgerAccountId}');
    final scroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('ledger-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    expect(scroll.position.pixels, closeTo(scroll.position.maxScrollExtent, 1));
    final view = tester.view.physicalSize / tester.view.devicePixelRatio;
    final composer = tester.getRect(find.byKey(const Key('ledger-composer')));
    expect(composer.bottom, lessThanOrEqualTo(view.height));
    final header = tester.getRect(find.byKey(const Key('ledger-header')));
    expect(header.top, greaterThanOrEqualTo(0));

    scroll.position.jumpTo(0);
    await tester.pump();
    expect(
      tester.getRect(find.byKey(const Key('ledger-header'))).top,
      header.top,
      reason: 'the total card does not scroll away',
    );
    expect(tester.takeException(), isNull);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a correction opens in its own row and closes there', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(430, 1600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    final button = find.byKey(const Key('correct-tx_1'));
    await tester.ensureVisible(button);
    await settle(tester);
    await tester.tap(button);
    await settle(tester);
    final inline = find.byKey(const Key('ledger-inline-edit-tx_1'));
    expect(inline, findsOneWidget);
    expect(
      find.descendant(
        of: inline,
        matching: find.byKey(const Key('correction-form')),
      ),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byKey(const Key('screen-ledger-customers')), findsOneWidget);
    final row = tester.getRect(find.byKey(const ValueKey('ledger-row-tx_1')));
    expect(tester.getRect(inline).top, greaterThanOrEqualTo(row.top));

    final close = find.byKey(const Key('close-inline-edit-tx_1'));
    await tester.ensureVisible(close);
    await settle(tester);
    await tester.tap(close);
    await settle(tester);
    expect(inline, findsNothing);
    expect(find.byKey(const Key('screen-ledger-customers')), findsOneWidget);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
  });
}
