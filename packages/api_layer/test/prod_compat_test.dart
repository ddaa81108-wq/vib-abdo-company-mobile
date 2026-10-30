// Production (vip2100.com) compatibility, checked 2026-10-31.
//
// Response bodies below copy the SHAPE of production JSON only. Ids, names,
// and amounts are invented. No production value is stored here.
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_client.dart';
import 'package:flutter_api_layer/data/repositories/accounts_repository.dart';
import 'package:flutter_api_layer/data/repositories/employee_totals_repository.dart';
import 'package:flutter_api_layer/data/repositories/notifications_repository.dart';
import 'package:flutter_api_layer/data/repositories/purchases_repository.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _Call {
  _Call(this.method, this.path, this.body);
  final String method;
  final String path;
  final Object? body;
  Map<String, dynamic> get json => (body as Map).cast<String, dynamic>();
}

/// Answers by `METHOD path`. A value that is an [Exception] is thrown.
class _StubClient implements ApiClient {
  _StubClient(this.routes);
  final Map<String, Object?> routes;
  final calls = <_Call>[];

  Future<ApiResponse> _answer(String method, String path, Object? body) async {
    calls.add(_Call(method, path, body));
    final key = '$method $path';
    if (!routes.containsKey(key)) {
      throw const NotFoundException(code: 'ROUTE_NOT_FOUND', message: 'x');
    }
    final value = routes[key];
    if (value is Exception) throw value;
    return ApiResponse(statusCode: 200, data: value);
  }

  @override
  Future<ApiResponse> get(String path,
          {Map<String, dynamic>? query,
          ApiRequestOptions options = const ApiRequestOptions()}) =>
      _answer('GET', path, null);
  @override
  Future<ApiResponse> post(String path,
          {Object? body,
          Map<String, dynamic>? query,
          ApiRequestOptions options = const ApiRequestOptions()}) =>
      _answer('POST', path, body);
  @override
  Future<ApiResponse> put(String path,
          {Object? body,
          ApiRequestOptions options = const ApiRequestOptions()}) =>
      _answer('PUT', path, body);
  @override
  Future<ApiResponse> patch(String path,
          {Object? body,
          ApiRequestOptions options = const ApiRequestOptions()}) =>
      _answer('PATCH', path, body);
  @override
  Future<ApiResponse> delete(String path,
          {Object? body,
          ApiRequestOptions options = const ApiRequestOptions()}) =>
      _answer('DELETE', path, body);
}

Future<ApiLayer> _fakeAdmin() async {
  final api = ApiLayer.create(
    config: const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
    fakeLatency: Duration.zero,
  );
  await api.session.login(username: 'admin.demo', password: 'x');
  return api;
}

/// Production ledger line: `transactionDate` as a UTC instant, no `version`.
Map<String, dynamic> _prodLine() => {
      'id': 'tx-prod-shape',
      'sequence': 1,
      'type': 'debt',
      'status': 'posted',
      'amountUnits': 1,
      'inputValue': 1,
      'calculationMode': 'direct',
      'factorMicros': null,
      'transactionDate': '2026-10-30T22:00:00.000Z',
      'referenceNo': 'CUST-00000001',
      'note': 'سطر تجريبي',
      'displayNote': 'سطر تجريبي',
      'actorName': 'مستخدم تجريبي',
      'actorIsOwner': true,
      'paymentMode': null,
      'correctsTransactionId': null,
      'currency': 'LYD',
      'createdAt': '2026-10-30T22:13:01.915Z',
      'updatedAt': '2026-10-30T22:13:01.915Z',
    };

