import 'package:flutter_api_layer/api_layer.dart';

/// Push boundary for the app.
///
/// The current implementation is a no-op: there is no device push token yet.
/// A future message is a signal only. The unread badge is never taken from it;
/// the notifications provider refetches the server count instead.
class AppPushService implements PushService {
  AppPushService([PushService inner = const NoopPushService()])
    : _inner = inner;

  final PushService _inner;

  @override
  Future<String?> getToken() => _inner.getToken();

  @override
  Stream<PushMessage> get messages => _inner.messages;

  @override
  Future<void> deleteToken() => _inner.deleteToken();
}
