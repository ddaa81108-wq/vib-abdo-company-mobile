import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_api_layer/api_layer.dart';

/// `generation` then role. An empty role line means the window must lock.
String captureIntentText({required int generation, String? role}) =>
    '$generation\n${role ?? ''}\n';

/// Writes the capture intent where Android reads it without the method channel.
abstract class CaptureIntentSink {
  void write({required int generation, String? role});
}

class FileCaptureIntentSink implements CaptureIntentSink {
  FileCaptureIntentSink([String? path])
    : _file = File(path ?? '/data/user/0/com.vip2100.vib/files/capture-intent.txt');

  final File _file;

  @override
  void write({required int generation, String? role}) {
    _file.parent.createSync(recursive: true);
    _file.writeAsStringSync(
      captureIntentText(generation: generation, role: role),
      flush: true,
    );
  }
}

class MemoryCaptureIntentSink implements CaptureIntentSink {
  int? generation;
  String? role;

  @override
  void write({required int generation, String? role}) {
    this.generation = generation;
    this.role = role;
  }
}

/// Repeats the last allow so the last-resort native hold does not lock a
/// live session. Logout does not wait for that hold: the intent file and
/// the channel update are written first. The hold remains only when both
/// of those updates are lost.
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
    CaptureIntentSink? intent,
    this.refreshInterval = const Duration(milliseconds: 500),
  }) : _channel = channel ?? const MethodChannel('app/screen_security'),
       _ticker = ticker ?? PeriodicTicker(),
       _intent = intent ?? FileCaptureIntentSink();

  final MethodChannel _channel;
  final CaptureTicker _ticker;
  final CaptureIntentSink _intent;
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
    try {
      _intent.write(generation: generation, role: verified);
    } catch (_) {
      // The channel update still runs. The hold is the remaining backstop.
    }
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
