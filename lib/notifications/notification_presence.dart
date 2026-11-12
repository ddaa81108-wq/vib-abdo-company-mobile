import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks Android to hold the process while a session is open.
abstract interface class NotificationPresence {
  Future<void> setHolding(bool holding);
}

class MethodChannelNotificationPresence implements NotificationPresence {
  const MethodChannelNotificationPresence({
    this.channel = const MethodChannel('app/notification_presence'),
  });

  final MethodChannel channel;

  @override
  Future<void> setHolding(bool holding) async {
    try {
      await channel.invokeMethod<void>(holding ? 'start' : 'stop');
    } on MissingPluginException {
      // Tests and non-Android hosts have no service. The socket policy
      // still runs; only the process hold is absent.
    }
  }
}

final notificationPresenceProvider = Provider<NotificationPresence>(
  (ref) => const MethodChannelNotificationPresence(),
);
