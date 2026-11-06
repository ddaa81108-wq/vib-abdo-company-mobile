import 'package:flutter/services.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/security/android_capture_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app/screen_security');
  final admin = PermissionService.adminRoleValue;
  final employee = PermissionService.employeeRoleValue;

  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  AndroidCaptureGate gate() => AndroidCaptureGate(channel: channel);

  Map<Object?, Object?> argsOf(MethodCall call) =>
      call.arguments as Map<Object?, Object?>;

  test('each verified role is sent and every other state is null', () async {
    final capture = gate();
    await capture.applySession(
      generation: 1,
      state: SessionAuthenticated(_person(role: admin)),
    );
    await capture.applySession(
      generation: 1,
      state: SessionAuthenticated(_person(role: employee)),
    );
    await capture.applySession(
      generation: 2,
      state: SessionAuthenticated(
        _person(role: 'Admin', permissions: [employee], fullAccess: true),
      ),
    );
    await capture.applySession(
      generation: 3,
      state: const SessionUnauthenticated(reason: 'logout'),
    );
    await capture.applySession(generation: 4, state: const SessionUnknown());
    await capture.applySession(
      generation: 5,
      state: const SessionOtpRequired(LoginChallenge(loginTicket: 'ticket')),
    );
    await capture.secure(generation: 6);

    expect(calls.map((call) => call.method), everyElement('applyVerifiedRole'));
    expect(argsOf(calls[0])['role'], admin);
    expect(argsOf(calls[1])['role'], employee);
    expect(argsOf(calls[2])['role'], isNull);
    expect(argsOf(calls[3])['role'], isNull);
    expect(argsOf(calls[4])['role'], isNull);
    expect(argsOf(calls[5])['role'], isNull);
    expect(argsOf(calls[6])['role'], isNull);
    expect(argsOf(calls[6])['generation'], 6);
  });

  test('an older allow is not sent after a newer revoke', () async {
    final capture = gate();
    await capture.applySession(
      generation: 2,
      state: SessionAuthenticated(_person(role: admin)),
    );
    await capture.secure(generation: 4);
    calls.clear();
    await capture.applySession(
      generation: 3,
      state: SessionAuthenticated(_person(role: employee)),
    );
    await capture.secure(generation: 2);
    expect(calls, isEmpty);
  });

  test('the same generation can secure and then allow again', () async {
    final capture = gate();
    await capture.secure(generation: 3);
    await capture.applySession(
      generation: 3,
      state: SessionAuthenticated(_person(role: employee)),
    );
    expect(argsOf(calls[0])['role'], isNull);
    expect(argsOf(calls[1])['role'], employee);
    expect(argsOf(calls[1])['generation'], 3);
  });

  test('a failed allow is followed by a secure call', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (argsOf(call)['role'] != null) {
            throw PlatformException(code: 'channel_down');
          }
          return null;
        });
    await gate().applySession(
      generation: 1,
      state: SessionAuthenticated(_person(role: admin)),
    );
    expect(calls.length, greaterThanOrEqualTo(2));
    expect(argsOf(calls.first)['role'], admin);
    expect(argsOf(calls.last)['role'], isNull);
    expect(calls.every((call) => call.method == 'applyVerifiedRole'), isTrue);
  });
}

UserProfile _person({
  String? role,
  List<String> permissions = const [],
  bool? fullAccess,
}) {
  return UserProfile(
    id: 'user-1',
    username: 'user-1',
    displayName: 'user-1',
    role: role,
    permissions: permissions,
    fullAccess: fullAccess,
    mustChangePassword: false,
  );
}
