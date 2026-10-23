import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/precise_json.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('financial ledger fields', () {
    test('present sectionKey, sourceStatus, and occurredAt keep their types',
        () {
      final row = FinancialLedgerEntryDto.fromJson({
        'id': 9,
        'sectionKey': 'customer_debts',
        'sourceStatus': 'posted',
        'occurredAt': '2026-10-22T22:33:25.523Z',
        'currency': 'LYD',
        'amountUnits': 100,
        'description': 'استلام',
      });

      expect(row.sectionKey, FinancialLedgerSectionKey.customerDebts);
      expect(row.sectionKeyRaw, 'customer_debts');
      expect(row.sourceStatus, FinancialLedgerSourceStatus.posted);
      expect(row.sourceStatusRaw, 'posted');
      expect(row.occurredAt, DateTime.utc(2026, 10, 22, 22, 33, 25, 523));
      expect(row.occurredAt!.isUtc, isTrue);
      expect(row.section, 'customer_debts');
      expect(row.status, 'posted');
      expect(row.createdAt, row.occurredAt);
      expect(row.amountUnits?.units, 100);
      expect(row.description, 'استلام');
    });

    test('an offset timestamp is the same instant as UTC', () {
      final row = FinancialLedgerEntryDto.fromJson({
        'id': '2',
        'sectionKey': 'treasury',
        'sourceStatus': 'draft',
        'occurredAt': '2026-10-23T00:33:25.523+02:00',
      });

      expect(row.sectionKey, FinancialLedgerSectionKey.treasury);
      expect(row.sourceStatus, FinancialLedgerSourceStatus.draft);
      expect(row.occurredAt, DateTime.utc(2026, 10, 22, 22, 33, 25, 523));
      expect(row.occurredAt!.isUtc, isTrue);
    });

    test('absent fields stay null and do not throw', () {
      final row = FinancialLedgerEntryDto.fromJson({
        'id': '1',
        'currency': 'EGP',
        'description': 'قديم',
        'section': 'customers',
        'status': 'posted',
        'createdAt': '2026-10-18T09:00:00+02:00',
      });

      expect(row.sectionKey, isNull);
      expect(row.sectionKeyRaw, isNull);
      expect(row.sourceStatus, isNull);
      expect(row.sourceStatusRaw, isNull);
      expect(row.occurredAt, isNull);
      expect(row.section, 'customers');
      expect(row.status, 'posted');
      expect(row.createdAt, DateTime.utc(2026, 10, 18, 7));
      expect(row.currency, Currency.egp);
    });

    test('unknown and non-string values do not throw', () {
      final unknown = FinancialLedgerEntryDto.fromJson({
        'id': 3,
        'sectionKey': 'masraweya',
        'sourceStatus': 'finalized',
        'occurredAt': 'not-a-date',
        'amountUnits': 80,
      });
      expect(unknown.sectionKey, FinancialLedgerSectionKey.unknown);
      expect(unknown.sectionKeyRaw, 'masraweya');
      expect(unknown.sourceStatus, FinancialLedgerSourceStatus.unknown);
      expect(unknown.sourceStatusRaw, 'finalized');
      expect(unknown.occurredAt, isNull);
      expect(unknown.createdAt, isNull);
      expect(unknown.amountUnits?.units, 80);
      expect(unknown.section, 'masraweya');
      expect(unknown.status, 'finalized');

      final typed = FinancialLedgerEntryDto.fromJson({
        'id': 4,
        'sectionKey': 7,
        'sourceStatus': true,
        'occurredAt': true,
        'section': 'customers',
        'createdAt': '2026-10-18T09:00:00Z',
      });
      expect(typed.sectionKey, FinancialLedgerSectionKey.unknown);
      expect(typed.sectionKeyRaw, isNull);
      expect(typed.sourceStatus, FinancialLedgerSourceStatus.unknown);
      expect(typed.sourceStatusRaw, isNull);
      expect(typed.occurredAt, isNull);
      expect(typed.section, 'customers');
      expect(typed.createdAt, DateTime.utc(2026, 10, 18, 9));
    });

    test('a bad amount marks that field and keeps the new fields', () {
      final lines = _beginLog();
      final row = runWithMoneyEndpoint(
        '/api/financial-ledger',
        () => FinancialLedgerEntryDto.fromJson(
          PreciseJson.decode(
            '{"id":"9","sectionKey":"purchases","sourceStatus":"draft",'
            '"occurredAt":"2026-10-22T22:33:25.399Z","amountUnits":10.005,'
            '"description":"مشتريات تجريبية"}',
          ) as Map<String, dynamic>,
        ),
      );

      expect(row.amountUnits, const MoneyValue.invalid());
      expect(row.amountUnits?.units, isNull);
      expect(row.sectionKey, FinancialLedgerSectionKey.purchases);
      expect(row.sourceStatus, FinancialLedgerSourceStatus.draft);
      expect(row.occurredAt, DateTime.utc(2026, 10, 22, 22, 33, 25, 399));
      expect(row.description, 'مشتريات تجريبية');
      expect(
        lines.single,
        '[api] invalid_money endpoint=/api/financial-ledger field=amountUnits row=9',
      );
      expect(lines.single.contains('10.005'), isFalse);
      expect(lines.single.contains('مشتريات'), isFalse);
    });
  });

  group('reports current, daily, and summary', () {
    test('a contract payload fills current, daily, and summary', () {
      final reports = ReportsDto.fromData({
        'current': _report(summary: 'هذا اليوم', payments: 100),
        'items': [
          _report(summary: 'صف', payments: 40),
        ],
        'methodology': {
          'formula': 'المعادلة',
          'note': 'ملاحظة',
          'currency': 'LYD',
        },
      });

      expect(reports.current, isNotNull);
      expect(reports.current!.summary, 'هذا اليوم');
      expect(reports.current!.businessDate, '2026-10-23');
      expect(reports.current!.dayStatus, ReportStatus.normal);
      expect(reports.current!.status, 'normal');
      expect(reports.current!.daily!.receivablesAddedUnits?.units, 3650);
      expect(reports.current!.daily!.paymentsUnits?.units, 100);
      expect(reports.current!.daily!.liabilitiesEffectUnits?.units, 380);
      expect(reports.current!.daily!.cashInUnits?.units, 500);
      expect(reports.current!.daily!.cashOutUnits?.units, 0);
      expect(reports.current!.netUnits?.units, 5160);
      expect(reports.current!.egyptianRate?.value, '10');
      expect(reports.current!.fiveAmClosing!.state, FiveAmClosingState.pending);
      expect(reports.current!.fiveAmClosing!.netUnits, isNull);
      expect(reports.rows.single.summary, 'صف');
      expect(reports.rows.single.daily!.paymentsUnits?.units, 40);
      expect(reports.rows.single.reasons.single.key, 'opening');
      expect(reports.rows.single.reasons.single.label, 'افتتاح');
      expect(reports.formula, 'المعادلة');
      expect(reports.methodologyNote, 'ملاحظة');
    });

    test('egyptianRate is null or a decimal number', () {
      final absent = DailyReportRowDto.fromJson({
        'sequence': 1,
        'egyptianRate': null,
      });
      expect(absent.egyptianRate, isNull);

      final decimal = DailyReportRowDto.fromJson(
        Map<String, dynamic>.from(
          PreciseJson.decode('{"sequence":1,"egyptianRate":10.5}') as Map,
        ),
      );
      expect(decimal.egyptianRate?.value, '10.5');
    });

    test('absent current, daily, and summary stay null', () {
      final reports = ReportsDto.fromData({
        'current': null,
        'items': [
          {
            'sequence': 2,
            'date': '2026-10-17',
            'status': 'needs_review',
            'netUnits': 2,
            'netChangeUnits': 1200,
          },
        ],
      });

      expect(reports.current, isNull);
      final row = reports.rows.single;
      expect(row.daily, isNull);
      expect(row.summary, isNull);
      expect(row.fiveAmClosing, isNull);
      expect(row.dayStatus, ReportStatus.unknown);
      expect(row.status, 'needs_review');
      expect(row.netUnits?.units, 2);
      expect(row.netChangeUnits?.units, 1200);
      expect(row.date, '2026-10-17');
    });

    test('one invalid daily amount marks that field only', () {
      final lines = _beginLog();
      final reports = runWithMoneyEndpoint(
        '/api/reports',
        () => ReportsDto.fromData(
          PreciseJson.decode('''
            {
              "current": {
                "sequence": 1,
                "businessDate": "2026-10-23",
                "summary": "سليم",
                "netUnits": 5160,
                "egyptianRate": 10.5,
                "status": "later",
                "daily": {
                  "receivablesAddedUnits": 3650,
                  "paymentsUnits": 10.005,
                  "liabilitiesEffectUnits": 380,
                  "cashInUnits": "500",
                  "cashOutUnits": 0
                },
                "fiveAmClosing": {
                  "state": "later",
                  "netUnits": 1
                }
              },
              "items": [
                {
                  "sequence": 1,
                  "businessDate": "2026-10-23",
                  "summary": 12,
                  "netUnits": 5160,
                  "daily": {
                    "receivablesAddedUnits": 1,
                    "paymentsUnits": 2,
                    "liabilitiesEffectUnits": 3,
                    "cashInUnits": 4,
                    "cashOutUnits": 5
                  }
                }
              ]
            }
          '''),
        ),
      );

      final current = reports.current!;
      expect(current.summary, 'سليم');
      expect(current.netUnits?.units, 5160);
      expect(current.egyptianRate?.value, '10.5');
      expect(current.dayStatus, ReportStatus.unknown);
      expect(current.status, 'later');
      expect(current.daily!.receivablesAddedUnits?.units, 3650);
      expect(current.daily!.paymentsUnits, const MoneyValue.invalid());
      expect(current.daily!.paymentsUnits?.units, isNull);
      expect(current.daily!.liabilitiesEffectUnits?.units, 380);
      expect(current.daily!.cashInUnits, const MoneyValue.invalid());
      expect(current.daily!.cashOutUnits?.units, 0);
      expect(current.fiveAmClosing!.state, FiveAmClosingState.unknown);
      expect(current.fiveAmClosing!.stateRaw, 'later');
      expect(current.fiveAmClosing!.netUnits?.units, 1);
      expect(reports.rows.single.summary, isNull);
      expect(reports.rows.single.daily!.paymentsUnits?.units, 2);
      expect(reports.rows.single.netUnits?.units, 5160);
      expect(
        lines.any((line) => line.contains('field=daily.paymentsUnits')),
        isTrue,
      );
      expect(
        lines.any((line) => line.contains('field=daily.cashInUnits')),
        isTrue,
      );
      expect(lines.any((line) => line.contains('field=netUnits')), isFalse);
      final text = lines.join('\n');
      expect(text.contains('10.005'), isFalse);
      expect(text.contains('5160'), isFalse);
      expect(text.contains('سليم'), isFalse);
    });

    test('a daily or current value that is not an object fails the response',
        () {
      expect(
        () => ReportsDto.fromData({
          'current': 'today',
          'items': [
            {'sequence': 1, 'netUnits': 1},
          ],
        }),
        throwsA(isA<InvalidServerResponseException>()),
      );
      expect(
        () => ReportsDto.fromData({
          'items': [
            {
              'sequence': 1,
              'daily': ['3650'],
              'netUnits': 1,
            },
          ],
        }),
        throwsA(isA<InvalidServerResponseException>()),
      );
    });
  });

  group('financial ledger section filter', () {
    test('the fake filters by the contract section query', () async {
      final api = ApiLayer.create(
        config:
            const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
        fakeLatency: Duration.zero,
      );
      addTearDown(api.dispose);
      await api.session.login(username: 'admin.demo', password: 'x');
      final fake = api.client as FakeApiClient;

      final all = await api.reports.financialLedger();
      expect(
        all.page.items.map((row) => row.sectionKey),
        [
          FinancialLedgerSectionKey.customerDebts,
          FinancialLedgerSectionKey.treasury,
          FinancialLedgerSectionKey.purchases,
          FinancialLedgerSectionKey.egyptianDeposits,
        ],
      );
      expect(all.pageTotals['LYD']?.units, 480);
      expect(all.pageTotals['EGP']?.units, 10000);
      expect(all.page.items.first.occurredAt,
          DateTime.utc(2026, 10, 22, 22, 33, 25, 523));
      expect(
        all.page.items[1].occurredAt,
        DateTime.utc(2026, 10, 22, 22, 33, 25, 469),
      );
      expect(all.page.items[2].sourceStatus, FinancialLedgerSourceStatus.draft);

      final customers = await api.reports.financialLedger(
        sectionKey: FinancialLedgerSectionKey.customerDebts,
      );
      expect(customers.page.items, hasLength(1));
      expect(customers.page.items.single.sectionKey,
          FinancialLedgerSectionKey.customerDebts);
      expect(customers.pageTotals['LYD']?.units, -100);
      expect(customers.pageTotals.containsKey('EGP'), isFalse);

      final treasury = await api.reports.financialLedger(section: 'treasury');
      expect(treasury.page.items.single.sectionKey,
          FinancialLedgerSectionKey.treasury);

      final preferred = await api.reports.financialLedger(
        sectionKey: FinancialLedgerSectionKey.purchases,
        section: 'treasury',
      );
      expect(preferred.page.items.single.sectionKey,
          FinancialLedgerSectionKey.purchases);

      final none = await api.reports.financialLedger(section: 'no_such');
      expect(none.page.items, isEmpty);
      expect(none.pageTotals, isEmpty);

      expect(
        fake.financialLedgerQueries.map((query) => query.section),
        [
          null,
          'customer_debts',
          'treasury',
          'purchases',
          'no_such',
        ],
      );
      expect(
        fake.financialLedgerQueries.map((query) => query.sectionKey),
        everyElement(isNull),
      );
    });
  });
}

