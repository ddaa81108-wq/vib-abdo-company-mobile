import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/auth/auth_strategy.dart';
import 'package:flutter_api_layer/data/repositories/auth_repository.dart';
import 'package:flutter_api_layer/data/repositories/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final admin = PermissionService.adminRoleValue;
  final employee = PermissionService.employeeRoleValue;

  test('release stays secure except exact admin and employee sessions', () {
    expect(
      captureWindowIsSecure(debuggable: false, state: const SessionUnknown()),
      isTrue,
    );
    for (final reason in [
      null,
      'logout',
      'session_expired',
      'restore_failed',
    ]) {
      expect(
        captureWindowIsSecure(
          debuggable: false,
          state: SessionUnauthenticated(reason: reason),
        ),
        isTrue,
      );
    }
    expect(
      captureWindowIsSecure(
        debuggable: false,
        state: const SessionOtpRequired(LoginChallenge(loginTicket: 'ticket')),
      ),
      isTrue,
    );
    expect(
      captureWindowIsSecure(
        debuggable: false,
        state: SessionAuthenticated(_person(role: admin)),
      ),
      isFalse,
    );
    expect(
      captureWindowIsSecure(
        debuggable: false,
        state: SessionAuthenticated(
          _person(role: employee, mustChangePassword: true),
        ),
      ),
      isFalse,
    );
    for (final role in <String?>[
      null,
      '',
      'Admin',
      'Employee',
      'admin ',
      ' employee',
      'guest',
      'owner',
      'staff',
    ]) {
      expect(
        releaseVerifiedRole(
          SessionAuthenticated(
            _person(
              role: role,
              permissions: [admin, employee, 'collections.write'],
              fullAccess: true,
            ),
          ),
        ),
        isNull,
        reason: 'role=$role',
      );
    }
  });

  test('a debug build stays capturable for every session state', () {
    for (final state in <SessionState>[
      const SessionUnknown(),
      const SessionUnauthenticated(reason: 'logout'),
      const SessionOtpRequired(LoginChallenge(loginTicket: 'ticket')),
      SessionAuthenticated(_person(role: null)),
      SessionAuthenticated(_person(role: admin)),
      SessionAuthenticated(_person(role: employee)),
    ]) {
      expect(captureWindowIsSecure(debuggable: true, state: state), isFalse);
    }
  });

  test('startup with no session stays secure', () async {
    final h = _Harness(persisted: false);
    addTearDown(h.dispose);
    await h.session.restore();
    expect(h.session.state, isA<SessionUnauthenticated>());
    expect((h.session.state as SessionUnauthenticated).reason, isNull);
    expect(h.gate.events, isNotEmpty);
    expect(h.gate.events.every((event) => event.role == null), isTrue);
  });

  test('startup restore allows each verified role', () async {
    for (final role in [admin, employee]) {
      final h = _Harness(
        persisted: true,
        user: _person(id: role, role: role),
      );
      addTearDown(h.dispose);
      await h.session.restore();
      final state = h.session.state;
      expect(state, isA<SessionAuthenticated>());
      expect((state as SessionAuthenticated).profile.role, role);
      expect(h.gate.events.last.role, role);
      final allowed = h.gate.events.lastIndexWhere(
        (event) => event.role == role,
      );
      final secured = h.gate.events.lastIndexWhere(
        (event) => event.kind == 'secure',
        allowed,
      );
      expect(secured, greaterThanOrEqualTo(0));
      expect(secured, lessThan(allowed));
    }
  });

  test('login allows each verified role', () async {
    for (final role in [admin, employee]) {
      final h = _Harness(
        user: _person(id: role, role: role),
      );
      addTearDown(h.dispose);
      await h.login();
      expect(releaseVerifiedRole(h.session.state), role);
      expect(h.permissions.role.name, role);
      expect(h.gate.events.last.role, role);
    }
  });

  test('a password-change session keeps the verified role', () async {
    final h = _Harness(user: _person(role: employee, mustChangePassword: true));
    addTearDown(h.dispose);
    await h.login();
    final state = h.session.state as SessionAuthenticated;
    expect(state.profile.mustChangePassword, isTrue);
    expect(releaseVerifiedRole(state), employee);
  });

  test('logout secures before the old session is cleared', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.login();
    final allowed = h.gate.events.last.generation;
    SessionState? duringLogout;
    h.auth.onLogout = () {
      duringLogout = h.session.state;
    };
    await h.session.logout();
    expect(duringLogout, isA<SessionAuthenticated>());
    expect(
      h.gate.events.any(
        (event) =>
            event.kind == 'secure' &&
            event.whileAuthenticated &&
            event.generation > allowed,
      ),
      isTrue,
    );
    final state = h.session.state as SessionUnauthenticated;
    expect(state.reason, 'logout');
    expect(h.gate.events.last.role, isNull);
    expect(h.permissions.role, AccountRole.unknown);
  });

  test('expiry secures and does not keep the previous role', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.login();
    await h.session.forceLogout('session_expired');
    final state = h.session.state as SessionUnauthenticated;
    expect(state.reason, 'session_expired');
    expect(h.gate.events.last.role, isNull);
    expect(h.gate.events.where((event) => event.role == admin).length, 1);
  });

  test('restore failure stays secure', () async {
    final h = _Harness(persisted: true);
    addTearDown(h.dispose);
    h.profile.error = StateError('down');
    await h.session.restore();
    final state = h.session.state as SessionUnauthenticated;
    expect(state.reason, 'restore_failed');
    expect(h.gate.events.every((event) => event.role == null), isTrue);
    expect(h.permissions.role, AccountRole.unknown);
  });

  test('an inexact role stays signed in and secure', () async {
    for (final role in <String?>[
      null,
      'Admin',
      'Employee',
      'guest',
      employee.toUpperCase(),
    ]) {
      final h = _Harness(
        user: _person(
          role: role,
          permissions: [employee, 'collections.write'],
          fullAccess: true,
        ),
      );
      addTearDown(h.dispose);
      await h.login();
      expect(h.session.state, isA<SessionAuthenticated>());
      expect(releaseVerifiedRole(h.session.state), isNull);
      expect(h.permissions.role, AccountRole.unknown);
      expect(h.gate.events.last.role, isNull);
    }
  });

  test('permissions do not make an unknown role an employee', () async {
    final h = _Harness(
      user: _person(
        role: null,
        permissions: [employee, admin, 'collections.write'],
        fullAccess: true,
      ),
    );
    addTearDown(h.dispose);
    await h.login();
    expect(PermissionService.verifiedCaptureRole(null), isNull);
    expect(releaseVerifiedRole(h.session.state), isNull);
    expect(h.permissions.fullAccess, isFalse);
  });

  test('a role change secures before the new role is applied', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.login();
    final adminAt = h.gate.events.lastIndexWhere(
      (event) => event.role == admin,
    );
    h.profile.user = _person(id: 'user-2', role: employee);
    await h.session.reloadProfileAndPermissions();
    final state = h.session.state as SessionAuthenticated;
    expect(state.profile.role, employee);
    final secured = h.gate.events.indexWhere(
      (event) => event.kind == 'secure',
      adminAt + 1,
    );
    final employeeAt = h.gate.events.lastIndexWhere(
      (event) => event.role == employee,
    );
    expect(secured, greaterThan(adminAt));
    expect(employeeAt, greaterThan(secured));
  });

  test('an account switch secures before the next login returns', () async {
    final h = _Harness(
      user: _person(id: 'admin-user', role: admin),
    );
    addTearDown(h.dispose);
    await h.login();
    final entered = Completer<void>();
    final release = Completer<void>();
    h.auth.onLogin = () async {
      entered.complete();
      await release.future;
    };
    h.profile.user = _person(id: 'employee-user', role: employee);
    final pending = h.login(username: 'employee-user');
    await entered.future;
    final during = h.session.state as SessionAuthenticated;
    expect(during.profile.id, 'admin-user');
    expect(
      h.gate.events.any(
        (event) => event.kind == 'secure' && event.whileAuthenticated,
      ),
      isTrue,
    );
    release.complete();
    await pending;
    final next = h.session.state as SessionAuthenticated;
    expect(next.profile.id, 'employee-user');
    expect(releaseVerifiedRole(next), employee);
  });

  test('a failed account switch keeps the previous verified role', () async {
    final h = _Harness(
      user: _person(id: 'admin-user', role: admin),
    );
    addTearDown(h.dispose);
    await h.login();
    h.auth.onLogin = () async => throw StateError('rejected');
    await expectLater(h.login(username: 'other'), throwsStateError);
    final state = h.session.state as SessionAuthenticated;
    expect(state.profile.id, 'admin-user');
    expect(h.gate.events.last.role, admin);
  });

  test(
    'a profile read that finishes after logout cannot allow capture',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.login();
      final entered = Completer<void>();
      final release = Completer<void>();
      h.profile.onFetch = () async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
      };
      final reload = h.session.reloadProfileAndPermissions();
      await entered.future;
      await h.session.logout();
      final cutoff = h.gate.events
          .lastWhere((event) => event.kind == 'secure')
          .generation;
      expect(h.session.state, isA<SessionUnauthenticated>());
      release.complete();
      await reload;
      expect((h.session.state as SessionUnauthenticated).reason, 'logout');
      expect(
        h.gate.events.where(
          (event) => event.role != null && event.generation >= cutoff,
        ),
        isEmpty,
      );
    },
  );

  test('a login that finishes after expiry cannot allow capture', () async {
    final h = _Harness(
      user: _person(id: 'admin-user', role: admin),
    );
    addTearDown(h.dispose);
    await h.login();
    final entered = Completer<void>();
    final release = Completer<void>();
    h.auth.onLogin = () async {
      entered.complete();
      await release.future;
    };
    h.profile.user = _person(id: 'employee-user', role: employee);
    final pending = h.login(username: 'employee-user');
    await entered.future;
    await h.session.forceLogout('session_expired');
    final cutoff = h.gate.events
        .lastWhere((event) => event.kind == 'secure')
        .generation;
    release.complete();
    await pending;
    expect(
      (h.session.state as SessionUnauthenticated).reason,
      'session_expired',
    );
    expect(
      h.gate.events.where(
        (event) => event.role != null && event.generation >= cutoff,
      ),
      isEmpty,
    );
  });
}

