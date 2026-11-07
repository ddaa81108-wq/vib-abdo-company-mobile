import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pages reached by replacing the route, such as settings siblings.
///
/// Nested account routes stay on the router stack and are not recorded here.
/// Logout clears the list so a later back cannot open a protected page.
class ShellHistory extends Notifier<List<String>> {
  String? _current;

  @override
  List<String> build() => const [];

  void note(String location) {
    final path = location.isEmpty ? '/' : location;
    final previous = _current;
    if (previous == path) return;
    _current = path;
    if (previous == null) return;
    if (_popped(previous, path)) return;
    if (_nested(previous, path)) return;
    state = [...state, previous];
  }

  void clear() {
    _current = null;
    state = const [];
  }

  /// The page to open. The caller navigates; this does not.
  String? takeBack() {
    if (state.isEmpty) return null;
    final previous = state.last;
    state = state.sublist(0, state.length - 1);
    _current = previous;
    return previous;
  }

  static const _stacked = [
    '/customers',
    '/companies',
    '/libyan-deposits',
    '/egyptian-deposits',
  ];

  /// A ledger under its list is already on the router stack.
  bool _popped(String from, String to) =>
      _stacked.any((parent) => to == parent && from.startsWith('$parent/'));

  bool _nested(String from, String to) =>
      _stacked.any((parent) => from == parent && to.startsWith('$parent/'));
}

final shellHistoryProvider = NotifierProvider<ShellHistory, List<String>>(
  ShellHistory.new,
);
