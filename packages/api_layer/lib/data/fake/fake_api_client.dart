import 'dart:async';
import 'dart:convert';

import '../../core/config/api_config.dart';
import '../../core/network/precise_json.dart';
import '../../core/network/wire_json.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/error_mapper.dart';
import '../../core/network/reachability.dart';
import '../models/purchase_models.dart';
import 'fake_fixtures.dart';

/// In-memory fake of the REAL API shapes so the UI can be built with zero contact
/// with the production system. Same ApiClient interface => Remote*Repository run unchanged.
/// Fake-only fixture switch by USERNAME (see FakeFixtures.meFor): `admin…` = admin like the real
/// server today (empty permission list), `limited.admin…`, `flag.admin…`, `guest…`, else employee.
/// Password "wrong" -> 401. It only returns canned values; it never computes money.
class FakeApiClient implements ApiClient {
  FakeApiClient(
      {this.latency = const Duration(milliseconds: 250),
      this.rateWireFormat = RateWireFormat.number});

  final Duration latency;
  final RateWireFormat rateWireFormat;

  /// Last request body exactly as it would go on the wire (for tests).
  String? lastWireBody;

  /// Request ids of business mutations, in send order (tests).
  final List<String> mutationRequestIds = [];

  /// The next N business mutations fail before they change fake state (tests).
  int failMutationsRemaining = 0;

  /// When set, business mutations wait here after their requestId is recorded (tests).
  Completer<void>? pauseMutations;

  /// The next N account-suggestion reads fail (tests).
  int failSuggestionsRemaining = 0;

  /// The next N proposed home reads fail so the app can use per-section data.
  int failHomeRemaining = 0;

  /// The next N older-page reads (`before`) fail (tests).
  int failOlderRemaining = 0;

  /// The next N notification writes fail (tests).
  int failNotificationWritesRemaining = 0;

  /// Omit `unreadCount` from the notifications page (tests).
  bool omitUnreadCount = false;

  /// When set, account-suggestion reads wait here (tests).
  Completer<void>? pauseSuggestions;
  bool _loggedIn = false;
  bool _admin = false;
  Map<String, dynamic> _me = FakeFixtures.me(admin: false);
  int _unread = 1; // canned server-side state, set (not computed) per action

  /// Card fields changed by a full payment or a cancel. Keyed by section|id.
  final Map<String, Map<String, dynamic>> _cardState = {};

  /// Ledger rows marked reversed, and their new versions. Keyed by section|txId.
  final Map<String, int> _txVersion = {};
  final Set<String> _reversedTx = {};

  /// Submission fields changed by a decision or cash receipt. Keyed by id.
  final Map<String, Map<String, dynamic>> _submissionState = {};

  /// Unlinked receipt fields changed by a decision or cash receipt. Keyed by id.
  final Map<String, Map<String, dynamic>> _unlinkedState = {};

  /// Purchase day fields changed by finalize. Keyed by book|day.
  final Map<String, Map<String, dynamic>> _purchaseDays = {};

  /// Posted lines added by a direct partial payment. Keyed by section.
  final Map<String, List<Map<String, dynamic>>> _extraLedger = {};
  static const _err = ErrorMapper();

  @override
  Future<ApiResponse> get(String path,
          {Map<String, dynamic>? query,
          ApiRequestOptions options = const ApiRequestOptions()}) =>
      _handle('GET', path, null, options, query: query);
  @override
  Future<ApiResponse> post(String path,
          {Object? body,
          Map<String, dynamic>? query,
          ApiRequestOptions options = const ApiRequestOptions()}) =>
      _handle('POST', path, body, options);
  @override
  Future<ApiResponse> put(String path,
          {Object? body,
          ApiRequestOptions options = const ApiRequestOptions()}) =>
      _handle('PUT', path, body, options);
  @override
  Future<ApiResponse> patch(String path,
          {Object? body,
          ApiRequestOptions options = const ApiRequestOptions()}) =>
      _handle('PATCH', path, body, options);
  @override
  Future<ApiResponse> delete(String path,
          {Object? body,
          ApiRequestOptions options = const ApiRequestOptions()}) =>
      _handle('DELETE', path, body, options);

