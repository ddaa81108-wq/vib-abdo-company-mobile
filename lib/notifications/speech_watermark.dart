import 'package:flutter_api_layer/api_layer.dart';

/// What the foreground voice is allowed to say.
///
/// Opening or resuming the app arms a watermark at the newest notification
/// already on the server. Those rows are marked seen and are not spoken.
/// A later row, newer than that mark, is spoken once. The same id never
/// speaks twice. This does not touch the system tray or its sound.
class SpeechWatermark {
  /// True until the open/resume snapshot has been recorded.
  var holding = true;

  DateTime? at;
  String? id;
  final seen = <String>{};

  /// The next snapshot is the backlog and must stay silent.
  void hold() {
    holding = true;
  }

  void reset() {
    holding = true;
    at = null;
    id = null;
    seen.clear();
  }

  /// Record [items] as already heard. Nothing in the snapshot is spoken.
  void baseline(Iterable<AppNotification> items) {
    for (final item in items) {
      _remember(item);
    }
    holding = false;
  }

  /// True only for a row that arrived after the watermark, the first time.
  bool admit(AppNotification item) {
    final key = item.notificationId;
    if (key.isEmpty || seen.contains(key)) return false;
    if (holding || !_newer(item)) {
      _remember(item);
      return false;
    }
    _remember(item);
    return true;
  }

  void _remember(AppNotification item) {
    if (item.notificationId.isNotEmpty) seen.add(item.notificationId);
    if (at == null || _newer(item)) {
      at = item.createdAt;
      id = item.notificationId;
    }
  }

  bool _newer(AppNotification item) {
    final mark = at;
    if (mark == null) return true;
    final byTime = item.createdAt.compareTo(mark);
    if (byTime > 0) return true;
    if (byTime < 0) return false;
    return _idAfter(item.notificationId, id);
  }

  static bool _idAfter(String candidate, String? mark) {
    if (mark == null || mark.isEmpty) return true;
    final left = int.tryParse(candidate);
    final right = int.tryParse(mark);
    if (left != null && right != null) return left > right;
    return candidate.compareTo(mark) > 0;
  }
}
