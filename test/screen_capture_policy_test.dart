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

  test('release stays FLAG_SECURE and debug clears it only by build type', () {
    expect(policy, contains('fun windowIsSecure(debuggable: Boolean): Boolean = !debuggable'));
    expect(
      policy,
      contains('window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)'),
    );
    expect(policy, isNot(contains('disable')));

    expect(activity, contains('ScreenCapturePolicy.apply(window, BuildConfig.DEBUG)'));
    expect(
      activity,
      contains('if (ScreenCapturePolicy.windowIsSecure(BuildConfig.DEBUG))'),
    );
    expect(activity, isNot(contains('clearFlags')));
    expect(activity, isNot(contains('"disable"')));
  });

  test('the secure flag is applied at both native entry points', () {
    final onCreate = activity.indexOf('override fun onCreate');
    final engine = activity.indexOf('override fun configureFlutterEngine');
    final enable = activity.indexOf('call.method == "enable"');
    expect(onCreate, greaterThanOrEqualTo(0));
    expect(engine, greaterThan(onCreate));
    expect(enable, greaterThan(engine));
    expect(
      activity.indexOf('ScreenCapturePolicy.apply(window, BuildConfig.DEBUG)', onCreate),
      lessThan(engine),
    );
    expect(
      activity.indexOf('ScreenCapturePolicy.apply(window, BuildConfig.DEBUG)', engine),
      lessThan(enable),
    );
  });
}
