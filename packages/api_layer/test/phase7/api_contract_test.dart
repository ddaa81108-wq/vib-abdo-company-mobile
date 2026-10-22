import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_client.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phase7_harness.dart';

/// Item 1. Wire contract of the real repositories and [DioApiClient].
/// P7-01 (live staging) is the separate opt-in smoke test.
void main() {
  for (final item in _cases) {
    test(item.$1, () async {
      final harness = await Phase7Harness.open();
      try {
        await harness.login();
        await item.$2(harness);
      } finally {
        await harness.dispose();
      }
    });
  }

  test('P7 contract public health and setup send GET and parse', () async {
    final harness = await Phase7Harness.open();
    try {
      final health = await harness.layer.client.get(ApiEndpoints.health);
      expect(health.dataMap['status'], 'ok');
      expectCall(harness, 'GET', ApiEndpoints.health, session: false);
      final setup = await harness.layer.client.get(ApiEndpoints.setupStatus);
      expect(setup.dataMap['ready'], isTrue);
      expectCall(harness, 'GET', ApiEndpoints.setupStatus, session: false);
    } finally {
      await harness.dispose();
    }
  });

  test('P7 contract login POST body has username and password', () async {
    final harness = await Phase7Harness.open();
    try {
      await harness.login(username: 'admin', password: 'demo-only');
      final call = expectCall(harness, 'POST', ApiEndpoints.login, session: false);
      expect(call.jsonBody?['username'], 'admin');
      expect(call.jsonBody?['password'], 'demo-only');
      expect(call.header('x-csrf-token'), isNull);
      expect(harness.layer.session.state, isA<SessionAuthenticated>());
    } finally {
      await harness.dispose();
    }
  });

  test('P7 contract error statuses map through the real client', () async {
    final harness = await Phase7Harness.open();
    try {
      await harness.login();
      await _expectStatus(harness, 403, ForbiddenException);
      await _expectStatus(harness, 404, NotFoundException);
      await _expectStatus(harness, 409, ConflictException);
      await _expectStatus(harness, 500, ServerException);
      await _expectStatus(harness, 503, ServerException);

      harness.transport.failNextStatus = 422;
      harness.transport.failNextDetails = [
        {'field': 'name', 'code': 'REQUIRED', 'message': 'الاسم مطلوب'},
        {'field': 'phone', 'code': 'INVALID', 'message': 'الهاتف غير صالح'},
      ];
      final validation = await _capture(
        harness.layer.client.get(
          ApiEndpoints.health,
          options: const ApiRequestOptions(noRetry: true),
        ),
      );
      expect(validation, isA<ValidationException>());
      final fields = (validation as ValidationException).fieldErrors;
      expect(fields.map((field) => field.field), ['name', 'phone']);
      expect(fields.map((field) => field.message), [
        'الاسم مطلوب',
        'الهاتف غير صالح',
      ]);
      expect(validation.message, isNot(contains('not-a-real-secret')));
    } finally {
      await harness.dispose();
    }
  });

  test('P7 contract 403 and 404 messages omit details secrets', () async {
    final harness = await Phase7Harness.open();
    try {
      await harness.login();
      for (final status in [403, 404]) {
        harness.transport.failNextStatus = status;
        harness.transport.failNextDetails = {
          'password': 'not-a-real-secret',
          'phone': '555-0100',
        };
        final error = await _capture(
          harness.layer.client.get(ApiEndpoints.me),
        );
        expect(error.message, isNot(contains('not-a-real-secret')));
        expect(error.message, isNot(contains('555-0100')));
        expect(error.toString(), isNot(contains('not-a-real-secret')));
      }
    } finally {
      await harness.dispose();
    }
  });

  test('P7 contract authenticated 401 is session expiry once', () async {
    final harness = await Phase7Harness.open();
    final reasons = <String?>[];
    final sub = harness.layer.session.states.listen((state) {
      if (state is SessionUnauthenticated) reasons.add(state.reason);
    });
    try {
      await harness.login();
      harness.transport.failNextStatus = 401;
      final error = await _capture(harness.layer.client.get(ApiEndpoints.me));
      expect(error, isA<SessionExpiredException>());
      expect(reasons, ['session_expired']);
      expect(harness.transport.matching('GET', ApiEndpoints.me), hasLength(2));
    } finally {
      await sub.cancel();
      await harness.dispose();
    }
  });
}

