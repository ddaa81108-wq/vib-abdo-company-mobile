import 'dart:async';
import 'dart:convert';

import '../../core/config/api_config.dart';
import '../../core/network/precise_json.dart';
import '../../core/network/wire_json.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/error_mapper.dart';
import '../../core/network/reachability.dart';
import '../../core/permissions/permission_codes.dart';
import '../../core/permissions/permission_service.dart';
import '../models/purchase_models.dart';
import 'fake_fixtures.dart';

/// In-memory fake of the REAL API shapes so the UI can be built with zero contact
/// with the production system. Same ApiClient interface => Remote*Repository run unchanged.
/// Fake-only fixture switch by USERNAME (see FakeFixtures.meFor): `admin…` = admin like the real
/// server today (empty permission list), `limited.admin…`, `flag.admin…`, `guest…`,
/// `mustchange…`, else employee.
/// Password "wrong" -> 401. It only returns canned values; it never computes money.
///
/// Section reads and writes are rejected with 403 unless the signed-in profile
/// allows them. The check uses [PermissionService], which is the only place that
/// matches the server role string. A successful business mutation is stored by
/// `requestId` for that user; a later call with the same id returns that result
/// and does not apply the operation again.
class FakeApiClient implements ApiClient {
  FakeApiClient({
    this.latency = const Duration(milliseconds: 250),
    this.rateWireFormat = RateWireFormat.number,
  });

  final Duration latency;
  final RateWireFormat rateWireFormat;

  /// Last request body exactly as it would go on the wire (for tests).
  String? lastWireBody;

  /// Request ids of business mutations that were attempted, in send order (tests).
  /// A replay of a request id that already succeeded is not added again.
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
  final PermissionService _access = PermissionService();
  final Set<String> _passwordChangedUserIds = {};
  final Map<String, Object?> _completedMutations = {};
  final Map<String, Completer<Object?>> _pendingMutations = {};
  String? _userId;
  Map<String, dynamic> _me = FakeFixtures.me(admin: false);
  int _unread = 1; // canned server-side state, set (not computed) per action
  static const _err = ErrorMapper();
  static const _denied = 'لا تملك صلاحية لهذا الإجراء';
  static const _adminOnly = 'هذا الإجراء للإدارة فقط';

