import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_api_layer/core/security/screen_security.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/security/platform_screen_security.dart';
import 'package:vib_abdo_company_mobile/security/screen_protection.dart';

class _RecordingSecurity implements ScreenSecurity {
  int enables = 0;
  int disables = 0;

  @override
  Future<void> enable() async => enables++;

  @override
  Future<void> disable() async => disables++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'enable uses the activity channel and disable does not clear it',
    () async {
      const channel = MethodChannel(PlatformScreenSecurity.channelName);
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      const security = PlatformScreenSecurity();
      await security.enable();
      await security.disable();
      expect(calls, ['enable']);
    },
  );

  testWidgets('protection is applied on start and resume and never removed', (
    tester,
  ) async {
    final security = _RecordingSecurity();
    await tester.pumpWidget(
      ScreenProtection(security: security, child: const SizedBox.shrink()),
    );
    await tester.pump();
    final afterStart = security.enables;
    expect(afterStart, greaterThanOrEqualTo(1));
    expect(security.disables, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(security.enables, afterStart);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(security.enables, greaterThan(afterStart));
    expect(security.disables, 0);
  });
}
