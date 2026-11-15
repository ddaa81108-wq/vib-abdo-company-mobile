// VIB-FIX-099. Logout must wipe the persisted cookie even when the logout
// HTTP call is slow or fails, and a login started while that call or the
// local wipe is still running must publish the new session and keep its
// cookie. The client, interceptor, and SessionManager are the real ones.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('logout clears the cookie so a restart opens signed out', () async {
    final cookies = InMemoryCookieStore();
    final adapter = _Adapter();
    final layer = _open(cookies, adapter);
    await layer.session.login(username: 'admin', password: 'secret');
    expect(layer.session.state, isA<SessionAuthenticated>());
    expect(await cookies.cookieHeader(), contains('abdo_session=admin'));

    adapter.logoutStatus = 500;
    await layer.session.logout();

    expect(layer.session.state, isA<SessionUnauthenticated>());
    expect(
      (layer.session.state as SessionUnauthenticated).reason,
      'logout',
    );
    expect(await cookies.isEmpty(), isTrue);
    expect(layer.permissions.canRead(SectionKey.purchases), isFalse);

    final restarted = _open(cookies, adapter);
    await restarted.session.restore();
    expect(restarted.session.state, isA<SessionUnauthenticated>());
    expect(adapter.meCalls, 1);
  });

  test('login after logout publishes the new account and its permissions',
      () async {
    final cookies = InMemoryCookieStore();
    final adapter = _Adapter();
    final layer = _open(cookies, adapter);
    await layer.session.login(username: 'admin', password: 'secret');
    await layer.session.logout();
    expect(await cookies.isEmpty(), isTrue);

    await layer.session.login(username: 'employee', password: 'secret');

    final state = layer.session.state;
    expect(state, isA<SessionAuthenticated>());
    expect((state as SessionAuthenticated).profile.username, 'employee');
    expect(layer.permissions.canRead(SectionKey.collections), isTrue);
    expect(layer.permissions.canRead(SectionKey.purchases), isFalse);
    expect(layer.session.signingOut, isFalse);
    expect(await cookies.cookieHeader(), contains('abdo_session=employee'));

    await layer.session.logout();
    await layer.session.login(username: 'admin', password: 'secret');
    expect(layer.session.currentUser?.username, 'admin');
    expect(layer.permissions.canRead(SectionKey.purchases), isTrue);
  });

  test('a slow logout does not swallow the login that races it', () async {
    final cookies = InMemoryCookieStore();
    final adapter = _Adapter()..holdLogout = true;
    final layer = _open(cookies, adapter);
    await layer.session.login(username: 'admin', password: 'secret');

    final loggedOut = layer.session.logout();
    await adapter.logoutStarted.future;
    final loggedIn = layer.session.login(
      username: 'employee',
      password: 'secret',
    );
    adapter.releaseLogout(status: 401);
    await loggedOut;
    await loggedIn;

    expect(layer.session.currentUser?.username, 'employee');
    expect(layer.session.signingOut, isFalse);
    expect(layer.permissions.canRead(SectionKey.collections), isTrue);
    expect(await cookies.cookieHeader(), contains('abdo_session=employee'));
    expect(await cookies.cookieHeader(), isNot(contains('abdo_session=admin')));
  });

  test('a login during the local wipe is published and survives restart',
      () async {
    final cookies = InMemoryCookieStore();
    final adapter = _Adapter();
    final gate = Completer<void>();
    final layer = _open(cookies, adapter, cleanups: [() => gate.future]);
    await layer.session.login(username: 'admin', password: 'secret');

    final loggedOut = layer.session.logout();
    await adapter.logoutStarted.future;
    final loggedIn = layer.session.login(
      username: 'employee',
      password: 'secret',
    );
    // The wipe is inside its cleanup. Releasing it lets the queued login
    // commit after the old cookie has been deleted.
    gate.complete();
    await loggedOut;
    await loggedIn;

    expect(layer.session.currentUser?.username, 'employee');
    expect(layer.permissions.canRead(SectionKey.collections), isTrue);
    expect(await cookies.cookieHeader(), contains('abdo_session=employee'));

    final restarted = _open(cookies, adapter);
    await restarted.session.restore();
    expect(restarted.session.currentUser?.username, 'employee');
  });
}

