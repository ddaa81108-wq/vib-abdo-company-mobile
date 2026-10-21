import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/notifications/notification_opener.dart';
import '../state/session_providers.dart';
import 'device_token_registrar.dart';
import 'push_providers.dart';

/// Binds the wipe gate, the push stream, and a cold-start tap.
///
/// Realtime start and stop stay in [RealtimeLifecycle]. This host does not
/// change his notification controller.
class NotificationTransportHost extends ConsumerStatefulWidget {
  const NotificationTransportHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NotificationTransportHost> createState() =>
      _NotificationTransportHostState();
}

class _NotificationTransportHostState
    extends ConsumerState<NotificationTransportHost> {
  StreamSubscription<Map<String, dynamic>>? _pushes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bind();
    });
  }

  @override
  void dispose() {
    _pushes?.cancel();
    super.dispose();
  }

  void _bind() {
    ref.read(deviceTokenRegistrarProvider);
    _pushes ??= ref.read(pushTransportProvider).payloads.listen((payload) {
      ref.read(notificationIngressProvider).acceptPush(payload);
    });
    final session = ref.read(sessionStateProvider);
    unawaited(
      syncPushRegistration(
        previous: const SessionPhase.signedOut(),
        next: phaseOf(session),
        registrar: ref.read(deviceTokenRegistrarProvider),
      ),
    );
    if (session is SessionAuthenticated) {
      unawaited(ref.read(backgroundNotificationSchedulerProvider).start());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionStateProvider, (previous, next) {
      unawaited(
        syncPushRegistration(
          previous: phaseOf(previous),
          next: phaseOf(next),
          registrar: ref.read(deviceTokenRegistrarProvider),
        ),
      );
      if (next is! SessionAuthenticated) return;
      unawaited(ref.read(backgroundNotificationSchedulerProvider).start());
      // After the router's own redirect, so a preserved tap is not overwritten
      // by the login → home redirect.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(ref.read(notificationOpenerProvider).resumePending());
      });
    });
    ref.listen(startupProvider, (previous, next) {
      if (!next.hasValue) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(ref.read(notificationOpenerProvider).resumePending());
      });
    });
    return widget.child;
  }
}
