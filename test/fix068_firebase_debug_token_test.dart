import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notification_permission.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notification_permission_registration.dart';
import 'package:vib_abdo_company_mobile/features/settings/firebase_debug_token.dart';
import 'package:vib_abdo_company_mobile/notifications/device_registration_client.dart';
import 'package:vib_abdo_company_mobile/notifications/device_token_registrar.dart';
import 'package:vib_abdo_company_mobile/notifications/device_token_store.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_dedup.dart';
import 'package:vib_abdo_company_mobile/notifications/push_providers.dart';
import 'package:vib_abdo_company_mobile/notifications/push_transport.dart';

void main() {
  test('the Firebase token row is compiled out of release builds', () {
    expect(showFirebaseDebugToken(debugBuild: false), isFalse);
    expect(showFirebaseDebugToken(debugBuild: true), isTrue);
    final source = File('lib/features/settings/development_screen.dart')
        .readAsStringSync();
    expect(source, contains('if (kDebugMode)'));
    expect(
      source,
      contains('developmentFirebaseSection(includeDebugRow: kDebugMode)'),
    );
  });

  testWidgets('release flag leaves the Firebase token row out of the tree', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: _Host(child: _ReleaseSection())),
      ),
    );
    expect(find.byKey(FirebaseDebugTokenPanel.rowKey), findsNothing);
    expect(find.text('رمز إشعارات Firebase'), findsNothing);
    expect(find.text('نسخ الرمز'), findsNothing);
  });

  testWidgets('debug row shows Firebase status and copies the token', (
    tester,
  ) async {
    final transport = FcmPushTransport(runtime: _ReadyRuntime('phone-token'));
    final copied = <String>[];
    await _pump(
      tester,
      transport: transport,
      permission: const GrantedNotificationPermission(),
      copied: copied,
    );

    expect(find.text('رمز إشعارات Firebase'), findsOneWidget);
    expect(find.text('مفعّل'), findsOneWidget);
    expect(find.text('مسموح'), findsOneWidget);
    expect(find.byKey(FirebaseDebugTokenPanel.askKey), findsNothing);

    await tester.tap(find.byKey(FirebaseDebugTokenPanel.copyKey));
    await tester.pump();
    expect(copied, ['phone-token']);
  });

  testWidgets('an unconfigured Firebase install stays off and cannot copy', (
    tester,
  ) async {
    await _pump(
      tester,
      transport: FcmPushTransport(runtime: const UnavailableFcmRuntime()),
      permission: const GrantedNotificationPermission(),
      copied: [],
    );
    expect(find.text('غير مفعّل'), findsOneWidget);
    final button = tester.widget<TextButton>(
      find.byKey(FirebaseDebugTokenPanel.copyKey),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('a denied permission keeps the request button', (tester) async {
    final permission = FakeNotificationPermissionService(
      initial: NotificationPermissionChoice.denied,
      afterRequest: NotificationPermissionChoice.denied,
    );
    await _pump(
      tester,
      transport: FcmPushTransport(runtime: _ReadyRuntime('phone-token')),
      permission: permission,
      copied: [],
    );
    expect(permission.requested, isTrue);
    expect(find.text('غير مسموح'), findsOneWidget);
    expect(find.byKey(FirebaseDebugTokenPanel.askKey), findsOneWidget);

    await tester.tap(find.byKey(FirebaseDebugTokenPanel.askKey));
    await tester.pumpAndSettle();
    expect(permission.requested, isTrue);
  });

  test('a missing device endpoint still asks and keeps the token', () async {
    final ui = FakeNotificationPermissionService(
      initial: NotificationPermissionChoice.denied,
      afterRequest: NotificationPermissionChoice.granted,
    );
    final transport = FakePushTransport(token: 'phone-token');
    addTearDown(transport.dispose);
    final client = RecordingDeviceRegistrationClient()
      ..registerError = StateError('no device route');
    final registrar = DeviceTokenRegistrar(
      transport: transport,
      permission: UiNotificationPermissionAdapter(
        ui,
        () async => 34,
        ask: true,
      ),
      store: MemoryDeviceTokenStore(),
      client: client,
      dedup: NotificationIdDedup(),
      currentUserId: () => 'u1',
    );
    addTearDown(registrar.dispose);

    await registrar.registerIfReady(signedIn: true);

    expect(ui.requested, isTrue);
    expect(client.registered, isEmpty);
    expect(await transport.currentToken(), 'phone-token');
  });
}

class _ReleaseSection extends StatelessWidget {
  const _ReleaseSection();

  @override
  Widget build(BuildContext context) {
    return developmentFirebaseSection(includeDebugRow: false);
  }
}

class _Host extends StatelessWidget {
  const _Host({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _ReadyRuntime implements FcmRuntime {
  _ReadyRuntime(this.value);

  final String value;

  @override
  Future<bool> start({
    required void Function(String token) onToken,
    required void Function(Map<String, dynamic> payload) onMessage,
  }) async => true;

  @override
  Future<String?> token() async => value;

  @override
  Future<void> deleteToken() async {}

  @override
  bool inForeground() => true;
}

Future<void> _pump(
  WidgetTester tester, {
  required PushTransport transport,
  required NotificationPermissionService permission,
  required List<String> copied,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pushTransportProvider.overrideWithValue(transport),
        notificationPermissionServiceProvider.overrideWithValue(permission),
        firebaseTokenCopyProvider.overrideWithValue((token) async {
          copied.add(token);
        }),
      ],
      child: const MaterialApp(home: Scaffold(body: FirebaseDebugTokenPanel())),
    ),
  );
  await tester.pumpAndSettle();
}
