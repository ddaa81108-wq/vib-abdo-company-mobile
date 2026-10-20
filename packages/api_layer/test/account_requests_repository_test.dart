import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_client.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_api_layer/data/repositories/account_requests_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountRequestDto (proposed fields)', () {
    test('known status, aliases, and a string version parse', () {
      final dto = AccountRequestDto.fromJson({
        'id': 'ar_9',
        'status': 'pending',
        'version': '3',
        'requestedUsername': 'person@example.invalid',
        'applicantName': 'شخص تجريبي',
        'role': 'employee',
        'reason': 'سبب',
        'createdAt': '2026-10-19T09:00:00+02:00',
        'allowedActions': ['approve'],
      });
      expect(dto.knownStatus, AccountRequestStatus.pending);
      expect(dto.version, 3);
      expect(dto.username, 'person@example.invalid');
      expect(dto.displayName, 'شخص تجريبي');
      expect(dto.requestedRole, 'employee');
      expect(dto.note, 'سبب');
      expect(dto.phone, isNull);
      expect(dto.decisionNote, isNull);
      expect(dto.allowedActions, ['approve']);
      expect(dto.createdAt, isNotNull);
    });

    test('unknown status and a non-integer version stay uninterpreted', () {
      final dto = AccountRequestDto.fromJson({
        'id': 'ar_x',
        'status': 'on_hold',
        'version': 2.5,
        'password': 'secret',
        'allowedActions': [],
      });
      expect(dto.status, 'on_hold');
      expect(dto.knownStatus, isNull);
      expect(dto.version, isNull);
      expect(dto.allowedActions, isEmpty);
      expect(dto.raw['password'], 'secret');
      final redacted = const Redactor().redact(dto.raw) as Map;
      expect(redacted['password'], '***');
      expect(redacted['id'], 'ar_x');
      expect(redacted['status'], 'on_hold');
    });

    test('a missing allowedActions list stays null', () {
      final dto = AccountRequestDto.fromJson({'id': 'ar', 'status': ''});
      expect(dto.allowedActions, isNull);
      expect(dto.knownStatus, isNull);
    });
  });

  group('users.manage is the proposed UI gate', () {
    test(
      'full access or the code allows it; an employee code list does not',
      () {
        final employee = PermissionService()
          ..applyFromServer(const ['collections.read'], role: 'employee');
        expect(employee.canDo(ManagementAction.accountRequestsDecide), isFalse);

        final coded = PermissionService()
          ..applyFromServer(const ['users.manage'], role: 'employee');
        expect(coded.canDo(ManagementAction.accountRequestsDecide), isTrue);

        final admin = PermissionService()
          ..applyFromServer(const [], role: 'admin');
        expect(admin.canDo(ManagementAction.accountRequestsDecide), isTrue);
      },
    );
  });

  group('RemoteAccountRequestsRepository', () {
    test('list reads the account-requests path and proposed fields', () async {
      final client = _RecordingClient({
        'items': [
          {
            'id': 'ar_9',
            'status': 'pending',
            'version': 3,
            'username': 'person@example.invalid',
            'displayName': 'شخص',
            'phone': '0910000002',
            'note': 'ملاحظة',
          },
        ],
        'nextCursor': 'ar_9',
        'hasMore': true,
      });
      final page = await RemoteAccountRequestsRepository(client)
          .list(cursor: 'ar_0', limit: 10, status: 'pending');
      expect(client.calls, 1);
      expect(client.method, 'GET');
      expect(client.path, ApiEndpoints.accountRequests);
      expect(client.query, {
        'limit': 10,
        'cursor': 'ar_0',
        'status': 'pending',
      });
      expect(page.items.single.id, 'ar_9');
      expect(page.items.single.version, 3);
      expect(page.page.nextCursor, 'ar_9');
      expect(page.page.hasMore, isTrue);
    });

    test('an omitted status filter is not sent', () async {
      final client = _RecordingClient({'items': []});
      await RemoteAccountRequestsRepository(client).list();
      expect(client.query, {'limit': 100, 'cursor': null});
      expect(client.query!.containsKey('status'), isFalse);
    });

    test(
      'decide sends requestId, expectedVersion, and decision only',
      () async {
        final client = _RecordingClient({
          'id': 'ar_9',
          'version': 4,
          'status': 'approved',
        });
        final ack = await RemoteAccountRequestsRepository(client).decide(
          'ar_9',
          AccountRequestDecision.approve,
          meta: MutationMeta(expectedVersion: 3, requestId: 'req-1'),
        );
        expect(client.method, 'POST');
        expect(client.path, ApiEndpoints.accountRequestDecision('ar_9'));
        expect(client.body, {
          'requestId': 'req-1',
          'expectedVersion': 3,
          'decision': 'approve',
        });
        expect(ack.id, 'ar_9');
        expect(ack.version, 4);
        expect(ack.raw['status'], 'approved');
      },
    );

    test('a note is sent to the server and is a redacted log key', () async {
      final client = _RecordingClient({'id': 'ar_9', 'version': 4});
      await RemoteAccountRequestsRepository(client).decide(
        'ar_9',
        AccountRequestDecision.reject,
        note: 'سبب الرفض',
        meta: MutationMeta(expectedVersion: 3, requestId: 'req-2'),
      );
      expect(client.body, {
        'requestId': 'req-2',
        'expectedVersion': 3,
        'decision': 'reject',
        'note': 'سبب الرفض',
      });
      final redacted = const Redactor().redact(client.body) as Map;
      expect(redacted['note'], '***');
      expect(redacted['decision'], 'reject');
      expect(redacted['requestId'], 'req-2');
    });

    test('blank note is omitted', () async {
      final client = _RecordingClient({'id': 'ar_9', 'version': 4});
      await RemoteAccountRequestsRepository(client).decide(
        'ar_9',
        AccountRequestDecision.reject,
        note: '',
        meta: MutationMeta(expectedVersion: 3, requestId: 'req-3'),
      );
      expect((client.body as Map).containsKey('note'), isFalse);
    });

    test('missing version or id never reaches the client', () async {
      final client = _RecordingClient({'id': 'ar_9'});
      final repo = RemoteAccountRequestsRepository(client);
      expect(
        () => repo.decide(
          'ar_9',
          AccountRequestDecision.approve,
          meta: MutationMeta(requestId: 'req-4'),
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.decide(
          '  ',
          AccountRequestDecision.approve,
          meta: MutationMeta(expectedVersion: 1, requestId: 'req-5'),
        ),
        throwsArgumentError,
      );
      expect(client.calls, 0);
    });

    test(
      'server errors propagate with correlation id and redacted details',
      () async {
        const forbidden = ForbiddenException(
          code: 'FORBIDDEN',
          message: 'هذا الإجراء للإدارة فقط',
          statusCode: 403,
          correlationId: 'cid-1',
          details: {'username': 'person@example.invalid', 'decisionNote': 'سر'},
        );
        final client = _RecordingClient(null, error: forbidden);
        await expectLater(
          RemoteAccountRequestsRepository(client).list(),
          throwsA(
            isA<ForbiddenException>()
                .having((e) => e.correlationId, 'correlationId', 'cid-1')
                .having(
                  (e) => e.toString(),
                  'toString',
                  isNot(contains('person@')),
                )
                .having((e) => e.toString(), 'toString', isNot(contains('سر'))),
          ),
        );
        final redacted = const Redactor().redact(forbidden.details) as Map;
        expect(redacted['username'], '***');
        expect(redacted['decisionNote'], '***');
      },
    );

    test('a version conflict stays a version conflict', () async {
      final client = _RecordingClient(
        null,
        error: const ConflictException(
          code: 'VERSION_CONFLICT',
          message: 'تم تعديل البيانات من مستخدم آخر',
          statusCode: 409,
          correlationId: 'cid-2',
        ),
      );
      await expectLater(
        RemoteAccountRequestsRepository(client).decide(
          'ar_9',
          AccountRequestDecision.approve,
          meta: MutationMeta(expectedVersion: 1, requestId: 'req-6'),
        ),
        throwsA(
          isA<ConflictException>()
              .having((e) => e.isVersionConflict, 'isVersionConflict', isTrue)
              .having((e) => e.correlationId, 'correlationId', 'cid-2'),
        ),
      );
    });
  });

  group('FakeApiClient account requests', () {
    test('admin lists the canned page', () async {
      final repo = RemoteAccountRequestsRepository(await _loggedIn('admin'));
      final page = await repo.list();
      expect(page.items.map((e) => e.id), ['ar_1', 'ar_2']);
      final pending = page.items.first;
      expect(pending.knownStatus, AccountRequestStatus.pending);
      expect(pending.version, 2);
      expect(pending.username, 'new.employee@example.invalid');
      expect(pending.displayName, 'موظف جديد تجريبي');
      expect(pending.phone, '0910000001');
      expect(pending.allowedActions, ['approve', 'reject']);
      final approved = page.items.last;
      expect(approved.knownStatus, AccountRequestStatus.approved);
      expect(approved.decisionNote, 'اعتماد تجريبي');
      expect(approved.phone, isNull);
      expect(approved.allowedActions, isNull);
      expect(page.page.hasMore, isFalse);
    });

    test('status filter and cursor paging stay on the server page', () async {
      final repo = RemoteAccountRequestsRepository(await _loggedIn('admin'));
      final pending = await repo.list(status: 'pending');
      expect(pending.items.map((e) => e.id), ['ar_1']);
      final unknown = await repo.list(status: 'on_hold');
      expect(unknown.items, isEmpty);

      final first = await repo.list(limit: 1);
      expect(first.items.single.id, 'ar_1');
      expect(first.page.hasMore, isTrue);
      expect(first.page.nextCursor, 'ar_1');
      final second = await repo.list(limit: 1, cursor: first.page.nextCursor);
      expect(second.items.single.id, 'ar_2');
      expect(second.page.hasMore, isFalse);
      final missing = await repo.list(cursor: 'missing');
      expect(missing.items, isEmpty);
    });

    test(
      'approve then reject updates server state and replays requestId',
      () async {
        final api = await _loggedIn('admin');
        final repo = RemoteAccountRequestsRepository(api);
        final ack = await repo.decide(
          'ar_1',
          AccountRequestDecision.approve,
          note: 'اعتماد',
          meta: MutationMeta(expectedVersion: 2, requestId: 'req-approve'),
        );
        expect(ack.version, 3);
        expect(ack.raw['status'], 'approved');
        expect(api.mutationRequestIds, ['req-approve']);
        expect(api.lastWireBody, contains('اعتماد'));
        final redacted = const Redactor().redact({
          'note': 'اعتماد',
          'decision': 'approve',
          'requestId': 'req-approve',
        }) as Map;
        expect(redacted['note'], '***');

        final replay = await repo.decide(
          'ar_1',
          AccountRequestDecision.reject,
          meta: MutationMeta(expectedVersion: 2, requestId: 'req-approve'),
        );
        expect(replay.version, 3);
        expect(replay.raw['status'], 'approved');

        final decided = (await repo.list()).items.firstWhere(
          (e) => e.id == 'ar_1',
        );
        expect(decided.knownStatus, AccountRequestStatus.approved);
        expect(decided.version, 3);
        expect(decided.decisionNote, 'اعتماد');
        expect(decided.allowedActions, isNull);
        expect(decided.decidedAt, isNotNull);

        await expectLater(
          repo.decide(
            'ar_1',
            AccountRequestDecision.reject,
            meta: MutationMeta(expectedVersion: 2, requestId: 'req-stale'),
          ),
          throwsA(
            isA<ConflictException>().having(
              (e) => e.isVersionConflict,
              'isVersionConflict',
              isTrue,
            ),
          ),
        );
        await expectLater(
          repo.decide(
            'ar_1',
            AccountRequestDecision.reject,
            meta: MutationMeta(expectedVersion: 3, requestId: 'req-again'),
          ),
          throwsA(
            isA<ConflictException>()
                .having((e) => e.code, 'code', 'ALREADY_DECIDED')
                .having(
                  (e) => e.isVersionConflict,
                  'isVersionConflict',
                  isFalse,
                ),
          ),
        );
        expect(
          (await repo.list()).items.firstWhere((e) => e.id == 'ar_1').version,
          3,
        );
      },
    );

    test(
      'reject is its own decision and a failed attempt can be retried',
      () async {
        final api = await _loggedIn('admin');
        final repo = RemoteAccountRequestsRepository(api);
        api.failMutationsRemaining = 1;
        await expectLater(
          repo.decide(
            'ar_1',
            AccountRequestDecision.reject,
            meta: MutationMeta(expectedVersion: 2, requestId: 'req-retry'),
          ),
          throwsA(
            isA<BadRequestException>().having(
              (e) => e.code,
              'code',
              'MUTATION_FAILED',
            ),
          ),
        );
        expect(
          (await repo.list()).items.firstWhere((e) => e.id == 'ar_1').status,
          'pending',
        );
        final ack = await repo.decide(
          'ar_1',
          AccountRequestDecision.reject,
          meta: MutationMeta(expectedVersion: 2, requestId: 'req-retry'),
        );
        expect(ack.raw['status'], 'rejected');
        expect(
          (await repo.list()).items
              .firstWhere((e) => e.id == 'ar_1')
              .knownStatus,
          AccountRequestStatus.rejected,
        );
      },
    );

    test(
      'the fake rejects a bad decision, a missing version, and unknown ids',
      () async {
        final api = await _loggedIn('admin');
        final repo = RemoteAccountRequestsRepository(api);

        await expectLater(
          api.post(
            '/api/account-requests/ar_1/decision',
            body: {'expectedVersion': 2, 'decision': 'approve'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (e) => e.code,
              'code',
              'REQUEST_ID_REQUIRED',
            ),
          ),
        );
        await expectLater(
          api.post(
            '/api/account-requests/ar_1/decision',
            body: {'requestId': 'req-no-version', 'decision': 'approve'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (e) => e.code,
              'code',
              'VALIDATION_ERROR',
            ),
          ),
        );
        await expectLater(
          api.post(
            '/api/account-requests/ar_1/decision',
            body: {
              'requestId': 'req-bad-decision',
              'expectedVersion': 2,
              'decision': 'hold',
            },
          ),
          throwsA(
            isA<BadRequestException>()
                .having((e) => e.code, 'code', 'VALIDATION_ERROR')
                .having((e) => e.message, 'message', isNot(contains('@'))),
          ),
        );
        await expectLater(
          repo.decide(
            'missing',
            AccountRequestDecision.approve,
            meta: MutationMeta(expectedVersion: 2, requestId: 'req-missing'),
          ),
          throwsA(isA<NotFoundException>()),
        );
        await expectLater(
          api.post('/api/account-requests', body: {'requestId': 'req-create'}),
          throwsA(isA<NotFoundException>()),
        );
        await expectLater(
          api.get('/api/account-requests/ar_1'),
          throwsA(isA<NotFoundException>()),
        );
        await expectLater(
          repo.list(limit: 0),
          throwsA(
            isA<BadRequestException>().having(
              (e) => e.code,
              'code',
              'VALIDATION_ERROR',
            ),
          ),
        );
        expect(
          (await repo.list()).items.firstWhere((e) => e.id == 'ar_1').status,
          'pending',
        );
      },
    );

    test('an already decided fixture cannot be decided again', () async {
      final repo = RemoteAccountRequestsRepository(await _loggedIn('admin'));
      await expectLater(
        repo.decide(
          'ar_2',
          AccountRequestDecision.reject,
          meta: MutationMeta(expectedVersion: 4, requestId: 'req-ar2'),
        ),
        throwsA(
          isA<ConflictException>().having(
            (e) => e.code,
            'code',
            'ALREADY_DECIDED',
          ),
        ),
      );
      expect((await repo.list()).items.last.version, 4);
    });

    test(
      'employee, limited admin, and a signed-out caller are refused',
      () async {
        Future<void> forbidden(String username) async {
          final repo = RemoteAccountRequestsRepository(
            await _loggedIn(username),
          );
          await expectLater(repo.list(), throwsA(isA<ForbiddenException>()));
          await expectLater(
            repo.decide(
              'ar_1',
              AccountRequestDecision.approve,
              meta: MutationMeta(
                expectedVersion: 2,
                requestId: 'req-$username',
              ),
            ),
            throwsA(
              isA<ForbiddenException>()
                  .having(
                    (e) => e.message,
                    'message',
                    isNot(contains('example')),
                  )
                  .having(
                    (e) => e.toString(),
                    'toString',
                    isNot(contains('تجريبي')),
                  ),
            ),
          );
        }

        await forbidden('employee');
        await forbidden('limited.admin');

        final signedOut = RemoteAccountRequestsRepository(
          FakeApiClient(latency: Duration.zero),
        );
        await expectLater(
          signedOut.list(),
          throwsA(
            isA<SessionExpiredException>().having(
              (e) => e.code,
              'code',
              'AUTH_REQUIRED',
            ),
          ),
        );
      },
    );

    test('ApiLayer wires the same repository on the fake client', () async {
      final api = ApiLayer.create(
        config: const ApiConfig(
          baseUrl: 'https://fake.invalid',
          useFakeApi: true,
        ),
        fakeLatency: Duration.zero,
      );
      addTearDown(api.dispose);
      await api.session.login(username: 'admin@example.invalid', password: 'x');
      expect(
        api.permissions.canDo(ManagementAction.accountRequestsDecide),
        isTrue,
      );
      final page = await api.accountRequests.list();
      expect(page.items, hasLength(2));
      await api.session.logout();

      await api.session.login(
        username: 'employee@example.invalid',
        password: 'x',
      );
      expect(
        api.permissions.canDo(ManagementAction.accountRequestsDecide),
        isFalse,
      );
      await expectLater(
        api.accountRequests.list(),
        throwsA(isA<ForbiddenException>()),
      );
    });
  });

  test('proposed account-request names are redacted', () {
    final redacted = const Redactor().redact({
      'id': 'ar_1',
      'status': 'pending',
      'version': 2,
      'requestedRole': 'employee',
      'username': 'new.employee@example.invalid',
      'displayName': 'موظف جديد تجريبي',
      'applicantName': 'اسم',
      'requestedUsername': 'user@example.invalid',
      'phone': '0910000001',
      'note': 'طلب تجريبي',
      'decisionNote': 'سرية',
    }) as Map;
    expect(redacted['id'], 'ar_1');
    expect(redacted['status'], 'pending');
    expect(redacted['version'], 2);
    expect(redacted['requestedRole'], 'employee');
    for (final key in [
      'username',
      'displayName',
      'applicantName',
      'requestedUsername',
      'phone',
      'note',
      'decisionNote',
    ]) {
      expect(redacted[key], '***', reason: key);
    }
  });
}