final _cases = <(String, Future<void> Function(Phase7Harness))>[
  (
    'P7 contract GET /api/me parses the user',
    (h) async {
      final me = await h.layer.profile.fetchMe();
      expect(me.user.id, 'u_1');
      expect(me.user.displayName, 'مدير تجريبي');
      final call = expectCall(h, 'GET', ApiEndpoints.me);
      expect(call.header('x-csrf-token'), isNull);
    },
  ),
  (
    'P7 contract GET /api/auth/csrf sends no CSRF header',
    (h) async {
      final before = h.transport.csrfToken;
      await h.layer.client.get(ApiEndpoints.csrf);
      final call = expectCall(h, 'GET', ApiEndpoints.csrf);
      expect(call.header('x-csrf-token'), isNull);
      expect(h.transport.csrfToken, isNot(before));
    },
  ),
  (
    'P7 contract customer list sends limit and parses the card',
    (h) async {
      final page = await h.layer.accounts.list(
        AccountSection.customers,
        q: 'زبون',
        filter: 'pinned',
      );
      expect(page.page.items.single.name, 'زبون تجريبي');
      expect(page.page.items.single.balanceUnits, 1500);
      final call = expectCall(h, 'GET', ApiEndpoints.accounts('customers'));
      expect('${call.query['q']}', 'زبون');
      expect('${call.query['filter']}', 'pinned');
      expect(call.query.containsKey('limit'), isTrue);
    },
  ),
  (
    'P7 contract company, Libyan, and Egyptian lists use their paths',
    (h) async {
      for (final section in [
        AccountSection.companies,
        AccountSection.libyanDeposits,
        AccountSection.egyptianDeposits,
      ]) {
        final page = await h.layer.accounts.list(section);
        expect(page.page.items.single.id, 'c1');
        expectCall(h, 'GET', ApiEndpoints.accounts(section.path));
      }
    },
  ),
  (
    'P7 contract suggestions, card, and ledger parse',
    (h) async {
      final suggestions = await h.layer.accounts.suggestions(
        AccountSection.customers,
        'زب',
      );
      expect(suggestions.single.name, 'اقتراح تجريبي');
      expectCall(h, 'GET', ApiEndpoints.accountSuggestions('customers'));
      final card = await h.layer.accounts.get(AccountSection.customers, 'c1');
      expect(card.balanceUnits, 1500);
      expectCall(h, 'GET', ApiEndpoints.account('customers', 'c1'));
      final ledger = await h.layer.accounts.ledger(
        AccountSection.customers,
        'c1',
      );
      expect(ledger.page.items.single.amountUnits, 10);
      expectCall(h, 'GET', ApiEndpoints.accountLedger('customers', 'c1'));
    },
  ),
  (
    'P7 contract account writes send requestId and expectedVersion',
    (h) async {
      final meta = MutationMeta(requestId: 'req-contract', expectedVersion: 4);
      final created = await h.layer.accounts.create(
        AccountSection.customers,
        const CreateAccountRequest(name: 'زبون جديد', phone: '555-0101'),
        meta,
      );
      expect(created.id, 'ack-1');
      expect(created.version, 5);
      final create = expectCall(h, 'POST', ApiEndpoints.accounts('customers'));
      expect(create.jsonBody?['requestId'], 'req-contract');
      expect(create.jsonBody?['expectedVersion'], 4);
      expect(create.jsonBody?['name'], 'زبون جديد');
      expect(create.header('x-csrf-token'), h.transport.csrfToken);

      final updated = await h.layer.accounts.update(
        AccountSection.customers,
        'c1',
        const UpdateAccountRequest(name: 'اسم محدّث'),
        meta,
      );
      expect(updated.version, 5);
      expect(
        expectCall(h, 'PATCH', ApiEndpoints.account('customers', 'c1'))
            .jsonBody?['name'],
        'اسم محدّث',
      );

      final tx = AccountTransactionRequest.debt(
        inputValue: 10,
        date: DateTime.utc(2026, 10, 21),
        note: 'phase7',
      );
      await h.layer.accounts.addTransaction(
        AccountSection.customers,
        'c1',
        tx,
        meta,
      );
      final posted = expectCall(
        h,
        'POST',
        ApiEndpoints.accountTransactions('customers', 'c1'),
      );
      expect(posted.jsonBody?['requestId'], 'req-contract');
      expect(posted.jsonBody?['expectedVersion'], 4);
      expect(posted.jsonBody?['type'], 'debt');
      expect(posted.jsonBody?['inputValue'], 10);

      await h.layer.accounts.correctTransaction(
        AccountSection.customers,
        'c1',
        'tx1',
        tx,
        meta,
      );
      expectCall(
        h,
        'POST',
        ApiEndpoints.accountTxCorrection('customers', 'c1', 'tx1'),
      );
      await h.layer.accounts.cancelTransaction(
        AccountSection.customers,
        'c1',
        'tx1',
        meta,
        reason: 'إلغاء تجريبي',
      );
      expect(
        expectCall(
          h,
          'POST',
          ApiEndpoints.accountTxCancel('customers', 'c1', 'tx1'),
        ).jsonBody?['reason'],
        'إلغاء تجريبي',
      );
      await h.layer.accounts.setPinned(
        AccountSection.customers,
        'c1',
        true,
        meta,
      );
      expect(
        expectCall(h, 'PATCH', ApiEndpoints.accountPin('customers', 'c1'))
            .jsonBody?['pinned'],
        isTrue,
      );
      await h.layer.accounts.confirmZeroReview('c1', meta);
      final zero = expectCall(h, 'POST', ApiEndpoints.customerZeroReview('c1'));
      expect(zero.jsonBody?['requestId'], 'req-contract');
      expect(zero.jsonBody?['expectedFinancialVersion'], 4);
      expect(zero.jsonBody?.containsKey('expectedVersion'), isFalse);
    },
  ),
  (
    'P7 contract exchange rate GET and PATCH',
    (h) async {
      final current = await h.layer.accounts.getExchangeRate();
      expect(current.egpPerLyd?.value, '9.5');
      expectCall(h, 'GET', ApiEndpoints.egyptianExchangeRate);
      final meta = MutationMeta(requestId: 'req-rate', expectedVersion: 2);
      final next = await h.layer.accounts.updateExchangeRate(
        DecimalString.tryParse('9.5')!,
        meta,
      );
      expect(next.version, 2);
      final call = expectCall(h, 'PATCH', ApiEndpoints.egyptianExchangeRate);
      expect(call.jsonBody?['requestId'], 'req-rate');
      expect(call.jsonBody?.containsKey('egpPerLyd'), isTrue);
    },
  ),
  (
    'P7 contract collections reads and writes',
    (h) async {
      final meta = MutationMeta(requestId: 'req-col', expectedVersion: 3);
      final overview = await h.layer.collections.overview();
      expect(overview.collectedUnits, 5);
      expectCall(h, 'GET', ApiEndpoints.collections);
      final people = await h.layer.collections.assignees();
      expect(people.single['id'], 'u_12');
      expectCall(h, 'GET', ApiEndpoints.collectionAssignees);
      final assigned = await h.layer.collections.assign(
        customerIds: const ['c1'],
        assigneeUserId: 'u_12',
        section: 'customers',
        meta: meta,
      );
      expect(assigned.id, 'ack-1');
      expect(
        expectCall(h, 'POST', ApiEndpoints.collectionAssignments).jsonBody,
        containsPair('assigneeUserId', 'u_12'),
      );
      await h.layer.collections.submit(
        'as1',
        mode: 'partial',
        amountUnits: 10,
        meta: meta,
      );
      expectCall(h, 'POST', ApiEndpoints.collectionSubmissions('as1'));
      await h.layer.collections.decide(
        'sub1',
        CollectionDecision.approve,
        meta: meta,
      );
      expect(
        expectCall(h, 'POST', ApiEndpoints.collectionSubmissionDecision('sub1'))
            .jsonBody?['decision'],
        'approve',
      );
      await h.layer.collections.markCashReceived('sub1', meta);
      expectCall(h, 'POST', ApiEndpoints.collectionSubmissionCashReceived('sub1'));
      await h.layer.collections.createUnlinkedReceipt(
        customerName: 'زبون',
        amountUnits: 10,
        meta: meta,
      );
      expectCall(h, 'POST', ApiEndpoints.collectionUnlinkedReceipts);
      final candidates = await h.layer.collections.linkCandidates('زب');
      expect(candidates, isNotEmpty);
      expectCall(h, 'GET', ApiEndpoints.collectionLinkCandidates);
      await h.layer.collections.decideUnlinked(
        'ur1',
        decision: CollectionDecision.reject,
        meta: meta,
      );
      expectCall(h, 'POST', ApiEndpoints.collectionUnlinkedDecision('ur1'));
      await h.layer.collections.markUnlinkedCashReceived('ur1', meta);
      expectCall(h, 'POST', ApiEndpoints.collectionUnlinkedCashReceived('ur1'));
      await h.layer.collections.closeDay(batchId: 'b1', meta: meta);
      expect(
        expectCall(h, 'POST', ApiEndpoints.collectionDaysClose).jsonBody?['batchId'],
        'b1',
      );
    },
  ),
  (
    'P7 contract payroll GET, POST, and PUT',
    (h) async {
      final meta = MutationMeta(requestId: 'req-pay', expectedVersion: 1);
      final payroll = await h.layer.collections.payroll();
      expect(payroll.employees.single.baseSalaryUnits, 10);
      expectCall(h, 'GET', ApiEndpoints.payroll);
      await h.layer.collections.addPayrollEntry(
        employeeUserId: 'u_12',
        kind: 'commission',
        amountUnits: 10,
        reason: 'تجريبي',
        meta: meta,
      );
      expectCall(h, 'POST', ApiEndpoints.payrollEntries);
      await h.layer.collections.setBaseSalary('u_12', 20, meta);
      expectCall(h, 'PUT', ApiEndpoints.payrollSalary('u_12'));
      await h.layer.collections.confirmPayrollEntry('pe1', meta);
      expectCall(h, 'POST', ApiEndpoints.payrollEntryConfirm('pe1'));
    },
  ),
  (
    'P7 contract masraweya day GET and PUT',
    (h) async {
      final day = await h.layer.masraweya.getDay(date: '2026-10-21');
      expect(day.businessDate, '2026-10-21');
      expect(day.workTotalUnits, 3);
      expectCall(h, 'GET', ApiEndpoints.masraweyaDay);
      final saved = await h.layer.masraweya.saveDay(
        const SaveMasraweyaDayRequest(businessDate: '2026-10-21'),
        MutationMeta(requestId: 'req-day', expectedVersion: 1),
      );
      expect(saved.remainingUnits, 1);
      final call = expectCall(h, 'PUT', ApiEndpoints.masraweyaDay);
      expect(call.jsonBody?['requestId'], 'req-day');
      expect(call.jsonBody?['expectedVersion'], 1);
    },
  ),
  (
    'P7 contract purchases books send expectedDayVersion',
    (h) async {
      final meta = MutationMeta(requestId: 'req-book', expectedVersion: 2);
      for (final book in PurchaseBook.values) {
        final page = await h.layer.purchases.list(book);
        expect(page.page.items, isEmpty);
        expectCall(h, 'GET', ApiEndpoints.purchases(book.path));
      }
      const entry = PurchaseEntryRequest(
        itemCode: PurchaseItemCodes.vodafoneCash,
        egpValueUnits: 10,
      );
      await h.layer.purchases.create(PurchaseBook.alBayan, entry, meta);
      final created = expectCall(h, 'POST', ApiEndpoints.purchases('al_bayan'));
      expect(created.jsonBody?['expectedDayVersion'], 2);
      expect(created.jsonBody?['itemCode'], 'vodafone_cash');
      await h.layer.purchases.update(PurchaseBook.alBayan, 'e1', entry, meta);
      expectCall(h, 'PATCH', ApiEndpoints.purchaseEntry('al_bayan', 'e1'));
      await h.layer.purchases.delete(PurchaseBook.alBayan, 'e1', meta);
      expectCall(h, 'DELETE', ApiEndpoints.purchaseEntry('al_bayan', 'e1'));
      await h.layer.purchases.setOpening(
        PurchaseBook.alBayan,
        previousDebtUnits: 1,
        previousVodafoneUnits: 2,
        meta: meta,
      );
      expectCall(h, 'PATCH', ApiEndpoints.purchasesOpening('al_bayan'));
      await h.layer.purchases.finalizeDay(PurchaseBook.alBayan, meta);
      expectCall(h, 'POST', ApiEndpoints.purchasesFinalize('al_bayan'));
      await h.layer.purchases.setDayCorrection(
        PurchaseBook.simsim,
        '2026-10-21',
        open: true,
        meta: meta,
      );
      expectCall(
        h,
        'PATCH',
        ApiEndpoints.purchasesDayCorrection('simsim', '2026-10-21'),
      );
    },
  ),
  (
    'P7 contract treasury, reports, and statement PDF',
    (h) async {
      final summary = await h.layer.treasury.summary();
      expect(summary.receivablesUnits, 1);
      expectCall(h, 'GET', ApiEndpoints.treasury);
      final cash = await h.layer.treasury.cashLedger();
      expect(cash.items.single.amountUnits, 2);
      expectCall(h, 'GET', ApiEndpoints.treasuryCashLedger);
      await h.layer.treasury.addCashEntry(
        const CashEntryRequest(
          direction: CashDirection.cashIn,
          amountUnits: 2,
          description: 'تجريبي',
        ),
        MutationMeta(requestId: 'req-cash', expectedVersion: 1),
      );
      final posted = expectCall(h, 'POST', ApiEndpoints.treasuryCashEntries);
      expect(posted.jsonBody?['requestId'], 'req-cash');
      expect(posted.jsonBody?['direction'], 'in');
      final reports = await h.layer.reports.daily();
      expect(reports.formula, 'server-formula');
      expectCall(h, 'GET', ApiEndpoints.reports);
      final ledger = await h.layer.reports.financialLedger();
      expect(ledger.pageTotals['LYD'], 1);
      expectCall(h, 'GET', ApiEndpoints.financialLedger);
      final pdf = await h.layer.reports.statementPdf(section: 'customers');
      expect(pdf.filename, 'statement.pdf');
      expect(pdf.bytes, isNotEmpty);
      expectCall(h, 'GET', ApiEndpoints.statementPdf);
    },
  ),
  (
    'P7 contract employee totals query has from and to and no employeeId',
    (h) async {
      final totals = await h.layer.employeeTotals.fetch(
        from: '2026-10-01',
        to: '2026-10-02',
      );
      expect(totals.items.single.employeeName, 'موظف تجريبي');
      final call = expectCall(h, 'GET', ApiEndpoints.employeeTotals);
      expect('${call.query['from']}', '2026-10-01');
      expect('${call.query['to']}', '2026-10-02');
      expect(call.query.containsKey('employeeId'), isFalse);
    },
  ),
  (
    'P7 contract notifications, home, events, and proposed paths',
    (h) async {
      final page = await h.layer.notifications.list();
      expect(page.unreadCount, 1);
      expect(page.items.single.id, 'n1');
      expectCall(h, 'GET', ApiEndpoints.notifications);
      final read = await h.layer.notifications.markRead('n1');
      expect(read.unreadCount, isNull);
      expectCall(h, 'PATCH', ApiEndpoints.notificationRead('n1'));
      await h.layer.notifications.markAllRead();
      expectCall(h, 'POST', ApiEndpoints.notificationsReadAll);
      final prefs = await h.layer.notifications.preferences();
      expect(prefs['soundEnabled'], isTrue);
      expectCall(h, 'GET', ApiEndpoints.notificationPreferences);
      await h.layer.notifications.updatePreferences({'soundEnabled': false});
      expect(
        expectCall(h, 'PATCH', ApiEndpoints.notificationPreferences).jsonBody,
        containsPair('soundEnabled', false),
      );
      expect(await h.layer.notifications.serverUnreadCount(), 2);
      expectCall(h, 'GET', ApiEndpoints.proposedUnreadCount);
      final home = await h.layer.home.fetch();
      expect(home.businessDate, '2026-10-21');
      expect(home.summaries.single.title, 'ديون');
      expectCall(h, 'GET', ApiEndpoints.proposedHome);
      await h.layer.client.get(ApiEndpoints.events);
      expectCall(h, 'GET', ApiEndpoints.events);
      await h.layer.client.get(ApiEndpoints.eventChanges);
      expectCall(h, 'GET', ApiEndpoints.eventChanges);
      await h.layer.client.post(ApiEndpoints.proposedMobilePushDevices, body: {
        'token': 'push-demo-token',
      });
      expectCall(h, 'POST', ApiEndpoints.proposedMobilePushDevices);
      await h.layer.client.get(ApiEndpoints.accountRequests);
      expectCall(h, 'GET', ApiEndpoints.accountRequests);
      await h.layer.client.post(
        ApiEndpoints.accountRequestDecision('ar1'),
        body: {'decision': 'approve'},
      );
      expectCall(h, 'POST', ApiEndpoints.accountRequestDecision('ar1'));
    },
  ),
  (
    'P7 contract admin catalogs and proposed mobile auth paths',
    (h) async {
      const paths = [
        ApiEndpoints.settings,
        ApiEndpoints.users,
        ApiEndpoints.staff,
        ApiEndpoints.employees,
        ApiEndpoints.admins,
        ApiEndpoints.audit,
        ApiEndpoints.operations,
      ];
      for (final path in paths) {
        await h.layer.client.get(path);
        expectCall(h, 'GET', path);
      }
      await h.layer.client.get(ApiEndpoints.user('u_20'));
      expectCall(h, 'GET', ApiEndpoints.user('u_20'));
      await h.layer.client.post(ApiEndpoints.proposedMobileLogin, body: {
        'username': 'admin',
        'password': 'demo-only',
      });
      expectCall(h, 'POST', ApiEndpoints.proposedMobileLogin);
      await h.layer.client.post(ApiEndpoints.proposedMobileRefresh);
      expectCall(h, 'POST', ApiEndpoints.proposedMobileRefresh);
      await h.layer.client.post(ApiEndpoints.proposedMobileLogout);
      expectCall(h, 'POST', ApiEndpoints.proposedMobileLogout);
    },
  ),
  (
    'P7 contract logout and change-password send cookie and CSRF',
    (h) async {
      await h.layer.auth.changePassword(
        currentPassword: 'current-demo',
        newPassword: 'new-password-demo',
      );
      final changed = expectCall(h, 'POST', ApiEndpoints.changePassword);
      expect(changed.jsonBody?['currentPassword'], 'current-demo');
      expect(changed.jsonBody?['newPassword'], 'new-password-demo');
      await h.layer.auth.logout();
      final logout = expectCall(h, 'POST', ApiEndpoints.logout);
      expect(logout.header('cookie'), contains('phase7-session'));
      expect(logout.header('x-csrf-token'), h.transport.csrfToken);
    },
  ),
];

