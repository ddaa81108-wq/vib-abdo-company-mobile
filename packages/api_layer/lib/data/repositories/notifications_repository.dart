import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/common.dart';
import '../models/notification_models.dart';

/// Badge rule: the count shown is ALWAYS the server's `unreadCount`, refetched after
/// read / read-all / any realtime signal. Never incremented or decremented locally.
abstract interface class NotificationsRepository {
  Future<NotificationsPage> list({String? before});
  Future<void> markRead(String id);
  Future<void> markAllRead();

  /// No dedicated endpoint exists today: reads `unreadCount` from the first page of
  /// GET /api/notifications. 🔶 Requested: a light GET /api/notifications/unread-count.
  Future<int?> fetchUnreadCount();
  Future<Json> preferences();
  Future<Json> updatePreferences(Json prefs);
}

class RemoteNotificationsRepository implements NotificationsRepository {
  RemoteNotificationsRepository(this._api);
  final ApiClient _api;

  @override
  Future<NotificationsPage> list({String? before}) async =>
      NotificationsPage.fromData((await _api
              .get(ApiEndpoints.notifications, query: {'before': before}))
          .data);

  @override
  Future<void> markRead(String id) async {
    await _api.patch(ApiEndpoints.notificationRead(id));
  }

  @override
  Future<void> markAllRead() async {
    await _api.post(ApiEndpoints.notificationsReadAll);
  }

  @override
  Future<int?> fetchUnreadCount() async => (await list()).unreadCount;

  @override
  Future<Json> preferences() async =>
      asJson((await _api.get(ApiEndpoints.notificationPreferences)).data);

  @override
  Future<Json> updatePreferences(Json prefs) async => asJson(
      (await _api.patch(ApiEndpoints.notificationPreferences, body: prefs))
          .data);
}
