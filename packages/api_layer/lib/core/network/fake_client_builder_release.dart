import '../auth/cookie_store.dart';
import '../config/api_config.dart';
import '../config/release_fake_api_guard.dart';
import '../session/token_storage.dart';
import 'fake_stack_parts.dart';

Future<void> _ignoreLogout(String _) async {}

/// Linked only when `dart.vm.product` is set (Flutter release).
///
/// This library does not import the fake client or the demo fixtures, so those
/// strings are not part of the release compilation.
FakeStackParts buildFakeStack({
  required ApiConfig config,
  Duration? fakeLatency,
  Future<void> Function(String reason) onForcedLogout = _ignoreLogout,
  CookieStore? cookieStore,
  TokenStorage? tokenStorage,
  String? fakeDataset,
}) {
  // Same signature as the debug builder. This file does not import the
  // catalog and does not read a dataset define.
  if (fakeDataset != null) {
    throw StateError(releaseFakeApiRejectedMessage);
  }
  throw StateError(releaseFakeApiRejectedMessage);
}
