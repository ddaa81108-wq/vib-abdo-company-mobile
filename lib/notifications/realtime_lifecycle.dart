import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';
import '../error_handling/error_handler.dart';
import '../state/notification_providers.dart';
import '../state/section_providers.dart';
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
  void didChangeAppLifecycleState(AppLifecycleState state) => _sync();

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
            await ref
                .read(notificationsProvider.notifier)
                .refresh(announce: true);
          } catch (error, stackTrace) {
            ref.read(errorHandlerProvider).report(error, stackTrace);
          }
        },
      );
      _signals = layer.realtime.signals.listen((signal) {
        // Signal only. Counts and cards are whatever the next fetch returns.
        // A notification-related refresh refetches the list. It does not
        // ingest the event payload.
        ref.invalidate(unreadCountProvider);
        ref.invalidate(homeDashboardProvider);
        ref.invalidate(collectionsProvider);
        ref.invalidate(ledgerProvider);
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
