import '../config/api_config.dart';
import '../config/release_fake_api_guard.dart';
import 'fake_stack_parts.dart';

/// Linked only when `dart.vm.product` is set (Flutter release).
///
/// This library does not import the fake client or the demo fixtures, so those
/// strings are not part of the release compilation.
FakeStackParts buildFakeStack({
  required ApiConfig config,
  Duration? fakeLatency,
}) {
  throw StateError(releaseFakeApiRejectedMessage);
}
