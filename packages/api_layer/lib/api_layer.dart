/// Composition root for the API layer. UI (Riverpod providers) depends on what is exposed here.
library;

import 'core/auth/cookie_store.dart';
import 'core/config/api_config.dart';
import 'core/money/money_formatter.dart';
import 'core/network/api_client.dart';
import 'core/network/api_client_factory.dart';
import 'core/permissions/permission_service.dart';
import 'core/push/push_service.dart';
import 'core/realtime/polling_realtime_service.dart';
import 'core/realtime/realtime_service.dart';
import 'core/realtime/resilient_realtime_service.dart';
import 'core/realtime/sse_realtime_service.dart';
import 'core/session/session_manager.dart';
import 'core/session/token_storage.dart';
import 'data/repositories/accounts_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/collections_repository.dart';
import 'data/repositories/home_repository.dart';
import 'data/repositories/masraweya_repository.dart';
import 'data/repositories/notifications_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'data/repositories/purchases_repository.dart';
import 'data/repositories/reports_repository.dart';
import 'data/repositories/treasury_repository.dart';

export 'core/auth/cookie_store.dart';
export 'core/config/api_config.dart';
export 'core/money/money_formatter.dart';
export 'core/network/api_exception.dart';
export 'core/network/reachability.dart';
export 'core/network/idempotency.dart';
export 'core/permissions/permission_codes.dart';
export 'core/permissions/permission_service.dart';
export 'core/push/push_service.dart';
export 'core/realtime/realtime_service.dart';
export 'core/security/redactor.dart';
export 'core/session/session_manager.dart';
export 'core/session/token_storage.dart';
export 'data/models/account_models.dart';
export 'data/models/auth_models.dart';
export 'data/models/collection_models.dart';
export 'data/models/common.dart';
export 'data/models/home_models.dart';
export 'data/models/masraweya_models.dart';
export 'data/models/notification_models.dart';
export 'data/models/profile_models.dart';
export 'data/models/purchase_models.dart';
export 'data/models/report_models.dart';
export 'data/models/treasury_models.dart';

class ApiLayer {
  ApiLayer._({
    required this.client,
    required this.permissions,
    required this.session,
    required this.realtime,
    required this.push,
    required this.money,
    required this.auth,
    required this.profile,
    required this.accounts,
    required this.collections,
    required this.masraweya,
    required this.purchases,
    required this.treasury,
    required this.reports,
    required this.notifications,
    required this.home,
    required this.useFakeApi,
  });

  final ApiClient client;
  final PermissionService permissions;
  final SessionManager session;
  final RealtimeService realtime;
  final PushService push;
  final MoneyFormatter money;
  final AuthRepository auth;
  final ProfileRepository profile;
  final AccountsRepository accounts;
  final CollectionsRepository collections;
  final MasraweyaRepository masraweya;
  final PurchasesRepository purchases;
  final TreasuryRepository treasury;
  final ReportsRepository reports;
  final NotificationsRepository notifications;
  final HomeRepository home;

  /// True only for the in-memory client. Real mode never calls proposed paths.
  final bool useFakeApi;

  static ApiLayer create({
    ApiConfig? config,
    List<SessionCleanup> cleanups = const [],
    PushService push = const NoopPushService(),
    CookieStore? cookieStore,
    TokenStorage? tokenStorage,
    Duration? fakeLatency,
  }) {
    final cfg = config ?? ApiConfig.fromEnvironment();
    final permissions = PermissionService();

    // Late-bound to break the cycle: interceptor -> session.forceLogout.
    SessionManager? sessionRef;
    final stack = ApiStack.build(
      config: cfg,
      onForcedLogout: (reason) async {
        await sessionRef?.forceLogout(reason);
      },
      cookieStore: cookieStore,
      tokenStorage: tokenStorage,
      fakeLatency: fakeLatency,
    );
    final api = stack.client;

    final cursor = SequenceCursor();
    final dio = stack.dio;
    final RealtimeService realtime = dio == null
        ? NoopRealtimeService()
        : ResilientRealtimeService(
            sse: SseRealtimeService(dio: dio, cursor: cursor),
            polling: PollingRealtimeService(
              api: api,
              cursor: cursor,
              interval: cfg.pollingInterval,
            ),
          );

    final auth = RemoteAuthRepository(api);
    final profile = RemoteProfileRepository(api);
    final session = SessionManager(
      authStrategy: stack.strategy,
      authRepository: auth,
      profileRepository: profile,
      permissionService: permissions,
      cleanups: [
        () async {
          await realtime.stop();
          cursor.reset();
          if (realtime is ResilientRealtimeService) realtime.reset();
        },
        push.deleteToken,
        // The active strategy wipes only the store it uses. main() always
        // creates both, so a leftover cookie or token would survive logout
        // and session expiry when the other strategy is selected.
        () async {
          await cookieStore?.clear();
          await tokenStorage?.clear();
        },
        ...cleanups,
      ],
    );
    sessionRef = session;

    return ApiLayer._(
      client: api,
      permissions: permissions,
      session: session,
      realtime: realtime,
      push: push,
      money: MoneyFormatter(unitScale: cfg.moneyUnitScale),
      auth: auth,
      profile: profile,
      accounts: RemoteAccountsRepository(api),
      collections: RemoteCollectionsRepository(api),
      masraweya: RemoteMasraweyaRepository(api),
      purchases: RemotePurchasesRepository(api),
      treasury: RemoteTreasuryRepository(api),
      reports: RemoteReportsRepository(api),
      notifications: RemoteNotificationsRepository(api),
      home: RemoteHomeRepository(api),
      useFakeApi: cfg.useFakeApi,
    );
  }

  /// Stops realtime delivery and releases the session listenable.
  Future<void> dispose() async {
    try {
      await realtime.stop();
    } catch (_) {}
    await session.dispose();
  }
}
