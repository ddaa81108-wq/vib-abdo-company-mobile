import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

/// P-08. Real [PermissionService] filled from the fake `/api/me`. The transport
/// is the only stand-in.
void main() {
  const limitedSections = [
    SectionKey.customers,
    SectionKey.collections,
    SectionKey.companies,
    SectionKey.libyanDeposits,
    SectionKey.egyptianDeposits,
    SectionKey.purchases,
    SectionKey.treasury,
    SectionKey.reports,
  ];

  test('limited reader sees the eight read sections and not the ledger',
      () async {
    final api = await _login('limited.reader');
    addTearDown(api.dispose);
    final me = await api.profile.fetchMe();
    expect(me.user.sectionAccess, isNull);
    expect(me.user.role, 'employee');
    expect(me.user.permissions, FakeFixtures.limitedReaderPermissions);
    expect(api.permissions.fullAccess, isFalse);
    expect(api.permissions.visibleSections, limitedSections);
    for (final section in limitedSections) {
      expect(api.permissions.canRead(section), isTrue, reason: section.key);
      expect(api.permissions.canWrite(section), isFalse, reason: section.key);
    }
    expect(api.permissions.canRead(SectionKey.masraweya), isFalse);
    expect(api.permissions.canViewFinancialLedger, isFalse);
    await expectLater(
      api.client.get('/api/financial-ledger'),
      throwsA(
        isA<ForbiddenException>().having(
          (error) => error.statusCode,
          'status',
          403,
        ),
      ),
    );
  });

  test('collector sees collections only; payroll and notices are not sections',
      () async {
    final api = await _login('employee.demo');
    addTearDown(api.dispose);
    final me = await api.profile.fetchMe();
    expect(me.user.sectionAccess, isNull);
    expect(me.user.permissions, FakeFixtures.collectorPermissions);
    expect(api.permissions.visibleSections, [SectionKey.collections]);
    expect(api.permissions.canWrite(SectionKey.collections), isTrue);
    for (final section in SectionKey.values) {
      if (section == SectionKey.collections) continue;
      expect(api.permissions.canRead(section), isFalse, reason: section.key);
    }
    final keys = SectionKey.values.map((section) => section.key);
    expect(keys, isNot(contains('payroll')));
    expect(keys, isNot(contains('notifications')));
    expect(keys, isNot(contains('event-changes')));
    expect((await api.client.get('/api/collections')).statusCode, 200);
    expect((await api.client.get('/api/collections/payroll')).statusCode, 200);
    expect((await api.client.get('/api/notifications')).statusCode, 200);
    expect((await api.client.get('/api/event-changes')).statusCode, 200);
    await expectLater(
      api.client.get('/api/customers'),
      throwsA(
        isA<ForbiddenException>().having(
          (error) => error.statusCode,
          'status',
          403,
        ),
      ),
    );
    await expectLater(
      api.client.get('/api/financial-ledger'),
      throwsA(isA<ForbiddenException>()),
    );
  });

  test('admin with an empty permission list stays unrestricted', () async {
    final api = await _login('admin.demo');
    addTearDown(api.dispose);
    final me = await api.profile.fetchMe();
    expect(me.user.sectionAccess, isNull);
    expect(me.user.permissions, isEmpty);
    final raw = await api.client.get('/api/me');
    expect(((raw.data as Map)['user'] as Map)['isOwner'], isTrue);
    expect(api.permissions.fullAccess, isTrue);
    expect(api.permissions.visibleSections, SectionKey.values);
    expect(api.permissions.canViewFinancialLedger, isTrue);
    expect((await api.client.get('/api/financial-ledger')).statusCode, 200);
    for (final section in SectionKey.values) {
      expect(api.permissions.canRead(section), isTrue, reason: section.key);
      if (section.write != null) {
        expect(api.permissions.canWrite(section), isTrue, reason: section.key);
      }
    }
    expect(api.permissions.canWrite(SectionKey.reports), isFalse);
  });

  test('a present sectionAccess read level still hides write', () async {
    final api = await _login('other.employee');
    addTearDown(api.dispose);
    final me = await api.profile.fetchMe();
    expect(me.user.sectionAccess, isNotNull);
    expect(me.user.sectionAccess!['customerDebts'], 'read');
    expect(api.permissions.canRead(SectionKey.customers), isTrue);
    expect(api.permissions.canWrite(SectionKey.customers), isFalse);
    expect(api.permissions.canRead(SectionKey.companies), isFalse);
  });
}

Future<ApiLayer> _login(String username) async {
  final api = ApiLayer.create(
    config: const ApiConfig(
      baseUrl: 'https://fake.invalid',
      useFakeApi: true,
    ),
    fakeLatency: Duration.zero,
  );
  await api.session.login(username: username, password: 'x');
  return api;
}
