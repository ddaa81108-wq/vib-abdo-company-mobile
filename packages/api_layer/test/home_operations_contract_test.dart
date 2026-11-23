import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('05:00 uses the recorded snapshot and matching server comparison only',
      () {
    final closing = ReportClosingOverviewDto.fromData({
      'position': {'netUnits': 999999},
      'latestClosing': {
        'state': 'recorded',
        'businessDate': '2026-11-22',
        'netUnits': 321,
      },
      'closings': [
        {'businessDate': '2026-11-21', 'changeUnits': 888},
        {
          'businessDate': '2026-11-22',
          'changeUnits': -17,
          'previousBusinessDate': '2026-11-21'
        },
      ],
    });
    expect(closing.netUnits?.asInt, 321);
    expect(closing.changeUnits?.asInt, -17);
    expect(closing.previousBusinessDate, '2026-11-21');
  });
  test('missing and invalid money never becomes zero or a live balance', () {
    for (final state in ['pending', 'missed', 'missing_rate']) {
      final row = ReportClosingOverviewDto.fromData({
        'position': {'netUnits': 999},
        'latestClosing': {'state': state},
      });
      expect(row.netUnits, isNull);
      expect(row.changeUnits, isNull);
    }
    final invalid = ReportClosingOverviewDto.fromData({
      'latestClosing': {'state': 'recorded', 'netUnits': 'invalid'},
    });
    expect(invalid.netUnits?.asInt, isNull);
    expect(() => ReportClosingOverviewDto.fromData({'latestClosing': []}),
        throwsA(anything));
  });
  test('activity preserves each currency and exact server amount', () {
    for (final currency in ['LYD', 'EGP']) {
      final row = ReportActivityDto.fromJson({
        'id': 5,
        'currency': currency,
        'amountUnits': 123456,
        'description': 'معاملة اختبار',
      });
      expect(row.currency, currency);
      expect(row.amountUnits?.asInt, 123456);
    }
  });
  test('home reports are read-only and report permission is enforced',
      () async {
    final api = ApiLayer.create(
      config:
          const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
      fakeLatency: Duration.zero,
    );
    addTearDown(api.dispose);
    await api.session.login(username: 'admin.demo', password: 'test-only');
    final fake = api.client as FakeApiClient;
    final before = fake.mutationPaths.length;
    expect((await api.reports.closingOverview()).netUnits?.asInt, 162665);
    expect((await api.reports.activity()).length, 2);
    expect(fake.mutationPaths.length, before);
    await api.session.logout();
    await api.session.login(username: 'employee.demo', password: 'test-only');
    await expectLater(
        api.reports.closingOverview(), throwsA(isA<ForbiddenException>()));
    await expectLater(
        api.reports.activity(), throwsA(isA<ForbiddenException>()));
  });
}
