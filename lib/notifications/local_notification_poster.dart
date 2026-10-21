/// Shows a generic shade line. The UI dev owns `POST_NOTIFICATIONS`.
///
/// This interface does not post through Android. The text is the only input,
/// and callers must build it with [genericNotificationText].
abstract interface class LocalNotificationPoster {
  Future<void> showGeneric(String text);
}

class SilentLocalNotificationPoster implements LocalNotificationPoster {
  const SilentLocalNotificationPoster();

  @override
  Future<void> showGeneric(String text) async {}
}

class RecordingLocalNotificationPoster implements LocalNotificationPoster {
  final List<String> texts = [];

  @override
  Future<void> showGeneric(String text) async {
    texts.add(text);
  }
}