ApiLayer _open(
  InMemoryCookieStore cookies,
  _Adapter adapter, {
  List<SessionCleanup> cleanups = const [],
}) {
  final layer = ApiLayer.create(
    config: const ApiConfig(
      baseUrl: 'https://example.invalid',
      useFakeApi: false,
    ),
    cookieStore: cookies,
    httpClientAdapter: adapter,
    cleanups: cleanups,
  );
  addTearDown(layer.dispose);
  return layer;
}

class _Adapter implements HttpClientAdapter {
  bool holdLogout = false;
  int logoutStatus = 200;
  int meCalls = 0;
  final logoutStarted = Completer<void>();
  Completer<int>? _logoutRelease;

  void releaseLogout({int status = 200}) {
    logoutStatus = status;
    _logoutRelease?.complete(status);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path == '/api/auth/login') {
      final user = _username(options);
      return _json(
        200,
        {
          'ok': true,
          'data': {
            'user': _user(user),
            'csrfToken': 'csrf-$user',
          },
        },
        setCookie: ['abdo_session=$user; Path=/; HttpOnly'],
      );
    }
    if (path == '/api/me') {
      meCalls++;
      final user = _cookieUser(options) ?? 'admin';
      return _json(200, {
        'ok': true,
        'data': {'user': _user(user)},
      });
    }
    if (path == '/api/auth/csrf') {
      return _json(200, {
        'ok': true,
        'data': {'csrfToken': 'csrf-refetch'},
      });
    }
    if (path == '/api/auth/logout') {
      if (!logoutStarted.isCompleted) logoutStarted.complete();
      var status = logoutStatus;
      if (holdLogout) {
        final gate = Completer<int>();
        _logoutRelease = gate;
        status = await gate.future;
      }
      if (status >= 400) {
        return _json(status, {
          'ok': false,
          'error': {
            'code': status == 401 ? 'AUTH_REQUIRED' : 'SERVER_ERROR',
            'message': 'logout failed',
          },
        });
      }
      return _json(
        200,
        {'ok': true, 'data': {}},
        setCookie: ['abdo_session=; Path=/; Max-Age=0'],
      );
    }
    return _json(404, {
      'ok': false,
      'error': {'code': 'NOT_FOUND', 'message': 'missing'},
    });
  }

  @override
  void close({bool force = false}) {}
}

String _username(RequestOptions options) {
  final raw = options.data;
  final data = raw is String ? jsonDecode(raw) : raw;
  if (data is Map && data['username'] is String) {
    return data['username'] as String;
  }
  return 'admin';
}

String? _cookieUser(RequestOptions options) {
  final header = options.headers['Cookie'] ?? options.headers['cookie'];
  final raw = header is List ? header.join(';') : header?.toString() ?? '';
  final match = RegExp(r'abdo_session=([^;]+)').firstMatch(raw);
  final value = match?.group(1);
  if (value == null || value.isEmpty) return null;
  return value;
}

Map<String, Object> _user(String username) {
  if (username == 'employee') {
    return {
      'id': '2',
      'username': 'employee',
      'displayName': 'Employee',
      'role': 'employee',
      'isOwner': false,
      'permissions': ['collections.read'],
      'mustChangePassword': false,
    };
  }
  return {
    'id': '1',
    'username': 'admin',
    'displayName': 'Admin',
    'role': 'admin',
    'isOwner': true,
    'permissions': <String>[],
    'mustChangePassword': false,
  };
}

ResponseBody _json(
  int status,
  Object body, {
  List<String>? setCookie,
}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        if (setCookie != null) 'set-cookie': setCookie,
      },
    );