Future<FakeApiClient> _loggedIn(String username) async {
  final api = FakeApiClient(latency: Duration.zero);
  await api.post(
    '/api/auth/login',
    body: {'username': '$username@example.invalid', 'password': 'x'},
  );
  return api;
}

class _RecordingClient implements ApiClient {
  _RecordingClient(this.data, {this.error});

  final Object? data;
  final ApiException? error;
  int calls = 0;
  String? method;
  String? path;
  Object? body;
  Map<String, dynamic>? query;

  Future<ApiResponse> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    calls++;
    this.method = method;
    this.path = path;
    this.body = body;
    this.query = query;
    final failure = error;
    if (failure != null) throw failure;
    return ApiResponse(statusCode: 200, data: data, correlationId: 'test');
  }

  @override
  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? query,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) => _send('GET', path, query: query);

  @override
  Future<ApiResponse> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) => _send('POST', path, body: body, query: query);

  @override
  Future<ApiResponse> put(
    String path, {
    Object? body,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) => _send('PUT', path, body: body);

  @override
  Future<ApiResponse> patch(
    String path, {
    Object? body,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) => _send('PATCH', path, body: body);

  @override
  Future<ApiResponse> delete(
    String path, {
    Object? body,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) => _send('DELETE', path, body: body);
}
