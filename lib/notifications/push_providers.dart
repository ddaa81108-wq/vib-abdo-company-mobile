import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';
import '../state/notification_providers.dart';
import '../state/session_providers.dart';
import 'background_poll.dart';
import 'background_scheduler.dart';
import 'device_registration_client.dart';
import 'device_token_registrar.dart';
import 'device_token_store.dart';
import 'local_notification_poster.dart';
import 'notification_dedup.dart';
import 'notification_ingress.dart';
import 'notification_permission_service.dart';
import 'push_drop_log.dart';
import 'push_transport.dart';

final notificationDedupProvider = Provider<NotificationIdDedup>(
  (ref) => NotificationIdDedup(),
);

final pushDropLogProvider = Provider<PushDropLog>((ref) => PushDropLog());

/// Noop unless `PUSH_TRANSPORT` is `fake` or `fcm`. Tests override this.
final pushTransportProvider = Provider<PushTransport>(
  (ref) => createPushTransport(kPushTransportName),
);

/// Stub. Granted is false until the UI dev overrides this provider.
final notificationPermissionProvider = Provider<NotificationPermissionService>(
  (ref) => const StubNotificationPermissionService(),
);

/// Memory by default so a test that forgets an override does not touch the
/// keystore. [main] overrides this with [SecureDeviceTokenStore].
final deviceTokenStoreProvider = Provider<DeviceTokenStore>(
  (ref) => MemoryDeviceTokenStore(),
);

/// The object [main] passes into the session wipe. Tests that drive logout
/// must override this with the same instance they put in `cleanups`.
final pushSessionGateProvider = Provider<PushSessionGate>(
  (ref) => PushSessionGate(),
);

final deviceRegistrationClientProvider = Provider<DeviceRegistrationClient>(
  (ref) => HttpDeviceRegistrationClient(ref.watch(apiLayerProvider).client),
);

final localNotificationPosterProvider = Provider<LocalNotificationPoster>(
  (ref) => const SilentLocalNotificationPoster(),
);

/// Off unless `BACKGROUND_NOTIFICATION_POLL=true`. Tests override the bool.
final backgroundPollEnabledProvider = Provider<bool>(
  (ref) => kBackgroundNotificationPoll,
);

final notificationIngressProvider = Provider<NotificationIngress>((ref) {
  final dedup = ref.watch(notificationDedupProvider);
  final drops = ref.watch(pushDropLogProvider);
  return NotificationIngress(
    userId: () {
      final session = ref.read(sessionStateProvider);
      if (session is! SessionAuthenticated) return null;
      return session.profile.id;
    },
    dedup: dedup,
    drops: drops,
    ingest: (items, source) =>
        ref.read(notificationsProvider.notifier).ingest(items, source: source),
  );
});

/// Poll and scheduler together. Building them in one place avoids a provider
/// cycle: the poll cancels the scheduler, and the scheduler runs the poll.
final backgroundRuntimeProvider = Provider<_BackgroundRuntime>((ref) {
  final enabled = ref.watch(backgroundPollEnabledProvider);
  final ingress = ref.watch(notificationIngressProvider);
  final poster = ref.watch(localNotificationPosterProvider);

  String? user() {
    final session = ref.read(sessionStateProvider);
    if (session is! SessionAuthenticated) return null;
    return session.profile.id;
  }

  Future<NotificationsPage> load() =>
      ref.read(apiLayerProvider).notifications.list();

  if (!enabled) {
    return _BackgroundRuntime(
      poll: BackgroundNotificationPoll(
        enabled: false,
        userId: user,
        load: load,
        ingress: ingress,
        poster: poster,
        cancelScheduler: () async {},
      ),
      scheduler: const NoopBackgroundNotificationScheduler(),
    );
  }

  late final InProcessBackgroundNotificationScheduler scheduler;
  final poll = BackgroundNotificationPoll(
    enabled: true,
    userId: user,
    load: load,
    ingress: ingress,
    poster: poster,
    cancelScheduler: () => scheduler.cancel(),
  );
  scheduler = InProcessBackgroundNotificationScheduler(poll: poll.run);
  return _BackgroundRuntime(poll: poll, scheduler: scheduler);
});

final backgroundNotificationPollProvider = Provider<BackgroundNotificationPoll>(
  (ref) => ref.watch(backgroundRuntimeProvider).poll,
);

final backgroundNotificationSchedulerProvider =
    Provider<BackgroundNotificationScheduler>(
      (ref) => ref.watch(backgroundRuntimeProvider).scheduler,
    );

class _BackgroundRuntime {
  const _BackgroundRuntime({required this.poll, required this.scheduler});

  final BackgroundNotificationPoll poll;
  final BackgroundNotificationScheduler scheduler;
}

final deviceTokenRegistrarProvider = Provider<DeviceTokenRegistrar>((ref) {
  final registrar = DeviceTokenRegistrar(
    transport: ref.watch(pushTransportProvider),
    permission: ref.watch(notificationPermissionProvider),
    store: ref.watch(deviceTokenStoreProvider),
    client: ref.watch(deviceRegistrationClientProvider),
    dedup: ref.watch(notificationDedupProvider),
    onCancelBackground: () =>
        ref.read(backgroundNotificationSchedulerProvider).cancel(),
  );
  final gate = ref.watch(pushSessionGateProvider);
  gate.onForget = registrar.forget;
  ref.onDispose(() {
    if (identical(gate.onForget, registrar.forget)) gate.onForget = null;
  });
  return registrar;
});

SessionPhase phaseOf(SessionState? session) {
  if (session is SessionAuthenticated) {
    return SessionPhase(userId: session.profile.id);
  }
  return const SessionPhase.signedOut();
}
