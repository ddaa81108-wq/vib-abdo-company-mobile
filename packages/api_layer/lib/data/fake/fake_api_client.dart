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

  /// Mutable copy of [FakeFixtures.accountRequests]. Decisions update it.
  /// 🔶 Status transitions are proposed; the fake never computes money.
  List<Map<String, dynamic>>? _accountRequests;

  /// Successful account-request decisions, keyed by `requestId`, so a retry of
  /// the same submission does not apply twice. 🔶 The real server is assumed
  /// to honour `requestId` the same way; failed attempts are not remembered.
  final Map<String, Map<String, dynamic>> _accountRequestAcks = {};

  bool _loggedIn = false;
  bool _admin = false;
  Map<String, dynamic> _me = FakeFixtures.me(admin: false);
  int _unread = 1; // canned server-side state, set (not computed) per action
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
          return _ok(FakeFixtures.accounts(egp: head == 'egyptian-deposits'));
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
          return _ok(FakeFixtures.ledger(before: before));
        }
        if (method == 'GET' && seg.length == 2) {
          return _ok(
              (FakeFixtures.accounts(egp: head == 'egyptian-deposits')['items']
                      as List)
                  .first);
        }
        if (b['expectedVersion'] == -1) {
          _fail(409, 'VERSION_CONFLICT', 'تم تعديل البيانات من مستخدم آخر');
        }
        if (seg.length > 2 && seg[2] == 'zero-review') _requireAdmin();
        return _ok({'id': 'tx_new', 'version': 5});
      case 'collections':
        if (method == 'GET' && seg.length == 1) {
          return _ok(FakeFixtures.collections());
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
        if (!employeeAllowed) _requireAdmin();
        final needsVersion = seg.isNotEmpty &&
            (seg.last == 'decision' || seg.last == 'cash-received');
        if (needsVersion && b['expectedVersion'] == null) {
          _fail(400, 'VALIDATION_ERROR', 'expectedVersion مطلوب');
        }
        return _ok({'id': 'ok', 'version': 1});
      case 'masraweya':
        return _ok(FakeFixtures.masraweyaDay());
      case 'purchases':
        if (method == 'GET') return _ok(FakeFixtures.purchases());
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
      case 'account-requests':
        // Admin role flag, like the web today (role name, no fine-grained code).
        // `users.manage` is 🔶 proposed and is not what this fake checks.
        _requireAdmin();
        if (method == 'GET' && seg.length == 1) {
          return _ok(_accountRequestsPage(query));
        }
        if (method == 'POST' && seg.length == 3 && seg[2] == 'decision') {
          return _ok(_decideAccountRequest(seg[1], b));
        }
        return _fail(404, 'NOT_FOUND', 'المسار غير موجود في الخادم التجريبي');
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

  List<Map<String, dynamic>> _accountRequestItems() {
    final existing = _accountRequests;
    if (existing != null) return existing;
    final raw = FakeFixtures.accountRequests()['items'];
    final copy = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) copy.add(Map<String, dynamic>.from(item));
      }
    }
    return _accountRequests = copy;
  }

  Map<String, dynamic> _accountRequestsPage(Map<String, dynamic>? query) {
    var items = _accountRequestItems();
    final status = query?['status']?.toString();
    if (status != null && status.isNotEmpty) {
      items = [
        for (final item in items)
          if (item['status'] == status) item,
      ];
    }
    final cursor = query?['cursor']?.toString();
    if (cursor != null && cursor.isNotEmpty) {
      final index = items.indexWhere((item) => item['id'] == cursor);
      // 🔶 Unknown cursor -> empty page, not an error.
      items = index < 0 ? <Map<String, dynamic>>[] : items.sublist(index + 1);
    }
    final limit = _pageLimit(query?['limit']);
    final hasMore = limit != null && items.length > limit;
    final page = hasMore ? items.sublist(0, limit) : items;
    return {
      'items': [
        for (final item in page) Map<String, dynamic>.from(item),
      ],
      'nextCursor': hasMore ? page.last['id'] : null,
      'hasMore': hasMore,
    };
  }

  /// Null when the caller did not ask for a page size (return the whole list).
  int? _pageLimit(Object? raw) {
    if (raw == null || '$raw'.isEmpty) return null;
    final limit = raw is int ? raw : int.tryParse('$raw');
    if (limit == null || limit < 1) {
      _fail(400, 'VALIDATION_ERROR', 'حد الصفحة غير صالح');
    }
    return limit;
  }

  Map<String, dynamic> _decideAccountRequest(
      String id, Map<dynamic, dynamic> body) {
    final requestId = '${body['requestId']}';
    final prior = _accountRequestAcks[requestId];
    if (prior != null) return prior;

    if (body['expectedVersion'] == null) {
      _fail(400, 'VALIDATION_ERROR', 'expectedVersion مطلوب');
    }
    final index =
        _accountRequestItems().indexWhere((item) => item['id'] == id);
    if (index < 0) {
      _fail(404, 'NOT_FOUND', 'العنصر غير موجود');
    }
    final item = _accountRequestItems()[index];
    if (body['expectedVersion'] != item['version']) {
      _fail(409, 'VERSION_CONFLICT', 'تم تعديل البيانات من مستخدم آخر');
    }
    // 🔶 A second decision on a request that is not pending.
    if (item['status'] != 'pending') {
      _fail(409, 'ALREADY_DECIDED', 'تم البت في هذا الطلب');
    }
    final status = switch (body['decision']) {
      'approve' => 'approved',
      'reject' => 'rejected',
      _ => null,
    };
    if (status == null) {
      _fail(400, 'VALIDATION_ERROR', 'القرار غير صالح');
    }
    final current = item['version'];
    final nextVersion = current is int ? current + 1 : 1;
    item['status'] = status;
    item['version'] = nextVersion;
    item['decidedAt'] = '2026-10-20T12:00:00+02:00';
    final note = body['note'];
    if (note != null && '$note'.isNotEmpty) item['decisionNote'] = note;
    // 🔶 Once decided, the server no longer offers approve/reject.
    item.remove('allowedActions');
    final ack = <String, dynamic>{
      'id': id,
      'version': nextVersion,
      'status': status,
    };
    _accountRequestAcks[requestId] = ack;
    return ack;
  }
}
