import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live connectivity. Widget tests override this with [FixedConnectivity].
abstract class ConnectivityPort {
  Future<bool> current();
  Stream<bool> watch();
}

class ToggleConnectivity implements ConnectivityPort {
  ToggleConnectivity([this.online = true]);

  bool online;
  final _updates = StreamController<bool>.broadcast();

  @override
  Future<bool> current() async => online;

  @override
  Stream<bool> watch() {
    return Stream<bool>.multi((listener) {
      listener.add(online);
      final sub = _updates.stream.listen(
        listener.add,
        onError: listener.addError,
        onDone: listener.close,
      );
      listener.onCancel = sub.cancel;
    });
  }

  void setOnline(bool value) {
    online = value;
    _updates.add(value);
  }
}

class FixedConnectivity implements ConnectivityPort {
  const FixedConnectivity(this.online);
  final bool online;

  @override
  Future<bool> current() async => online;

  @override
  Stream<bool> watch() => Stream<bool>.value(online);
}

/// Platform network state when the OS can report it.
///
/// When that channel is missing, the fallback is the last API call: success
/// stays online, a transport failure goes offline. No public host is contacted.
class PlatformConnectivity implements ConnectivityPort {
  static const _channel = MethodChannel('app/connectivity');

  @override
  Future<bool> current() async {
    final platform = await _platformOnline();
    if (platform != null) return platform;
    return ApiReachability.instance.lastSucceeded ?? true;
  }

  @override
  Stream<bool> watch() async* {
    yield await current();
    final platform = await _platformOnline();
    if (platform == null) {
      yield* ApiReachability.instance.updates;
      return;
    }
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 8));
      yield await current();
    }
  }

  Future<bool?> _platformOnline() async {
    try {
      return await _channel.invokeMethod<bool>('isOnline');
    } catch (_) {
      return null;
    }
  }
}

final connectivityPortProvider = Provider<ConnectivityPort>(
  (ref) => PlatformConnectivity(),
);
