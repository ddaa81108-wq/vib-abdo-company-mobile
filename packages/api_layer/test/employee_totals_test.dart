import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';
import 'package:flutter_api_layer/core/network/precise_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ApiLayer> login(
    String username, {
    EmployeeTotalsSource source = EmployeeTotalsSource.standalone,
  }) async {
    final api = ApiLayer.create(
      config: ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
        employeeTotalsSource: source,
      ),
      fakeLatency: Duration.zero,
    );
    await api.session.login(username: username, password: 'x');
    return api;
  }

  test('admin standalone returns canned server fields', () async {
    final api = await login('admin.demo');
    addTearDown(api.dispose);
    expect(api.permissions.canViewEmployeeTotals, isTrue);

    final report = await api.employeeTotals.fetch();
    expect(report.generatedAt, '2026-10-18T18:00:00+02:00');
    expect(report.from, isNull);
    expect(report.to, isNull);
    expect(report.version, 1);
    expect(report.currency, Currency.lyd);
    expect(report.items, hasLength(1));
    final row = report.items.single;
    expect(row.employeeId, 'u_12');
    expect(row.employeeName, 'موظف استلام تجريبي');
    expect(row.collectedUnits, 0);
    expect(row.pendingUnits, 100);
    expect(row.approvedCount, 0);
    expect(row.rejectedCount, 0);
    expect(row.pendingCount, 1);
    expect(row.cashOutstandingUnits, 250);
    expect(row.currency, Currency.lyd);
    expect(report.totals.collectedUnits, 0);
    expect(report.totals.pendingUnits, 100);
  });

  test(
    'from and to are echoed and an outside window is a canned empty range',
    () async {
      final api = await login('admin.demo');
      addTearDown(api.dispose);

      final inside = await api.employeeTotals.fetch(
        from: '2026-10-01',
        to: '2026-10-18',
      );
      expect(inside.from, '2026-10-01');
      expect(inside.to, '2026-10-18');
      expect(inside.items.single.employeeId, 'u_12');
      expect(inside.totals.pendingUnits, 100);

      final outside = await api.employeeTotals.fetch(
        from: '2026-10-19',
        to: '2026-10-20',
      );
      expect(outside.from, '2026-10-19');
      expect(outside.to, '2026-10-20');
      expect(outside.items, isEmpty);
      expect(outside.totals.collectedUnits, 0);
      expect(outside.totals.pendingUnits, 0);
    },
  );

  test('employeeId is not a filter on the admin payload', () async {
    final api = await login('admin.demo');
    addTearDown(api.dispose);
    final report = EmployeeTotalsDto.fromStandalone(
      (await api.client.get(
        ApiEndpoints.employeeTotals,
        query: const {'employeeId': 'u_99'},
      )).data,
    );
    expect(report.items.single.employeeId, 'u_12');
  });

  test(
    'collections source reads employeeTotals and ignores the date window',
    () async {
      final api = await login(
        'admin.demo',
        source: EmployeeTotalsSource.collections,
      );
      addTearDown(api.dispose);
      final report = await api.employeeTotals.fetch(
        from: '2026-01-01',
        to: '2026-01-02',
      );
      expect(report.items, hasLength(1));
      expect(report.items.single.employeeName, 'موظف استلام تجريبي');
      expect(report.items.single.employeeId, isNull);
      expect(report.items.single.collectedUnits, 0);
      expect(report.items.single.pendingUnits, isNull);
      expect(report.items.single.approvedCount, 0);
      expect(report.items.single.pendingCount, 1);
      expect(report.items.single.cashOutstandingUnits, isNull);
      expect(report.items.single.currency, Currency.lyd);
      expect(report.from, isNull);
      expect(report.to, isNull);
      expect(report.version, 1);
      expect(report.currency, Currency.lyd);
      expect(report.totals.collectedUnits, isNull);
      expect(report.totals.pendingUnits, isNull);
    },
  );

  test(
    'collections source leaves omitted fields null, not zero',
    () async {
      final api = await login(
        'admin.demo',
        source: EmployeeTotalsSource.collections,
      );
      addTearDown(api.dispose);
      final report = await api.employeeTotals.fetch(
        from: '2026-10-01',
        to: '2026-10-18',
      );
      final row = report.items.single;
      const money = MoneyFormatter();

      // 🔶 Not provided by this source. Null, not a fabricated 0, so the UI
      // shows '—' rather than a zero amount or an invented id/date.
      expect(row.employeeId, isNull);
      expect(row.employeeId, isNot(0));
      expect(row.pendingUnits, isNull);
      expect(row.pendingUnits, isNot(0));
      expect(report.from, isNull);
      expect(report.from, isNot(0));
      expect(report.to, isNull);
      expect(report.to, isNot(0));
      expect(money.formatOrDash(row.pendingUnits, row.currency), '—');
      expect(money.formatOrDash(0, row.currency), isNot('—'));

      // A zero the collections row actually sends stays zero.
      expect(row.collectedUnits, 0);
      expect(money.formatOrDash(row.collectedUnits, row.currency), isNot('—'));
    },
  );

  test(
    'DTO round-trip keeps server totals that are not the sum of the rows',
    () {
      final original = EmployeeTotalsDto.fromStandalone({
        'generatedAt': '2026-10-18T18:00:00+02:00',
        'from': '2026-10-01',
        'to': '2026-10-18',
        'version': 4,
        'currency': 'LYD',
        'items': [
          {
            'employeeId': 'u_12',
            'displayName': 'ignored when employeeName is set',
            'employeeName': 'موظف استلام تجريبي',
            'collectedUnits': 5,
            'pendingUnits': 7,
            'approvedCount': 1,
            'rejectedCount': 2,
            'pendingCount': 3,
            'cashOutstandingUnits': 9,
          },
        ],
        'totals': {'collectedUnits': 40, 'pendingUnits': 2},
      });
      final again = EmployeeTotalsDto.fromJson(original.toJson());
      expect(again.generatedAt, original.generatedAt);
      expect(again.from, '2026-10-01');
      expect(again.to, '2026-10-18');
      expect(again.version, 4);
      expect(again.currency, Currency.lyd);
      expect(again.items.single.employeeName, 'موظف استلام تجريبي');
      expect(again.items.single.collectedUnits, 5);
      expect(again.items.single.pendingUnits, 7);
      expect(again.items.single.cashOutstandingUnits, 9);
      expect(again.items.single.currency, Currency.lyd);
      expect(again.totals.collectedUnits, 40);
      expect(again.totals.pendingUnits, 2);
    },
  );

  test('displayName fills employeeName and currency defaults to LYD', () {
    final row = EmployeeTotalsItemDto.fromJson({
      'displayName': 'موظف استلام تجريبي',
      'collectedUnits': 0,
    });
    expect(row.employeeName, 'موظف استلام تجريبي');
    expect(row.currency, Currency.lyd);

    final egp = EmployeeTotalsItemDto.fromJson({
      'employeeName': 'موظف',
      'currency': 'EGP',
      'collectedUnits': 1,
    });
    expect(egp.currency, Currency.egp);

    final overview = EmployeeTotalsDto.fromCollectionsOverview({
      'employeeTotals': [
        {
          'displayName': 'موظف استلام تجريبي',
          'collectedUnits': 0,
          'cashOutstandingUnits': 250,
          'currency': 'LYD',
        },
      ],
      'metrics': {
        'collectedUnits': 999,
        'cashOutstandingUnits': 1,
        'dayTotalUnits': 100,
      },
    });
    expect(overview.items.single.employeeName, 'موظف استلام تجريبي');
    expect(overview.items.single.cashOutstandingUnits, 250);
    expect(overview.totals.collectedUnits, isNull);
    expect(overview.totals.pendingUnits, isNull);
  });

  test('non-integer money is INVALID_SERVER_RESPONSE', () {
    final fractional = (PreciseJson.decode('{"collectedUnits":1.5}') as Map)
        .cast<String, dynamic>();
    expect(
      () => EmployeeTotalsItemDto.fromJson(fractional),
      throwsA(
        isA<InvalidServerResponseException>().having(
          (error) => error.code,
          'code',
          'INVALID_SERVER_RESPONSE',
        ),
      ),
    );
    for (final bad in <Object?>['250', 10.0, true]) {
      expect(
        () => EmployeeTotalsItemDto.fromJson({'cashOutstandingUnits': bad}),
        throwsA(isA<InvalidServerResponseException>()),
        reason: '$bad',
      );
      expect(
        () => EmployeeTotalsSummaryDto.fromJson({'pendingUnits': bad}),
        throwsA(isA<InvalidServerResponseException>()),
        reason: 'totals $bad',
      );
    }
  });
}
