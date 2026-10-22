@Tags(['permissions-negative'])
library;

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_client.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';
import 'package:flutter_api_layer/data/fake/fake_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

/// HTTP status order on the Fake. This does not close staging P7-04.
/// The fake marks the 401 → 404 → 403 choices 🔶 unconfirmed, so the order
/// test is pending-decision.
void main() {
  test('401 is returned before 404 and 404 before 403', () async {
    final anonymous = _layer();
    await _expectStatus(
      anonymous.client.get(ApiEndpoints.user(FakeFixtures.otherEmployeeId)),
      401,
      SessionExpiredException,
      'AUTH_REQUIRED',
    );
    await _expectStatus(
      anonymous.client.get(ApiEndpoints.treasury),
      401,
      SessionExpiredException,
      'AUTH_REQUIRED',
    );
    await _expectStatus(
      anonymous.client.get(
        ApiEndpoints.accounts('customers'),
        query: {'employeeId': FakeFixtures.otherEmployeeId},
      ),
      401,
      SessionExpiredException,
      'AUTH_REQUIRED',
    );
    await _expectStatus(
      anonymous.client.get('/api/not-a-real-route'),
      401,
      SessionExpiredException,
      'AUTH_REQUIRED',
    );
    await _expectStatus(
      anonymous.client.get('${ApiEndpoints.notifications}/88'),
      401,
      SessionExpiredException,
      'AUTH_REQUIRED',
    );

    final employee = await _signedIn('employee.demo');
    await _expectStatus(
      employee.client.get(ApiEndpoints.user(FakeFixtures.otherEmployeeId)),
      404,
      NotFoundException,
      'NOT_FOUND',
    );
    final directory = await _expectStatus(
      employee.client.get(ApiEndpoints.users),
      403,
      ForbiddenException,
      'FORBIDDEN',
    );
    expect(directory.message, 'هذا الإجراء للإدارة فقط');
    await _expectStatus(
      employee.client.get(ApiEndpoints.user(FakeFixtures.demoEmployeeId)),
      403,
      ForbiddenException,
      'FORBIDDEN',
    );
    await _expectStatus(
      employee.client.get(
        ApiEndpoints.payrollSalary(FakeFixtures.otherEmployeeId),
      ),
      404,
      NotFoundException,
      'NOT_FOUND',
    );
    await _expectStatus(
      employee.client.get(
        ApiEndpoints.payrollSalary(FakeFixtures.demoEmployeeId),
      ),
      403,
      ForbiddenException,
      'FORBIDDEN',
    );
    final treasury = await _expectStatus(
      employee.client.get(ApiEndpoints.treasury),
      403,
      ForbiddenException,
      'FORBIDDEN',
    );
    expect(treasury.message, 'لا تملك صلاحية لهذا الإجراء');
    // 🔶 recipientUserId. An id owned by someone else is 404, including a
    // missing id. Full access does not open another user's row.
    await _expectStatus(
      employee.client.get('${ApiEndpoints.notifications}/88'),
      404,
      NotFoundException,
      'NOT_FOUND',
    );

    final admin = await _signedIn('admin.demo');
    expect((await admin.client.get(ApiEndpoints.treasury)).statusCode, 200);
  }, tags: ['pending-decision']);

  test('guest and flag admin are denied the customers list', () async {
    for (final username in ['guest.demo', 'flag.admin.demo']) {
      final layer = await _signedIn(username);
      final error = await _expectStatus(
        layer.client.get(ApiEndpoints.accounts('customers')),
        403,
        ForbiddenException,
        'FORBIDDEN',
      );
      expect(error.message, 'لا تملك صلاحية لهذا الإجراء');
    }
  });

  test('limited admin employee-totals route is 403', () async {
    // DEF-002 is open. The standalone route stays full-access only. This is
    // not a Pass for the limited manager, and it does not close the decision.
    final layer = await _signedIn('limited.admin.demo');
    final error = await _expectStatus(
      layer.client.get(ApiEndpoints.employeeTotals),
      403,
      ForbiddenException,
      'FORBIDDEN',
    );
    expect(error.message, 'هذا الإجراء للإدارة فقط');
  }, tags: ['pending-decision']);
}

ApiLayer _layer() {
  final layer = ApiLayer.create(
    config: const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
    fakeLatency: Duration.zero,
  );
  addTearDown(layer.dispose);
  return layer;
}

Future<ApiLayer> _signedIn(String username) async {
  final layer = _layer();
  await layer.session.login(username: username, password: 'x');
  return layer;
}

Future<ApiException> _expectStatus(
  Future<ApiResponse> request,
  int status,
  Type type,
  String code,
) async {
  try {
    await request;
    fail('expected $status');
  } on ApiException catch (error) {
    expect(error.runtimeType, type);
    expect(error.statusCode, status);
    expect(error.code, code);
    return error;
  }
}
