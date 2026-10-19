import 'dart:async';

import 'polling_realtime_service.dart';
import 'realtime_service.dart';
import 'sse_realtime_service.dart';

/// SSE first; polling every 4s whenever SSE is disconnected. Merged signal stream,
/// de-duplicated by sequence. Consumers ONLY invalidate/refetch on a signal.
class ResilientRealtimeService implements RealtimeService {
  ResilientRealtimeService(
      {required SseRealtimeService sse,
      required PollingRealtimeService polling})
      : _sse = sse,
        _polling = polling;

  final SseRealtimeService _sse;
  final PollingRealtimeService _polling;
  final _out = StreamController<RealtimeSignal>.broadcast();
  final List<StreamSubscription<dynamic>> _subs = [];
  int _lastEmitted = 0;
  bool _running = false;

  @override
  Stream<RealtimeSignal> get signals => _out.stream;

  @override
  RealtimeMode get mode => !_running
      ? RealtimeMode.stopped
      : (_sse.isConnected ? RealtimeMode.sse : RealtimeMode.polling);

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;
    _subs
      ..add(_sse.signals.listen(_forward))
      ..add(_polling.signals.listen(_forward))
      ..add(_sse.connection.listen(
          (connected) => connected ? _polling.stop() : _polling.start()));
    await _polling.start(); // until SSE reports connected
    await _sse.start();
  }

  void _forward(RealtimeSignal s) {
    if (s.fullResync) {
      _out.add(s);
      return;
    }
    if (s.sequence <= _lastEmitted) return;
    _lastEmitted = s.sequence;
    _out.add(s);
  }

  @override
  Future<void> stop() async {
    _running = false;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _sse.stop();
    await _polling.stop();
  }

  /// Logout: forget the cursor dedup state.
  void reset() => _lastEmitted = 0;
}

/// Fake mode / tests.
class NoopRealtimeService implements RealtimeService {
  @override
  Stream<RealtimeSignal> get signals => const Stream.empty();
  @override
  RealtimeMode get mode => RealtimeMode.stopped;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
}
