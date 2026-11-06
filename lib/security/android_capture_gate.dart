import 'package:flutter/services.dart';
import 'package:flutter_api_layer/api_layer.dart';

/// Sends the verified role to Android. Release clears FLAG_SECURE only for
/// an exact admin or employee role. A debug build ignores the role and
/// stays capturable. There is no method that clears the flag by itself.
class AndroidCaptureGate implements SessionCaptureGate {
  AndroidCaptureGate({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('app/screen_security');

  final MethodChannel _channel;
  int _appliedGeneration = -1;

  @override
  Future<void> secure({required int generation}) async {
    try {
      await _send(generation: generation, role: null);
    } catch (_) {
      if (generation < _appliedGeneration) return;
      try {
        await _send(generation: generation, role: null, force: true);
      } catch (_) {}
    }
  }

  @override
  Future<void> applySession({
    required int generation,
    required SessionState state,
  }) async {
    try {
      await _send(generation: generation, role: releaseVerifiedRole(state));
    } catch (_) {
      if (generation < _appliedGeneration) return;
      try {
        await _send(generation: generation, role: null, force: true);
      } catch (_) {}
    }
  }

  Future<void> _send({
    required int generation,
    required String? role,
    bool force = false,
  }) async {
    if (!force && generation < _appliedGeneration) return;
    if (generation > _appliedGeneration) _appliedGeneration = generation;
    final verified = PermissionService.verifiedCaptureRole(role);
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (!force && generation < _appliedGeneration) return;
      try {
        await _channel.invokeMethod<void>('applyVerifiedRole', {
          'generation': generation,
          'role': verified,
        });
        return;
      } catch (error) {
        lastError = error;
      }
    }
    Error.throwWithStackTrace(
      lastError ?? StateError('capture channel failed'),
      StackTrace.current,
    );
  }
}
