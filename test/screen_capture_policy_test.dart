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
  final lock = File(
    'android/app/src/main/kotlin/com/vip2100/vib/CaptureLock.kt',
  ).readAsStringSync();
  final messages = File(
    'android/app/src/main/kotlin/com/vip2100/vib/CaptureMessages.kt',
  ).readAsStringSync();
  final intents = File(
    'android/app/src/main/kotlin/com/vip2100/vib/CaptureIntents.kt',
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
    for (final source in [rules, policy, activity, gate, lock, messages]) {
      expect(source, isNot(contains('disable')));
    }
    expect(activity, isNot(contains('Long.MAX_VALUE')));
  });

  test('a stale generation cannot clear the flag', () {
    expect(lock, contains('if (!generations.accept(generation)) return false'));
    expect(policy, contains('if (!lock.apply(role, generation)) return false'));
    expect(
      policy.indexOf('if (!lock.apply(role, generation)) return false'),
      lessThan(policy.indexOf('window.clearFlags')),
    );
    expect(activity, isNot(contains('clearFlags')));
  });

  test('logout does not wait on the hold, and the hold remains a last resort', () {
    expect(lock, contains('const val DEFAULT_HOLD_MS = 2000L'));
    expect(lock, contains('fun onHoldElapsed(token: Long)'));
    expect(lock, contains('fun onHostPause()'));
    expect(lock, contains('if (hostPaused) return false'));
    expect(activity, contains('onHostPause()'));
    expect(activity, contains('onHostResume()'));
    expect(intents, contains('capture-intent.txt'));
    expect(activity, contains('FileObserver'));
    expect(activity, contains('shouldApply'));
    expect(intents, contains('fun shouldApply'));
    expect(gate, contains('captureIntentText'));
    expect(gate, contains('Duration(milliseconds: 500)'));
    expect(activity, contains('onCaptureHoldElapsed'));
    expect(activity, contains('captureLock.disarm()'));
    expect(activity, contains('captureLock.resetForNewEngine()'));
  });

  test(
    'the release window starts secure and only a verified role can update it',
    () {
    expect(activity, contains('secureWindowAtStart()'));
    expect(activity, contains('CaptureMessages.handle'));
    expect(messages, contains('const val METHOD = "applyVerifiedRole"'));
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
      lessThan(activity.indexOf('CaptureMessages.handle')),
    );
    },
  );
}
