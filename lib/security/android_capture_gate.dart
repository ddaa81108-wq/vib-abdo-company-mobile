import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_api_layer/api_layer.dart';

/// Repeats the last allow so the native hold does not lock a live session.
///
/// The native hold is 2000ms ([CaptureLock.DEFAULT_HOLD_MS]). This refresh
/// stays shorter than that hold.
abstract class CaptureTicker {
  void start(Duration interval, void Function() onTick);
  void stop();
}

class PeriodicTicker implements CaptureTicker {
  Timer? _timer;

  @override
  void start(Duration interval, void Function() onTick) {
    stop();
    _timer = Timer.periodic(interval, (_) => onTick());
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Sends the verified role to Android. Release clears FLAG_SECURE only for
/// an exact admin or employee role, and only until the native hold expires.
/// A debug build ignores the role and stays capturable. There is no method
/// that clears the flag by itself.
class AndroidCaptureGate implements SessionCaptureGate {
  AndroidCaptureGate({
    MethodChannel? channel,
    CaptureTicker? ticker,
    this.refreshInterval = const Duration(milliseconds: 500),
  }) : _channel = channel ?? const MethodChannel('app/screen_security'),
       _ticker = ticker ?? PeriodicTicker();

  final MethodChannel _channel;
  final CaptureTicker _ticker;
  final Duration refreshInterval;
  int _appliedGeneration = -1;

  @override
  Future<void> secure({required int generation}) async {
    _ticker.stop();
    try {
      await _send(generation: generation, role: null);
    } catch (_) {
      await _retrySecure(generation);
    }
  }

  @override
  Future<void> applySession({
    required int generation,
    required SessionState state,
  }) async {
    final role = releaseVerifiedRole(state);
    if (role == null) {
      await secure(generation: generation);
      return;
    }
    try {
      await _send(generation: generation, role: role);
      _arm(generation, role);
    } catch (_) {
      _ticker.stop();
      await _retrySecure(generation);
    }
  }

  void dispose() => _ticker.stop();

  void _arm(int generation, String role) {
    _ticker.start(refreshInterval, () {
      unawaited(_refresh(generation, role));
    });
  }

  Future<void> _refresh(int generation, String role) async {
    if (generation < _appliedGeneration) return;
    try {
      await _send(generation: generation, role: role);
    } catch (_) {
      // The native hold is not extended when this refresh does not land.
    }
  }

  Future<void> _retrySecure(int generation) async {
    if (generation < _appliedGeneration) return;
    try {
      await _send(generation: generation, role: null, force: true);
    } catch (_) {}
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
