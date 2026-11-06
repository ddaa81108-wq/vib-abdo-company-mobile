import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/auth/auth_strategy.dart';
import 'package:flutter_api_layer/data/repositories/auth_repository.dart';
import 'package:flutter_api_layer/data/repositories/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/security/android_capture_gate.dart';

/// The assertions below read [ReleaseWindow], which changes only when a
/// channel call is applied. They do not treat a signed-out session as proof
/// that the window locked. The same hold rules are executed on the production
/// Kotlin [CaptureLock] by ScreenCapturePolicyTest.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app/screen_security');
  final admin = PermissionService.adminRoleValue;
  final employee = PermissionService.employeeRoleValue;

  late ReleaseWindow window;
  late List<MethodCall> calls;
  late bool dropSecure;
  late ManualTicker ticker;
  late AndroidCaptureGate gate;

  setUp(() {
    window = ReleaseWindow();
    calls = [];
    dropSecure = false;
    ticker = ManualTicker();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          final args = call.arguments as Map<Object?, Object?>;
          final role = args['role'] as String?;
          if (dropSecure && role == null) {
            throw PlatformException(code: 'secure_dropped');
          }
          window.apply(role, args['generation'] as int);
          return null;
        });
    gate = AndroidCaptureGate(channel: channel, ticker: ticker);
  });

  tearDown(() {
    gate.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'a delivered secure locks the window without waiting for the hold',
    () async {
      await gate.applySession(
        generation: 1,
        state: SessionAuthenticated(_person(role: admin)),
      );
      expect(window.secure, isFalse);
      await gate.secure(generation: 2);
      expect(window.secure, isTrue);
      window.elapse();
      expect(window.secure, isTrue);
    },
  );

  test(
    'a dropped secure leaves the window open until the hold elapses',
    () async {
      await gate.applySession(
        generation: 1,
        state: SessionAuthenticated(_person(role: employee)),
      );
      expect(window.secure, isFalse);
      dropSecure = true;
      await gate.secure(generation: 2);
      expect(window.secure, isFalse);
      final afterSecure = calls.length;
      await ticker.tick();
      expect(calls.length, afterSecure);
      window.elapse();
      expect(window.secure, isTrue);
    },
  );

  test(
    'a live session refresh reopens after the hold and logout does not',
    () async {
      await gate.applySession(
        generation: 4,
        state: SessionAuthenticated(_person(role: admin)),
      );
      window.elapse();
      expect(window.secure, isTrue);
      await ticker.tick();
      expect(window.secure, isFalse);
      dropSecure = true;
      await gate.secure(generation: 5);
      await ticker.tick();
      window.elapse();
      expect(window.secure, isTrue);
      await ticker.tick();
      expect(window.secure, isTrue);
    },
  );

  test(
    'logout does not lock the window when the secure call is dropped',
    () async {
      final harness = _Harness(
        gate: gate,
        user: _person(id: 'admin-user', role: admin),
      );
      addTearDown(harness.dispose);
      await harness.login();
      expect(window.secure, isFalse);
      expect(harness.session.state, isA<SessionAuthenticated>());
      dropSecure = true;
      await harness.session.logout();
      expect(
        (harness.session.state as SessionUnauthenticated).reason,
        'logout',
      );
      expect(window.secure, isFalse);
      final afterLogout = calls.length;
      await ticker.tick();
      expect(calls.length, afterLogout);
      window.elapse();
      expect(window.secure, isTrue);
    },
  );

  test(
    'a delivered logout locks while the old session is still on screen',
    () async {
      final harness = _Harness(
        gate: gate,
        user: _person(role: admin),
      );
      addTearDown(harness.dispose);
      await harness.login();
      bool? secureWhileAuthenticated;
      harness.auth.onLogout = () {
        secureWhileAuthenticated =
            window.secure && harness.session.state is SessionAuthenticated;
      };
      await harness.session.logout();
      expect(secureWhileAuthenticated, isTrue);
      expect(window.secure, isTrue);
    },
  );

  test('expiry with a dropped secure locks only after the hold', () async {
    final harness = _Harness(
      gate: gate,
      user: _person(role: employee),
    );
    addTearDown(harness.dispose);
    await harness.login();
    dropSecure = true;
    await harness.session.forceLogout('session_expired');
    expect(
      (harness.session.state as SessionUnauthenticated).reason,
      'session_expired',
    );
    expect(window.secure, isFalse);
    window.elapse();
    expect(window.secure, isTrue);
  });

  test(
    'an account switch locks the old admin window before the next login',
    () async {
      final harness = _Harness(
        gate: gate,
        user: _person(id: 'admin-user', role: admin),
      );
      addTearDown(harness.dispose);
      await harness.login();
      dropSecure = true;
      final entered = Completer<void>();
      final release = Completer<void>();
      harness.auth.onLogin = () async {
        entered.complete();
        await release.future;
      };
      harness.profile.user = _person(id: 'employee-user', role: employee);
      final pending = harness.login(username: 'employee-user');
      await entered.future;
      expect(window.secure, isFalse);
      window.elapse();
      expect(window.secure, isTrue);
      final during = harness.session.state as SessionAuthenticated;
      expect(during.profile.id, 'admin-user');
      dropSecure = false;
      release.complete();
      await pending;
      final next = harness.session.state as SessionAuthenticated;
      expect(next.profile.id, 'employee-user');
      expect(window.secure, isFalse);
    },
  );

  test('a role that is not exact locks the window while the session stays signed in', () async {
    final harness = _Harness(
      gate: gate,
      user: _person(role: admin),
    );
    addTearDown(harness.dispose);
    await harness.login();
    expect(window.secure, isFalse);
    harness.profile.user = _person(
      role: 'Admin',
      permissions: [employee, admin],
      fullAccess: true,
    );
    await harness.session.reloadProfileAndPermissions();
    expect(harness.session.state, isA<SessionAuthenticated>());
    expect(harness.permissions.role, AccountRole.unknown);
    expect(window.secure, isTrue);
  });

  test('the window model rejects a stale allow after a delivered secure', () {
    expect(window.apply(admin, 2), isTrue);
    expect(window.secure, isFalse);
    expect(window.apply(null, 6), isTrue);
    expect(window.secure, isTrue);
    expect(window.apply(employee, 5), isFalse);
    expect(window.secure, isTrue);
    window.elapse();
    expect(window.secure, isTrue);
  });
}

