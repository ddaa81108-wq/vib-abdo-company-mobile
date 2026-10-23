@Tags(['permissions-negative'])
library;

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_client.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_api_layer/data/fake/fake_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an employee is refused every admin and management route', () async {
    final employee = FakeApiClient(latency: Duration.zero);
    await _login(employee, 'employee.demo');

    for (final call in _forbidden) {
      await expectLater(
        _send(employee, call),
        throwsA(_forbiddenMatcher(call.message, code: call.code)),
        reason: '${call.method} ${call.path}',
      );
    }
  });

  test('own data is scoped and another employee id is not found', () async {
    final employee = FakeApiClient(latency: Duration.zero);
    await _login(employee, 'employee.demo');

    final overview = await employee.get('/api/collections');
    final collections = overview.data as Map;
    expect(_ids(collections['employeeTotals']), [FakeFixtures.demoEmployeeId]);
    expect(_ids(collections['assignments'], field: 'assigneeUserId'), [
      FakeFixtures.demoEmployeeId,
    ]);
    expect(_ids(collections['submissions'], field: 'submittedByUserId'), [
      FakeFixtures.demoEmployeeId,
      FakeFixtures.demoEmployeeId,
    ]);
    expect(_ids(collections['unlinkedReceipts'], field: 'submittedByUserId'), [
      FakeFixtures.demoEmployeeId,
      FakeFixtures.demoEmployeeId,
    ]);
    expect((collections['metrics'] as Map)['dayTotalUnits'], 40);
    expect((collections['metrics'] as Map)['collectedUnits'], 0);
    final names = [
      for (final row in collections['employeeTotals'] as List)
        (row as Map)['employeeName'],
    ];
    expect(names, isNot(contains('موظف آخر تجريبي')));

    final payroll = await employee.get('/api/collections/payroll');
    expect(_ids((payroll.data as Map)['employees']), [
      FakeFixtures.demoEmployeeId,
    ]);

    final notes = await employee.get('/api/notifications');
    expect(_ids((notes.data as Map)['items'], field: 'id'), ['77']);

    final me = await employee.get('/api/me');
    expect((me.data as Map)['user']['id'], FakeFixtures.demoEmployeeId);

    await expectLater(
      employee.get('/api/customers/c_55/ledger'),
      throwsA(_forbiddenMatcher(deniedMessage)),
    );

    for (final call in _notFound) {
      await expectLater(
        _send(employee, call),
        throwsA(_notFoundMatcher),
        reason: '${call.method} ${call.path}',
      );
    }
  });

  test('a stored requestId does not bypass a later forbidden call', () async {
    final employee = FakeApiClient(latency: Duration.zero);
    await _login(employee, 'employee.demo');
    const requestId = 'replay-across-routes';

    final allowed = await employee.post(
      '/api/collections/unlinked-receipts',
      body: {
        'requestId': requestId,
        'customerName': 'عميل',
        'amountUnits': 50,
      },
    );
    expect(allowed.statusCode, 200);

    await expectLater(
      employee.post(
        '/api/collections/submissions/sb_1/decision',
        body: {
          'requestId': requestId,
          'expectedVersion': 1,
          'decision': 'approve',
        },
      ),
      throwsA(_forbiddenMatcher(adminOnlyMessage)),
    );
    final overview = await employee.get('/api/collections');
    final pending = (overview.data as Map)['submissions'] as List;
    final submission = pending.cast<Map>().firstWhere(
          (row) => row['id'] == 'sb_1',
        );
    expect(submission['status'], 'pending');
    expect(employee.mutationRequestIds, [requestId]);

    await expectLater(
      employee.post(
        '/api/collections/submissions/sb_1/decision',
        body: {
          'requestId': 'decide-again',
          'expectedVersion': 1,
          'decision': 'reject',
        },
      ),
      throwsA(_forbiddenMatcher(adminOnlyMessage)),
    );
    await expectLater(
      employee.post(
        '/api/collections/submissions/sb_1/decision',
        body: {
          'requestId': 'decide-again',
          'expectedVersion': 1,
          'decision': 'approve',
        },
      ),
      throwsA(_forbiddenMatcher(adminOnlyMessage)),
    );
  });

  test('a missing session is 401 and limited admin still has decide', () async {
    final signedOut = FakeApiClient(latency: Duration.zero);
    await expectLater(
      signedOut.get('/api/collections'),
      throwsA(_unauthenticated),
    );
    await expectLater(
      signedOut.post(
        '/api/collections/submissions/sb_1/decision',
        body: {
          'requestId': 'no-session',
          'expectedVersion': 1,
          'decision': 'approve',
        },
      ),
      throwsA(_unauthenticated),
    );

    final limited = FakeApiClient(latency: Duration.zero);
    await _login(limited, 'limited.admin.demo');
    final decision = await limited.post(
      '/api/collections/submissions/sb_1/decision',
      body: {
        'requestId': 'limited-still-decides',
        'expectedVersion': 1,
        'decision': 'approve',
      },
    );
    expect(decision.statusCode, 200);

    final admin = FakeApiClient(latency: Duration.zero);
    await _login(admin, 'admin.demo');
    final audit = await admin.get('/api/audit');
    expect(audit.statusCode, 200);
    expect((audit.data as Map)['items'], isNotEmpty);
    final payroll = await admin.get('/api/collections/payroll');
    expect(
        _ids((payroll.data as Map)['employees']),
        containsAll([
          FakeFixtures.demoEmployeeId,
          FakeFixtures.otherEmployeeId,
        ]));
  });
}

