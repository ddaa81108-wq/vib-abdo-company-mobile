/// DEF-036 on screen. Real widgets and repositories; only the fake transport
/// is scripted.
///
/// PR #60 skips `DEF-036 the website fraction is not a displayed number` in
/// `test/acceptance/phase8/phase8_reconciliation_test.dart`, a file that branch
/// adds. Enabling it here would collide with that PR, so this file is the
/// equivalent.
library;

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/purchases/purchases_screen.dart';
import 'package:vib_abdo_company_mobile/features/treasury/treasury_screen.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';

import 'support/pump_app.dart';

class _Kind {
  const _Kind(this.name, this.json, this.secret);
  final String name;
  final String json;
  final List<String> secret;
}

const _kinds = <_Kind>[
  _Kind('fraction', '10.005', ['10.005', '10 د.ل', '11 د.ل']),
  _Kind('string', '"1500"', ['1500', '1,500']),
  _Kind('huge', '123456789012345678901234', ['123456789012345678901234']),
];

const _names = ['اسم سري', 'عميل سليم', 'عميل صفر', 'صنف سري', 'صنف سليم'];

void main() {
  for (final kind in _kinds) {
    testWidgets('DEF-036 customers ${kind.name} summary keeps the other rows', (
      tester,
    ) async {
      final lines = await _open(tester, {
        '/api/customers': _customersJson(kind),
      }, '/customers');

      expect(
        find.byKey(const Key('screen-customers'), skipOffstage: false),
        findsOneWidget,
      );
      expect(_text('عميل سليم'), findsWidgets);
      expect(_text('320 د.ل'), findsWidgets);
      expect(_text('0 د.ل'), findsWidgets);
      expect(_text('10,635 د.ل'), findsWidgets);
      expect(_text(MoneyValue.invalidLabel), findsWidgets);
      expect(_icon(), findsWidgets);
      expect(_text('10 د.ل'), findsNothing);
      expect(_text('11 د.ل'), findsNothing);
      expect(_text('1,500 د.ل'), findsNothing);
      expect(_text('1,500'), findsNothing);
      expect(
        find.textContaining('123456789012345678901234', skipOffstage: false),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('account-card-c_ok'), skipOffstage: false),
          matching: _text('320 د.ل'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('account-card-c_frac'), skipOffstage: false),
          matching: _text(MoneyValue.invalidLabel),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('account-card-c_text'), skipOffstage: false),
          matching: _icon(),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('account-card-c_huge'), skipOffstage: false),
          matching: _text(MoneyValue.invalidLabel),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(_key(const ValueKey('zero-review-c_zero')), findsOneWidget);
      expect(_key(const ValueKey('zero-review-c_frac')), findsNothing);
      expect(_key(const ValueKey('zero-review-c_text')), findsNothing);
      expect(_key(const ValueKey('zero-review-c_huge')), findsNothing);
      _expectLine(
        lines,
        endpoint: '/api/customers',
        field: 'balanceUnits',
        row: 'c_frac',
      );
      _expectLine(
        lines,
        endpoint: '/api/customers',
        field: 'balanceUnits',
        row: 'c_text',
      );
      _expectLine(
        lines,
        endpoint: '/api/customers',
        field: 'balanceUnits',
        row: 'c_huge',
      );
      _expectLine(
        lines,
        endpoint: '/api/customers',
        field: 'summary.netBalance',
        row: '-',
      );
      expect(lines.any((line) => line.contains('row=c_ok')), isFalse);
      _expectClean(lines, [
        ...kind.secret,
        ..._names,
        '10.005',
        '1500',
        '123456789012345678901234',
      ]);
      _expectLogShape(lines);
    });

    testWidgets(
      'DEF-036 balance ${kind.name} refuses payment and full payment',
      (tester) async {
        final layer = await pumpFakeApp(tester, size: const Size(800, 2200));
        final fake = layer.client as FakeApiClient;
        await signIn(tester, username: 'admin.demo', password: 'demo-only');
        final lines = _beginLog();
        fake.scriptedGetJson['/api/customers/c_55'] = _cardJson(kind);
        await go(tester, '/customers/c_55');

        final header = tester.widget<MoneyText>(
          find.byKey(const Key('ledger-header-balance'), skipOffstage: false),
        );
        expect(header.text, MoneyValue.invalidLabel);
        expect(
          find.descendant(
            of: find.byKey(
              const Key('ledger-header-balance'),
              skipOffstage: false,
            ),
            matching: _icon(),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        expect(_text('اسم سري'), findsWidgets);
        expect(_text('سداد جزئي'), findsWidgets);
        expect(_text('320 د.ل'), findsWidgets);
        expect(_text('10 د.ل'), findsNothing);
        expect(_text('1,500 د.ل'), findsNothing);
        expect(
          find.textContaining('123456789012345678901234', skipOffstage: false),
          findsNothing,
        );

        await tester.ensureVisible(find.byKey(const Key('full-payment')));
        await tester.tap(find.byKey(const Key('full-payment')));
        await settle(tester);
        expect(fake.mutationRequestIds, isEmpty);
        expect(_errorTexts(tester), contains(MoneyValue.invalidLabel));

        await tester.tap(find.byKey(const Key('add-payment')));
        await settle(tester);
        await enterAmount(tester, '10');
        await tester.tap(find.byKey(const Key('save-movement')));
        await settle(tester);

        expect(fake.mutationRequestIds, isEmpty);
        expect(_errorTexts(tester), everyElement(MoneyValue.invalidLabel));
        _expectLine(
          lines,
          endpoint: '/api/customers/c_55',
          field: 'balanceUnits',
          row: 'c_55',
        );
        _expectClean(lines, [...kind.secret, ..._names]);
        _expectLogShape(lines);
      },
    );
  }

  testWidgets('DEF-036 treasury totals keep the other totals', (tester) async {
    final lines = await _open(tester, {
      '/api/treasury': _treasuryJson(),
    }, '/treasury');

    expect(
      find.byKey(TreasuryScreen.screenKey, skipOffstage: false),
      findsOneWidget,
    );
    expect(_text('51,000 د.ل'), findsWidgets);
    expect(_text('95,000 ج.م'), findsWidgets);
    expect(_text('10,000 د.ل'), findsWidgets);
    expect(_text(MoneyValue.invalidLabel), findsWidgets);
    expect(_icon(), findsWidgets);
    expect(_text('10 د.ل'), findsNothing);
    expect(_text('12,000 د.ل'), findsNothing);
    expect(_text('1,500 د.ل'), findsNothing);
    expect(
      find.textContaining('123456789012345678901234', skipOffstage: false),
      findsNothing,
    );
    _expectLine(
      lines,
      endpoint: '/api/treasury',
      field: 'totals.receivablesUnits',
      row: '-',
    );
    _expectLine(
      lines,
      endpoint: '/api/treasury',
      field: 'totals.liabilitiesUnits',
      row: '-',
    );
    _expectLine(
      lines,
      endpoint: '/api/treasury',
      field: 'totals.activeCashUnits',
      row: '-',
    );
    expect(
      lines.any((line) => line.contains('field=totals.netUnits')),
      isFalse,
    );
    _expectClean(lines, const [
      '10.005',
      '12000',
      '12,000',
      '123456789012345678901234',
      ..._names,
    ]);
    _expectLogShape(lines);
  });

  testWidgets('DEF-036 purchases totals keep the other rows', (tester) async {
    final lines = await _open(tester, {
      '/api/purchases/al_bayan': _purchasesJson(),
    }, '/purchases');

    expect(
      find.byKey(PurchasesScreen.screenKey, skipOffstage: false),
      findsOneWidget,
    );
    expect(_text('صنف سليم'), findsWidgets);
    expect(_text('40 د.ل'), findsWidgets);
    expect(_text('7 د.ل'), findsWidgets);
    expect(_text('100 د.ل'), findsWidgets);
    expect(_text('50,000 د.ل'), findsWidgets);
    expect(_text(MoneyValue.invalidLabel), findsWidgets);
    expect(_icon(), findsWidgets);
    expect(_text('10 د.ل'), findsNothing);
    expect(_text('47,447 د.ل'), findsNothing);
    expect(
      find.textContaining('123456789012345678901234', skipOffstage: false),
      findsNothing,
    );
    _expectLine(
      lines,
      endpoint: '/api/purchases/al_bayan',
      field: 'resultUnits',
      row: 'e_bad',
    );
    _expectLine(
      lines,
      endpoint: '/api/purchases/al_bayan',
      field: 'registerTotals.paidUnits',
      row: '-',
    );
    _expectLine(
      lines,
      endpoint: '/api/purchases/al_bayan',
      field: 'registerTotals.remainingUnits',
      row: '-',
    );
    expect(lines.any((line) => line.contains('row=e_ok')), isFalse);
    _expectClean(lines, const [
      '10.005',
      '47447',
      '47,447',
      '123456789012345678901234',
      ..._names,
    ]);
    _expectLogShape(lines);
  });
}

