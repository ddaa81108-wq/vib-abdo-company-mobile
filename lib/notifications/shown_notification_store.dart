import 'package:shared_preferences/shared_preferences.dart';

/// Ids already posted to the system tray, plus the poll cursor.
///
/// Shared by the foreground presenter and the WorkManager isolate. Not a
/// secret store: the values are notification ids and a page cursor.
abstract interface class ShownNotificationStore {
  Future<bool> contains(String id);
  Future<void> add(String id);
  Future<String?> readCursor();
  Future<void> writeCursor(String? cursor);

  /// Drops the ids and the cursor. Logout, account switch, and session wipe.
  Future<void> clear();
}

class MemoryShownNotificationStore implements ShownNotificationStore {
  MemoryShownNotificationStore({this.capacity = 200});

  final int capacity;
  final List<String> ids = [];
  String? cursor;

  @override
  Future<bool> contains(String id) async => ids.contains(id);

  @override
  Future<void> add(String id) async {
    if (id.isEmpty || ids.contains(id)) return;
    ids.add(id);
    while (ids.length > capacity) {
      ids.removeAt(0);
    }
  }

  @override
  Future<String?> readCursor() async => cursor;

  @override
  Future<void> writeCursor(String? value) async {
    cursor = value;
  }

  @override
  Future<void> clear() async {
    ids.clear();
    cursor = null;
  }
}

class PreferencesShownNotificationStore implements ShownNotificationStore {
  PreferencesShownNotificationStore({this.capacity = 200});

  static const idsKey = 'notifications.shown_ids.v1';
  static const cursorKey = 'notifications.poll_cursor.v1';

  final int capacity;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<bool> contains(String id) async {
    final prefs = await _prefs;
    return prefs.getStringList(idsKey)?.contains(id) ?? false;
  }

  @override
  Future<void> add(String id) async {
    if (id.isEmpty) return;
    final prefs = await _prefs;
    final ids = [...?prefs.getStringList(idsKey)];
    if (ids.contains(id)) return;
    ids.add(id);
    while (ids.length > capacity) {
      ids.removeAt(0);
    }
    await prefs.setStringList(idsKey, ids);
  }

  @override
  Future<String?> readCursor() async {
    final prefs = await _prefs;
    return prefs.getString(cursorKey);
  }

  @override
  Future<void> writeCursor(String? cursor) async {
    final prefs = await _prefs;
    if (cursor == null || cursor.isEmpty) {
      await prefs.remove(cursorKey);
      return;
    }
    await prefs.setString(cursorKey, cursor);
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(idsKey);
    await prefs.remove(cursorKey);
  }
}
