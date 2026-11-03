import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/accounts/ledger_running_balance.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';

import 'support/phase7_ui.dart';
import 'support/pump_app.dart';

/// الرصيد mirrors the website's `ve` in LedgerWorkspace-BQxJagtI.js: start at
/// pageOpeningBalanceUnits, sort by sequence, only `posted` rows move it,
/// debt adds and anything else subtracts. Integer minor units.
LedgerEntryDto _row(
  String id,
  int? sequence,
  String type,
  Object? amount, {
  String status = 'posted',
}) => LedgerEntryDto.fromJson({
  'id': id,
  'sequence': sequence,
  'type': type,
  'status': status,
  'amountUnits': amount,
  if (type == 'payment') 'paymentMode': 'partial',
});

const _known = MoneyValue.known;

void main() {
  group('websiteRunningBalances', () {
    test('one page: opening, debt adds, payment subtracts', () {
      final map = websiteRunningBalances(
        opening: _known(100),
        items: [_row('a', 1, 'debt', 50), _row('b', 2, 'payment', 30)],
      );
      expect(map, {'a': 150, 'b': 120});
    });

    test('rows are taken in sequence order, not list order', () {
      final map = websiteRunningBalances(
        opening: _known(0),
        items: [_row('b', 2, 'payment', 30), _row('a', 1, 'debt', 50)],
      );
      expect(map, {'a': 50, 'b': 20});
    });

    test('a hidden reversed row does not move the balance', () {
      final items = [
        _row('a', 1, 'debt', 500),
        _row('x', 2, 'debt', 999, status: 'reversed'),
        _row('b', 3, 'payment', 180),
      ];
      final map = websiteRunningBalances(opening: _known(0), items: items)!;
      expect(map['a'], 500);
      expect(map['x'], 500); // the website still keys it; it is not drawn
      expect(map['b'], 320);
      expect(items.where(websiteShowsRow).map((e) => e.id), ['a', 'b']);
    });

    test('corrected rows stay drawn but only posted rows count', () {
      final items = [
        _row('a', 1, 'debt', 100),
        _row('c', 2, 'debt', 40, status: 'corrected'),
      ];
      expect(websiteRunningBalances(opening: _known(0), items: items), {
        'a': 100,
        'c': 100,
      });
      expect(items.every(websiteShowsRow), isTrue);
    });

    test('an older page loaded above starts from its own opening', () {
      // The website's merge: older items first, older page's opening.
      final older = [_row('o1', 1, 'debt', 40), _row('o2', 2, 'payment', 10)];
      final newer = [_row('n3', 3, 'debt', 500), _row('n4', 4, 'payment', 180)];
      final merged = [...older, ...newer];
      final map = websiteRunningBalances(opening: _known(0), items: merged);
      expect(map, {'o1': 40, 'o2': 30, 'n3': 530, 'n4': 350});
      expect(
        websiteBalancesMatchingServer(
          opening: _known(0),
          items: merged,
          serverBalance: _known(350),
        ),
        map,
      );
      expect(
        websiteBalancesMatchingServer(
          opening: _known(0),
          items: merged,
          serverBalance: _known(320),
        ),
        isNull,
      );
    });

    test('unusable figures show nothing', () {
      expect(
        websiteRunningBalances(opening: null, items: [_row('a', 1, 'debt', 1)]),
        isNull,
      );
      expect(
        websiteRunningBalances(
          opening: _known(0),
          items: [_row('a', null, 'debt', 1)],
        ),
        isNull,
      );
      expect(
        websiteRunningBalances(
          opening: _known(0),
          items: [_row('a', 1, 'debt', 1.5)],
        ),
        isNull,
      );
      // A broken amount on a row that does not count is ignored.
      expect(
        websiteRunningBalances(
          opening: _known(0),
          items: [_row('a', 1, 'debt', 'x', status: 'reversed')],
        ),
        {'a': 0},
      );
      expect(
        websiteBalancesMatchingServer(
          opening: _known(0),
          items: const [],
          serverBalance: null,
        ),
        isNull,
      );
    });
  });

  Map<String, dynamic> onePage({int opening = 0}) {
    final raw = FakeFixtures.ledger();
    raw['pageOpeningBalanceUnits'] = opening;
    raw['nextBefore'] = null;
    raw['hasMore'] = false;
    return raw;
  }

  testWidgets('the column shows the running balance when it ends on the card', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      size: const Size(430, 932),
      overrides: [
        ledgerProvider.overrideWith(
          (ref, key) async => LedgerPage.fromData(onePage(), key.$1),
        ),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    await settle(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('ledger-column-header')),
        matching: find.text(AppStrings.ledgerColBalance),
      ),
      findsOneWidget,
    );
    String shown(String id) =>
        tester.widget<MoneyText>(find.byKey(Key('ledger-balance-$id'))).text;
    expect(shown('tx_1'), contains('500'));
    expect(shown('tx_2'), contains('320'));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a ledger that does not end on the card shows no column', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      size: const Size(430, 932),
      overrides: [
        ledgerProvider.overrideWith(
          (ref, key) async => LedgerPage.fromData(onePage(opening: 7), key.$1),
        ),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    await settle(tester);
    expect(find.text(AppStrings.ledgerColBalance), findsNothing);
    expect(find.byKey(const Key('ledger-balance-tx_1')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('with an older page loaded above, the balance runs through it', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      size: const Size(430, 1400),
      overrides: [
        // Newest page from the fake (cursor tx_1); its older page is
        // tx_old 40 from opening 0. The card stores 360 = 0+40+500-180.
        accountCardProvider.overrideWith((ref, key) async {
          return AccountCardDto.fromJson({
            'id': key.$2,
            'name': 'عميل',
            'balanceUnits': 360,
            'version': 4,
          }, key.$1);
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    await settle(tester);
    String shown(String id) =>
        tester.widget<MoneyText>(find.byKey(Key('ledger-balance-$id'))).text;
    expect(shown('tx_old'), contains('40'));
    expect(shown('tx_1'), contains('540'));
    expect(shown('tx_2'), contains('360'));
    await tester.pump(const Duration(seconds: 1));
  });
}