void main() {
  group('1 ledger dates', () {
    test('reads transactionDate and converts it to local time', () {
      final line = LedgerEntryDto.fromJson(_prodLine());
      final expected = DateTime.utc(2026, 10, 30, 22).toLocal();
      expect(line.date, expected);
      expect(line.date!.isUtc, isFalse);
      // The calendar day is the local one (2026-10-31 in Africa/Tripoli).
      expect(line.date!.day, expected.day);
      expect(line.recordedAt!.isUtc, isFalse);
    });

    test('falls back to date for older bodies', () {
      final raw = _prodLine()
        ..remove('transactionDate')
        ..['date'] = '2026-10-02';
      expect(LedgerEntryDto.fromJson(raw).date, DateTime(2026, 10, 2));
    });

    test('prefers transactionDate when both are present', () {
      final raw = _prodLine()..['date'] = '2001-01-01';
      expect(LedgerEntryDto.fromJson(raw).date!.year, 2026);
    });
  });

  group('2 cancel and correct use the card version', () {
    test('fake rejects a cancel without expectedVersion like production',
        () async {
      final api = await _fakeAdmin();
      await expectLater(
        api.accounts.cancelTransaction(
          AccountSection.customers,
          'c_55',
          'tx_2',
          MutationMeta(),
        ),
        throwsA(isA<BadRequestException>()
            .having((e) => e.code, 'code', 'EXPECTED_VERSION_REQUIRED')),
      );
    });

    test('fake accepts the card version for cancel and correction', () async {
      final api = await _fakeAdmin();
      final ledger =
          await api.accounts.ledger(AccountSection.customers, 'c_55');
      expect(ledger.page.items.every((line) => line.version == null), isTrue,
          reason: 'production ledger lines carry no version');
      var card = await api.accounts.get(AccountSection.customers, 'c_55');
      final corrected = await api.accounts.correctTransaction(
        AccountSection.customers,
        'c_55',
        'tx_1',
        AccountTransactionRequest.debt(
          inputValue: 2,
          date: DateTime(2026, 10, 31),
        ),
        MutationMeta(expectedVersion: card.version),
      );
      expect(corrected.version, card.version! + 1);
      card = await api.accounts.get(AccountSection.customers, 'c_55');
      final cancelled = await api.accounts.cancelTransaction(
        AccountSection.customers,
        'c_55',
        'tx_2',
        MutationMeta(expectedVersion: card.version),
      );
      expect(cancelled.version, card.version! + 1);
    });

    test('a stale card version is a version conflict', () async {
      final api = await _fakeAdmin();
      await expectLater(
        api.accounts.cancelTransaction(
          AccountSection.customers,
          'c_55',
          'tx_2',
          MutationMeta(expectedVersion: 999),
        ),
        throwsA(isA<ConflictException>()),
      );
    });
  });

  group('3 pin', () {
    test('sends isPinned, not pinned', () async {
      final stub = _StubClient({
        'PATCH /api/customers/c1/pin': {
          'customerId': 'c1',
          'isPinned': true,
          'customerVersion': 3,
        },
      });
      final ack = await RemoteAccountsRepository(stub).setPinned(
        AccountSection.customers,
        'c1',
        true,
        MutationMeta(expectedVersion: 2),
      );
      final body = stub.calls.single.json;
      expect(body['isPinned'], isTrue);
      expect(body.containsKey('pinned'), isFalse);
      expect(body['expectedVersion'], 2);
      expect(ack.version, 3);
    });

    test('fake rejects the old pinned body with INVALID_PIN_STATE', () async {
      final api = await _fakeAdmin();
      final card = await api.accounts.get(AccountSection.customers, 'c_55');
      await expectLater(
        api.client.patch('/api/customers/c_55/pin', body: {
          'requestId': 'pin-old-body',
          'expectedVersion': card.version,
          'pinned': true,
        }),
        throwsA(isA<BadRequestException>()
            .having((e) => e.code, 'code', 'INVALID_PIN_STATE')),
      );
      await api.accounts.setPinned(AccountSection.customers, 'c_55', true,
          MutationMeta(expectedVersion: card.version));
      final pinned = await api.accounts.get(AccountSection.customers, 'c_55');
      expect(pinned.pinned, isTrue);
      await api.accounts.setPinned(AccountSection.customers, 'c_55', false,
          MutationMeta(expectedVersion: pinned.version));
      final unpinned = await api.accounts.get(AccountSection.customers, 'c_55');
      expect(unpinned.pinned, isFalse);
    });
  });

  group('4 treasury cashVersion', () {
    test('reads cashVersion from the production body', () {
      final dto = TreasurySummaryDto.fromData({
        'currency': 'LYD',
        'receivablesUnits': 100,
        'liabilitiesUnits': 40,
        'activeCashUnits': 10,
        'egyptianSourceUnits': 55,
        'egyptianConvertedUnits': 10,
        // The wire decoder keeps a number literal as text; a Dart double is
        // never produced, so the test passes the text form.
        'egyptianRate': '5.5',
        'netUnits': 80,
        'cashVersion': 54,
        'sources': {'customers': 60, 'companies': 40},
      });
      expect(dto.version, 54);
    });

    test('falls back to version', () {
      expect(
          TreasurySummaryDto.fromData({'version': 7, 'totals': {}}).version, 7);
    });

    test('a cash entry sends cashVersion as expectedVersion (fake)', () async {
      final api = await _fakeAdmin();
      final summary = await api.treasury.summary();
      expect(summary.version, 7);
      final ack = await api.treasury.addCashEntry(
        const CashEntryRequest(
          direction: CashDirection.cashIn,
          amountUnits: 1,
          description: 'تجربة',
        ),
        MutationMeta(expectedVersion: summary.version),
      );
      expect(ack.version, 8);
      expect((await api.treasury.summary()).version, 8);
      final fake = api.client as FakeApiClient;
      expect(fake.mutationBodies.last, contains('"expectedVersion":7'));
    });
  });

  group('5 purchases versions', () {
    const entry = PurchaseEntryRequest(
      itemCode: PurchaseItemCodes.custom,
      itemLabel: 'صنف تجريبي',
      egpValueUnits: 10,
      calculationMode: CalculationMode.divide,
      paidUnits: 0,
      vodafoneConsumedUnits: 0,
    );

    test('edit and delete send the row version and the day version', () async {
      final stub = _StubClient({
        'PATCH /api/purchases/simsim/entries/e1': {'entryId': 'e1'},
        'DELETE /api/purchases/simsim/entries/e1': {
          'entryId': 'e1',
          'eventSequences': [1],
        },
      });
      final repo = RemotePurchasesRepository(stub);
      final updated = await repo.update(
          PurchaseBook.simsim, 'e1', entry, MutationMeta(expectedVersion: 5),
          entryVersion: 1);
      final deleted = await repo.delete(
          PurchaseBook.simsim, 'e1', MutationMeta(expectedVersion: 6),
          entryVersion: 2);
      expect(stub.calls[0].json['expectedDayVersion'], 5);
      expect(stub.calls[0].json['expectedVersion'], 1);
      expect(stub.calls[1].json['expectedDayVersion'], 6);
      expect(stub.calls[1].json['expectedVersion'], 2);
      expect(updated.id, 'e1');
      expect(deleted.id, 'e1');
    });

    test('day correction sends expectedVersion', () async {
      final stub = _StubClient({
        'PATCH /api/purchases/simsim/days/d1/correction': {'id': 'd1'},
      });
      await RemotePurchasesRepository(stub).setDayCorrection(
        PurchaseBook.simsim,
        'd1',
        open: true,
        meta: MutationMeta(expectedVersion: 3),
      );
      final body = stub.calls.single.json;
      expect(body['expectedVersion'], 3);
      expect(body.containsKey('expectedDayVersion'), isFalse);
      expect(body['open'], isTrue);
    });

    test('fake rejects edit and delete without the row version', () async {
      final api = await _fakeAdmin();
      Matcher invalid() => throwsA(isA<BadRequestException>()
          .having((e) => e.code, 'code', 'INVALID_PURCHASE_VALUE'));
      await expectLater(
        api.purchases.update(PurchaseBook.alBayan, 'pe_1', entry,
            MutationMeta(expectedVersion: 3),
            entryVersion: null),
        invalid(),
      );
      await expectLater(
        api.purchases.delete(
            PurchaseBook.alBayan, 'pe_1', MutationMeta(expectedVersion: 3),
            entryVersion: null),
        invalid(),
      );
    });
  });

  group('6 unread count', () {
    test('a 404 on unread-count falls back to the list and is remembered',
        () async {
      final stub = _StubClient({
        'GET /api/notifications': {
          'items': [
            {
              'id': 1,
              'action': 'transaction.created',
              'entityType': 'customer',
              'entityId': 'c1',
              'sectionKey': 'customers',
              'details': {},
              'actorName': 'مستخدم تجريبي',
              'actorUsername': 'user.demo',
              'actorRole': 'admin',
              'createdAt': '2026-10-30T20:00:00.000Z',
              'readAt': null,
            },
          ],
          'unreadCount': 1,
          'nextBefore': null,
        },
      });
      final repo = RemoteNotificationsRepository(stub);
      expect(await repo.serverUnreadCount(), 1);
      expect(await repo.serverUnreadCount(), 1);
      final countCalls = stub.calls
          .where((c) => c.path == '/api/notifications/unread-count')
          .length;
      expect(countCalls, 1, reason: 'the missing route is not retried');
    });

    test('the list without unreadCount is still invalid', () async {
      final stub = _StubClient({
        'GET /api/notifications': {'items': [], 'nextBefore': null},
      });
      await expectLater(RemoteNotificationsRepository(stub).serverUnreadCount(),
          throwsA(isA<InvalidServerResponseException>()));
    });
  });

  group('7 employee totals', () {
    Map<String, dynamic> collections() => {
          'assignments': [],
          'submissions': [],
          'unlinkedReceipts': [],
          'metrics': {'collectedUnits': 0, 'pendingCount': 0},
          'employeeTotals': [
            {
              'employeeId': 'u1',
              'employeeName': 'موظف تجريبي',
              'collectedUnits': 0,
              'approvedCount': 0,
              'pendingCount': 0,
            },
          ],
        };

    test('standalone 404 ROUTE_NOT_FOUND falls back to collections for admin',
        () async {
      final stub = _StubClient({'GET /api/collections': collections()});
      final permissions = PermissionService()
        ..applyFromServer(const [], role: 'admin');
      final repo = RemoteEmployeeTotalsRepository(stub,
          permissions: permissions, source: EmployeeTotalsSource.standalone);
      final dto = await repo.fetch();
      expect(dto.items, hasLength(1));
      expect(stub.calls.map((c) => c.path),
          ['/api/admin/employee-totals', '/api/collections']);
    });

    test('a caller without the permission keeps the 404', () async {
      final stub = _StubClient({'GET /api/collections': collections()});
      final permissions = PermissionService()
        ..applyFromServer(const [], role: 'employee');
      final repo = RemoteEmployeeTotalsRepository(stub,
          permissions: permissions, source: EmployeeTotalsSource.standalone);
      await expectLater(repo.fetch(), throwsA(isA<NotFoundException>()));
      expect(stub.calls.map((c) => c.path), ['/api/admin/employee-totals']);
    });

    test('another 404 code is not treated as a missing route', () async {
      final stub = _StubClient({
        'GET /api/admin/employee-totals':
            const NotFoundException(code: 'NOT_FOUND', message: 'x'),
        'GET /api/collections': collections(),
      });
      final permissions = PermissionService()
        ..applyFromServer(const [], role: 'admin');
      final repo = RemoteEmployeeTotalsRepository(stub,
          permissions: permissions, source: EmployeeTotalsSource.standalone);
      await expectLater(repo.fetch(), throwsA(isA<NotFoundException>()));
    });
  });

  group('8 created ids', () {
    test('account create reads customer.id and customer.version', () {
      final ack = MutationAck.fromData({
        'customer': {
          'id': 'new-card-id',
          'name': 'عميل تجريبي',
          'version': 1,
          'balanceUnits': 0,
        },
      });
      expect(ack.id, 'new-card-id');
      expect(ack.version, 1);
    });

    test('purchase create reads entryId', () {
      final ack = MutationAck.fromData({
        'entryId': 'new-entry-id',
        'sequence': 40,
        'eventSequences': [1],
      });
      expect(ack.id, 'new-entry-id');
    });

    test('top-level id still wins', () {
      expect(
          MutationAck.fromData({
            'id': 'a',
            'entryId': 'b',
            'customer': {'id': 'c'}
          }).id,
          'a');
    });
  });
}