  ApiResponse _ok(Object? data, {int status = 200}) {
    ApiReachability.instance.recordSuccess();
    return ApiResponse(
        statusCode: status,
        // Same decode path as the real client: fixtures -> JSON text -> PreciseJson.
        data: data == null ? null : PreciseJson.decode(jsonEncode(data)),
        correlationId: 'fake');
  }

  Never _fail(int status, String code, String message) {
    if (code == 'NETWORK_UNAVAILABLE' || code == 'TIMEOUT') {
      ApiReachability.instance.recordTransportFailure();
    }
    throw _err.fromResponse(status, {
      'ok': false,
      'error': {
        'code': code,
        'message': message,
        'details': {},
        'correlationId': 'fake'
      },
    });
  }

  void _requireAdmin() {
    if (!_admin) _fail(403, 'FORBIDDEN', 'هذا الإجراء للإدارة فقط');
  }

  void _requireMutationMeta(Map b) {
    if (b['requestId'] == null) {
      _fail(400, 'REQUEST_ID_REQUIRED', 'requestId مطلوب');
    }
  }

  Future<ApiResponse> _handle(
      String method, String path, Object? body, ApiRequestOptions options,
      {Map<String, dynamic>? query}) async {
    await Future<void>.delayed(latency);
    // Same serialization as the real client, then decoded like a server would.
    lastWireBody = body == null ? null : WireJson.encode(body, rateWireFormat);
    final decoded = lastWireBody == null ? null : jsonDecode(lastWireBody!);
    final b = decoded is Map ? decoded : const {};
    final seg = path
        .split('/')
        .where((s) => s.isNotEmpty)
        .skip(1)
        .toList(); // drop "api"
    final head = seg.isEmpty ? '' : seg.first;

    if (method == 'POST' && path == '/api/auth/login') {
      if (b['password'] == 'wrong') {
        _fail(401, 'INVALID_CREDENTIALS', 'بيانات الدخول غير صحيحة');
      }
      _loggedIn = true;
      final username = '${b['username']}';
      _admin = username.startsWith('admin'); // fake server-side switch only
      _me = FakeFixtures.meFor(username);
      return _ok({..._me, 'csrfToken': 'fake-csrf'});
    }
    if (path == '/api/auth/csrf') return _ok({'csrfToken': 'fake-csrf'});
    if (options.authenticated && !_loggedIn) {
      _fail(401, 'AUTH_REQUIRED', 'يجب تسجيل الدخول أولًا.');
    }
    if (path == '/api/auth/logout') {
      _loggedIn = false;
      return _ok({});
    }
    if (path == '/api/auth/change-password') return _ok({});
    if (path == '/api/me') return _ok(_me);

    if (method != 'GET' &&
        head != 'notifications' &&
        head != 'notification-preferences') {
      _requireMutationMeta(b);
      mutationRequestIds.add('${b['requestId']}');
      final paused = pauseMutations;
      if (paused != null) await paused.future;
      if (failMutationsRemaining > 0) {
        failMutationsRemaining--;
        _fail(400, 'MUTATION_FAILED', 'تعذر تنفيذ الطلب.');
      }
    }

    switch (head) {
      case 'home': // 🔶 proposed endpoint, fake only
        if (failHomeRemaining > 0) {
          failHomeRemaining--;
          _fail(404, 'NOT_FOUND', 'المسار غير موجود');
        }
        return _ok(FakeFixtures.home(admin: _admin));
      case 'customers':
      case 'companies':
      case 'libyan-deposits':
      case 'egyptian-deposits':
        if (seg.length > 1 && seg[1] == 'exchange-rate') {
          return _ok({'egpPerLyd': '9.5', 'version': 2});
        }
        if (method == 'GET' && seg.length == 1) {
          return _ok(_accountsView(head));
        }
        if (method == 'GET' && seg.length > 1 && seg[1] == 'suggestions') {
          final paused = pauseSuggestions;
          if (paused != null) await paused.future;
          if (failSuggestionsRemaining > 0) {
            failSuggestionsRemaining--;
            _fail(503, 'NETWORK_UNAVAILABLE', 'تعذر البحث.');
          }
          return _ok({'items': []});
        }
        if (method == 'GET' && seg.length == 3 && seg[2] == 'ledger') {
          final before = query?['before']?.toString();
          if (before != null && before.isNotEmpty && failOlderRemaining > 0) {
            failOlderRemaining--;
            _fail(503, 'NETWORK_UNAVAILABLE', 'تعذر تحميل الأقدم.');
          }
          return _ok(_ledgerView(head, before));
        }
        if (method == 'GET' && seg.length == 2) {
          return _ok(_cardView(head, seg[1]));
        }
        if (method == 'POST' &&
            seg.length == 3 &&
            seg[2] == 'transactions' &&
            b['paymentMode'] == 'full') {
          return _applyFullPayment(head, seg[1], b);
        }
        if (method == 'POST' && seg.length == 3 && seg[2] == 'transactions') {
          return _applyMovement(head, seg[1], b);
        }
        if (method == 'POST' &&
            seg.length == 5 &&
            seg[2] == 'transactions' &&
            seg[4] == 'cancel') {
          return _applyCancel(head, seg[1], seg[3], b);
        }
        if (b['expectedVersion'] == -1) {
          _fail(409, 'VERSION_CONFLICT', 'تم تعديل البيانات من مستخدم آخر');
        }
        if (seg.length > 2 && seg[2] == 'zero-review') _requireAdmin();
        return _ok({'id': 'tx_new', 'version': 5});
      case 'collections':
        if (method == 'GET' && seg.length == 1) {
          return _ok(_collectionsView());
        }
        if (method == 'GET' && seg.length > 1 && seg[1] == 'payroll') {
          return _ok(FakeFixtures.payroll());
        }
        if (method == 'GET' && seg.length > 1 && seg[1] == 'assignees') {
          return _ok({
            'items': [
              {'id': 'u_12', 'displayName': 'موظف استلام تجريبي'}
            ]
          });
        }
        if (method == 'GET') return _ok({'items': []});
        final employeeAllowed = (seg.length > 2 &&
                seg[1] == 'assignments' &&
                seg.last == 'submissions') ||
            (seg.length == 2 && seg[1] == 'unlinked-receipts') ||
            (seg.length > 3 && seg[1] == 'payroll' && seg.last == 'confirm');
        // A profile that includes collections.decide may decide. The username
        // prefix is not the permission. Full admin still passes _requireAdmin.
        final decision = seg.isNotEmpty && seg.last == 'decision';
        if (!employeeAllowed &&
            !(decision && _meAllows('collections.decide'))) {
          _requireAdmin();
        }
        final needsVersion = seg.isNotEmpty &&
            (seg.last == 'decision' || seg.last == 'cash-received');
        if (needsVersion && b['expectedVersion'] == null) {
          _fail(400, 'VALIDATION_ERROR', 'expectedVersion مطلوب');
        }
        if (seg.length == 4 &&
            seg[1] == 'submissions' &&
            seg[3] == 'decision') {
          return _applyDecision(seg[2], b);
        }
        if (seg.length == 4 &&
            seg[1] == 'submissions' &&
            seg[3] == 'cash-received') {
          return _applyCash(seg[2], b, unlinked: false);
        }
        if (seg.length == 4 &&
            seg[1] == 'unlinked-receipts' &&
            seg[3] == 'decision') {
          return _applyUnlinkedDecision(seg[2], b);
        }
        if (seg.length == 4 &&
            seg[1] == 'unlinked-receipts' &&
            seg[3] == 'cash-received') {
          return _applyCash(seg[2], b, unlinked: true);
        }
        return _ok({'id': 'ok', 'version': 1});
      case 'masraweya':
        return _ok(FakeFixtures.masraweyaDay());
      case 'purchases':
        if (method == 'GET') {
          return _ok(_purchasesView(seg.length > 1 ? seg[1] : ''));
        }
        if (seg.length == 3 && seg[2] == 'finalize') {
          return _applyFinalize(seg[1], b);
        }
        final entryWrite = (method == 'POST' && seg.length == 2) ||
            ((method == 'POST' || method == 'PATCH') &&
                seg.length > 3 &&
                seg[2] == 'entries');
        if (entryWrite) {
          try {
            PurchaseItemCodes.require(
              b['itemCode']?.toString(),
              b['itemLabel']?.toString(),
            );
          } on BadRequestException catch (error) {
            _fail(400, error.code, error.message);
          }
        }
        return _ok({'id': 'pe_new', 'version': 4});
      case 'treasury':
        if (method == 'GET' && seg.length == 1) {
          return _ok(FakeFixtures.treasury());
        }
        if (method == 'GET') {
          final before = query?['before']?.toString();
          if (before != null && before.isNotEmpty && failOlderRemaining > 0) {
            failOlderRemaining--;
            _fail(503, 'NETWORK_UNAVAILABLE', 'تعذر تحميل الأقدم.');
          }
          return _ok(FakeFixtures.cashLedger(before: before));
        }
        return _ok({'id': 'ce_new', 'version': 8});
      case 'reports':
        return _ok(FakeFixtures.reports());
      case 'statements':
        // Proposed endpoint, pending server confirmation. Fake mode only.
        _requireAdmin();
        return _ok({
          'filename': 'statement.pdf',
          'contentBase64': 'JVBERi0xLjQK',
        });
      case 'financial-ledger':
        _requireAdmin();
        return _ok({
          'items': [],
          'scopeTotals': {'LYD': 0, 'EGP': 0}
        });
      case 'notifications':
        if (method == 'GET') {
          final data = FakeFixtures.notifications(_unread);
          if (omitUnreadCount) data.remove('unreadCount');
          return _ok(data);
        }
        if (failNotificationWritesRemaining > 0) {
          failNotificationWritesRemaining--;
          _fail(500, 'SERVER_ERROR', 'تعذر تحديث الإشعار.');
        }
        _unread = 0; // fake server state reset (single notification fixture)
        return _ok({});
      case 'notification-preferences':
        return _ok({'soundEnabled': true, 'speechEnabled': false});
      case 'event-changes':
        return _ok({'events': [], 'latest': 0, 'fullResync': false});
    }
    _fail(404, 'NOT_FOUND', 'المسار غير موجود في الخادم التجريبي');
  }

