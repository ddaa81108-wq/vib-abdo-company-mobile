/// Transport-level memory of recent notification ids.
///
/// Shared by push, poll, and the realtime refresh path. The controller's
/// ingest is still the final dedup. Cleared on logout and account switch.
class NotificationIdDedup {
  NotificationIdDedup({this.capacity = 200});

  final int capacity;
  final List<String> _order = [];
  final Set<String> _ids = {};

  int get length => _ids.length;

  /// True when [id] was not already stored. Empty ids are not stored.
  bool add(String id) {
    if (id.isEmpty) return false;
    if (_ids.contains(id)) return false;
    _ids.add(id);
    _order.add(id);
    while (_order.length > capacity) {
      final removed = _order.removeAt(0);
      _ids.remove(removed);
    }
    return true;
  }

  bool contains(String id) => _ids.contains(id);

  void clear() {
    _order.clear();
    _ids.clear();
  }
}
