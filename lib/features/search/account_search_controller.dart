import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/repositories/accounts_repository.dart';

import 'account_search_page.dart';

/// Read-only account search. Each query owns its response and page cursor;
/// old responses cannot leak across a query, section, session, or disposal.
class AccountSearchController extends ChangeNotifier {
  AccountSearchController({
    required this.repository,
    required this.canRead,
    required this.currentUserId,
  });

  static const debounce = Duration(milliseconds: 250);
  final AccountsRepository Function() repository;
  final bool Function(AccountSection) canRead;
  final String? Function() currentUserId;
  Timer? _timer;
  bool _disposed = false;
  int _ticket = 0;
  String _query = '';
  AccountSection? _scope;
  List<GlobalAccountHit> _items = [];
  bool _busy = false;
  bool _paging = false;
  String _error = '';
  Map<AccountSection, String> _cursors = {};

  AccountSection? get scope => _scope;
  List<GlobalAccountHit> get items => List.unmodifiable(_items);
  bool get busy => _busy;
  bool get paging => _paging;
  String get error => _error;
  bool get hasMore => _cursors.isNotEmpty;
  Map<AccountSection, String> get nextCursors => Map.unmodifiable(_cursors);

  void setScope(AccountSection? section) {
    if (_scope == section) return;
    _scope = section;
    search(_query);
  }

  void search(String value) {
    _timer?.cancel();
    final ticket = ++_ticket;
    _query = value.trim();
    _items = [];
    _cursors = {};
    _error = '';
    _paging = false;
    _busy = _query.length >= 2;
    notifyListeners();
    if (!_busy) return;
    final query = _query, section = _scope, userId = currentUserId();
    _timer = Timer(debounce, () {
      unawaited(_fetch(ticket, query, section, userId));
    });
  }

  void retry() {
    if (hasMore && _items.isNotEmpty) {
      unawaited(loadMore());
    } else {
      search(_query);
    }
  }

  Future<void> loadMore() async {
    if (_busy || _paging || !hasMore) return;
    final after = Map<AccountSection, String>.of(_cursors);
    _paging = true;
    _error = '';
    notifyListeners();
    await _fetch(_ticket, _query, _scope, currentUserId(), after: after);
  }

  Future<void> _fetch(
    int ticket,
    String query,
    AccountSection? section,
    String? userId, {
    Map<AccountSection, String>? after,
  }) async {
    if (!_current(ticket, query, section, userId)) return;
    try {
      final sections = section == null
          ? AccountSection.values.where(canRead).toList()
          : [section];
      if (section != null && !canRead(section)) {
        throw StateError('Section not permitted');
      }
      final page = await readAccountSearchPage(
        repository(),
        query: query,
        sections: sections,
        after: after,
      );
      if (!_current(ticket, query, section, userId)) return;
      final merged = {
        if (after != null)
          for (final item in _items) '${item.section.path}/${item.id}': item,
        for (final item in page.items) '${item.section.path}/${item.id}': item,
      };
      _items = merged.values.toList();
      _cursors = page.nextCursors;
      _busy = false;
      _paging = false;
      _error = '';
      notifyListeners();
    } catch (_) {
      if (!_current(ticket, query, section, userId)) return;
      _busy = false;
      _paging = false;
      _error = 'تعذر البحث. تحقق من الاتصال ثم أعد المحاولة.';
      notifyListeners();
    }
  }

  bool _current(
    int ticket,
    String query,
    AccountSection? section,
    String? userId,
  ) =>
      !_disposed &&
      ticket == _ticket &&
      query == _query &&
      section == _scope &&
      userId != null &&
      userId == currentUserId();

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
