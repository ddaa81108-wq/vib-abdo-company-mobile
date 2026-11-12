import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/notifications/background_sound_policy.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_presence.dart';

import 'support/pump_app.dart';

class _RecordingPresence implements NotificationPresence {
  final calls = <bool>[];

  @override
  Future<void> setHolding(bool holding) async {
    calls.add(holding);
  }
}

void main() {
  test('paused and locked keep the socket; detached and signed-out do not', () {
    for (final phase in [
      null,
      AppLifecycleState.resumed,
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      expect(
        BackgroundSoundPolicy.keepRealtime(signedIn: true, phase: phase),
        isTrue,
        reason: '$phase',
      );
      expect(
        BackgroundSoundPolicy.holdProcess(signedIn: true, phase: phase),
        isTrue,
        reason: '$phase',
      );
    }
    expect(
      BackgroundSoundPolicy.keepRealtime(
        signedIn: true,
        phase: AppLifecycleState.detached,
      ),
      isFalse,
    );
    expect(
      BackgroundSoundPolicy.keepRealtime(
        signedIn: false,
        phase: AppLifecycleState.resumed,
      ),
      isFalse,
    );
    expect(
      BackgroundSoundPolicy.holdProcess(
        signedIn: false,
        phase: AppLifecycleState.paused,
      ),
      isFalse,
    );
  });

  test(
    'the report names the four states and does not claim a killed app rings',
    () {
      expect(backgroundSoundStates, hasLength(4));
      final killed = backgroundSoundStates[2];
      expect(killed.sound, 'لا يصل في وقته');
      expect(killed.why, contains('FCM'));
      expect(backgroundSoundStates.last.why, contains('BOOT_COMPLETED'));
    },
  );

  test('Android holds the process with a silent dataSync service and no boot receiver', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_DATA_SYNC'),
    );
    expect(manifest, contains('android:name=".NotificationPresenceService"'));
    expect(manifest, contains('android:foregroundServiceType="dataSync"'));
    expect(manifest, isNot(contains('RECEIVE_BOOT_COMPLETED')));
    final service = File(
      'android/app/src/main/kotlin/com/vip2100/vib/NotificationPresenceService.kt',
    ).readAsStringSync();
    expect(service, contains('vib_presence_v1'));
    expect(service, contains('IMPORTANCE_LOW'));
    expect(service, contains('setSound(null, null)'));
    expect(service, contains('FOREGROUND_SERVICE_TYPE_DATA_SYNC'));
    final host = File(
      'android/app/src/main/kotlin/com/vip2100/vib/MainActivity.kt',
    ).readAsStringSync();
    expect(host, contains('app/notification_presence'));
    final alerts = File(
      'android/app/src/main/kotlin/com/vip2100/vib/MainActivity.kt',
    ).readAsStringSync();
    expect(
      alerts.contains('notification_channel_id') ||
          alerts.contains('vib_notices_sound_v1'),
      isTrue,
    );
    expect(alerts, contains('TYPE_NOTIFICATION'));
  });

  testWidgets('pausing keeps the hold and detaching releases it', (
    tester,
  ) async {
    final presence = _RecordingPresence();
    await pumpFakeApp(
      tester,
      overrides: [notificationPresenceProvider.overrideWith((ref) => presence)],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await tester.pump();
    expect(presence.calls, contains(true));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(presence.calls.last, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    await tester.pump();
    expect(presence.calls.last, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
  });
}