  @override
  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? query,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) => _handle('GET', path, null, options, query: query);
  @override
  Future<ApiResponse> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) => _handle('POST', path, body, options);
  @override
  Future<ApiResponse> put(
    String path, {
    Object? body,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) => _handle('PUT', path, body, options);
  @override
  Future<ApiResponse> patch(
    String path, {
    Object? body,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) => _handle('PATCH', path, body, options);
  @override
  Future<ApiResponse> delete(
    String path, {
    Object? body,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) => _handle('DELETE', path, body, options);

  ApiResponse _ok(Object? data, {int status = 200}) {
    ApiReachability.instance.recordSuccess();
    return ApiResponse(
      statusCode: status,
      // Same decode path as the real client: fixtures -> JSON text -> PreciseJson.
      data: data == null ? null : PreciseJson.decode(jsonEncode(data)),
      correlationId: 'fake',
    );
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
        'correlationId': 'fake',
      },
    });
  }

  void _requireMutationMeta(Map b) {
    if (b['requestId'] == null) {
      _fail(400, 'REQUEST_ID_REQUIRED', 'requestId مطلوب');
    }
  }

  void _requireRead(SectionKey section) {
    if (!_access.canRead(section)) _fail(403, 'FORBIDDEN', _denied);
  }

  void _requireWrite(SectionKey section) {
    if (!_access.canWrite(section)) _fail(403, 'FORBIDDEN', _denied);
  }

  void _requireAction(ManagementAction action) {
    if (!_access.canDo(action)) _fail(403, 'FORBIDDEN', _adminOnly);
  }

  void _requireFullAccess() {
    if (!_access.fullAccess) _fail(403, 'FORBIDDEN', _adminOnly);
  }

  void _activate(Map<String, dynamic> me) {
    final user = Map<String, dynamic>.from(me['user'] as Map);
    if (_passwordChangedUserIds.contains('${user['id']}')) {
      user['mustChangePassword'] = false;
    }
    _me = {'user': user};
    _userId = '${user['id']}';
    final section = user['sectionAccess'];
    _access.applyFromServer(
      (user['permissions'] as List).map((code) => '$code'),
      role: user['role'] as String?,
      sectionAccess: section is Map
          ? section.map((key, value) => MapEntry('$key', '$value'))
          : const {},
      fullAccess: user['fullAccess'] is bool
          ? user['fullAccess'] as bool
          : null,
    );
  }

  SectionKey _sectionFor(String head) {
    for (final section in SectionKey.values) {
      if (section.key == head) return section;
    }
    _fail(404, 'NOT_FOUND', 'المسار غير موجود في الخادم التجريبي');
  }

  /// Home publishes the full fixture catalog, then drops every summary, counter,
  /// and old-debt row whose section this profile cannot read. An unknown section
  /// name is dropped as well.
  Map<String, dynamic> _homeForSignedInUser() {
    final source = FakeFixtures.home();
    final summaries = <Map<String, dynamic>>[
      for (final raw in source['summaries'] as List)
        if (_mayReadSection((raw as Map)['section']))
          Map<String, dynamic>.from(raw),
    ];
    final counters = <String, Object?>{
      for (final entry in (source['counters'] as Map).entries)
        if (_mayReadSection(entry.key)) '${entry.key}': entry.value,
    };
    final debts = <Map<String, dynamic>>[
      for (final raw in source['oldDebts'] as List)
        if (_mayReadSection((raw as Map)['section']))
          Map<String, dynamic>.from(raw),
    ];
    return {
      'businessDate': source['businessDate'],
      'generatedAt': source['generatedAt'],
      'summaries': summaries,
      'counters': counters,
      if (debts.isNotEmpty) 'oldDebts': debts,
    };
  }

  bool _mayReadSection(Object? name) {
    for (final section in SectionKey.values) {
      if (section.key == name) return _access.canRead(section);
    }
    return false;
  }

  Map<String, dynamic>? _cardOrNull(String head, String id) {
    final card = FakeFixtures.cardById(head, id);
    return card.isEmpty ? null : card;
  }

  Map<String, dynamic> _requireCard(String head, String id) {
    final card = _cardOrNull(head, id);
    if (card == null) _fail(404, 'NOT_FOUND', 'العنصر غير موجود');
    return card;
  }

  void _rejectSystemManagedWrite(String head, List<String> seg) {
    if (seg.length < 2) return;
    final id = seg[1];
    if (id == 'suggestions' || id == 'exchange-rate') return;
    final card = _cardOrNull(head, id);
    if (card != null && card['systemManaged'] == true) {
      _fail(403, 'FORBIDDEN', _denied);
    }
  }

  Future<ApiResponse> _handle(
    String method,
    String path,
    Object? body,
    ApiRequestOptions options, {
    Map<String, dynamic>? query,
  }) async {
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
      _activate(FakeFixtures.meFor('${b['username']}'));
      return _ok({..._me, 'csrfToken': 'fake-csrf'});
    }
    if (path == '/api/auth/csrf') return _ok({'csrfToken': 'fake-csrf'});
    if (options.authenticated && !_loggedIn) {
      _fail(401, 'AUTH_REQUIRED', 'يجب تسجيل الدخول أولًا.');
    }
    if (path == '/api/auth/logout') {
      _loggedIn = false;
      _access.applyFromServer(const [], role: null);
      return _ok({});
    }
    if (path == '/api/auth/change-password') {
      final user = (_me['user'] as Map).cast<String, dynamic>();
      user['mustChangePassword'] = false;
      final id = user['id'];
      if (id != null) _passwordChangedUserIds.add('$id');
      return _ok({});
    }
    if (path == '/api/me') return _ok(_me);

    if (method != 'GET' &&
        head != 'notifications' &&
        head != 'notification-preferences') {
      return _mutate(b, () => _route(method, b, seg, head, query));
    }
    return _route(method, b, seg, head, query);
  }

  /// A repeated [requestId] for this user returns the original success and
  /// does not apply the operation again. A failure is not remembered, so a
  /// retry of the same id can still succeed.
  Future<ApiResponse> _mutate(
    Map b,
    Future<ApiResponse> Function() send,
  ) async {
    _requireMutationMeta(b);
    final requestId = '${b['requestId']}';
    final key = '${_userId ?? ''}|$requestId';
    if (_completedMutations.containsKey(key)) {
      return _ok(_completedMutations[key]);
    }
    final pending = _pendingMutations[key];
    if (pending != null) {
      final data = await pending.future;
      return _ok(data);
    }
    final gate = Completer<Object?>();
    _pendingMutations[key] = gate;
    gate.future.ignore();
    mutationRequestIds.add(requestId);
    try {
      final paused = pauseMutations;
      if (paused != null) await paused.future;
      if (failMutationsRemaining > 0) {
        failMutationsRemaining--;
        _fail(400, 'MUTATION_FAILED', 'تعذر تنفيذ الطلب.');
      }
      final response = await send();
      _completedMutations[key] = response.data;
      if (!gate.isCompleted) gate.complete(response.data);
      return response;
    } catch (error, stack) {
      if (!gate.isCompleted) gate.completeError(error, stack);
      Error.throwWithStackTrace(error, stack);
    } finally {
      _pendingMutations.remove(key);
    }
  }

  Future<ApiResponse> _route(
    String method,
    Map b,
    List<String> seg,
    String head,
    Map<String, dynamic>? query,
  ) async {
    switch (head) {
      case 'home': // 🔶 proposed endpoint, fake only
        if (failHomeRemaining > 0) {
          failHomeRemaining--;
          _fail(404, 'NOT_FOUND', 'المسار غير موجود');
        }
        return _ok(_homeForSignedInUser());
      case 'customers':
      case 'companies':
      case 'libyan-deposits':
      case 'egyptian-deposits':
        return _accounts(method, head, seg, b, query);
      case 'collections':
        return _collections(method, seg, b);
      case 'masraweya':
        if (method == 'GET') {
          _requireRead(SectionKey.masraweya);
        } else {
          _requireWrite(SectionKey.masraweya);
        }
        return _ok(FakeFixtures.masraweyaDay());
      case 'purchases':
        if (method == 'GET') {
          _requireRead(SectionKey.purchases);
          return _ok(FakeFixtures.purchases());
        }
        if (seg.isNotEmpty && seg.last == 'finalize') {
          if (!_access.canFinalizePurchases) _fail(403, 'FORBIDDEN', _denied);
        } else {
          _requireWrite(SectionKey.purchases);
        }
        final entryWrite =
            (method == 'POST' && seg.length == 2) ||
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
        if (method == 'GET') {
          _requireRead(SectionKey.treasury);
          if (seg.length == 1) return _ok(FakeFixtures.treasury());
          final before = query?['before']?.toString();
          if (before != null && before.isNotEmpty && failOlderRemaining > 0) {
            failOlderRemaining--;
            _fail(503, 'NETWORK_UNAVAILABLE', 'تعذر تحميل الأقدم.');
          }
          return _ok(FakeFixtures.cashLedger(before: before));
        }
        _requireWrite(SectionKey.treasury);
        return _ok({'id': 'ce_new', 'version': 8});
      case 'reports':
        if (method != 'GET') _requireWrite(SectionKey.reports);
        _requireRead(SectionKey.reports);
        return _ok(FakeFixtures.reports());
      case 'statements':
        // Proposed endpoint, pending server confirmation. Fake mode only.
        _requireFullAccess();
        return _ok({
          'filename': 'statement.pdf',
          'contentBase64': 'JVBERi0xLjQK',
        });
      case 'financial-ledger':
        _requireFullAccess();
        return _ok({
          'items': [],
          'scopeTotals': {'LYD': 0, 'EGP': 0},
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

  Future<ApiResponse> _accounts(
    String method,
    String head,
    List<String> seg,
    Map b,
    Map<String, dynamic>? query,
  ) async {
    final section = _sectionFor(head);
    if (seg.length > 1 && seg[1] == 'exchange-rate') {
      if (method == 'GET') {
        _requireRead(section);
      } else {
        _requireWrite(section);
      }
      return _ok({'egpPerLyd': '9.5', 'version': 2});
    }
    if (method == 'GET') {
      _requireRead(section);
      if (seg.length == 1) return _ok(FakeFixtures.accountsFor(head));
      if (seg.length > 1 && seg[1] == 'suggestions') {
        final paused = pauseSuggestions;
        if (paused != null) await paused.future;
        if (failSuggestionsRemaining > 0) {
          failSuggestionsRemaining--;
          _fail(503, 'NETWORK_UNAVAILABLE', 'تعذر البحث.');
        }
        return _ok({'items': []});
      }
      if (seg.length == 3 && seg[2] == 'ledger') {
        _requireCard(head, seg[1]);
        final before = query?['before']?.toString();
        if (before != null && before.isNotEmpty && failOlderRemaining > 0) {
          failOlderRemaining--;
          _fail(503, 'NETWORK_UNAVAILABLE', 'تعذر تحميل الأقدم.');
        }
        return _ok(FakeFixtures.ledger(before: before));
      }
      if (seg.length == 2) return _ok(_requireCard(head, seg[1]));
      _fail(404, 'NOT_FOUND', 'المسار غير موجود في الخادم التجريبي');
    }
    if (seg.length > 2 && seg[2] == 'zero-review') {
      _requireAction(ManagementAction.customerZeroReview);
    } else {
      _requireWrite(section);
    }
    _rejectSystemManagedWrite(head, seg);
    if (seg.length > 1 &&
        seg[1] != 'suggestions' &&
        seg[1] != 'exchange-rate') {
      _requireCard(head, seg[1]);
    }
    if (b['expectedVersion'] == -1) {
      _fail(409, 'VERSION_CONFLICT', 'تم تعديل البيانات من مستخدم آخر');
    }
    return _ok({'id': 'tx_new', 'version': 5});
  }

  Future<ApiResponse> _collections(
    String method,
    List<String> seg,
    Map b,
  ) async {
    if (method == 'GET' && seg.length == 1) {
      _requireRead(SectionKey.collections);
      return _ok(FakeFixtures.collections());
    }
    if (method == 'GET' && seg.length > 1 && seg[1] == 'payroll') {
      if (!_access.canDo(ManagementAction.payrollManage) &&
          !_access.canWrite(SectionKey.collections)) {
        _fail(403, 'FORBIDDEN', _denied);
      }
      return _ok(FakeFixtures.payroll());
    }
    if (method == 'GET' && seg.length > 1 && seg[1] == 'assignees') {
      _requireRead(SectionKey.collections);
      return _ok({
        'items': [
          {'id': 'u_12', 'displayName': 'موظف استلام تجريبي'},
        ],
      });
    }
    if (method == 'GET') {
      _requireRead(SectionKey.collections);
      return _ok({'items': []});
    }
    _requireCollectionMutation(seg);
    final needsVersion =
        seg.isNotEmpty &&
        (seg.last == 'decision' || seg.last == 'cash-received');
    if (needsVersion && b['expectedVersion'] == null) {
      _fail(400, 'VALIDATION_ERROR', 'expectedVersion مطلوب');
    }
    return _ok({'id': 'ok', 'version': 1});
  }

  void _requireCollectionMutation(List<String> seg) {
    final last = seg.isEmpty ? '' : seg.last;
    if (seg.length > 2 && seg[1] == 'assignments' && last == 'submissions') {
      _requireWrite(SectionKey.collections);
      return;
    }
    if (seg.length == 2 && seg[1] == 'unlinked-receipts') {
      _requireWrite(SectionKey.collections);
      return;
    }
    if (seg.length > 3 && seg[1] == 'payroll' && last == 'confirm') {
      if (!_access.canWrite(SectionKey.collections) &&
          !_access.canDo(ManagementAction.payrollManage)) {
        _fail(403, 'FORBIDDEN', _adminOnly);
      }
      return;
    }
    if (seg.length == 2 && seg[1] == 'assignments') {
      _requireAction(ManagementAction.collectionsAssign);
      return;
    }
    if (last == 'decision') {
      _requireAction(ManagementAction.collectionsDecide);
      return;
    }
    if (last == 'cash-received') {
      _requireAction(ManagementAction.collectionsCashReceived);
      return;
    }
    if (seg.length > 2 && seg[1] == 'days' && last == 'close') {
      _requireAction(ManagementAction.collectionsCloseDay);
      return;
    }
    if (seg.length > 1 && seg[1] == 'payroll') {
      _requireAction(ManagementAction.payrollManage);
      return;
    }
    if (!_access.fullAccess) _fail(403, 'FORBIDDEN', _adminOnly);
  }
}
