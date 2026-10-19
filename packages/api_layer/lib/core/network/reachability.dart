import 'dart:async';

/// Outcome of the last API call that either succeeded or failed in transport.
///
/// Used only when the platform cannot report a network. This never looks up a
/// public host.
class ApiReachability {
  ApiReachability._();

  static final instance = ApiReachability._();

  bool? lastSucceeded;
  final _updates = StreamController<bool>.broadcast();

  Stream<bool> get updates => _updates.stream;

  void recordSuccess() => _set(true);

  void recordTransportFailure() => _set(false);

  void reset() {
    lastSucceeded = null;
  }

  void _set(bool value) {
    lastSucceeded = value;
    if (!_updates.isClosed) _updates.add(value);
  }
}
