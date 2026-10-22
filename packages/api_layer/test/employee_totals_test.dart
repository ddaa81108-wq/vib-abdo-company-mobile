import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';
import 'package:flutter_api_layer/core/network/precise_json.dart';
import 'package:flutter_api_layer/data/fake/fake_fixtures.dart';
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
    expect(row.collectedUnits?.units, 0);
    expect(row.pendingUnits?.units, 100);
    expect(row.approvedCount, 0);
    expect(row.rejectedCount, 0);
    expect(row.pendingCount, 1);
    expect(row.cashOutstandingUnits?.units, 250);
    expect(row.currency, Currency.lyd);
    expect(report.totals.collectedUnits?.units, 0);
    expect(report.totals.pendingUnits?.units, 100);
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
      expect(inside.totals.pendingUnits?.units, 100);

      final outside = await api.employeeTotals.fetch(
        from: '2026-10-19',
        to: '2026-10-20',
      );
      expect(outside.from, '2026-10-19');
      expect(outside.to, '2026-10-20');
      expect(outside.items, isEmpty);
      expect(outside.totals.collectedUnits?.units, 0);
      expect(outside.totals.pendingUnits?.units, 0);
    },
  );

  test('employeeId is not a filter on the admin payload', () async {
    final api = await login('admin.demo');
    addTearDown(api.dispose);
    final report = EmployeeTotalsDto.fromStandalone(
      (await api.client.get(
        ApiEndpoints.employeeTotals,
        query: const {'employeeId': 'u_99'},
      ))
          .data,
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
      final byId = await _collectionsTotalsByUser(api);
      expect(
        byId.keys,
        containsAll(
            [FakeFixtures.demoEmployeeId, FakeFixtures.otherEmployeeId]),
      );
      final own = _rowForUser(report, byId, FakeFixtures.demoEmployeeId);
      final other = _rowForUser(report, byId, FakeFixtures.otherEmployeeId);
      expect(own.employeeName, 'موظف استلام تجريبي');
      expect(own.employeeId, isNull);
      expect(own.collectedUnits?.units, 0);
      expect(own.pendingUnits, isNull);
      expect(own.approvedCount, 0);
      expect(own.pendingCount, 1);
      expect(own.cashOutstandingUnits, isNull);
      expect(own.currency, Currency.lyd);
      expect(other.employeeName, 'موظف آخر تجريبي');
      expect(other.employeeId, isNull);
      expect(other.collectedUnits?.units, 900);
      expect(other.approvedCount, 4);
      expect(other.pendingCount, 2);
      expect(other.pendingUnits, isNull);
      expect(other.cashOutstandingUnits, isNull);
      expect(other.currency, Currency.lyd);
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
      final byId = await _collectionsTotalsByUser(api);
      final own = _rowForUser(report, byId, FakeFixtures.demoEmployeeId);
      final other = _rowForUser(report, byId, FakeFixtures.otherEmployeeId);
      const money = MoneyFormatter();

      // 🔶 Not provided by this source. Null, not a fabricated 0, so the UI
      // shows '—' rather than a zero amount or an invented id/date.
      // `userId` on the fixture is the scoping id, not `employeeId`.
      for (final row in [own, other]) {
        expect(row.employeeId, isNull);
        expect(row.employeeId, isNot(0));
        expect(row.pendingUnits, isNull);
        expect(row.pendingUnits?.units, isNot(0));
        expect(row.cashOutstandingUnits, isNull);
        expect(money.formatOrDash(row.pendingUnits, row.currency), '—');
      }
      expect(report.from, isNull);
      expect(report.from, isNot(0));
      expect(report.to, isNull);
      expect(report.to, isNot(0));
      expect(money.formatOrDash(0, own.currency), isNot('—'));

      // A zero the collections row actually sends stays zero. The other
      // employee's stored collected amount stays that amount.
      expect(own.collectedUnits?.units, 0);
      expect(other.collectedUnits?.units, 900);
      expect(money.formatOrDash(own.collectedUnits, own.currency), isNot('—'));
      expect(
        money.formatOrDash(other.collectedUnits, other.currency),
        isNot('—'),
      );
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
      expect(again.items.single.collectedUnits?.units, 5);
      expect(again.items.single.pendingUnits?.units, 7);
      expect(again.items.single.cashOutstandingUnits?.units, 9);
      expect(again.items.single.currency, Currency.lyd);
      expect(again.totals.collectedUnits?.units, 40);
      expect(again.totals.pendingUnits?.units, 2);
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
    expect(overview.items.single.cashOutstandingUnits?.units, 250);
    expect(overview.totals.collectedUnits, isNull);
    expect(overview.totals.pendingUnits, isNull);
  });

  test('non-integer money marks the field and keeps the row', () {
    final fractional = (PreciseJson.decode(
      '{"employeeId":"u_12","employeeName":"موظف","collectedUnits":1.5,"pendingUnits":4}',
    ) as Map).cast<String, dynamic>();
    final row = EmployeeTotalsItemDto.fromJson(fractional);
    expect(row.employeeName, 'موظف');
    expect(row.collectedUnits!.isInvalid, isTrue);
    expect(row.collectedUnits?.units, isNot(1));
    expect(row.collectedUnits?.units, isNot(2));
    expect(row.pendingUnits?.units, 4);
    for (final bad in <Object?>['250', 10.0, true]) {
      final item = EmployeeTotalsItemDto.fromJson({
        'employeeId': 'u_12',
        'cashOutstandingUnits': bad,
        'collectedUnits': 3,
      });
      expect(item.cashOutstandingUnits!.isInvalid, isTrue, reason: '$bad');
      expect(item.collectedUnits?.units, 3, reason: '$bad');
      final totals = EmployeeTotalsSummaryDto.fromJson({'pendingUnits': bad});
      expect(totals.pendingUnits!.isInvalid, isTrue, reason: 'totals $bad');
      expect(totals.pendingUnits?.units, isNot(0), reason: 'totals $bad');
    }
  });
}

/// Collections rows keyed by the fixture `userId`. That id is not copied onto
/// [EmployeeTotalsItemDto.employeeId].
Future<Map<String, Map<String, dynamic>>> _collectionsTotalsByUser(
  ApiLayer api,
) async {
  final data = Map<String, dynamic>.from(
    (await api.client.get(ApiEndpoints.collections)).data as Map,
  );
  final rows = <String, Map<String, dynamic>>{};
  for (final raw in data['employeeTotals'] as List) {
    final row = Map<String, dynamic>.from(raw as Map);
    rows['${row['userId']}'] = row;
  }
  return rows;
}

EmployeeTotalsItemDto _rowForUser(
  EmployeeTotalsDto report,
  Map<String, Map<String, dynamic>> byId,
  String userId,
) {
  final name = '${byId[userId]!['employeeName']}';
  return report.items.singleWhere((row) => row.employeeName == name);
}
