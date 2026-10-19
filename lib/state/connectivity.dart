import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
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

class PlatformConnectivity implements ConnectivityPort {
  static const _channel = MethodChannel('app/connectivity');

  @override
  Future<bool> current() async {
    try {
      final online = await _channel.invokeMethod<bool>('isOnline');
      if (online != null) return online;
    } catch (_) {}
    try {
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<bool> watch() async* {
    yield await current();
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 8));
      yield await current();
    }
  }
}

final connectivityPortProvider = Provider<ConnectivityPort>(
  (ref) => PlatformConnectivity(),
);