  bool _meAllows(String code) {
    if (_admin) return true;
    final user = _me['user'];
    if (user is! Map) return false;
    final permissions = user['permissions'];
    return permissions is List && permissions.contains(code);
  }

  void _requireVersion(Object? expected, Object? current) {
    if (expected == null) {
      _fail(400, 'VALIDATION_ERROR', 'expectedVersion مطلوب');
    }
    if (expected != current) {
      _fail(409, 'VERSION_CONFLICT', 'تم تعديل البيانات من مستخدم آخر');
    }
  }

  Map<String, dynamic> _copy(Object? value) =>
      (jsonDecode(jsonEncode(value)) as Map).cast<String, dynamic>();

  Map<String, dynamic> _cardView(String section, String? id) {
    final items =
        FakeFixtures.accounts(egp: section == 'egyptian-deposits')['items']
            as List;
    Map? match;
    Map? first;
    for (final raw in items) {
      final card = raw as Map;
      first ??= card;
      if (id != null && card['id'] == id) match = card;
    }
    final card = Map<String, dynamic>.from(match ?? first!);
    final state = _cardState['$section|${card['id']}'];
    if (state != null) card.addAll(state);
    return card;
  }

  Map<String, dynamic> _accountsView(String section) {
    final body =
        _copy(FakeFixtures.accounts(egp: section == 'egyptian-deposits'));
    final items = <Map<String, dynamic>>[];
    // Shift the stored summary by each card's stored balance change.
    // The fixture total stays the base. Cards are not added together.
    var delta = 0;
    for (final raw in body['items'] as List) {
      final card = Map<String, dynamic>.from(raw as Map);
      final state = _cardState['$section|${card['id']}'];
      final previous = card['balanceUnits'];
      final next = state?['balanceUnits'];
      if (previous is int && next is int) delta += next - previous;
      if (state != null) card.addAll(state);
      items.add(card);
    }
    body['items'] = items;
    if (delta != 0) {
      final summary = Map<String, dynamic>.from(body['summary'] as Map);
      if (summary['netBalance'] is int) {
        summary['netBalance'] = (summary['netBalance'] as int) + delta;
      }
      if (summary['totalDebt'] is int) {
        summary['totalDebt'] = (summary['totalDebt'] as int) + delta;
      }
      body['summary'] = summary;
    }
    return body;
  }

