import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Injected from [main] or from a test with [ProviderScope.overrides].
/// This provider does not construct a client.
final apiLayerProvider = Provider<ApiLayer>(
  (ref) => throw StateError(
    'ApiLayer must be injected with apiLayerProvider.overrideWithValue',
  ),
);
