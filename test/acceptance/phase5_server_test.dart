import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 5 server checks against the in-memory Fake API on current main.
///
/// These tests lock behavior the fake client already implements. Routes the
/// fake does not implement, and real token expiry, stay in phase-5.md as
/// "Needs staging" and are not asserted here.
void main() {
  test('P5-11 full admin can read the admin and section endpoints', () async {
    final api = await _signedIn('admin.demo');
    for (final path in _adminReads) {
      final response = await api.client.get(path);
      expect(response.statusCode, 200, reason: path);
    }
    final collections = await api.client.get('/api/collections');
    final totals = collections.dataMap['employeeTotals'] as List;
    expect(totals, isNotEmpty);
    final payroll = await api.collections.payroll();
    expect(payroll.employees.map((e) => e.userId), containsAll(['u_12', 'u_20']));
    expect(payroll.employees, hasLength(2));
  });

  test('P5-14 a logged-out token cannot read or approve', () async {
    final api = await _signedIn('admin.demo');
    await api.session.logout();
    expect(api.session.state, isA<SessionUnauthenticated>());
    expect(api.permissions.role, AccountRole.unknown);

    final me = await _apiOf(() => api.client.get('/api/me'));
    expect(me.statusCode, 401);
    expect(me.code, 'AUTH_REQUIRED');

    final decide = await _apiOf(
      () => api.collections.decide(
        'sb_1',
        CollectionDecision.approve,
        meta: MutationMeta(expectedVersion: 1, requestId: 'p5-14-reuse'),
      ),
    );
    expect(decide.statusCode, 401);
    expect(decide.code, 'AUTH_REQUIRED');

    await api.session.login(username: 'admin.demo', password: 'demo-only');
    final overview = await api.collections.overview();
    final sb1 = overview.submissions.singleWhere((s) => s.id == 'sb_1');
    expect(sb1.status, 'pending');
    expect(sb1.version, isNull);
  });

  test('P5-21 limited admin matches the fixture, including DEF-002', () async {
    final api = await _signedIn('limited.admin.demo');
    expect(api.permissions.canDo(ManagementAction.collectionsDecide), isTrue);
    expect(api.permissions.fullAccess, isFalse);

    final decision = await api.collections.decide(
      'sb_1',
      CollectionDecision.approve,
      meta: MutationMeta(expectedVersion: 1, requestId: 'p5-21-decide'),
    );
    expect(decision.version, isNull);
    expect(decision.raw['status'], 'approved');
    final overview = await api.collections.overview();
    expect(
      overview.submissions.singleWhere((s) => s.id == 'sb_1').status,
      'approved',
    );

    await _expectForbidden(
      api,
      const [
        '/api/reports',
        '/api/treasury',
        '/api/companies',
        '/api/masraweya/day',
        '/api/purchases/al_bayan',
      ],
      message: 'لا تملك صلاحية لهذا الإجراء',
    );
    for (final path in const [
      '/api/financial-ledger',
      '/api/statements/pdf',
    ]) {
      final error = await _apiOf(() => api.client.get(path));
      expect(error.statusCode, 403, reason: path);
      expect(error.code, 'FORBIDDEN', reason: path);
      expect(error.message, 'هذا الإجراء للإدارة فقط', reason: path);
    }

    final salary = await _apiOf(
      () => api.collections.setBaseSalary(
        'u_1',
        9000,
        MutationMeta(requestId: 'p5-21-salary'),
      ),
    );
    expect(salary.statusCode, 404);
    expect(salary.code, 'NOT_FOUND');

    final home = await api.client.get('/api/home');
    expect(_sections(home.dataMap), ['customers', 'collections']);
  });

  test('P5-32 employee writes are rejected and reads stay in scope', () async {
    final api = await _signedIn('employee.demo');
    expect(api.permissions.canDo(ManagementAction.collectionsDecide), isFalse);
    expect(api.permissions.canRead(SectionKey.customers), isTrue);
    expect(api.permissions.canRead(SectionKey.collections), isTrue);
    expect(api.permissions.canRead(SectionKey.treasury), isFalse);

    const adminOnly = 'هذا الإجراء للإدارة فقط';
    for (final call in <Future<Object?> Function()>[
      () => api.collections.decide(
        'sb_1',
        CollectionDecision.reject,
        meta: MutationMeta(expectedVersion: 1, requestId: 'p5-32-reject'),
      ),
      () => api.collections.decideUnlinked(
        'ur_1',
        decision: CollectionDecision.approve,
        meta: MutationMeta(expectedVersion: 1, requestId: 'p5-32-unlinked'),
      ),
      () => api.collections.markCashReceived(
        'sb_2',
        MutationMeta(expectedVersion: 3, requestId: 'p5-32-cash'),
      ),
      () => api.collections.closeDay(
        batchId: 'b_1',
        meta: MutationMeta(expectedVersion: 1, requestId: 'p5-32-close'),
      ),
      () => api.collections.assign(
        customerIds: const ['c_55'],
        assigneeUserId: 'u_12',
        section: 'customers',
        meta: MutationMeta(requestId: 'p5-32-assign'),
      ),
    ]) {
      final error = await _apiOf(call);
      expect(error.statusCode, 403);
      expect(error.code, 'FORBIDDEN');
      expect(error.message, adminOnly);
    }

    final salary = await _apiOf(
      () => api.collections.setBaseSalary(
        'u_1',
        9000,
        MutationMeta(requestId: 'p5-32-salary'),
      ),
    );
    expect(salary.statusCode, 404);
    expect(salary.code, 'NOT_FOUND');

    final overview = await api.collections.overview();
    expect(
      overview.submissions.singleWhere((s) => s.id == 'sb_1').status,
      'pending',
    );
    // The collections read is allowed. The fake body still includes the
    // totals board. Stripping that field is not implemented; see P5-32.
    final rawCollections = await api.client.get('/api/collections');
    expect(rawCollections.dataMap['employeeTotals'], isNotEmpty);

    await _expectForbidden(
      api,
      const [
        '/api/reports',
        '/api/treasury',
        '/api/companies',
        '/api/companies/c_55',
        '/api/masraweya/day',
        '/api/purchases/al_bayan',
        '/api/libyan-deposits',
        '/api/egyptian-deposits',
      ],
      message: 'لا تملك صلاحية لهذا الإجراء',
    );

    for (final path in const [
      '/api/financial-ledger',
      '/api/statements/pdf',
    ]) {
      final error = await _apiOf(() => api.client.get(path));
      expect(error.statusCode, 403, reason: path);
      expect(error.code, 'FORBIDDEN', reason: path);
      expect(error.message, 'هذا الإجراء للإدارة فقط', reason: path);
    }

    final customers = await api.client.get('/api/customers/c_56');
    expect(customers.statusCode, 200);
    final home = await api.client.get('/api/home');
    expect(_sections(home.dataMap), ['customers', 'collections']);
    final debts = home.dataMap['oldDebts'] as List;
    expect(debts, hasLength(1));
    expect((debts.single as Map)['id'], 'c_55');
  });

  test('P5-36 payroll id and employeeId query do not select a row', () async {
    final api = await _signedIn('employee.demo');
    final plain = await api.client.get('/api/collections/payroll');
    final byPath = await api.client.get(
      '/api/collections/payroll/employees/u_1',
    );
    for (final response in [plain, byPath]) {
      expect(response.statusCode, 200);
      final ids = [
        for (final row in (response.dataMap['employees'] as List))
          (row as Map)['userId'],
      ];
      expect(ids, ['u_12']);
    }
    final byQuery = await _apiOf(
      () => api.client.get(
        '/api/collections/payroll',
        query: const {'employeeId': 'u_1'},
      ),
    );
    expect(byQuery.statusCode, 404);
    expect(byQuery.code, 'NOT_FOUND');
  });

  test('P5-42 guest and flag.admin are refused on the server', () async {
    for (final username in const ['guest.demo', 'flag.admin.demo']) {
      final api = await _signedIn(username);
      expect(api.permissions.role, isNot(AccountRole.employee));
      expect(api.permissions.fullAccess, isFalse);
      expect(api.permissions.visibleSections, isEmpty);

      final home = await api.client.get('/api/home');
      expect(home.statusCode, 200, reason: username);
      expect(_sections(home.dataMap), isEmpty, reason: username);
      expect(home.dataMap.containsKey('oldDebts'), isFalse, reason: username);

      await _expectForbidden(api, const [
        '/api/customers',
        '/api/customers/c_55',
        '/api/collections',
        '/api/collections/payroll',
        '/api/financial-ledger',
        '/api/statements/pdf',
        '/api/reports',
        '/api/treasury',
        '/api/companies',
      ]);
      final decide = await _apiOf(
        () => api.collections.decide(
          'sb_1',
          CollectionDecision.approve,
          meta: MutationMeta(expectedVersion: 1, requestId: 'p5-42-$username'),
        ),
      );
      expect(decide.statusCode, 403, reason: username);
      expect(decide.code, 'FORBIDDEN', reason: username);
    }
  });

  test('P5-65 account-requests is an admin catalog on the fake', () async {
    final admin = await _signedIn('admin.demo');
    final list = await admin.client.get('/api/account-requests');
    expect(list.statusCode, 200);
    expect(list.dataMap['items'], isNotEmpty);
    final decision = await admin.client.get(
      '/api/account-requests/ar_1/decision',
    );
    expect(decision.statusCode, 200);

    for (final username in const [
      'limited.admin.demo',
      'employee.demo',
      'guest.demo',
      'flag.admin.demo',
    ]) {
      final api = await _signedIn(username);
      for (final path in const [
        '/api/account-requests',
        '/api/account-requests/ar_1/decision',
      ]) {
        final error = await _apiOf(() => api.client.get(path));
        expect(error.statusCode, 403, reason: '$username $path');
        expect(error.code, 'FORBIDDEN', reason: '$username $path');
      }
    }
  });
}

