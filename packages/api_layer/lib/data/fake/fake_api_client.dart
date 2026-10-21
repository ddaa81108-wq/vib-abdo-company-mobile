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
/// Password "wrong" -> 401. Fixture pages stay canned. A successful mutation
/// stores its result, and the next read returns that stored result.
///
/// Section reads and writes are rejected with 403 unless the signed-in profile
/// allows them. The check uses [PermissionService], which is the only place that
/// matches the server role string. A successful business mutation is stored by
/// `requestId` for that user; a later call with the same id returns that result
/// and does not apply the operation again. Permission is checked before that
/// replay, so a stored success cannot answer a call the profile may not make.
///
/// 🔶 Status choices below are not confirmed by the server:
/// an employee who calls an admin, approve, reject, or other management route
/// gets 403 `FORBIDDEN` (never an empty list); a route that names another
/// employee's id gets 404 `NOT_FOUND`; an employee reads their own summary
/// from the route that does not take an employee id. A missing session is 401.
///
/// Creating, updating, or deleting a purchase entry on a day whose status is
/// `finalized` is rejected with 409 [dayFinalizedCode]. The README and the
/// in-repo API notes do not name this status or code. `PurchaseDayDto.status`
/// is still marked proposed, so this code is an open stand-in, not a confirmed
/// contract field. A stored success for the same `requestId` does not skip the
/// check.
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

  /// The next N admin employee-totals reads fail after the permission check.
  int failEmployeeTotalsRemaining = 0;

  /// When set, admin employee-totals reads wait here after the permission check.
  Completer<void>? pauseEmployeeTotals;

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

  /// Masraweya day after a successful PUT. Null until the first save.
  ///
  /// Submitted inputs replace the stored day. `workTotalUnits`,
  /// `remainingUnits`, and `historicalAdjustmentUnits` stay as last stored
  /// by the server fixture: this repo does not confirm a formula for them,
  /// and the fake does not invent one.
  Map<String, dynamic>? _masraweyaDay;

  /// Posted lines added by a direct partial payment. Keyed by section.
  final Map<String, List<Map<String, dynamic>>> _extraLedger = {};

  /// Cash lines stored by POST /api/treasury/cash-entries, oldest first.
  final List<Map<String, dynamic>> _cashEntries = [];

  /// Treasury version and the running cash figures stored by those lines.
  /// Null until the first successful entry. Reads otherwise use the fixture.
  Map<String, dynamic>? _treasuryState;
  static const _err = ErrorMapper();
  static const _denied = 'لا تملك صلاحية لهذا الإجراء';
  static const _adminOnly = 'هذا الإجراء للإدارة فقط';

  /// Open stand-in. No in-repo contract names the rejection for a purchase
  /// entry write on a finalized day. HTTP 409 keeps the existing conflict
  /// mapping and leaves [ConflictException.code] as this value, distinct from
  /// `VERSION_CONFLICT`.
  static const dayFinalizedCode = 'DAY_FINALIZED';
  static const dayFinalizedMessage =
      'اليوم مرحّل. لا يمكن إضافة أو تعديل أو حذف بند.';

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

  static const _notFound = 'العنصر غير موجود';

  /// 🔶 Query names the fake treats as an employee id. Own data is not read
  /// through these names.
  static const _employeeQueryKeys = [
    'employeeId',
    'userId',
    'employeeUserId',
  ];

  String? _queryEmployeeId(Map<String, dynamic>? query) {
    if (query == null) return null;
    for (final key in _employeeQueryKeys) {
      final value = query[key];
      if (value == null) continue;
      final text = '$value';
      if (text.isEmpty) continue;
      return text;
    }
    return null;
  }

  /// Another employee's id is 404. The caller's own id on a route that should
  /// not take an employee id is 403. 🔶
  void _rejectEmployeeSelector(String? id) {
    if (id == null) return;
    if (id != _userId) _fail(404, 'NOT_FOUND', _notFound);
    _fail(403, 'FORBIDDEN', _adminOnly);
  }

  void _rejectEmployeeQuery(Map<String, dynamic>? query) {
    _rejectEmployeeSelector(_queryEmployeeId(query));
  }

  bool get _seesEveryCollection =>
      _access.fullAccess || _access.canDo(ManagementAction.collectionsDecide);

  bool get _managesPayroll =>
      _access.fullAccess || _access.canDo(ManagementAction.payrollManage);

  bool _managesDirectory(String head) {
    if (_access.fullAccess) return true;
    if (head == 'account-requests') {
      return _access.canDo(ManagementAction.accountRequestsDecide);
    }
    return _access.canDo(ManagementAction.settingsManage);
  }

  /// Runs before idempotent replay and before the handler. A stored success
  /// must not answer a forbidden call.
  void _authorize(
    String method,
    List<String> seg,
    String head,
    Map<String, dynamic>? query,
  ) {
    switch (head) {
      case 'home':
      case 'event-changes':
      case 'notification-preferences':
        _rejectEmployeeQuery(query);
        return;
      case 'notifications':
        _authorizeNotifications(seg, query);
        return;
      case 'customers':
      case 'companies':
      case 'libyan-deposits':
      case 'egyptian-deposits':
        _authorizeAccounts(method, head, seg, query);
        return;
      case 'collections':
        _authorizeCollections(method, seg, query);
        return;
      case 'masraweya':
        if (method == 'GET') {
          _requireRead(SectionKey.masraweya);
        } else {
          _requireWrite(SectionKey.masraweya);
        }
        return;
      case 'purchases':
        _authorizePurchases(method, seg);
        return;
      case 'treasury':
        if (method == 'GET') {
          _requireRead(SectionKey.treasury);
        } else {
          _requireWrite(SectionKey.treasury);
        }
        return;
      case 'reports':
        if (method != 'GET') _requireWrite(SectionKey.reports);
        _requireRead(SectionKey.reports);
        return;
      case 'statements':
      case 'financial-ledger':
        _requireFullAccess();
        return;
      case 'account-requests':
      case 'users':
      case 'staff':
      case 'employees':
      case 'admins':
      case 'settings':
      case 'audit':
      case 'operations':
        _authorizeAdminApi(head, seg, query);
        return;
    }
  }

  void _authorizeAccounts(
    String method,
    String head,
    List<String> seg,
    Map<String, dynamic>? query,
  ) {
    final section = _sectionFor(head);
    _rejectEmployeeQuery(query);
    if (method == 'GET') {
      _requireRead(section);
      return;
    }
    if (seg.length > 2 && seg[2] == 'zero-review') {
      _requireAction(ManagementAction.customerZeroReview);
      return;
    }
    _requireWrite(section);
  }

  void _authorizePurchases(String method, List<String> seg) {
    if (method == 'GET') {
      _requireRead(SectionKey.purchases);
      return;
    }
    final finalize = seg.isNotEmpty && seg.last == 'finalize';
    final correction =
        method == 'PATCH' && seg.length >= 5 && seg.last == 'correction';
    if (finalize || correction) {
      if (!_access.canFinalizePurchases) _fail(403, 'FORBIDDEN', _denied);
      return;
    }
    _requireWrite(SectionKey.purchases);
  }

  void _authorizeCollections(
    String method,
    List<String> seg,
    Map<String, dynamic>? query,
  ) {
    if (_isSalaryPath(seg)) {
      _authorizeSalary(seg[3]);
      return;
    }
    if (seg.length > 3 && seg[1] == 'payroll' && seg.last == 'confirm') {
      _requireAction(ManagementAction.payrollManage);
      return;
    }
    if (method == 'GET' && seg.length > 1 && seg[1] == 'payroll') {
      _rejectEmployeeQuery(query);
      if (!_managesPayroll && !_access.canWrite(SectionKey.collections)) {
        _fail(403, 'FORBIDDEN', _denied);
      }
      return;
    }
    if (method != 'GET') {
      _requireCollectionMutation(seg);
      return;
    }
    if (seg.length > 1 && seg[1] == 'assignees') {
      _requireAction(ManagementAction.collectionsAssign);
      return;
    }
    if (seg.length == 2 && seg[1] == 'assignments') {
      _requireAction(ManagementAction.collectionsAssign);
      return;
    }
    if (seg.length > 1 && seg[1] == 'link-candidates') {
      _requireAction(ManagementAction.collectionsDecide);
      return;
    }
    _rejectEmployeeQuery(query);
    _requireRead(SectionKey.collections);
  }

  bool _isSalaryPath(List<String> seg) =>
      seg.length >= 5 &&
      seg[1] == 'payroll' &&
      seg[2] == 'employees' &&
      seg[4] == 'salary';

  /// Salary-by-id is a payroll admin route. 🔶 An employee does not pass
  /// their own id here; another employee's id is not found.
  void _authorizeSalary(String employeeId) {
    if (_managesPayroll) return;
    if (employeeId != _userId) _fail(404, 'NOT_FOUND', _notFound);
    _fail(403, 'FORBIDDEN', _adminOnly);
  }

  void _authorizeNotifications(List<String> seg, Map<String, dynamic>? query) {
    _rejectEmployeeQuery(query);
    if (seg.length < 2) return;
    final id = seg[1];
    if (id == 'read-all' || id == 'unread-count') return;
    final owner = _notificationOwner(id);
    if (owner != null && owner != _userId && !_access.fullAccess) {
      _fail(404, 'NOT_FOUND', _notFound);
    }
  }

  String? _notificationOwner(String id) {
    for (final raw in FakeFixtures.notifications(0)['items'] as List) {
      final item = raw as Map;
      if ('${item['id']}' != id) continue;
      final owner = item['recipientUserId'];
      if (owner == null) return null;
      return '$owner';
    }
    return null;
  }

  /// 🔶 Admin catalog paths are proposed. An id that belongs to someone else
  /// is 404 before the 403 for the catalog itself.
  void _authorizeAdminApi(
    String head,
    List<String> seg,
    Map<String, dynamic>? query,
  ) {
    final pathId = _directoryUserId(head, seg);
    if (!_managesDirectory(head)) {
      if (pathId != null && pathId != _userId) {
        _fail(404, 'NOT_FOUND', _notFound);
      }
      final queryId = _queryEmployeeId(query);
      if (queryId != null && queryId != _userId) {
        _fail(404, 'NOT_FOUND', _notFound);
      }
      _fail(403, 'FORBIDDEN', _adminOnly);
    }
  }

  String? _directoryUserId(String head, List<String> seg) {
    const directories = {'users', 'staff', 'employees', 'admins'};
    if (!directories.contains(head) || seg.length < 2) return null;
    return seg[1];
  }

  /// 🔶 GET /api/admin/employee-totals. Full admin only until DEF-002, via
  /// [_requireFullAccess]. An employee, a limited admin, and any other
  /// profile without full access gets 403 and never an empty list. `from`
  /// and `to` are echoed by the fixture. `employeeId` is ignored.
  Future<ApiResponse> _employeeTotals(
    String method,
    List<String> seg,
    Map<String, dynamic>? query,
  ) async {
    if (method != 'GET' || seg.length != 2 || seg[1] != 'employee-totals') {
      _fail(404, 'NOT_FOUND', 'المسار غير موجود في الخادم التجريبي');
    }
    _requireFullAccess();
    final paused = pauseEmployeeTotals;
    if (paused != null) await paused.future;
    if (failEmployeeTotalsRemaining > 0) {
      failEmployeeTotalsRemaining--;
      _fail(500, 'SERVER_ERROR', 'تعذر تحميل إجماليات الموظفين.');
    }
    return _ok(FakeFixtures.employeeTotals(
      from: _queryText(query, 'from'),
      to: _queryText(query, 'to'),
    ));
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
    if (section == 'treasury' && key == 'treasury.activeCash') {
      final stored = _treasuryView()['totals'];
      if (stored is Map && stored['activeCashUnits'] != null) {
        summary['valueUnits'] = stored['activeCashUnits'];
      }
      return summary;
    }
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
    if (path == '/api/me') {
      // Own profile. 🔶 An employee id on this route is not how own data is read.
      _rejectEmployeeQuery(query);
      return _ok(_me);
    }

    if (method != 'GET' &&
        head != 'notifications' &&
        head != 'notification-preferences') {
      return _mutate(
        b,
        method,
        path,
        seg,
        head,
        query,
        () => _route(method, b, seg, head, query),
      );
    }
    return _route(method, b, seg, head, query);
  }

  /// A repeated [requestId] for this user returns the original success and
  /// does not apply the operation again. A failure is not remembered, so a
  /// retry of the same id can still succeed. Permission is checked before
  /// that replay. A purchase-entry write on a finalized day is rejected here
  /// as well, so a stored success cannot skip that check.
  Future<ApiResponse> _mutate(
    Map b,
    String method,
    String path,
    List<String> seg,
    String head,
    Map<String, dynamic>? query,
    Future<ApiResponse> Function() send,
  ) async {
    _requireMutationMeta(b);
    _authorize(method, seg, head, query);
    final requestId = '${b['requestId']}';
    final key = '${_userId ?? ''}|$requestId';
    if (_completedMutations.containsKey(key)) {
      _rejectFinalizedPurchaseEntry(path);
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
    _authorize(method, seg, head, query);
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
          return _ok(_masraweyaView());
        }
        _requireWrite(SectionKey.masraweya);
        if (method == 'PUT') return _saveMasraweyaDay(b);
        return _ok(_masraweyaView());
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
        if (_isPurchaseEntryWrite(method, seg)) {
          _rejectIfPurchaseDayFinalized(seg);
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
          if (seg.length == 1) return _ok(_treasuryView());
          final before = query?['before']?.toString();
          if (before != null && before.isNotEmpty && failOlderRemaining > 0) {
            failOlderRemaining--;
            _fail(503, 'NETWORK_UNAVAILABLE', 'تعذر تحميل الأقدم.');
          }
          return _ok(_cashLedgerView(before));
        }
        _requireWrite(SectionKey.treasury);
        if (method == 'POST' && seg.length > 1 && seg[1] == 'cash-entries') {
          return _applyCashEntry(b);
        }
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
          final data = _notificationsForCaller();
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
      case 'account-requests':
        return _accountRequests(seg, b);
      case 'users':
      case 'staff':
      case 'employees':
      case 'admins':
      case 'settings':
      case 'audit':
      case 'operations':
        // 🔶 Proposed admin catalogs. Reached only after [_authorize].
        return _adminCatalog(head, seg);
      case 'admin':
        return _employeeTotals(method, seg, query);
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
      return _ok(_collectionsForCaller());
    }
    if (method == 'GET' && _isSalaryPath(seg)) {
      return _ok(_salaryRecord(seg[3]));
    }
    if (method == 'GET' && seg.length > 1 && seg[1] == 'payroll') {
      if (!_managesPayroll && !_access.canWrite(SectionKey.collections)) {
        _fail(403, 'FORBIDDEN', _denied);
      }
      return _ok(_payrollForCaller());
    }
    if (method == 'GET' && seg.length > 1 && seg[1] == 'assignees') {
      _requireAction(ManagementAction.collectionsAssign);
      return _ok({
        'items': [
          {
            'id': FakeFixtures.demoEmployeeId,
            'displayName': 'موظف استلام تجريبي',
          },
          {
            'id': FakeFixtures.otherEmployeeId,
            'displayName': 'موظف آخر تجريبي',
          },
        ],
      });
    }
    if (method == 'GET' && seg.length > 1 && seg[1] == 'link-candidates') {
      _requireAction(ManagementAction.collectionsDecide);
      return _ok({
        'items': [
          {'id': 'c_55', 'name': 'عميل تجريبي'},
        ],
      });
    }
    if (method == 'GET' && seg.length == 2 && seg[1] == 'assignments') {
      _requireAction(ManagementAction.collectionsAssign);
      return _ok({'items': _collectionsView()['assignments']});
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
      _requireAction(ManagementAction.payrollManage);
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

  Map<String, dynamic> _masraweyaView() =>
      _copy(_masraweyaDay ?? FakeFixtures.masraweyaDay());

  /// Persists the submitted day. Version, idempotency, and the permission
  /// check are the caller's: [_mutate] stores the first success for
  /// `requestId`, and the route calls [_requireWrite] before this method.
  /// A mismatched `expectedVersion` is 409 and does not change the stored day.
  ApiResponse _saveMasraweyaDay(Map b) {
    final current = _masraweyaView();
    _requireVersion(b['expectedVersion'], current['version']);
    final version = current['version'];
    if (version is! int) {
      _fail(400, 'VALIDATION_ERROR', 'expectedVersion مطلوب');
    }
    final next = _copy(current);
    next['version'] = version + 1;
    final businessDate = b['businessDate'];
    if (businessDate != null) next['businessDate'] = '$businessDate';
    if (b.containsKey('previousValueUnits')) {
      next['previousValueUnits'] = b['previousValueUnits'];
    }
    if (b.containsKey('purchasesUnits')) {
      next['purchasesUnits'] = b['purchasesUnits'];
    }
    final entries = b['entries'];
    if (entries is List) {
      next['entries'] = [
        for (final raw in entries)
          if (raw is Map) Map<String, dynamic>.from(raw),
      ];
    }
    _masraweyaDay = next;
    return _ok(next);
  }

  /// Create is `POST /api/purchases/{book}`. Update and delete are
  /// `POST`/`PATCH`/`DELETE` on `/api/purchases/{book}/entries/{id}`.
  bool _isPurchaseEntryWrite(String method, List<String> seg) {
    if (seg.length < 2 || seg.first != 'purchases') return false;
    if (method == 'POST' && seg.length == 2) return true;
    return seg.length >= 4 &&
        seg[2] == 'entries' &&
        (method == 'POST' || method == 'PATCH' || method == 'DELETE');
  }

  /// Idempotent replay enters here with the path only. [_mutate] is used for
  /// non-GET calls, so an entry-shaped path is a create, update, or delete.
  void _rejectFinalizedPurchaseEntry(String path) {
    final seg =
        path.split('/').where((part) => part.isNotEmpty).skip(1).toList();
    if (seg.length < 2 || seg.first != 'purchases') return;
    final entryPath =
        seg.length == 2 || (seg.length >= 4 && seg[2] == 'entries');
    if (!entryPath) return;
    _rejectIfPurchaseDayFinalized(seg);
  }

  /// The in-repo contract does not define this rejection. Status `finalized`
  /// is the value [_applyFinalize] stores. A day in `correction` stays writable.
  void _rejectIfPurchaseDayFinalized(List<String> seg) {
    final rawDays = _purchasesView(seg[1])['days'];
    if (rawDays is! List || rawDays.isEmpty) return;
    final days = <Map<String, dynamic>>[
      for (final raw in rawDays)
        if (raw is Map) Map<String, dynamic>.from(raw),
    ];
    if (days.isEmpty) return;
    if (seg.length >= 4 && seg[2] == 'entries') {
      final entryId = seg[3];
      Map<String, dynamic>? owner;
      for (final day in days) {
        final entries = day['entries'];
        if (entries is! List) continue;
        for (final entry in entries) {
          if (entry is Map && '${entry['id']}' == entryId) {
            owner = day;
            break;
          }
        }
        if (owner != null) break;
      }
      final blocked = owner != null
          ? owner['status'] == 'finalized'
          : days.every((day) => day['status'] == 'finalized');
      if (blocked) _failDayFinalized();
      return;
    }
    if (days.every((day) => day['status'] == 'finalized')) {
      _failDayFinalized();
    }
  }

  Never _failDayFinalized() =>
      _fail(409, dayFinalizedCode, dayFinalizedMessage);

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

  /// Fixture treasury, with version and running cash from a stored entry.
  Map<String, dynamic> _treasuryView() {
    final body = _copy(FakeFixtures.treasury());
    final state = _treasuryState;
    if (state == null) return body;
    body['version'] = state['version'];
    final totals = Map<String, dynamic>.from(body['totals'] as Map);
    totals['activeCashUnits'] = state['activeCashUnits'];
    totals['netUnits'] = state['netUnits'];
    body['totals'] = totals;
    return body;
  }

  /// First page prepends stored cash lines, newest first. An older page stays
  /// the fixture page: new lines are not copied onto it.
  Map<String, dynamic> _cashLedgerView(String? before) {
    final page = _copy(FakeFixtures.cashLedger(before: before));
    if (before != null && before.isNotEmpty) return page;
    final items = <Map<String, dynamic>>[
      for (final entry in _cashEntries.reversed)
        Map<String, dynamic>.from(entry),
      for (final raw in page['items'] as List)
        Map<String, dynamic>.from(raw as Map),
    ];
    page['items'] = items;
    return page;
  }

  /// Stores one cash line and the running treasury figures.
  ///
  /// `direction` is the line type (`in` or `out`). `amountUnits` is stored as
  /// posted. The running cash is the previous stored active cash with that
  /// amount applied, and the same signed amount is stored on `netUnits`
  /// because the fixture net already includes active cash one-for-one.
  /// `activeCashTone` is left as the fixture sent it. A repeated `requestId`
  /// never reaches this method.
  ApiResponse _applyCashEntry(Map b) {
    final treasury = _treasuryView();
    _requireVersion(b['expectedVersion'], treasury['version']);
    final direction = b['direction'];
    if (direction != 'in' && direction != 'out') {
      _fail(400, 'VALIDATION_ERROR', 'الاتجاه غير معروف');
    }
    final amount = b['amountUnits'];
    if (amount is! int || amount <= 0) {
      _fail(400, 'VALIDATION_ERROR', 'amountUnits مطلوب');
    }
    final totals = treasury['totals'] as Map;
    final previousCash = totals['activeCashUnits'];
    final previousNet = totals['netUnits'];
    if (previousCash is! int || previousNet is! int) {
      _fail(500, 'SERVER_ERROR', 'الخزينة بلا رصيد مخزّن');
    }
    final signed = direction == 'in' ? amount : -amount;
    final runningCash = previousCash + signed;
    final runningNet = previousNet + signed;
    final version = (treasury['version'] as int) + 1;
    final user = _me['user'];
    final actor = user is Map && user['displayName'] != null
        ? '${user['displayName']}'
        : 'مدير تجريبي';
    final stamp = _cashEntries.length;
    final minute = (stamp ~/ 60).toString().padLeft(2, '0');
    final second = (stamp % 60).toString().padLeft(2, '0');
    final entry = <String, dynamic>{
      'id': 'ce_$version',
      'direction': direction,
      'amountUnits': amount,
      'description': b['description'] is String ? b['description'] : null,
      'balanceAfterUnits': runningCash,
      'createdAt': '2026-10-21T03:$minute:$second+02:00',
      'createdByName': actor,
    };
    _cashEntries.add(entry);
    _treasuryState = {
      'version': version,
      'activeCashUnits': runningCash,
      'netUnits': runningNet,
    };
    return _ok({'id': entry['id'], 'version': version});
  }

  Map<String, dynamic> _collectionsForCaller() {
    final body = _collectionsView();
    if (_seesEveryCollection) return body;
    final id = _userId;
    body['assignments'] = _owned(body['assignments'], 'assigneeUserId', id);
    body['submissions'] = _owned(body['submissions'], 'submittedByUserId', id);
    body['unlinkedReceipts'] =
        _owned(body['unlinkedReceipts'], 'submittedByUserId', id);
    body['employeeTotals'] = _owned(body['employeeTotals'], 'userId', id);
    // 🔶 Own overview figures are stored literals, not a sum of the rows above.
    if (id == FakeFixtures.demoEmployeeId) {
      body['metrics'] =
          Map<String, dynamic>.from(FakeFixtures.ownCollectionMetrics);
      body['assignedCount'] = FakeFixtures.ownAssignedCount;
    } else {
      body['metrics'] = {
        'collectedUnits': 0,
        'dayTotalUnits': 0,
        'pendingCount': 0,
        'unlinkedPendingCount': 0,
        'cashOutstandingUnits': 0,
      };
      body['assignedCount'] = 0;
    }
    return body;
  }

  List<Map<String, dynamic>> _owned(Object? raw, String field, String? id) {
    if (raw is! List || id == null) return const [];
    return [
      for (final item in raw)
        if (item is Map && '${item[field]}' == id)
          Map<String, dynamic>.from(item),
    ];
  }

  Map<String, dynamic> _payrollForCaller() {
    final body = _copy(FakeFixtures.payroll());
    if (_managesPayroll) return body;
    body['employees'] = _owned(body['employees'], 'userId', _userId);
    return body;
  }

  Map<String, dynamic> _salaryRecord(String employeeId) {
    for (final raw in FakeFixtures.payroll()['employees'] as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      if ('${row['userId']}' == employeeId) return {'employee': row};
    }
    _fail(404, 'NOT_FOUND', _notFound);
  }

  Map<String, dynamic> _notificationsForCaller() {
    final data = FakeFixtures.notifications(_unread);
    final items = <Map<String, dynamic>>[];
    for (final raw in data['items'] as List) {
      final item = Map<String, dynamic>.from(raw as Map);
      final owner = item['recipientUserId'];
      if (owner == null || _access.fullAccess || '$owner' == _userId) {
        items.add(item);
      }
    }
    data['items'] = items;
    return data;
  }

  ApiResponse _accountRequests(List<String> seg, Map b) {
    if (seg.length >= 3 && seg[2] == 'decision') {
      return _ok({
        'id': seg[1],
        'status': '${b['decision'] ?? 'approved'}',
      });
    }
    return _ok({
      'items': [
        {'id': 'ar_1', 'status': 'pending'},
      ],
    });
  }

  /// 🔶 Proposed admin catalog. Callers who fail [_authorize] never reach this.
  ApiResponse _adminCatalog(String head, List<String> seg) {
    final id = _directoryUserId(head, seg);
    if (id != null) return _ok(_userRecord(id));
    return _ok({
      'items': [
        {'id': 'row_1', 'kind': head},
      ],
    });
  }

  Map<String, dynamic> _userRecord(String id) {
    const known = {
      'u_1': 'مدير تجريبي',
      'u_2': 'إداري محدود تجريبي',
      'u_3': 'إداري بعلم صريح',
      'u_4': 'مستخدم تغيير كلمة المرور',
      'u_9': 'دور غير معروف',
      FakeFixtures.demoEmployeeId: 'موظف استلام تجريبي',
      FakeFixtures.otherEmployeeId: 'موظف آخر تجريبي',
    };
    final name = known[id];
    if (name == null) _fail(404, 'NOT_FOUND', _notFound);
    return {'id': id, 'displayName': name};
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