  Map<String, dynamic> _ledgerView(String section, String? before) {
    if (before != null && before.isNotEmpty) {
      return FakeFixtures.ledger(before: before);
    }
    final body = _copy(FakeFixtures.ledger());
    final items = <Map<String, dynamic>>[];
    for (final raw in body['items'] as List) {
      final entry = Map<String, dynamic>.from(raw as Map);
      final key = '$section|${entry['id']}';
      if (_reversedTx.contains(key)) entry['status'] = 'reversed';
      final version = _txVersion[key];
      if (version != null) entry['version'] = version;
      items.add(entry);
    }
    for (final extra in _extraLedger[section] ?? const []) {
      items.add(Map<String, dynamic>.from(extra));
    }
    body['items'] = items;
    return body;
  }

  /// Full payment stores balance 0. That is the server result, not arithmetic.
  ApiResponse _applyFullPayment(String section, String id, Map b) {
    final card = _cardView(section, id);
    _requireVersion(b['expectedVersion'], card['version']);
    final version = (card['version'] as int) + 1;
    _cardState['$section|${card['id']}'] = {
      'balanceUnits': 0,
      'version': version,
    };
    return _ok({'id': 'tx_new', 'version': version});
  }

  /// Debt or partial payment. The version is the card's stored version.
  ///
  /// A direct partial payment stores the previous card balance with the
  /// received `inputValue` applied. That result is what later reads return.
  /// The app does not calculate it. A rate-based movement only bumps the
  /// version; this fake does not turn a factor into an amount.
  ApiResponse _applyMovement(String section, String id, Map b) {
    final card = _cardView(section, id);
    _requireVersion(b['expectedVersion'], card['version']);
    final version = (card['version'] as int) + 1;
    final state = <String, dynamic>{'version': version};
    final previous = card['balanceUnits'];
    final entered = b['inputValue'];
    if (b['type'] == 'payment' &&
        b['paymentMode'] == 'partial' &&
        b['calculationMode'] == 'direct' &&
        previous is int &&
        entered is int) {
      final stored = previous - entered;
      state['balanceUnits'] = stored;
      _extraLedger.putIfAbsent(section, () => []).add({
        'id': 'tx_partial_$version',
        'sequence': version,
        'type': 'payment',
        'status': 'posted',
        'paymentMode': 'partial',
        'date': b['date'],
        'amountUnits': entered,
        'inputValue': entered,
        'calculationMode': 'direct',
        'balanceAfterUnits': stored,
        'createdByName': 'مدير تجريبي',
        'version': 1,
      });
    }
    _cardState['$section|${card['id']}'] = state;
    return _ok({'id': 'tx_new', 'version': version});
  }

