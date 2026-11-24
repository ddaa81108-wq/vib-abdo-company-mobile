import 'dart:async';

/// Merge committed-change invalidations within one display frame. Never delays
/// the window again when more signals arrive, and never applies event amounts.
final class LiveRefreshBatch<T> {
  LiveRefreshBatch(this.refresh);

  final void Function(List<T>) refresh;
  final _pending = <T>{};
  Timer? _timer;

  void addAll(Iterable<T> providers) {
    _pending.addAll(providers);
    if (_pending.isEmpty) return;
    _timer ??= Timer(const Duration(milliseconds: 16), () {
      _timer = null;
      final ready = _pending.toList(growable: false);
      _pending.clear();
      refresh(ready);
    });
  }

  /// Logout/dispose: no deferred read may cross the session boundary.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pending.clear();
  }
}