Finder _text(String value) => find.text(value, skipOffstage: false);

Finder _icon() => find.byIcon(Icons.error_outline, skipOffstage: false);

Finder _key(Key key) => find.byKey(key, skipOffstage: false);

List<String?> _errorTexts(WidgetTester tester) {
  final errors = tester.widgetList<Text>(
    find.byKey(const Key('mutation-error'), skipOffstage: false),
  );
  return [for (final text in errors) text.data];
}

Future<List<String>> _open(
  WidgetTester tester,
  Map<String, String> scripted,
  String path,
) async {
  final layer = await pumpFakeApp(tester, size: const Size(900, 2400));
  final fake = layer.client as FakeApiClient;
  await signIn(tester, username: 'admin.demo', password: 'demo-only');
  final lines = _beginLog();
  fake.scriptedGetJson.addAll(scripted);
  await go(tester, path);
  return lines;
}

List<String> _beginLog() {
  final lines = <String>[];
  SafeLog.sink = (message, {wrapWidth}) {
    if (message != null) lines.add(message);
  };
  addTearDown(() => SafeLog.sink = null);
  return lines;
}

void _expectLine(
  List<String> lines, {
  required String endpoint,
  required String field,
  required String row,
}) {
  expect(
    lines.any(
      (line) =>
          line.contains('endpoint=$endpoint') &&
          line.contains('field=$field') &&
          line.contains('row=$row'),
    ),
    isTrue,
    reason: lines.join('\n'),
  );
}