final _unauthenticated = isA<SessionExpiredException>()
    .having((error) => error.statusCode, 'status', 401)
    .having((error) => error.code, 'code', 'AUTH_REQUIRED');

final _notFoundMatcher = isA<NotFoundException>()
    .having((error) => error.statusCode, 'status', 404)
    .having((error) => error.code, 'code', 'NOT_FOUND');

Matcher _forbiddenMatcher(String message, {String code = 'FORBIDDEN'}) =>
    isA<ForbiddenException>()
        .having((error) => error.statusCode, 'status', 403)
        .having((error) => error.code, 'code', code)
        .having((error) => error.message, 'message', message);

class _Call {
  const _Call(
    this.method,
    this.path, {
    this.body,
    this.query,
    this.message = adminOnlyMessage,
    this.code = 'FORBIDDEN',
  });

  final String method;
  final String path;
  final Map<String, Object?>? body;
  final Map<String, dynamic>? query;
  final String message;
  final String code;
}

const adminOnlyMessage = 'هذا الإجراء للإدارة فقط';
const deniedMessage = 'لا تملك صلاحية لهذا الإجراء';

Map<String, Object?> _mutation(String id, {int? version, String? decision}) => {
      'requestId': id,
      if (version != null) 'expectedVersion': version,
      if (decision != null) 'decision': decision,
    };

final _forbidden = <_Call>[
  // Section reads the ordinary employee cannot open.
  const _Call('GET', '/api/companies', message: deniedMessage),
  const _Call('GET', '/api/companies/suggestions', message: deniedMessage),
  const _Call('GET', '/api/companies/c_co_02', message: deniedMessage),
  const _Call('GET', '/api/companies/c_co_02/ledger', message: deniedMessage),
  const _Call('GET', '/api/libyan-deposits', message: deniedMessage),
  const _Call('GET', '/api/egyptian-deposits', message: deniedMessage),
  const _Call(
    'GET',
    '/api/egyptian-deposits/exchange-rate',
    message: deniedMessage,
  ),
  const _Call('GET', '/api/masraweya/day', message: deniedMessage),
  const _Call('GET', '/api/purchases/al_bayan', message: deniedMessage),
  const _Call('GET', '/api/treasury', message: deniedMessage),
  const _Call('GET', '/api/treasury/cash-ledger', message: deniedMessage),
  const _Call('GET', '/api/reports', message: deniedMessage),
  const _Call(
    'GET',
    '/api/financial-ledger',
    message: adminOnlyMessage,
    code: 'PERMISSION_DENIED',
  ),
  const _Call('GET', '/api/statements/pdf', message: adminOnlyMessage),
  // Section writes and movement cancels the employee cannot perform.
  _Call(
    'POST',
    '/api/customers/c_55/transactions',
    body: _mutation('tx', version: 4),
    message: deniedMessage,
  ),
  _Call(
    'POST',
    '/api/customers/c_55/transactions/tx_1/cancel',
    body: _mutation('cancel', version: 1),
    message: deniedMessage,
  ),
  _Call(
    'POST',
    '/api/customers/c_55/transactions/tx_1/corrections',
    body: _mutation('correct', version: 1),
    message: deniedMessage,
  ),
  _Call(
    'POST',
    '/api/customers/c_55/pin',
    body: _mutation('pin', version: 4),
    message: deniedMessage,
  ),
  _Call(
    'POST',
    '/api/customers/c_55/zero-review',
    body: _mutation('zero', version: 4),
    message: adminOnlyMessage,
  ),
  _Call(
    'PUT',
    '/api/masraweya/day',
    body: _mutation('mas', version: 2),
    message: deniedMessage,
  ),
  _Call(
    'POST',
    '/api/purchases/al_bayan',
    body: _mutation('purchase'),
    message: deniedMessage,
  ),
  _Call(
    'POST',
    '/api/purchases/al_bayan/finalize',
    body: {..._mutation('finalize'), 'expectedDayVersion': 3},
    message: deniedMessage,
  ),
  _Call(
    'PATCH',
    '/api/purchases/al_bayan/days/12/correction',
    body: {..._mutation('correction'), 'expectedDayVersion': 3},
    message: deniedMessage,
  ),
  _Call(
    'PATCH',
    '/api/purchases/al_bayan/opening',
    body: {..._mutation('opening'), 'expectedDayVersion': 3},
    message: deniedMessage,
  ),
  _Call(
    'POST',
    '/api/treasury/cash-entries',
    body: _mutation('cash', version: 7),
    message: deniedMessage,
  ),
  _Call('POST', '/api/reports',
      body: _mutation('report'), message: deniedMessage),
  // Approve, reject, confirm, and other management routes.
  _Call('POST', '/api/collections/assignments', body: _mutation('assign')),
  _Call(
    'POST',
    '/api/collections/submissions/sb_1/decision',
    body: _mutation('decide', version: 1, decision: 'approve'),
  ),
  _Call(
    'POST',
    '/api/collections/submissions/sb_1/decision',
    body: _mutation('reject', version: 1, decision: 'reject'),
  ),
  _Call(
    'POST',
    '/api/collections/submissions/sb_2/cash-received',
    body: _mutation('cash-in', version: 3),
  ),
  _Call(
    'POST',
    '/api/collections/unlinked-receipts/ur_1/decision',
    body: _mutation('ulink', version: 1, decision: 'approve'),
  ),
  _Call(
    'POST',
    '/api/collections/unlinked-receipts/ur_2/cash-received',
    body: _mutation('ucash', version: 4),
  ),
  _Call('POST', '/api/collections/days/close',
      body: _mutation('close', version: 1)),
  _Call('POST', '/api/collections/payroll/entries',
      body: _mutation('payroll-entry')),
  _Call(
    'PUT',
    '/api/collections/payroll/employees/${FakeFixtures.demoEmployeeId}/salary',
    body: {..._mutation('own-salary'), 'baseSalaryUnits': 1500},
  ),
  _Call(
    'POST',
    '/api/collections/payroll/entries/pe_1/confirm',
    body: _mutation('confirm'),
  ),
  const _Call('GET', '/api/collections/assignees'),
  const _Call('GET', '/api/collections/assignments'),
  const _Call('GET', '/api/collections/link-candidates'),
  const _Call('GET', '/api/account-requests'),
  _Call('POST', '/api/account-requests', body: _mutation('account-request')),
  _Call(
    'POST',
    '/api/account-requests/ar_1/decision',
    body: _mutation('account-decision', decision: 'approve'),
  ),
  // 🔶 Proposed admin catalogs.
  const _Call('GET', '/api/settings'),
  const _Call('GET', '/api/users'),
  const _Call('GET', '/api/staff'),
  const _Call('GET', '/api/employees'),
  const _Call('GET', '/api/admins'),
  const _Call('GET', '/api/audit'),
  const _Call('GET', '/api/operations'),
  const _Call('GET', '/api/users/${FakeFixtures.demoEmployeeId}'),
  const _Call(
    'GET',
    '/api/notifications',
    query: {'employeeId': FakeFixtures.demoEmployeeId},
  ),
  const _Call(
    'GET',
    '/api/collections',
    query: {'userId': FakeFixtures.demoEmployeeId},
  ),
  const _Call(
    'GET',
    '/api/me',
    query: {'employeeId': FakeFixtures.demoEmployeeId},
  ),
];