  /// Copies balanceAfterUnits already stored on the latest remaining posted line.
  int _latestPostedBalance(String section) {
    var balance = 0;
    for (final raw in _ledgerView(section, null)['items'] as List) {
      final entry = raw as Map;
      if (entry['status'] == 'posted' && entry['balanceAfterUnits'] is int) {
        balance = entry['balanceAfterUnits'] as int;
      }
    }
    return balance;
  }

  ApiResponse _applyCancel(
      String section, String accountId, String txId, Map b) {
    Map<String, dynamic>? entry;
    for (final raw in _ledgerView(section, null)['items'] as List) {
      final item = Map<String, dynamic>.from(raw as Map);
      if (item['id'] == txId) entry = item;
    }
    if (entry == null) _fail(404, 'NOT_FOUND', 'الحركة غير موجودة');
    _requireVersion(b['expectedVersion'], entry['version']);
    final key = '$section|$txId';
    _reversedTx.add(key);
    _txVersion[key] = (entry['version'] as int) + 1;
    final card = _cardView(section, accountId);
    final version = (card['version'] as int) + 1;
    _cardState['$section|${card['id']}'] = {
      'balanceUnits': _latestPostedBalance(section),
      'version': version,
    };
    return _ok({'id': 'tx_new', 'version': version});
  }