void _expectClean(List<String> lines, List<String> secrets) {
  final text = lines.join('\n');
  for (final secret in secrets) {
    expect(text.contains(secret), isFalse, reason: '$secret\n$text');
  }
}

void _expectLogShape(List<String> lines) {
  final shape = RegExp(
    r'^\[api\] invalid_money endpoint=\S+ field=\S+ row=\S+$',
  );
  expect(lines, isNotEmpty);
  for (final line in lines) {
    expect(line, matches(shape), reason: line);
  }
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

Future<void> enterAmount(WidgetTester tester, String value) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('movement-amount')),
      matching: find.byType(TextField),
    ),
    value,
  );
  await tester.pump();
}

String _customersJson(_Kind kind) =>
    '''
{
  "items": [
    {"id":"c_frac","name":"اسم سري","balanceUnits":10.005,"currency":"LYD"},
    {"id":"c_text","name":"اسم سري","balanceUnits":"1500","currency":"LYD"},
    {"id":"c_huge","name":"اسم سري","balanceUnits":123456789012345678901234,"currency":"LYD"},
    {"id":"c_ok","name":"عميل سليم","balanceUnits":320,"currency":"LYD"},
    {"id":"c_zero","name":"عميل صفر","balanceUnits":0,"currency":"LYD","zeroReview":{"status":"pending"}}
  ],
  "summary": {"netBalance":${kind.json},"totalDebt":10635,"activeCards":5},
  "totalItems": 5
}
''';

String _cardJson(_Kind kind) =>
    '{"id":"c_55","name":"اسم سري","balanceUnits":${kind.json},"currency":"LYD","version":4}';

String _treasuryJson() => '''
{
  "version": 7,
  "totals": {
    "receivablesUnits": 10.005,
    "liabilitiesUnits": "12000",
    "activeCashUnits": 123456789012345678901234,
    "egyptianSourceUnits": 95000,
    "egyptianRate": "9.5",
    "egyptianConvertedUnits": 10000,
    "netUnits": 51000,
    "activeCashTone": "positive"
  }
}
''';

String _purchasesJson() => '''
{
  "day": {
    "id": "day-1",
    "dayNumber": 1,
    "status": "draft",
    "version": 1,
    "todayResultUnits": 100,
    "todayPaidUnits": 40
  },
  "entries": [
    {"id":"e_ok","itemLabel":"صنف سليم","resultUnits":40,"paidUnits":40,"remainingUnits":40},
    {"id":"e_bad","itemLabel":"صنف سري","resultUnits":10.005,"paidUnits":7,"remainingUnits":7}
  ],
  "registerTotals": {
    "resultUnits": 50000,
    "paidUnits": "47447",
    "remainingUnits": 123456789012345678901234,
    "vodafoneConsumedUnits": 0,
    "vodafoneRemainingUnits": 1
  }
}
''';
