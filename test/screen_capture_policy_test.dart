import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source guard for the Android capture policy. A device capture is not run.
void main() {
  final activity = File(
    'android/app/src/main/kotlin/com/vip2100/vib/MainActivity.kt',
  ).readAsStringSync();
  final policy = File(
    'android/app/src/main/kotlin/com/vip2100/vib/ScreenCapturePolicy.kt',
  ).readAsStringSync();
  final rules = File(
    'android/app/src/main/kotlin/com/vip2100/vib/CaptureRules.kt',
  ).readAsStringSync();
  final gate = File('lib/security/android_capture_gate.dart')
      .readAsStringSync();
  final permissions = File(
    'packages/api_layer/lib/core/permissions/permission_service.dart',
  ).readAsStringSync();

  test('release opens only for the exact server role strings', () {
    expect(permissions, contains("static const adminRoleValue = 'admin'"));
    expect(
      permissions,
      contains("static const employeeRoleValue = 'employee'"),
    );
    expect(rules, contains('const val adminRole = "admin"'));
    expect(rules, contains('const val employeeRole = "employee"'));
    expect(rules, contains('if (debuggable) return false'));
    expect(
      rules.indexOf('if (debuggable) return false'),
      lessThan(rules.indexOf('verifiedRole(role) == null')),
    );
    expect(rules, isNot(contains('disable')));
    expect(policy, isNot(contains('disable')));
    expect(activity, isNot(contains('disable')));
    expect(gate, isNot(contains('disable')));
    expect(gate, isNot(contains('kDebugMode')));
  });

  test('a stale generation cannot clear the flag', () {
    final accept = policy.indexOf('generations.accept(generation)');
    final clear = policy.indexOf('window.clearFlags');
    expect(accept, greaterThanOrEqualTo(0));
    expect(clear, greaterThan(accept));
    expect(
      policy,
      contains('if (!generations.accept(generation)) return false'),
    );
    expect(activity, isNot(contains('clearFlags')));
  });

  test(
    'the release window starts secure and only a verified role can update it',
    () {
      expect(activity, contains('secureWindowAtStart()'));
      expect(activity, contains('captureGenerations.reset()'));
      expect(activity, contains('applyVerifiedRole'));
      expect(gate, contains("'applyVerifiedRole'"));
      expect(activity, contains('BuildConfig.DEBUG'));
      expect(activity, contains('null,'));
      expect(activity, contains('0L'));
      final onCreate = activity.indexOf('override fun onCreate');
      final engine = activity.indexOf('override fun configureFlutterEngine');
      expect(onCreate, greaterThanOrEqualTo(0));
      expect(engine, greaterThan(onCreate));
      expect(
        activity.indexOf('secureWindowAtStart()', onCreate),
        lessThan(engine),
      );
      expect(
        activity.indexOf('secureWindowAtStart()', engine),
        lessThan(activity.indexOf('applyVerifiedRole')),
      );
    },
  );
}