  Map<String, dynamic> _collectionsView() {
    final body = _copy(FakeFixtures.collections());
    final items = <Map<String, dynamic>>[];
    for (final raw in body['submissions'] as List) {
      final item = Map<String, dynamic>.from(raw as Map);
      final state = _submissionState['${item['id']}'];
      if (state != null) item.addAll(state);
      items.add(item);
    }
    body['submissions'] = items;
    final receipts = <Map<String, dynamic>>[];
    for (final raw in body['unlinkedReceipts'] as List) {
      final item = Map<String, dynamic>.from(raw as Map);
      final state = _unlinkedState['${item['id']}'];
      if (state != null) item.addAll(state);
      receipts.add(item);
    }
    body['unlinkedReceipts'] = receipts;
    return body;
  }

  ApiResponse _applyDecision(String id, Map b) {
    Map<String, dynamic>? submission;
    for (final raw in _collectionsView()['submissions'] as List) {
      final item = raw as Map<String, dynamic>;
      if (item['id'] == id) submission = item;
    }
    if (submission == null) _fail(404, 'NOT_FOUND', 'الاستلام غير موجود');
    _requireVersion(b['expectedVersion'], submission['version']);
    final decision = b['decision'];
    final status = switch (decision) {
      'approve' => 'approved',
      'reject' => 'rejected',
      _ => null,
    };
    if (status == null) _fail(400, 'VALIDATION_ERROR', 'قرار غير معروف');
    final version = (submission['version'] as int) + 1;
    _submissionState[id] = {
      ...?_submissionState[id],
      'status': status,
      'version': version,
    };
    return _ok({'id': 'ok', 'version': version});
  }

  ApiResponse _applyCash(String id, Map b, {required bool unlinked}) {
    final view = _collectionsView();
    final items =
        (unlinked ? view['unlinkedReceipts'] : view['submissions']) as List;
    final current = _recordById(
      items,
      id,
      unlinked ? 'الإيصال غير موجود' : 'الاستلام غير موجود',
    );
    _requireVersion(b['expectedVersion'], current['version']);
    final version = (current['version'] as int) + 1;
    final store = unlinked ? _unlinkedState : _submissionState;
    store[id] = {
      ...?store[id],
      'cashStatus': 'received',
      'cashPending': false,
      'version': version,
    };
    return _ok({'id': 'ok', 'version': version});
  }

  ApiResponse _applyUnlinkedDecision(String id, Map b) {
    final current = _recordById(
      _collectionsView()['unlinkedReceipts'] as List,
      id,
      'الإيصال غير موجود',
    );
    _requireVersion(b['expectedVersion'], current['version']);
    final decision = b['decision'];
    final status = switch (decision) {
      'approve' => 'approved',
      'reject' => 'rejected',
      _ => null,
    };
    if (status == null) _fail(400, 'VALIDATION_ERROR', 'قرار غير معروف');
    final version = (current['version'] as int) + 1;
    final customerId = b['customerId'];
    _unlinkedState[id] = {
      ...?_unlinkedState[id],
      'status': status,
      'version': version,
      if (customerId != null) 'customerId': customerId,
    };
    return _ok({'id': 'ok', 'version': version});
  }

  Map<String, dynamic> _purchasesView(String book) {
    final body = _copy(FakeFixtures.purchases());
    final days = <Map<String, dynamic>>[];
    for (final raw in body['days'] as List) {
      final day = Map<String, dynamic>.from(raw as Map);
      final state = _purchaseDays['$book|${day['day']}'];
      if (state != null) day.addAll(state);
      days.add(day);
    }
    body['days'] = days;
    return body;
  }

  ApiResponse _applyFinalize(String book, Map b) {
    final days = _purchasesView(book)['days'] as List;
    if (days.isEmpty) _fail(404, 'NOT_FOUND', 'اليوم غير موجود');
    final day = days.first as Map<String, dynamic>;
    _requireVersion(b['expectedDayVersion'], day['version']);
    final version = (day['version'] as int) + 1;
    _purchaseDays['$book|${day['day']}'] = {
      'status': 'finalized',
      'version': version,
    };
    return _ok({'id': 'ok', 'version': version});
  }

  Map<String, dynamic> _recordById(List items, String id, String missing) {
    for (final raw in items) {
      final item = raw as Map<String, dynamic>;
      if (item['id'] == id) return item;
    }
    _fail(404, 'NOT_FOUND', missing);
  }
}