UserProfile _person({
  String id = 'user-1',
  String? role,
  List<String> permissions = const [],
  bool? fullAccess,
  bool mustChangePassword = false,
}) {
  return UserProfile(
    id: id,
    username: id,
    displayName: id,
    role: role,
    permissions: permissions,
    fullAccess: fullAccess,
    mustChangePassword: mustChangePassword,
  );
}

class _Event {
  const _Event({
    required this.kind,
    required this.generation,
    required this.role,
    required this.whileAuthenticated,
  });

  final String kind;
  final int generation;
  final String? role;
  final bool whileAuthenticated;
}

class _Gate implements SessionCaptureGate {
  _Gate(this._session);

  final SessionManager Function() _session;
  final events = <_Event>[];

  @override
  Future<void> secure({required int generation}) async {
    events.add(
      _Event(
        kind: 'secure',
        generation: generation,
        role: null,
        whileAuthenticated: _session().state is SessionAuthenticated,
      ),
    );
  }

  @override
  Future<void> applySession({
    required int generation,
    required SessionState state,
  }) async {
    events.add(
      _Event(
        kind: 'apply',
        generation: generation,
        role: releaseVerifiedRole(state),
        whileAuthenticated: _session().state is SessionAuthenticated,
      ),
    );
  }
}

class _Harness {
  _Harness({UserProfile? user, this.persisted = false}) {
    profile = _Profiles(
      user ?? _person(role: PermissionService.adminRoleValue),
    );
    auth = _Auth();
    strategy = _Strategy(persisted: persisted);
    permissions = PermissionService();
    gate = _Gate(() => session);
    session = SessionManager(
      authStrategy: strategy,
      authRepository: auth,
      profileRepository: profile,
      permissionService: permissions,
      captureGate: gate,
    );
  }