class ManualTicker implements CaptureTicker {
  void Function()? onTick;

  @override
  void start(Duration interval, void Function() onTick) {
    this.onTick = onTick;
  }

  @override
  void stop() => onTick = null;

  Future<void> tick() async {
    final callback = onTick;
    if (callback == null) return;
    callback();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }
}

/// Mirrors [CaptureLock] for a release window. The production class is the
/// Kotlin one; this model only applies channel payloads.
class ReleaseWindow {
  bool secure = true;
  int? generation;
  int holdToken = 0;

  bool apply(String? role, int next) {
    final current = generation;
    if (current != null && next < current) return false;
    generation = next;
    if (role != PermissionService.adminRoleValue &&
        role != PermissionService.employeeRoleValue) {
      _disarm();
      secure = true;
      return true;
    }
    secure = false;
    holdToken += 1;
    return true;
  }

  void elapse() {
    if (holdToken == 0) return;
    secure = true;
    _disarm();
  }

  void _disarm() => holdToken = 0;
}

UserProfile _person({
  String id = 'user-1',
  String? role,
  List<String> permissions = const [],
  bool? fullAccess,
}) {
  return UserProfile(
    id: id,
    username: id,
    displayName: id,
    role: role,
    permissions: permissions,
    fullAccess: fullAccess,
    mustChangePassword: false,
  );
}

class _Harness {
  _Harness({required this.gate, UserProfile? user}) {
    profile = _Profiles(
      user ?? _person(role: PermissionService.adminRoleValue),
    );
    auth = _Auth();
    permissions = PermissionService();
    session = SessionManager(
      authStrategy: _Strategy(),
      authRepository: auth,
      profileRepository: profile,
      permissionService: permissions,
      captureGate: gate,
    );
  }

  final AndroidCaptureGate gate;
  late final _Profiles profile;
  late final _Auth auth;
  late final PermissionService permissions;
  late final SessionManager session;

  Future<void> login({String username = 'person'}) {
    return session.login(username: username, password: 'secret');
  }

  Future<void> dispose() => session.dispose();
}

class _Profiles implements ProfileRepository {
  _Profiles(this.user);
  UserProfile user;

  @override
  Future<MeResponse> fetchMe() async => MeResponse(user: user);
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
  Future<void> logout() async => onLogout?.call();

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}
}

class _Strategy implements AuthStrategy {
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
  Future<bool> hasPersistedSession() async => false;

  @override
  Future<AuthErrorAction> handleAuthError(
    ApiException error,
    RequestOptions request, {
    required bool authenticated,
  }) async => AuthErrorAction.passThrough;

  @override
  Future<void> clear() async {}
}
