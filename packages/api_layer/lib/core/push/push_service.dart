/// Mobile push abstraction (doc 04 §4). The existing system only has WEB Push
/// (/api/browser-push/*, VAPID + service worker) — NOT usable by a native app.
/// No FCM/APNs exists today. 🔶 Open question to the server owner.
/// Until then: NoopPushService + RealtimeService (SSE / polling) while the app is in foreground.
/// Rule: a push message is a SIGNAL only (type + entity id) — never numbers to display or apply.
class PushMessage {
  const PushMessage({required this.type, this.entityId});
  final String type;
  final String? entityId;
}

abstract interface class PushService {
  Future<String?> getToken();
  Stream<PushMessage> get messages;
  Future<void> deleteToken(); // called from a SessionCleanup on logout
}

class NoopPushService implements PushService {
  const NoopPushService();
  @override
  Future<String?> getToken() async => null;
  @override
  Stream<PushMessage> get messages => const Stream.empty();
  @override
  Future<void> deleteToken() async {}
}
