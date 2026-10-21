import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/notifications/notification_opener.dart';
import '../state/session_providers.dart';
import 'android_notification_setup.dart';
import 'device_token_registrar.dart';
import 'push_providers.dart';
import 'system_tray_tap.dart';

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
      final present = ref
          .read(systemTrayPresenterProvider)
          .presentPush(payload);
      // presentPush returns a delivery for session errors. This still swallows
      // a throw so the unawaited call cannot surface an uncaught async error.
      unawaited(present.then<void>((_) {}, onError: (_, _) {}));
    });
    unawaited(
      AndroidNotificationSetup.start(
        onSelect: (payload) {
          if (!mounted) return;
          unawaited(
            ref.read(systemTrayTapHandlerProvider).openPayload(payload),
          );
        },
      ),
    );
    final session = ref.read(sessionStateProvider);
    unawaited(_sync(const SessionPhase.signedOut(), phaseOf(session), session));
  }

  Future<void> _sync(
    SessionPhase previous,
    SessionPhase next,
    SessionState? state,
  ) async {
    await syncPushRegistration(
      previous: previous,
      next: next,
      registrar: ref.read(deviceTokenRegistrarProvider),
    );
    if (!mounted) return;
    if (state is! SessionAuthenticated) return;
    await ref.read(backgroundNotificationSchedulerProvider).start();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionStateProvider, (previous, next) {
      unawaited(_sync(phaseOf(previous), phaseOf(next), next));
      if (next is! SessionAuthenticated) return;
      // After the router's own redirect, so a preserved tap is not overwritten
      // by the login → home redirect.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(ref.read(notificationOpenerProvider).resumePending());
        unawaited(ref.read(systemTrayTapHandlerProvider).resume());
      });
    });
    ref.listen(startupProvider, (previous, next) {
      if (!next.hasValue) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(ref.read(notificationOpenerProvider).resumePending());
        unawaited(ref.read(systemTrayTapHandlerProvider).resume());
      });
    });
    return widget.child;
  }
}
