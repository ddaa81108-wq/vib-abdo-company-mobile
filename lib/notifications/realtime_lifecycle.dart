import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';
import '../error_handling/error_handler.dart';
import '../state/live_refresh.dart';
import '../state/notification_providers.dart';
import '../state/session_providers.dart';
import 'notification_signal_bridge.dart';

/// Starts realtime delivery while a session is open and the app is in front.
///
/// Every signal invalidates the unread-count provider. The signal payload is
/// ignored: the next count comes from a refetch.
class RealtimeLifecycle extends ConsumerStatefulWidget {
  const RealtimeLifecycle({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RealtimeLifecycle> createState() => _RealtimeLifecycleState();
}

class _RealtimeLifecycleState extends ConsumerState<RealtimeLifecycle>
    with WidgetsBindingObserver {
  StreamSubscription<RealtimeSignal>? _signals;
  StreamSubscription<PushMessage>? _pushes;
  NotificationSignalBridge? _bridge;
  var _running = false;
  var _sawBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _signals?.cancel();
    _pushes?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _sawBackground = true;
      // Anything that arrives while away is backlog, not a voice replay.
      ref.read(notificationsProvider.notifier).holdSpeech();
    }
    _sync();
    if (state == AppLifecycleState.resumed && _sawBackground) {
      _sawBackground = false;
      ref.read(notificationsProvider.notifier).holdSpeech();
      refreshAllLiveSections(ref);
    }
  }

  void _sync() {
    final session = ref.read(sessionStateProvider);
    final layer = ref.read(apiLayerProvider);
    final phase = WidgetsBinding.instance.lifecycleState;
    final foreground =
        phase != AppLifecycleState.paused &&
        phase != AppLifecycleState.detached &&
        phase != AppLifecycleState.hidden;
    final shouldRun = session is SessionAuthenticated && foreground;
    if (shouldRun && !_running) {
      _running = true;
      _bridge ??= NotificationSignalBridge(
        refresh: () async {
          try {
            // List ingest happens before the unread-count fetch. A 404 on
            // that count route does not throw and does not roll the list back.
            await ref
                .read(notificationsProvider.notifier)
                .refresh(announce: true);
          } catch (error, stackTrace) {
            ref.read(errorHandlerProvider).report(error, stackTrace);
          }
        },
      );
      _signals = layer.realtime.signals.listen((signal) {
        // Signal only. The topic chooses which cached reads to drop.
        // The payload is never applied. The notification bridge refetches
        // the list and does not ingest the event.
        applyLiveSignal(
          ref,
          RealtimeSignalView(
            topic: signal.topic,
            fullResync: signal.fullResync,
          ),
        );
        _bridge?.onSignal(signal);
      });
      _pushes = layer.push.messages.listen((_) {
        ref.invalidate(unreadCountProvider);
      });
      layer.realtime.start().catchError((Object error, StackTrace stackTrace) {
        ref.read(errorHandlerProvider).report(error, stackTrace);
      });
    } else if (!shouldRun && _running) {
      _running = false;
      _signals?.cancel();
      _pushes?.cancel();
      _signals = null;
      _pushes = null;
      _bridge?.reset();
      layer.realtime.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SessionState>(sessionStateProvider, (previous, next) => _sync());
    return widget.child;
  }
}
