import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/app_push_service.dart';
import '../secure_storage/app_secure_stores.dart';

/// Build-time configuration. Defaults to the in-memory fake client.
final apiConfigProvider = Provider<ApiConfig>(
  (ref) => ApiConfig.fromEnvironment(),
);

/// Composition root. Features read repositories from this object.
final apiLayerProvider = Provider<ApiLayer>((ref) {
  final stores = ref.watch(secureStoresProvider);
  final layer = ApiLayer.create(
    config: ref.watch(apiConfigProvider),
    cookieStore: stores.cookies,
    tokenStorage: stores.tokens,
    push: ref.watch(pushServiceProvider),
  );
  ref.onDispose(layer.dispose);
  return layer;
});
