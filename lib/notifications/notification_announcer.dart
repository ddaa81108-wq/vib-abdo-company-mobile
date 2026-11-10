import 'package:flutter/services.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/notifications/notification_sentence.dart';

/// Foreground sound and speech. The website plays a short tone when
/// `soundEnabled` is true and speaks [notificationSentence] when
/// `speechEnabled` is true. Both stay on the device; no extra endpoint.
abstract class NotificationAnnouncer {
  Future<void> speak(String text);
  Future<void> tone();
  Future<void> stop();
}

class RecordingNotificationAnnouncer implements NotificationAnnouncer {
  final spoken = <String>[];
  var tones = 0;
  var stopped = 0;

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> tone() async {
    tones++;
  }

  @override
  Future<void> stop() async {
    stopped++;
  }
}

final notificationAnnouncerProvider = Provider<NotificationAnnouncer>(
  (ref) => const MethodChannelNotificationAnnouncer(),
);

class MethodChannelNotificationAnnouncer implements NotificationAnnouncer {
  const MethodChannelNotificationAnnouncer();

  static const channel = MethodChannel('app/notification_speech');

  @override
  Future<void> speak(String text) async {
    await channel.invokeMethod<void>('speak', {'text': text, 'lang': 'ar'});
  }

  @override
  Future<void> tone() async {
    await channel.invokeMethod<void>('tone');
  }

  @override
  Future<void> stop() async {
    await channel.invokeMethod<void>('stop');
  }
}

/// Applies the saved preferences to one newly seen row.
///
/// Speech uses the Arabic sentence. A tone still plays when sound is on,
/// including when speech is also on, matching the website. A missing
/// `soundEnabled` stays on (the server default). Speech stays off until
/// the account turns «النطق» on.
Future<void> announceNewNotification({
  required AppNotification note,
  required Map<String, dynamic> preferences,
  required NotificationAnnouncer announcer,
}) async {
  final sentence = notificationSentence(note);
  if (preferences['speechEnabled'] == true && sentence != null) {
    await announcer.speak(spokenNotificationText(sentence));
  }
  if (preferences['soundEnabled'] != false) {
    await announcer.tone();
  }
}
