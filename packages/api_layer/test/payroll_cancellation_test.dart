import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'website cancellation restores server totals, removes rows and safely replays',
      () async {
    final api = await login('admin.demo');
    final fake = api.client as FakeApiClient;
    final before = await api.collections.payroll();
    expect(before.employees.first.remainingUnits?.asInt, 1250);
    await api.collections.cancelPayrollEntry('pe_1', MutationMeta());
    expect(fake.mutationPaths.last,
        '/api/collections/payroll/entries/pe_1/cancel');
    final afterWithdrawal = await api.collections.payroll();
    expect(afterWithdrawal.employees.first.remainingUnits?.asInt, 1550);
    expect(afterWithdrawal.employees.first.withdrawalsUnits?.asInt, 0);
    expect(afterWithdrawal.employees.first.movements.map((row) => row.id),
        ['pe_2']);
    final replay =
        await api.collections.cancelPayrollEntry('pe_1', MutationMeta());
    expect(replay.replayed, true);
    await api.collections.cancelPayrollEntry('pe_2', MutationMeta());
    final after = await api.collections.payroll();
    expect(after.employees.first.remainingUnits?.asInt, 1500);
    expect(after.employees.first.commissionsUnits?.asInt, 0);
    expect(after.employees.first.movements, isEmpty);
    expect(after.employees.last.remainingUnits?.asInt,
        before.employees.last.remainingUnits?.asInt);
    expect(after.employees.last.movements.map((row) => row.id), ['pe_9']);
  });

  test('employees cannot cancel an own or another employee movement', () async {
    final api = await login('employee.demo');
    for (final id in ['pe_1', 'pe_9']) {
      await expectLater(api.collections.cancelPayrollEntry(id, MutationMeta()),
          throwsA(isA<ForbiddenException>()));
    }
    expect(
        (await api.collections.payroll())
            .employees
            .single
            .remainingUnits
            ?.asInt,
        1250);
  });

  test(
      'cancelled legacy history is hidden without recalculating server balances',
      () {
    final employee = PayrollEmployeeDto.fromJson({
      'employeeId': 'fixture-only',
      'employeeName': 'موظف اختبار',
      'remainingUnits': 777,
      'entries': [
        {'id': 'live', 'kind': 'withdrawal', 'amountUnits': 100},
        {
          'id': 'cancelled',
          'kind': 'commission',
          'amountUnits': 999,
          'cancelledAt': '2026-11-23T00:00:00Z',
          'cancelledByName': 'مدير اختبار'
        },
      ],
    });
    expect(employee.movements.map((entry) => entry.id), ['live']);
    expect(employee.remainingUnits?.asInt, 777);
    expect(PayrollEntryDto.fromJson(employee.entries.last).cancelledByName,
        'مدير اختبار');
  });
}

Future<ApiLayer> login(String name) async {
  final api = ApiLayer.create(
      config:
          const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
      fakeLatency: Duration.zero);
  addTearDown(api.dispose);
  await api.session.login(username: name, password: 'test-only');
  return api;
}