RecordedCall expectCall(
  Phase7Harness harness,
  String method,
  String path, {
  bool session = true,
}) {
  final matches = harness.transport.matching(method, path);
  expect(matches, isNotEmpty, reason: '$method $path');
  final call = matches.last;
  final accept = call.header('accept');
  expect(accept, isNotNull);
  expect(accept, contains('application/json'));
  expect(call.header('x-client-api-version'), '1');
  if (method == 'GET' || method == 'HEAD') {
    expect(call.header('x-csrf-token'), isNull);
  } else if (path != ApiEndpoints.login && session) {
    expect(call.header('x-csrf-token'), isNotNull);
    if (call.jsonBody != null) {
      expect(call.header('content-type'), contains('application/json'));
    }
  }
  if (session && path != ApiEndpoints.login) {
    expect(call.header('cookie'), contains('phase7-session'));
  }
  return call;
}

Future<void> _expectStatus(
  Phase7Harness harness,
  int status,
  Type type,
) async {
  harness.transport.failNextStatus = status;
  harness.transport.failNextDetails = {'password': 'not-a-real-secret'};
  final error = await _capture(
    harness.layer.client.get(
      ApiEndpoints.health,
      options: const ApiRequestOptions(noRetry: true),
    ),
  );
  expect(error.runtimeType, type, reason: 'status $status');
  expect(error.statusCode, status);
  expect(error.message, isNot(contains('not-a-real-secret')));
}

Future<ApiException> _capture(Future<Object?> future) async {
  try {
    await future;
  } on ApiException catch (error) {
    return error;
  }
  fail('expected an ApiException');
}
