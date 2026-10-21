@Tags(['permissions-negative'])
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/auth/auth_strategy.dart';
import 'package:flutter_api_layer/core/network/api_client.dart';
import 'package:flutter_api_layer/core/network/auth_interceptor.dart';
import 'package:flutter_api_layer/core/network/error_mapper.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = ErrorMapper();

  test('login 401 stays invalid credentials and any later 401 or bare 419 does not', () {
    final login = mapper.fromResponse(
      401,
      _envelope('AUTH_REQUIRED', 'يجب تسجيل الدخول'),
      null,
      false,
    );
    expect(login, isA<InvalidCredentialsException>());
    expect(login.code, 'AUTH_REQUIRED');

    final weird = mapper.fromResponse(
      401,
      _envelope('NOPE', 'no'),
    );
    expect(weird, isA<SessionExpiredException>());
    expect(weird.code, 'NOPE');

    final expired = mapper.fromResponse(
      419,
      _envelope('WHATEVER', 'gone'),
    );
    expect(expired, isA<SessionExpiredException>());
    expect(expired.code, 'WHATEVER');
    expect(expired.statusCode, 419);

    final csrf = mapper.fromResponse(
      419,
      _envelope('CSRF_INVALID', 'csrf'),
    );
    expect(csrf, isA<CsrfInvalidException>());

    final csrfMessage = mapper.fromResponse(
      419,
      _envelope('PAGE_EXPIRED', 'missing CSRF token'),
    );
    expect(csrfMessage, isA<CsrfInvalidException>());
  });

  test('an authenticated 401 of any code asks the interceptor to end the session once', () async {
    final reasons = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://fake.invalid'));
    dio.httpClientAdapter = _ScriptAdapter((options) {
      return ResponseBody.fromString(
        '{"ok":false,"error":{"code":"NOPE","message":"no","details":{},"correlationId":"c"}}',
        401,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final auth = AuthInterceptor(
      strategy: _LogoutOnExpiry(),
      onForcedLogout: (reason) async => reasons.add(reason),
    )..retryDio = dio;
    dio.interceptors.add(auth);

    await expectLater(
      dio.get<Object>('/api/home'),
      throwsA(isA<DioException>()),
    );
    expect(reasons, ['session_expired']);
    expect(dio.interceptors, isNotEmpty);
  });

  test('logout and expiry refuse every endpoint category and a replay stays a 401', () async {
    final api = FakeApiClient(latency: Duration.zero);
    await api.post(
      '/api/auth/login',
      body: {'username': 'admin.demo', 'password': 'x'},
      options: const ApiRequestOptions(authenticated: false),
    );
    final first = await api.post(
      '/api/customers/c_55/transactions',
      body: const {
        'requestId': 'paid-once',
        'expectedVersion': 4,
        'type': 'payment',
        'paymentMode': 'full',
      },
    );
    expect((first.data as Map)['id'], isNotNull);

    api.expireSession();
    await expectLater(
      api.post(
        '/api/customers/c_55/transactions',
        body: const {
          'requestId': 'paid-once',
          'expectedVersion': 4,
          'type': 'debt',
        },
      ),
      throwsA(_unauthorized()),
    );
    expect(api.mutationRequestIds, ['paid-once']);

    await api.post(
      '/api/auth/login',
      body: {'username': 'admin.demo', 'password': 'x'},
      options: const ApiRequestOptions(authenticated: false),
    );
    await api.post('/api/auth/logout');
    for (final path in _categories) {
      await expectLater(
        api.get(path),
        throwsA(_unauthorized()),
        reason: path,
      );
    }
    await expectLater(
      api.post(
        '/api/auth/change-password',
        body: {'currentPassword': 'x', 'newPassword': '0123456789ab'},
      ),
      throwsA(_unauthorized()),
    );
    await expectLater(api.post('/api/auth/logout'), throwsA(_unauthorized()));
    await expectLater(
      api.get('/api/me', options: const ApiRequestOptions(headers: {'Cookie': ''})),
      throwsA(_unauthorized()),
    );
  });

  test('a paused write does not apply after the session is expired', () async {
    final api = FakeApiClient(latency: Duration.zero);
    await api.post(
      '/api/auth/login',
      body: {'username': 'admin.demo', 'password': 'x'},
      options: const ApiRequestOptions(authenticated: false),
    );
    final before = await api.get('/api/customers/c_55');
    final gate = Completer<void>();
    api.pauseMutations = gate;
    final pending = api.post(
      '/api/customers/c_55/transactions',
      body: const {
        'requestId': 'in-flight',
        'expectedVersion': 4,
        'type': 'payment',
        'paymentMode': 'full',
      },
    );
    await Future<void>.delayed(Duration.zero);
    expect(api.mutationRequestIds, ['in-flight']);
    api.expireSession();
    gate.complete();
    await expectLater(pending, throwsA(_unauthorized()));
    final after = await api.post(
      '/api/auth/login',
      body: {'username': 'admin.demo', 'password': 'x'},
      options: const ApiRequestOptions(authenticated: false),
    );
    expect(after.statusCode, 200);
    final card = await api.get('/api/customers/c_55');
    expect((card.data as Map)['balanceUnits'], (before.data as Map)['balanceUnits']);
  });

  test('many 401s share one wipe and logout does not show expiry', () async {
    final cookies = InMemoryCookieStore();
    final tokens = InMemoryTokenStorage();
    var cleanups = 0;
    final api = ApiLayer.create(
      config: const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
      cookieStore: cookies,
      tokenStorage: tokens,
      fakeLatency: Duration.zero,
      cleanups: [
        () async {
          cleanups++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        },
      ],
    );
    addTearDown(api.dispose);
    await tokens.saveTokens(accessToken: 'stale', refreshToken: 'stale-refresh');
    await api.session.login(username: 'admin.demo', password: 'x');
    expect(await tokens.readAccessToken(), 'stale');
    expect(await cookies.cookieHeader(), contains('session='));

    final fake = api.client as FakeApiClient;
    await api.client.post(
      '/api/customers/c_55/transactions',
      body: const {
        'requestId': 'csrf-check',
        'expectedVersion': 4,
        'type': 'payment',
        'paymentMode': 'full',
      },
    );
    expect(_header(fake.lastRequestHeaders, 'x-csrf-token'), 'fake-csrf');
    expect(_header(fake.lastRequestHeaders, 'cookie'), contains('session='));

    fake.expireSession();
    await Future.wait([
      _swallow(api.home.fetch()),
      _swallow(api.notifications.list()),
      _swallow(api.accounts.list(AccountSection.customers)),
      _swallow(api.reports.daily()),
    ]);
    expect(api.session.state, isA<SessionUnauthenticated>());
    expect(
      (api.session.state as SessionUnauthenticated).reason,
      'session_expired',
    );
    expect(cleanups, 1);
    expect(await cookies.isEmpty(), isTrue);
    expect(await tokens.readAccessToken(), isNull);

    await api.session.login(username: 'employee.demo', password: 'x');
    await tokens.saveTokens(accessToken: 'leftover', refreshToken: 'leftover-refresh');
    await api.session.logout();
    expect((api.session.state as SessionUnauthenticated).reason, 'logout');
    expect(await cookies.isEmpty(), isTrue);
    expect(await tokens.readAccessToken(), isNull);
    expect(await tokens.readRefreshToken(), isNull);
    await _swallow(
      api.session.changePassword(
        currentPassword: 'x',
        newPassword: '0123456789ab',
      ),
    );
    expect(_header(fake.lastRequestHeaders, 'cookie'), isNull);
    expect(_header(fake.lastRequestHeaders, 'x-csrf-token'), isNull);
    expect((api.session.state as SessionUnauthenticated).reason, 'logout');
  });
}

const _categories = [
  '/api/me',
  '/api/home',
  '/api/customers',
  '/api/companies',
  '/api/libyan-deposits',
  '/api/egyptian-deposits',
  '/api/collections',
  '/api/masraweya/day',
  '/api/purchases/al_bayan',
  '/api/treasury',
  '/api/reports',
  '/api/notifications',
  '/api/financial-ledger',
];

Map<String, Object?> _envelope(String code, String message) => {
  'ok': false,
  'error': {
    'code': code,
    'message': message,
    'details': <String, Object?>{},
    'correlationId': 'c',
  },
};

Matcher _unauthorized() => isA<SessionExpiredException>()
    .having((error) => error.statusCode, 'status', 401)
    .having((error) => error.code, 'code', 'AUTH_REQUIRED');

String? _header(Map<String, String> headers, String name) {
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == name) return entry.value;
  }
  return null;
}

Future<void> _swallow(Future<Object?> run) async {
  try {
    await run;
  } catch (_) {}
}

class _ScriptAdapter implements HttpClientAdapter {
  _ScriptAdapter(this._handler);
  final ResponseBody Function(RequestOptions options) _handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => _handler(options);
}

class _LogoutOnExpiry implements AuthStrategy {
  @override
  String get name => 'test';

  @override
  Future<void> attach(RequestOptions options, {required bool authenticated}) async {}

  @override
  Future<void> capture(Response<dynamic> response) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<AuthErrorAction> handleAuthError(
    ApiException error,
    RequestOptions request, {
    required bool authenticated,
  }) async {
    if (error is SessionExpiredException && authenticated) {
      return AuthErrorAction.forceLogout;
    }
    return AuthErrorAction.passThrough;
  }

  @override
  Future<bool> hasPersistedSession() async => false;

  @override
  Future<void> onLoginSucceeded(Map<String, dynamic> loginData) async {}

  @override
  Future<void> onSessionResumed() async {}
}
