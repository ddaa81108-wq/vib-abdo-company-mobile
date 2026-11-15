import 'package:flutter/widgets.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/widgets/common.dart';
import 'session_providers.dart';

/// Signed-out routes must not paint [ForbiddenPane].
///
/// Logout publishes [SessionUnauthenticated] and then clears permissions.
/// A section that only asked `canRead` would treat that empty grant as
/// «القسم غير مصرح لهذا الحساب» for a frame, or for as long as a 403 from an
/// in-flight request was still the latest error. A signed-out session returns
/// an empty box. The router has already been told to open `/login`.
///
/// Returns null when the signed-in user is [allowed] and the screen should
/// build. [denied] is the signed-in denial; it defaults to [ForbiddenPane].
Widget? sectionGate(
  WidgetRef ref, {
  required bool allowed,
  Widget denied = const ForbiddenPane(),
}) {
  final session = ref.watch(sessionStateProvider);
  if (session is! SessionAuthenticated) {
    return const SizedBox.shrink(key: Key('signed-out-section'));
  }
  if (!allowed) return denied;
  return null;
}