const _adminReads = [
  '/api/financial-ledger',
  '/api/statements/pdf',
  '/api/reports',
  '/api/treasury',
  '/api/companies',
  '/api/masraweya/day',
  '/api/purchases/al_bayan',
  '/api/home',
  '/api/collections',
  '/api/collections/payroll',
];

Future<ApiLayer> _signedIn(String username) async {
  final api = ApiLayer.create(
    config: const ApiConfig(
      baseUrl: 'https://fake.invalid',
      useFakeApi: true,
    ),
    fakeLatency: Duration.zero,
  );
  addTearDown(api.dispose);
  await api.session.login(username: username, password: 'demo-only');
  return api;
}

Future<ApiException> _apiOf(Future<Object?> Function() call) async {
  try {
    await call();
  } on ApiException catch (error) {
    return error;
  }
  fail('expected an ApiException');
}

Future<void> _expectForbidden(
  ApiLayer api,
  Iterable<String> paths, {
  String? message,
}) async {
  for (final path in paths) {
    final error = await _apiOf(() => api.client.get(path));
    expect(error.statusCode, 403, reason: path);
    expect(error.code, 'FORBIDDEN', reason: path);
    if (message != null) expect(error.message, message, reason: path);
  }
}

List<String> _sections(Map<String, dynamic> data) => [
  for (final row in (data['summaries'] as List)) '${(row as Map)['section']}',
];
