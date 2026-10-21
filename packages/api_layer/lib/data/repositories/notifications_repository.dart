import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../models/common.dart';
import '../models/notification_models.dart';

/// Badge rule: the count shown is ALWAYS the server's `unreadCount`, refetched after
/// read / read-all / any realtime signal. Never incremented or decremented locally.
abstract interface class NotificationsRepository {
  Future<NotificationsPage> list({String? before});
  Future<NotificationWriteResult> markRead(String id, {String? requestId});
  Future<NotificationWriteResult> markAllRead({String? requestId});

  /// No dedicated endpoint is called by the bell today: reads `unreadCount` from
  /// the first page of GET /api/notifications. Null when the server omits it.
  Future<int?> fetchUnreadCount();

  /// 🔶 GET /api/notifications/unread-count. The matrix lists the path as
  /// declared and not called. Throws when `unreadCount` is missing so the
  /// client does not invent 0.
  Future<int> serverUnreadCount();

  /// Drops stored write results. The controller calls this when the session
  /// user changes so a reused request id cannot answer as the previous account.
  void clearWriteCache();

  Future<Json> preferences();
  Future<Json> updatePreferences(Json prefs);
}

class RemoteNotificationsRepository implements NotificationsRepository {
  RemoteNotificationsRepository(this._api);
  final ApiClient _api;

  final Map<String, NotificationWriteResult> _writes = {};

  /// Request ids that reached HTTP, in send order. A cache replay is not added.
  /// Tests use this to prove a retry keeps the same id. The id is not on the wire.
  final List<String> attemptedWriteRequestIds = [];

  @override
  void clearWriteCache() => _writes.clear();

  @override
  Future<NotificationsPage> list({String? before}) async =>
      NotificationsPage.fromData((await _api
              .get(ApiEndpoints.notifications, query: {'before': before}))
          .data);

  @override
  Future<NotificationWriteResult> markRead(
    String id, {
    String? requestId,
  }) async {
    final cached = _cached(requestId);
    if (cached != null) return cached;
    // The current client sends PATCH with an empty body. 🔶 requestId is not
    // sent: other mutations put it in the JSON body, and this route has no body.
    if (requestId != null) attemptedWriteRequestIds.add(requestId);
    final result = NotificationWriteResult.fromData(
      (await _api.patch(ApiEndpoints.notificationRead(id))).data,
    );
    _remember(requestId, result);
    return result;
  }

  @override
  Future<NotificationWriteResult> markAllRead({String? requestId}) async {
    final cached = _cached(requestId);
    if (cached != null) return cached;
    if (requestId != null) attemptedWriteRequestIds.add(requestId);
    final result = NotificationWriteResult.fromData(
      (await _api.post(ApiEndpoints.notificationsReadAll)).data,
    );
    _remember(requestId, result);
    return result;
  }

  @override
  Future<int?> fetchUnreadCount() async => (await list()).unreadCount;

  @override
  Future<int> serverUnreadCount() async {
    final data =
        (await _api.get(ApiEndpoints.proposedUnreadCount)).data;
    final count = data is int ? data : intOrNull(asJson(data)['unreadCount']);
    if (count == null) {
      throw const InvalidServerResponseException(
        message: 'استجابة الخادم غير صالحة (عدد الإشعارات)',
      );
    }
    return count;
  }

  @override
  Future<Json> preferences() async =>
      asJson((await _api.get(ApiEndpoints.notificationPreferences)).data);

  @override
  Future<Json> updatePreferences(Json prefs) async => asJson(
      (await _api.patch(ApiEndpoints.notificationPreferences, body: prefs))
          .data);

  NotificationWriteResult? _cached(String? requestId) {
    if (requestId == null || requestId.isEmpty) return null;
    return _writes[requestId];
  }

  void _remember(String? requestId, NotificationWriteResult result) {
    if (requestId == null || requestId.isEmpty) return;
    _writes[requestId] = result;
  }
}
