import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/notifications/firebase_messaging_runtime.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_channels.dart';
import 'package:vib_abdo_company_mobile/notifications/push_transport.dart';

void main() {
  test(
    'foreground FCM posts the local shade; background does not duplicate',
    () {
      expect(
        fcmShouldForwardToTray(
          inForeground: true,
          hasNotificationPayload: true,
        ),
        isTrue,
      );
      expect(
        fcmShouldForwardToTray(
          inForeground: false,
          hasNotificationPayload: true,
        ),
        isFalse,
      );
      expect(
        fcmShouldForwardToTray(
          inForeground: false,
          hasNotificationPayload: false,
        ),
        isTrue,
      );
      expect(
        fcmShouldPostLocalAlert(
          inForeground: false,
          hasNotificationPayload: true,
        ),
        isFalse,
      );
      expect(
        fcmShouldPostLocalAlert(
          inForeground: true,
          hasNotificationPayload: false,
        ),
        isFalse,
      );
      expect(
        fcmShouldPostLocalAlert(
          inForeground: false,
          hasNotificationPayload: false,
        ),
        isTrue,
      );
    },
  );

  test('absent Firebase config keeps the no-op transport', () async {
    final transport = await resolveAppPushTransport(
      runtime: const UnavailableFcmRuntime(),
    );
    expect(transport, isA<NoopPushTransport>());
    expect(transport.registersDevices, isFalse);
    expect(await transport.currentToken(), isNull);
    expect(transport.payloads, isA<Stream<Map<String, dynamic>>>());
  });

  test(
    'an unconfigured FCM transport has no token and does not throw',
    () async {
      final fcm = FcmPushTransport();
      expect(await fcm.prepare(), isFalse);
      expect(await fcm.currentToken(), isNull);
      expect(fcm.registersDevices, isTrue);
      await fcm.deleteToken();
    },
  );

  test('the audible channel id stays the one Android already uses', () {
    expect(NotificationChannels.collectionsId, 'vib_notices_sound_v1');
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, isNot(contains('tools:node="remove"')));
    expect(manifest, contains('.VibApplication'));
    expect(manifest, contains('vib_notices_sound_v1'));
  });
}
