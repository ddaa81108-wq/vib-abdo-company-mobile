import 'dart:async';

/// Periodic notification poll. The default is a no-op.
///
/// `workmanager` is not a dependency. A background isolate plus a shade
/// plugin would pull `POST_NOTIFICATIONS` into the manifest, and that
/// permission belongs to the UI dev. The flag
/// `BACKGROUND_NOTIFICATION_POLL` stays off until backend question 9
/// (a cookie from a background process with no Origin and no CSRF).
abstract interface class BackgroundNotificationScheduler {
  bool get enabled;

  /// Android's periodic floor. Schedulers must not use a shorter period.
  Duration get minInterval;

  Future<void> start();
  Future<void> cancel();
}

/// Selected when the flag is off. [start] does not schedule work.
class NoopBackgroundNotificationScheduler
    implements BackgroundNotificationScheduler {
  const NoopBackgroundNotificationScheduler();

  @override
  bool get enabled => false;

  @override
  Duration get minInterval => const Duration(minutes: 15);

  @override
  Future<void> start() async {}

  @override
  Future<void> cancel() async {}
}

/// In-process stand-in used only when the flag is on.
///
/// It does not survive process death. A later WorkManager callback should
/// call the same poll function and then [cancel] on 401 or 419.
class InProcessBackgroundNotificationScheduler
    implements BackgroundNotificationScheduler {
  InProcessBackgroundNotificationScheduler({
    required this.poll,
    this.minInterval = const Duration(minutes: 15),
  });

  final Future<void> Function() poll;

  @override
  final Duration minInterval;

  Timer? _timer;

  @override
  bool get enabled => true;

  bool get started => _timer != null;

  @override
  Future<void> start() async {
    if (minInterval < const Duration(minutes: 15)) {
      throw StateError('Background poll interval is below 15 minutes.');
    }
    _timer?.cancel();
    _timer = Timer.periodic(minInterval, (_) {
      poll();
    });
  }

  @override
  Future<void> cancel() async {
    _timer?.cancel();
    _timer = null;
  }

  /// One poll, the body a WorkManager worker would run.
  Future<void> tick() => poll();
}
