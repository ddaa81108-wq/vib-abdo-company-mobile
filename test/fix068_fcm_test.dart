import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_channels.dart';
import 'package:vib_abdo_company_mobile/notifications/push_transport.dart';

void main() {
  test('foreground FCM does not post a second tray sound', () {
    expect(
      fcmShouldForwardToTray(inForeground: true, hasNotificationPayload: true),
      isFalse,
    );
    expect(
      fcmShouldForwardToTray(inForeground: false, hasNotificationPayload: true),
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
    expect(manifest, contains('FirebaseInitProvider'));
    expect(manifest, contains('tools:node="remove"'));
    expect(manifest, contains('vib_notices_sound_v1'));
  });
}