  final bool persisted;
  late final _Profiles profile;
  late final _Auth auth;
  late final _Strategy strategy;
  late final PermissionService permissions;
  late final _Gate gate;
  late final SessionManager session;

  Future<void> login({String username = 'person'}) {
    return session.login(username: username, password: 'secret');
  }

  Future<void> dispose() => session.dispose();
}

class _Profiles implements ProfileRepository {
  _Profiles(this.user);

  UserProfile user;
  Future<void> Function()? onFetch;
  Object? error;

  @override
  Future<MeResponse> fetchMe() async {
    final hook = onFetch;
    if (hook != null) await hook();
    final failure = error;
    if (failure != null) throw failure;
    return MeResponse(user: user);
  }
}

class _Auth implements AuthRepository {
  Future<void> Function()? onLogin;
  void Function()? onLogout;

  @override
  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    final hook = onLogin;
    if (hook != null) await hook();
    return LoginResult(raw: <String, dynamic>{});
  }

  @override
  Future<void> logout() async {
    onLogout?.call();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}
}

class _Strategy implements AuthStrategy {
  _Strategy({required this.persisted});

  final bool persisted;

  @override
  String get name => 'test';

  @override
  Future<void> attach(
    RequestOptions options, {
    required bool authenticated,
  }) async {}

  @override
  Future<void> acquireWrite(RequestOptions options) async {}

  @override
  void releaseWrite(RequestOptions options) {}

  @override
  Future<Response<dynamic>?> adoptCsrfGet(RequestOptions options) async => null;

  @override
  Future<void> capture(Response<dynamic> response) async {}

  @override
  Future<void> onLoginSucceeded(Map<String, dynamic> loginData) async {}

  @override
  Future<void> onSessionResumed() async {}

  @override
  Future<bool> hasPersistedSession() async => persisted;

  @override
  Future<AuthErrorAction> handleAuthError(
    ApiException error,
    RequestOptions request, {
    required bool authenticated,
  }) async => AuthErrorAction.passThrough;

  @override
  Future<void> clear() async {}
}
