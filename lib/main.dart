import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_providers.dart';
import 'app.dart';
import 'error_handling/error_handler.dart';
import 'notifications/app_push_service.dart';
import 'secure_storage/app_secure_stores.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const errors = ErrorHandler();
  FlutterError.onError = (details) {
    errors.report(details.exception, details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    errors.report(error, stack);
    return true;
  };

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
