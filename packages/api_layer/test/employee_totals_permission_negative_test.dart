@Tags(['permissions-negative'])
library;

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
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

  Matcher forbidden() => isA<ForbiddenException>()
      .having((error) => error.statusCode, 'status', 403)
      .having((error) => error.code, 'code', 'FORBIDDEN')
      .having((error) => error.message, 'message', 'هذا الإجراء للإدارة فقط')
      .having((error) => error.correlationId, 'correlationId', 'fake')
      .having(
        (error) => error.details is Map && (error.details as Map).isEmpty,
        'details',
        true,
      );

  test('employee gets 403 FORBIDDEN and not an empty list', () async {
    final api = await login('employee.demo');
    addTearDown(api.dispose);
    expect(api.permissions.canViewEmployeeTotals, isFalse);
    await expectLater(api.employeeTotals.fetch(), throwsA(forbidden()));
    await expectLater(
      api.client.get(ApiEndpoints.employeeTotals),
      throwsA(forbidden()),
    );
  });

  test('employeeId does not grant an employee their own row', () async {
    final api = await login('employee.demo');
    addTearDown(api.dispose);
    await expectLater(
      api.client.get(
        ApiEndpoints.employeeTotals,
        query: const {'employeeId': 'u_12', 'from': '2026-10-01'},
      ),
      throwsA(forbidden()),
    );
  });

  test('limited admin is denied until DEF-002', () async {
    final api = await login('limited.admin.demo');
    addTearDown(api.dispose);
    expect(api.permissions.canViewEmployeeTotals, isFalse);
    expect(api.permissions.canDo(ManagementAction.collectionsDecide), isTrue);
    await expectLater(api.employeeTotals.fetch(), throwsA(forbidden()));
  });

  test('fullAccess false and an unknown role are 403', () async {
    final flagged = await login('flag.admin.demo');
    addTearDown(flagged.dispose);
    expect(flagged.permissions.canViewEmployeeTotals, isFalse);
    await expectLater(flagged.employeeTotals.fetch(), throwsA(forbidden()));

    final guest = await login('guest.demo');
    addTearDown(guest.dispose);
    expect(guest.permissions.canViewEmployeeTotals, isFalse);
    await expectLater(guest.employeeTotals.fetch(), throwsA(forbidden()));
  });

  test('collections source still 403s and does not return the array', () async {
    final api = await login(
      'employee.demo',
      source: EmployeeTotalsSource.collections,
    );
    addTearDown(api.dispose);
    final fake = api.client as FakeApiClient;
    final reads = fake.collectionOverviewReads;
    await expectLater(
      api.employeeTotals.fetch(from: '2026-10-01', to: '2026-10-18'),
      throwsA(forbidden()),
    );
    expect(fake.collectionOverviewReads, reads);
  });

  test('signed out is 401 AUTH_REQUIRED', () async {
    final api = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
      fakeLatency: Duration.zero,
    );
    addTearDown(api.dispose);
    await expectLater(
      api.employeeTotals.fetch(),
      throwsA(
        isA<SessionExpiredException>()
            .having((error) => error.statusCode, 'status', 401)
            .having((error) => error.code, 'code', 'AUTH_REQUIRED')
            .having(
              (error) => error.message,
              'message',
              'يجب تسجيل الدخول أولًا.',
            ),
      ),
    );
    await expectLater(
      api.client.get(ApiEndpoints.employeeTotals),
      throwsA(
        isA<SessionExpiredException>().having(
          (error) => error.statusCode,
          'status',
          401,
        ),
      ),
    );
  });
}