Map<String, Object?> _report({required String summary, required int payments}) {
  return {
    'sequence': 1,
    'businessDate': '2026-10-23',
    'receivablesUnits': 3550,
    'liabilitiesUnits': 380,
    'activeCashUnits': 500,
    'egyptianSourceUnits': 14900,
    'egyptianConvertedUnits': 1490,
    'egyptianRate': 10,
    'netUnits': 5160,
    'daily': {
      'receivablesAddedUnits': 3650,
      'paymentsUnits': payments,
      'liabilitiesEffectUnits': 380,
      'cashInUnits': 500,
      'cashOutUnits': 0,
    },
    'status': 'normal',
    'summary': summary,
    'reasons': [
      {'key': 'opening', 'label': 'افتتاح', 'changeUnits': null},
    ],
    'version': 1,
    'generatedAt': '2026-10-22T22:33:25.958Z',
    'updatedAt': '2026-10-22T22:33:25.958Z',
    'isFinalized': false,
    'finalizedAt': null,
    'fiveAmClosing': {
      'state': 'pending',
      'scheduledAt': '2026-10-24T03:00:00.000Z',
      'capturedAt': null,
      'netUnits': null,
    },
  };
}

List<String> _beginLog() {
  final lines = <String>[];
  SafeLog.sink = (message, {wrapWidth}) {
    if (message != null) lines.add(message);
  };
  addTearDown(() => SafeLog.sink = null);
  return lines;
}
