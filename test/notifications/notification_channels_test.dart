import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_channels.dart';

void main() {
  test('collections channel id, Arabic name, and badge flag stay stable', () {
    expect(NotificationChannels.collectionsId, 'vib_collections_alerts');
    expect(NotificationChannels.collectionsName, 'تنبيهات VIB');
    expect(
      NotificationChannels.collectionsDescription,
      'تنبيهات عامة وتنبيهات التحصيل',
    );
    expect(
      NotificationChannels.collectionsName,
      contains(NotificationChannels.manifestLabel),
    );
    expect(NotificationChannels.collections.showBadge, isTrue);
    expect(
      NotificationChannels.collections.importance,
      NotificationImportance.high,
    );
    expect(NotificationChannels.smallIcon, 'ic_stat_notification');
    expect(
      NotificationChannels.applicationId,
      'com.example.vib_abdo_company_mobile',
    );
    expect(NotificationChannels.minSdkCeiling, 29);
    expect(NotificationChannels.runtimePermissionSdk, 33);
  });

  test('manifest declares POST_NOTIFICATIONS, the icon, and FCM defaults', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(
      manifest,
      contains('android:label="${NotificationChannels.manifestLabel}"'),
    );
    expect(
      manifest,
      contains(NotificationChannels.postNotificationsPermission),
    );
    expect(
      manifest,
      isNot(contains('android.permission.RECEIVE_BOOT_COMPLETED')),
    );
    expect(
      manifest,
      isNot(contains('android.permission.SCHEDULE_EXACT_ALARM')),
    );
    expect(manifest, isNot(contains('android.permission.USE_EXACT_ALARM')));
    expect(
      manifest,
      contains('android:name="${NotificationChannels.fcmDefaultIconMeta}"'),
    );
    expect(manifest, contains('@drawable/${NotificationChannels.smallIcon}'));
    expect(
      manifest,
      contains('android:name="${NotificationChannels.fcmDefaultChannelMeta}"'),
    );
    expect(
      manifest,
      contains('android:value="${NotificationChannels.collectionsId}"'),
    );
  });

  test('status icon is a white-on-transparent vector', () {
    final icon = File(
      'android/app/src/main/res/drawable/${NotificationChannels.smallIcon}.xml',
    ).readAsStringSync();
    expect(icon, contains('<vector'));
    expect(icon, contains('android:fillColor="#FFFFFFFF"'));
    expect(RegExp(r'fillColor="#(?!FFFFFFFF|FFFFFF")').hasMatch(icon), isFalse);
  });

  test('string resources match the Dart channel constants', () {
    final xml = File('android/app/src/main/res/values/strings.xml')
        .readAsStringSync();
    expect(
      _stringResource(xml, 'notification_channel_id'),
      NotificationChannels.collectionsId,
    );
    expect(
      _stringResource(xml, 'notification_channel_name'),
      NotificationChannels.collectionsName,
    );
    expect(
      _stringResource(xml, 'notification_channel_description'),
      NotificationChannels.collectionsDescription,
    );
  });

  test('minSdk stays <= 29 and the application id is unchanged', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(
      gradle,
      contains('applicationId = "${NotificationChannels.applicationId}"'),
    );
    expect('applicationId ='.allMatches(gradle), hasLength(1));
    expect(gradle, contains('minSdk = minOf(flutter.minSdkVersion, 29)'));
    expect(gradle, contains('compileSdk = flutter.compileSdkVersion'));
    expect(gradle, contains('targetSdk = flutter.targetSdkVersion'));
    expect(gradle, contains('isCoreLibraryDesugaringEnabled = true'));
    expect(gradle, contains('google-services.json'));
    expect(gradle, contains('enableGoogleServices'));
    expect(gradle, contains('ENABLE_GOOGLE_SERVICES'));
    final settings = File('android/settings.gradle.kts').readAsStringSync();
    expect(settings, contains('com.google.gms.google-services'));
  });

  test('google-services.json is gitignored and not scheduled on every PR', () {
    final ignore = File('.gitignore').readAsStringSync();
    expect(ignore, contains('android/app/google-services.json'));
    final workflow = File(
      '.github/workflows/android-notifications-emulator.yml',
    ).readAsStringSync();
    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, contains('schedule:'));
    expect(workflow, isNot(contains('pull_request:')));
    expect(workflow, contains('api: [29, 33, 34]'));
    expect(
      workflow,
      contains('reactivecircus/android-emulator-runner@v2.38.0'),
    );
    expect(workflow, contains('USE_FAKE_API=true'));
    final script = File('tool/android_notification_emulator_test.sh')
        .readAsStringSync();
    expect(script, contains(NotificationChannels.applicationId));
    expect(script, contains('pm grant'));
    expect(script, contains('pm revoke'));
    expect(script, contains('NOTIF_CASE'));
  });

  test('launcher badge count ignores a negative value', () {
    expect(LauncherBadge.countFor(null), isNull);
    expect(LauncherBadge.countFor(-1), isNull);
    expect(LauncherBadge.countFor(0), 0);
    expect(LauncherBadge.countFor(4), 4);
  });
}

String _stringResource(String xml, String name) {
  final match = RegExp('<string name="$name"[^>]*>([^<]*)</string>')
      .firstMatch(xml);
  expect(match, isNotNull, reason: name);
  return match!.group(1)!;
}
