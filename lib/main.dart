import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_providers.dart';
import 'app.dart';
import 'error_handling/error_handler.dart';
import 'notifications/app_push_service.dart';
import 'secure_storage/app_secure_stores.dart';
import 'security/platform_screen_security.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const errors = ErrorHandler();
  installErrorHooks(errors);
  // The activity also sets FLAG_SECURE in onCreate, before this runs.
  unawaited(const PlatformScreenSecurity().enable());

  final stores = AppSecureStores();
  final layer = ApiLayer.create(
    config: ApiConfig.fromEnvironment(),
    cookieStore: stores.cookies,
    tokenStorage: stores.tokens,
    push: AppPushService(),
  );
  runApp(
    ProviderScope(
      overrides: [apiLayerProvider.overrideWithValue(layer)],
      child: const CompanyApp(),
    ),
  );
}
