import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import 'api/api_providers.dart';
import 'app.dart';
import 'error_handling/error_handler.dart';
import 'features/notifications/notification_permission_registration.dart';
import 'notifications/android_notification_setup.dart';
import 'notifications/app_push_service.dart';
import 'notifications/device_token_registrar.dart';
import 'notifications/device_token_store.dart';
import 'notifications/firebase_messaging_runtime.dart';
import 'notifications/push_providers.dart';
import 'notifications/push_transport.dart';
import 'security/android_capture_gate.dart';
import 'secure_storage/app_secure_stores.dart';

Future<void> main() async {
  // Compile-time rejection of USE_FAKE_API=true in release. Debug ignores it.
  const ReleaseFakeApiGuard();
  rejectFakeApiInRelease(kUseFakeApiFromEnvironment);

  WidgetsFlutterBinding.ensureInitialized();
  final pushTransport = await resolveAppPushTransport();
  const errors = ErrorHandler();
  FlutterError.onError = (details) {
    errors.report(details.exception, details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    errors.report(error, stack);
    return true;
  };

  // Channel only, after the activity exists. POST_NOTIFICATIONS is asked
  // later, and only when Firebase actually started.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(AndroidNotificationSetup.start(onError: errors.report));
  });

  final stores = AppSecureStores();
  final pushGate = PushSessionGate();
  final layer = ApiLayer.create(
    config: ApiConfig.fromEnvironment(),
    cookieStore: stores.cookies,
    tokenStorage: stores.tokens,
    push: AppPushService(),
    cleanups: [pushGate.forget],
    captureGate: AndroidCaptureGate(),
  );
  runApp(
    buildAppRoot(
      layer: layer,
      pushGate: pushGate,
      tokenStore: SecureDeviceTokenStore(),
      overrides: [pushTransportProvider.overrideWithValue(pushTransport)],
      askNotificationPermission:
          pushTransport is FcmPushTransport && pushTransport.configured,
    ),
  );
}

/// Root scope the process and the registration tests share.
///
/// [notificationPermissionRegistrarOverride] is on this scope, so the
/// registrar created here sees the screen permission service. Tests may add
/// ports (transport, connectivity). They do not replace the registrar.
ProviderScope buildAppRoot({
  required ApiLayer layer,
  required PushSessionGate pushGate,
  required DeviceTokenStore tokenStore,
  List<Override> overrides = const [],
  Widget child = const CompanyApp(),
  bool askNotificationPermission = false,
}) {
  return ProviderScope(
    // A dead session is not fetched again. A 403 is not retried.
    // Every other failure keeps Riverpod's own retry.
    retry: (retryCount, error) {
      if (error is SessionExpiredException) return null;
      return retryUnlessForbidden(retryCount, error);
    },
    overrides: [
      apiLayerProvider.overrideWithValue(layer),
      pushSessionGateProvider.overrideWithValue(pushGate),
      deviceTokenStoreProvider.overrideWithValue(tokenStore),
      notificationPermissionRegistrarOverride(ask: askNotificationPermission),
      ...overrides,
    ],
    child: child,
  );
}
