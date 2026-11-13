import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/purchases/purchase_running_balance.dart';

import 'support/pump_app.dart';

void main() {
  test('website running balance is anchored at the open day total', () {
    final rows = [
      _row('pe_old', result: 100, paid: 100),
      _row('pe_1', result: 1053, paid: 500),
    ];
    final after = purchaseRunningAfter(oldestFirst: rows, closingUnits: 2553);
    expect(after, {'pe_old': 2000, 'pe_1': 2553});
  });

  test('a negative carry stays negative and is not flipped', () {
    final after = purchaseRunningAfter(
      oldestFirst: [_row('a', result: 20, paid: 50)],
      closingUnits: -30,
    );
    expect(after, {'a': -30});
  });

  test('one invalid row blanks every balance', () {
    final after = purchaseRunningAfter(
      oldestFirst: [
        _row('ok', result: 10, paid: 0),
        PurchaseEntryDto(
          id: 'bad',
          resultUnits: const MoneyValue.invalid(),
          paidUnits: MoneyValue.known(1),
        ),
      ],
      closingUnits: 100,
    );
    expect(after, isNull);
  });

  test('a missing open-day total blanks the column', () {
    expect(
      purchaseRunningAfter(
        oldestFirst: [_row('a', result: 1, paid: 1)],
        closingUnits: null,
      ),
      isNull,
    );
  });

  testWidgets('the ledger prints the running balance, not result minus paid', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(1280, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await tester.scrollUntilVisible(
      find.byKey(const Key('purchase-balance-pe_old')),
      80,
      scrollable: find.descendant(
        of: find.byKey(const Key('screen-purchases')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
        ),
      ),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('purchase-balance-pe_old')))
          .data,
      '2,000',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('purchase-balance-pe_1'))).data,
      '2,553',
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('purchase-carry-close-11')),
              matching: find.byType(Text),
            ),
          )
          .data,
      '2,000',
    );
    expect(tester.takeException(), isNull);
  });
}

PurchaseEntryDto _row(String id, {required int result, required int paid}) {
  return PurchaseEntryDto(
    id: id,
    resultUnits: MoneyValue.known(result),
    paidUnits: MoneyValue.known(paid),
  );
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).go(path);
  await tester.pumpAndSettle();
}
