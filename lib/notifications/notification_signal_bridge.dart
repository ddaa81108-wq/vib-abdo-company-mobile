import 'dart:async';

import 'package:flutter_api_layer/api_layer.dart';

/// Turns realtime signals into one coalesced `refresh(announce: true)`.
///
/// The connect resync is skipped so the controller's initial load stays
/// quiet (`announce: false`). Later signals never pass the event payload
/// into ingest.
/// A delayed call the bridge can cancel. Production uses [Timer].
abstract interface class DelayHandle {
  void cancel();
}

class _TimerDelay implements DelayHandle {
  _TimerDelay(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

typedef DelayStarter = DelayHandle Function(
  Duration delay,
  void Function() callback,
);

class NotificationSignalBridge {
  NotificationSignalBridge({
    required this.refresh,
    this.wait = const Duration(milliseconds: 400),
    DelayStarter? startDelay,
  }) : _startDelay = startDelay ?? _timerDelay;

  final Future<void> Function() refresh;
  final Duration wait;
  final DelayStarter _startDelay;
  DelayHandle? _pending;
  var _skippedConnect = false;
  int refreshCalls = 0;

  static DelayHandle _timerDelay(Duration delay, void Function() callback) {
    return _TimerDelay(Timer(delay, callback));
  }

  void onSignal(RealtimeSignal signal) {
    if (signal.fullResync && !_skippedConnect) {
      _skippedConnect = true;
      return;
    }
    _pending?.cancel();
    _pending = _startDelay(wait, () {
      _pending = null;
      refreshCalls++;
      refresh();
    });
  }

  void stop() {
    _pending?.cancel();
    _pending = null;
  }

  void reset() {
    stop();
    _skippedConnect = false;
  }
}
