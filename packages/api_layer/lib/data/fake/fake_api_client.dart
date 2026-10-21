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

  /// Paths of those mutations, in the same order (tests).
  final List<String> mutationPaths = [];

  /// Wire bodies of those mutations, in the same order (tests).
  final List<String> mutationBodies = [];

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

  /// The next N versioned collection mutations fail with VERSION_CONFLICT (tests).
  int versionConflictRemaining = 0;

  /// When set, purchases days without a stored finalize or correction use this
  /// status on the next GET (tests).
  String? purchaseFixtureStatus;

  /// GET /api/collections calls, including a refetch after a conflict (tests).
  int collectionOverviewReads = 0;

  /// Omit `unreadCount` from the notifications page (tests).
  bool omitUnreadCount = false;

  /// When set, account-suggestion reads wait here (tests).
  Completer<void>? pauseSuggestions;

  /// Account-list reads, in call order (tests). `filter` / `q` / `cursor` are
  /// null when the request omitted them.
  final List<AccountListQuery> accountListQueries = [];

  /// When set, the first account-list page reports this `nextCursor` (tests).
  String? accountNextCursor;

  /// Items returned for an account-list read that sends `cursor` (tests).
  List<Map<String, dynamic>> accountNextItems = const [];

  /// When set, account-list reads wait here (tests).
  Completer<void>? pauseAccountLists;

  /// Suggestion reads, in call order (tests).
  final List<AccountSuggestionQuery> suggestionQueries = [];

  /// When non-null, suggestion reads return these items instead of `[]` (tests).
  List<Map<String, dynamic>>? suggestionItems;
  bool _loggedIn = false;
  final PermissionService _access = PermissionService();
  final Set<String> _passwordChangedUserIds = {};
  final Map<String, Object?> _completedMutations = {};
  final Map<String, Completer<Object?>> _pendingMutations = {};
  String? _userId;
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

  /// Purchase day fields changed by finalize or correction. Keyed by book|day.
  final Map<String, Map<String, dynamic>> _purchaseDays = {};

  /// Opening amounts echoed on the next purchases GET. Keyed by book.
  final Map<String, Map<String, dynamic>> _openingByBook = {};

  /// Collections day close. The next batch id is a stored successor.
  Map<String, dynamic>? _batchState;

  /// Posted lines added by a direct partial payment. Keyed by section.
  final Map<String, List<Map<String, dynamic>>> _extraLedger = {};
  static const _err = ErrorMapper();
  static const _denied = 'لا تملك صلاحية لهذا الإجراء';
  static const _adminOnly = 'هذا الإجراء للإدارة فقط';

  @override
  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? query,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) =>
      _handle('GET', path, null, options, query: query);
  @override
  Future<ApiResponse> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) =>
      _handle('POST', path, body, options);
  @override
  Future<ApiResponse> put(
    String path, {
    Object? body,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) =>
      _handle('PUT', path, body, options);
  @override
  Future<ApiResponse> patch(
    String path, {
    Object? body,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) =>
      _handle('PATCH', path, body, options);
  @override
  Future<ApiResponse> delete(
    String path, {
    Object? body,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) =>
      _handle('DELETE', path, body, options);

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
      fullAccess:
          user['fullAccess'] is bool ? user['fullAccess'] as bool : null,
    );
  }

  SectionKey _sectionFor(String head) {
    for (final section in SectionKey.values) {
      if (section.key == head) return section;
    }
    _fail(404, 'NOT_FOUND', 'المسار غير موجود في الخادم التجريبي');
  }

  /// Home publishes the section catalog, then replaces each account-section
  /// net figure with the summary the list endpoint returns for that section.
  /// Each old-debt row keeps its catalog place and copies `balanceUnits` from
  /// the card stored after later writes. It then drops every summary, counter,
  /// and old-debt row whose section this profile cannot read. An unknown
  /// section name is dropped as well.
  Map<String, dynamic> _homeForSignedInUser() {
    final source = FakeFixtures.home();
    final summaries = <Map<String, dynamic>>[
      for (final raw in source['summaries'] as List)
        if (_mayReadSection((raw as Map)['section']))
          _withStoredSectionFigure(Map<String, dynamic>.from(raw)),
    ];
    final counters = <String, Object?>{
      for (final entry in (source['counters'] as Map).entries)
        if (_mayReadSection(entry.key)) '${entry.key}': entry.value,
    };
    final debts = <Map<String, dynamic>>[
      for (final raw in source['oldDebts'] as List)
        if (_mayReadSection((raw as Map)['section']))
          _withStoredDebtBalance(Map<String, dynamic>.from(raw)),
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

  /// Account sections whose list summary is the home figure for that section.
  static const _accountSections = {
    'customers',
    'companies',
    'libyan-deposits',
    'egyptian-deposits',
  };

  /// The same page [AccountsRepository.list] returns for [section], including
  /// balances stored by later writes.
  Map<String, dynamic> _sectionPage(String section) => _accountsView(section);

  Map<String, dynamic> _withStoredSectionFigure(Map<String, dynamic> summary) {
    final section = summary['section'];
    final key = summary['key'];
    if (section is! String ||
        key is! String ||
        !key.endsWith('.netBalance') ||
        !_accountSections.contains(section)) {
      return summary;
    }
    final stored = _sectionPage(section)['summary'];
    if (stored is Map && stored['netBalance'] != null) {
      summary['valueUnits'] = stored['netBalance'];
    }
    return summary;
  }

  /// Bulletin membership stays the catalog. The amount is the card's stored
  /// balance, including 0 after a full payment. The proposed home payload does
  /// not say a settled card leaves the list, so this does not drop the row.
  Map<String, dynamic> _withStoredDebtBalance(Map<String, dynamic> debt) {
    final section = debt['section'];
    final id = debt['id'];
    if (section is! String || id is! String) return debt;
    if (_cardOrNull(section, id) == null) return debt;
    debt['balanceUnits'] = _cardView(section, id)['balanceUnits'];
    return debt;
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
      return _mutate(b, path, () => _route(method, b, seg, head, query));
    }
    return _route(method, b, seg, head, query);
  }

  /// A repeated [requestId] for this user returns the original success and
  /// does not apply the operation again. A failure is not remembered, so a
  /// retry of the same id can still succeed.
  Future<ApiResponse> _mutate(
    Map b,
    String path,
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
    mutationPaths.add(path);
    if (lastWireBody != null) mutationBodies.add(lastWireBody!);
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
          return _ok(_purchasesView(seg.length > 1 ? seg[1] : ''));
        }
        if (seg.isNotEmpty && seg.last == 'finalize') {
          if (!_access.canFinalizePurchases) _fail(403, 'FORBIDDEN', _denied);
          return _applyFinalize(seg.length > 1 ? seg[1] : '', b);
        }
        if (method == 'PATCH' && seg.length >= 5 && seg.last == 'correction') {
          if (!_access.canFinalizePurchases) _fail(403, 'FORBIDDEN', _denied);
          return _applyCorrection(seg[1], seg[3], b);
        }
        _requireWrite(SectionKey.purchases);
        if (method == 'PATCH' && seg.length >= 3 && seg[2] == 'opening') {
          return _applyOpening(seg[1], b);
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
      if (seg.length == 1) {
        final paused = pauseAccountLists;
        if (paused != null) await paused.future;
        final filter = _queryText(query, 'filter');
        final q = _queryText(query, 'q');
        final cursor = _queryText(query, 'cursor');
        accountListQueries.add(
          AccountListQuery(section: head, filter: filter, q: q, cursor: cursor),
        );
        final page = _sectionPage(head);
        if (cursor != null) {
          return _ok({...page, 'items': accountNextItems, 'nextCursor': null});
        }
        if (accountNextCursor != null) {
          return _ok({...page, 'nextCursor': accountNextCursor});
        }
        return _ok(page);
      }
      if (seg.length > 1 && seg[1] == 'suggestions') {
        final paused = pauseSuggestions;
        if (paused != null) await paused.future;
        suggestionQueries.add(
          AccountSuggestionQuery(
            section: head,
            q: _queryText(query, 'q') ?? '',
          ),
        );
        if (failSuggestionsRemaining > 0) {
          failSuggestionsRemaining--;
          _fail(503, 'NETWORK_UNAVAILABLE', 'تعذر البحث.');
        }
        return _ok({'items': suggestionItems ?? const []});
      }
      if (seg.length == 3 && seg[2] == 'ledger') {
        _requireCard(head, seg[1]);
        final before = query?['before']?.toString();
        if (before != null && before.isNotEmpty && failOlderRemaining > 0) {
          failOlderRemaining--;
          _fail(503, 'NETWORK_UNAVAILABLE', 'تعذر تحميل الأقدم.');
        }
        return _ok(_ledgerView(head, before));
      }
      if (seg.length == 2) return _ok(_cardView(head, seg[1]));
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
    return _ok({'id': 'tx_new', 'version': 5});
  }

  Future<ApiResponse> _collections(
    String method,
    List<String> seg,
    Map b,
  ) async {
    if (method == 'GET' && seg.length == 1) {
      _requireRead(SectionKey.collections);
      collectionOverviewReads++;
      return _ok(_collectionsView());
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
    final needsVersion = seg.isNotEmpty &&
        (seg.last == 'decision' || seg.last == 'cash-received');
    if (needsVersion && b['expectedVersion'] == null) {
      _fail(400, 'VALIDATION_ERROR', 'expectedVersion مطلوب');
    }
    if (needsVersion && versionConflictRemaining > 0) {
      versionConflictRemaining--;
      _fail(409, 'VERSION_CONFLICT', 'تم تعديل البيانات من مستخدم آخر');
    }
    if (seg.length == 4 && seg[1] == 'submissions' && seg[3] == 'decision') {
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
    // CollectionsRepository.closeDay posts /api/collections/days/close.
    if (seg.length == 3 && seg[1] == 'days' && seg[2] == 'close') {
      return _applyClose(b);
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

  Map<String, dynamic> _cardView(String section, String id) {
    final card = Map<String, dynamic>.from(_requireCard(section, id));
    final state = _cardState['$section|$id'];
    if (state != null) card.addAll(state);
    return card;
  }

  Map<String, dynamic> _accountsView(String section) {
    final body = _copy(FakeFixtures.accountsFor(section));
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
    String section,
    String accountId,
    String txId,
    Map b,
  ) {
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
    final batch = _batchState;
    if (batch != null) body.addAll(batch);
    return body;
  }

  /// Compares the stored batch version. A match stores the next batch id.
  ApiResponse _applyClose(Map b) {
    final current = _collectionsView();
    _requireVersion(b['expectedVersion'], current['version']);
    final version = (current['version'] as int) + 1;
    _batchState = {'batchId': 'b_2', 'version': version};
    return _ok({'id': 'ok', 'version': version});
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
      if (state != null) {
        day.addAll(state);
      } else if (purchaseFixtureStatus != null) {
        day['status'] = purchaseFixtureStatus;
      }
      days.add(day);
    }
    body['days'] = days;
    final opening = _openingByBook[book];
    if (opening != null) body['opening'] = Map<String, dynamic>.from(opening);
    return body;
  }

  ApiResponse _applyOpening(String book, Map b) {
    final days = _purchasesView(book)['days'] as List;
    final stored = _openingByBook[book];
    final current = stored != null
        ? stored['version']
        : (days.isEmpty ? null : (days.first as Map)['version']);
    _requireVersion(b['expectedDayVersion'], current);
    _openingByBook[book] = {
      'previousDebtUnits': b['previousDebtUnits'],
      'previousVodafoneUnits': b['previousVodafoneUnits'],
      'version': current,
    };
    return _ok({'id': 'opening', 'version': current});
  }

  ApiResponse _applyCorrection(String book, String dayId, Map b) {
    Map<String, dynamic>? day;
    for (final raw in _purchasesView(book)['days'] as List) {
      final item = raw as Map<String, dynamic>;
      if ('${item['day']}' == dayId) {
        day = item;
        break;
      }
    }
    if (day == null) _fail(404, 'NOT_FOUND', 'اليوم غير موجود');
    _requireVersion(b['expectedDayVersion'], day['version']);
    final open = b['open'] == true;
    _purchaseDays['$book|$dayId'] = {
      ...?_purchaseDays['$book|$dayId'],
      'status': open ? 'correction' : 'finalized',
    };
    return _ok({
      'id': dayId,
      'version': day['version'],
      'status': open ? 'correction' : 'finalized',
    });
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

String? _queryText(Map<String, dynamic>? query, String key) {
  final value = query?[key];
  if (value == null) return null;
  final text = '$value';
  if (text.isEmpty) return null;
  return text;
}

/// One recorded `GET /api/{section}` (tests).
class AccountListQuery {
  const AccountListQuery({
    required this.section,
    this.filter,
    this.q,
    this.cursor,
  });

  final String section;
  final String? filter;
  final String? q;
  final String? cursor;
}

/// One recorded `GET /api/{section}/suggestions` (tests).
class AccountSuggestionQuery {
  const AccountSuggestionQuery({required this.section, required this.q});

  final String section;
  final String q;
}