final _notFound = <_Call>[
  const _Call(
    'GET',
    '/api/collections/payroll/employees/${FakeFixtures.otherEmployeeId}/salary',
  ),
  _Call(
    'PUT',
    '/api/collections/payroll/employees/${FakeFixtures.otherEmployeeId}/salary',
    body: {..._mutation('other-salary'), 'baseSalaryUnits': 2400},
  ),
  const _Call('GET', '/api/users/${FakeFixtures.otherEmployeeId}'),
  const _Call('GET', '/api/staff/${FakeFixtures.otherEmployeeId}'),
  const _Call(
    'GET',
    '/api/notifications',
    query: {'userId': FakeFixtures.otherEmployeeId},
  ),
  const _Call(
    'GET',
    '/api/collections',
    query: {'employeeId': FakeFixtures.otherEmployeeId},
  ),
  const _Call(
    'GET',
    '/api/customers/c_55/ledger',
    query: {'employeeId': FakeFixtures.otherEmployeeId},
  ),
  const _Call(
    'GET',
    '/api/me',
    query: {'userId': FakeFixtures.otherEmployeeId},
  ),
  const _Call(
    'PATCH',
    '/api/notifications/88/read',
    body: <String, Object?>{},
  ),
];

Future<ApiResponse> _send(FakeApiClient api, _Call call) {
  return switch (call.method) {
    'GET' => api.get(call.path, query: call.query),
    'POST' => api.post(call.path, body: call.body),
    'PUT' => api.put(call.path, body: call.body),
    'PATCH' => api.patch(call.path, body: call.body),
    'DELETE' => api.delete(call.path, body: call.body),
    _ => throw StateError(call.method),
  };
}

List<Object?> _ids(Object? raw, {String field = 'userId'}) => [
      for (final row in raw as List) (row as Map)[field],
    ];

Future<ApiResponse> _login(FakeApiClient api, String username) {
  return api.post(
    '/api/auth/login',
    body: {'username': username, 'password': 'demo-only'},
  );
}
