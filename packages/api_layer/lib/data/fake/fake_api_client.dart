import 'dart:async';
import 'dart:convert';

import '../../core/config/api_config.dart';
import '../../core/config/release_fake_api_guard.dart';
import '../../core/network/precise_json.dart';
import '../../core/network/wire_json.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/error_mapper.dart';
import '../../core/network/reachability.dart';
import '../../core/permissions/permission_codes.dart';
import '../../core/permissions/permission_service.dart';
import '../models/profile_models.dart';
import '../models/purchase_models.dart';
import 'fake_collections_engine.dart';
import 'fake_fixtures.dart';
import 'fake_large_catalog.dart';

/// In-memory fake of the REAL API shapes so the UI can be built with zero contact
/// with the production system. Same ApiClient interface => Remote*Repository run unchanged.
/// Fake-only fixture switch by USERNAME (see FakeFixtures.meFor): `admin…` = admin like the real
/// server today (empty permission list), `limited.admin…`, `flag.admin…`, `guest…`,
/// `mustchange…`, else employee.
/// Password "wrong" -> 401 invalid credentials. A successful login sets an
/// `abdo_session` cookie and returns `csrfToken`.
///
/// Header checks live only on [serveHttp], the HTTP boundary the Dio adapter
/// uses. An authenticated write that arrives there without
/// `X-Client-Api-Version: 1` returns 409 `CLIENT_VERSION_MISMATCH`. An
/// authenticated write whose `X-CSRF-Token` is missing or stale returns 403
/// `CSRF_REJECTED`. `GET /api/auth/csrf` rotates the token and rejects the
/// previous one. Direct in-process calls (`get`, `post`, and the other
/// [ApiClient] methods when no gateway is bound) skip those header checks so
/// repository tests can call this client without a Dio stack.
/// There is no bearer token and no refresh token. Session
/// lifetime is not known (🔶): this client does not run a local timer. Call
/// [expireSession] to make the current cookie fail the next request.
/// POST /api/auth/logout revokes that cookie. A missing, revoked, or expired
/// cookie then gets 401 AUTH_REQUIRED on every authenticated call, and a
/// stored `requestId` is not returned in place of that 401.
/// Fixture pages stay canned. A successful mutation stores its result, and
/// the next read returns that stored result.
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
/// `finalized` and whose `correctionOpen` is false is rejected with 409
/// [dayFinalizedCode]. The contract names `draft` and `finalized`; this 409
/// code is still a stand-in. A stored success for the same `requestId` does
/// not skip the check. Edit and delete also need the row's `expectedVersion`
/// (400 `INVALID_PURCHASE_VALUE` without it), as production does.
class FakeApiClient implements ApiClient {
  FakeApiClient({
    this.latency = const Duration(milliseconds: 250),
    this.rateWireFormat = RateWireFormat.number,
    String? dataset,
  }) : dataset = FakeDataset.resolve(dataset) {
    // Release AOT never reaches this constructor: the release builder does
    // not import this library. The check is for a test that forces
    // dart.vm.product and still tries to build a fake client.
    if (const bool.fromEnvironment('dart.vm.product')) {
      throw StateError(releaseFakeApiRejectedMessage);
    }
  }

  final Duration latency;
  final RateWireFormat rateWireFormat;

  /// [FakeDataset.standard] or [FakeDataset.large]. Large is debug/profile/test.
  final String dataset;

  bool get _large => dataset == FakeDataset.large;

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

  /// The next N collections writes on the no-replay path are APPLIED, then
  /// answer with a network error, as if the reply was lost (tests).
  int loseCollectionRepliesRemaining = 0;

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

  /// Cursor advertised on the first purchases page. Null keeps the fixture.
  int? purchaseFirstNextBefore;

  /// Older purchases pages keyed by the integer `before` the previous page
  /// advertised. Totals are not stored here; the fixture register totals stay.
  final Map<int, Map<String, dynamic>> purchaseOlderPages = {};

  /// Each purchases list read, including `before` when the app sent one.
  final List<Map<String, dynamic>> purchaseQueries = [];

  /// The next N notification writes fail (tests).
  int failNotificationWritesRemaining = 0;

  /// Notification writes that changed state. A requestId replay is not counted.
  int notificationMutationApplies = 0;

  /// `POST .../decision` when the row is no longer pending.
  static const submissionAlreadyDecidedMessage =
      'تمت مراجعة هذا الاستلام من قبل.';

  /// `POST .../cash-received` when the row is not approved.
  static const submissionNotApprovedMessage =
      'لا يمكن استلام النقدية قبل اعتماد الاستلام.';

  /// When set, a purchase day without a stored finalize or correction uses this
  /// status on the next GET (tests). `correction` is the contract flag
  /// `correctionOpen` on a finalized day, not a third status.
  String? purchaseFixtureStatus;

  /// GET /api/collections calls, including a refetch after a conflict (tests).
  int collectionOverviewReads = 0;

  /// Omit `unreadCount` from the notifications page (tests).
  bool omitUnreadCount = false;

  /// The next N GET /api/notifications/unread-count calls answer 404 (tests).
  int failUnreadCountRemaining = 0;

  /// Registration POSTs to the existing proposed device route (tests).
  /// Unregister posts are not counted. The token is not stored here.
  int mobilePushRegisterPosts = 0;

  /// The next N of those registration POSTs fail. A failure is still counted,
  /// and it is not treated as a stored success by the app.
  int failMobilePushDevicesRemaining = 0;

  /// The next authenticated request fails with this status, once (tests).
  /// 419 uses `PAGE_EXPIRED`, which ends the session and is not a CSRF error.
  int? failNextAuthenticatedStatus;

  /// The next authenticated request, other than login and `GET /api/auth/csrf`,
  /// fails once with this envelope (tests). Login and a CSRF refresh are left
  /// alone so a scripted write can still be followed by a real refresh.
  ({int status, String code, String message})? failNextResponse;

  /// The next GET /api/notifications list (not unread-count) fails with this
  /// status, once (tests). 404 is not found. 401 ends the session. Any other
  /// status is a failed GET.
  int? failNextNotificationListStatus;

  /// Omit `unreadCount` from mark-read and mark-all responses (tests).
  bool omitNotificationWriteUnreadCount = false;

  /// When set, account-suggestion reads wait here (tests).
  Completer<void>? pauseSuggestions;

  /// Account-list reads, in call order (tests). `filter` / `q` / `cursor` are
  /// null when the request omitted them.
  final List<AccountListQuery> accountListQueries = [];

  /// Financial-ledger reads, in call order (tests).
  ///
  /// [FinancialLedgerQuery.section] is the contract query name. It is null
  /// when the request omitted it. [FinancialLedgerQuery.sectionKey] is set
  /// only when a caller sent that query name; the repository sends `section`.
  final List<FinancialLedgerQuery> financialLedgerQueries = [];

  /// When set, the first account-list page reports this `nextCursor` (tests).
  String? accountNextCursor;

  /// Items returned for an account-list read that sends `cursor` (tests).
  List<Map<String, dynamic>> accountNextItems = const [];

  /// One-shot raw `data` JSON for a GET, decoded with [PreciseJson].
  ///
  /// Fractions and oversized integers stay non-integers. The body is not logged.
  /// Authenticated calls still require a session. Tests only.
  final Map<String, String> scriptedGetJson = {};

  /// GETs whose path is a key wait on that completer before [scriptedGetJson]
  /// is read (tests). A path that is absent is not delayed.
  final Map<String, Completer<void>> pauseGets = {};

  /// GET paths that answer 503 until removed (tests).
  final Set<String> failGetPaths = {};

  /// One-shot raw `data` JSON for a non-GET, decoded with [PreciseJson].
  ///
  /// The write is not applied. Tests use this to feed one invalid money field
  /// through the repository parser. The text is not logged. Authenticated
  /// calls still require a session.
  final Map<String, String> scriptedMutationJson = {};

  /// Overlay for `GET /api/treasury` totals (tests).
  ///
  /// A null value is encoded as JSON `null` and the key stays. Every other
  /// total stays the stored fixture or the cash-entry running figure. This
  /// map is not divided, summed, or converted into another currency.
  Map<String, Object?>? treasuryTotalsPatch;

  /// Keys deleted from those totals so the JSON omits them (tests).
  /// Distinct from a null [treasuryTotalsPatch] value, which is sent as null.
  final Set<String> omitTreasuryTotalKeys = {};

  /// `jsonEncode` of the last treasury summary body after the patch (tests).
  String? lastTreasuryJson;

  /// When set, account-list reads wait here (tests).
  Completer<void>? pauseAccountLists;

  /// Suggestion reads, in call order (tests).
  final List<AccountSuggestionQuery> suggestionQueries = [];

  /// When non-null, suggestion reads return these items instead of `[]` (tests).
  List<Map<String, dynamic>>? suggestionItems;

  /// Headers of the latest request, as the fake server saw them (tests).
  Map<String, String> lastRequestHeaders = const {};

  /// Server-side cookie sessions. The id is the `abdo_session` cookie value.
  final Map<String, _FakeSession> _sessions = {};
  final Map<String, _MfaChallenge> _mfaChallenges = {};
  int _sessionSeq = 0;

  /// Marks every pending MFA challenge expired. Tests only.
  void expireMfaChallenges() {
    final past = DateTime.now().toUtc().subtract(const Duration(seconds: 1));
    for (final challenge in _mfaChallenges.values) {
      challenge.expiresAt = past;
    }
  }

  int _csrfSeq = 0;
  String? _jarId;
  String? _latestSessionId;

  /// When set, public calls go through the auth interceptor. [serveHttp] does not.
  ApiClient? _gateway;

  final PermissionService _access = PermissionService();
  final Set<String> _passwordChangedUserIds = {};
  final Map<String, Object?> _completedMutations = {};
  final Map<String, Completer<Object?>> _pendingMutations = {};
  String? _userId;
  Map<String, dynamic> _me = FakeFixtures.me(admin: false);

  /// Per-user notification rows and the server unread counter.
  /// The counter is a stored literal that mark-read decrements. It is not
  /// derived by counting rows on the client.
  bool _noticesReady = false;
  final Map<String, List<Map<String, dynamic>>> _notices = {};
  final Map<String, int> _unreadByUser = {};
  final Map<String, Map<String, dynamic>> _notificationReplays = {};

  /// Large-history reads are generated, not stored. These record mark-read
  /// without keeping every notice map.
  final Set<String> _largeReadIds = {};
  bool _largeAllRead = false;
  static const _noticeReadStamp = '2026-10-21T18:00:00Z';

  /// Card fields changed by a full payment or a cancel. Keyed by section|id.
  final Map<String, Map<String, dynamic>> _cardState = {};

  /// Ledger rows marked reversed, and their new versions. Keyed by section|txId.
  final Map<String, int> _txVersion = {};
  final Set<String> _reversedTx = {};

  /// Purchase day fields changed by finalize or correction. Keyed by book|day.
  final Map<String, Map<String, dynamic>> _purchaseDays = {};

  /// Opening amounts echoed on the next purchases GET. Keyed by book.
  final Map<String, Map<String, dynamic>> _openingByBook = {};

  /// Masraweya days after a successful PUT, keyed by `businessDate`.
  /// Null until the first read builds the fixture day.
  ///
  /// Submitted inputs replace that date only. `workTotalUnits`,
  /// `remainingUnits`, and `historicalAdjustmentUnits` stay as last stored:
  /// this fake does not invent a formula, does not propagate a previous
  /// balance onto the next date, and does not run a 04:00 closure.
  /// `editable` is a stored flag the app reads; it is not computed on device.
  Map<String, Map<String, dynamic>>? _masraweyaByDate;

  /// The fixture's current business date. Not the device clock.
  static const masraweyaToday = '2026-10-19';

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

  /// Routes later public calls through [gateway] (the auth interceptor).
  void bindGateway(ApiClient gateway) => _gateway = gateway;

  /// Client installed by [bindGateway]. The fake stack sets the Dio client.
  ///
  /// A test that observes a call has to wrap this client. Replacing it with
  /// a direct [serveHttp] call skips `X-Client-Api-Version`, the cookie, and
  /// `X-CSRF-Token`, which the HTTP boundary now requires.
  ApiClient? get boundGateway => _gateway;

  /// Drops the in-process cookie jar. The server session is left as it is.
  void dropHeldCookie() => _jarId = null;

  /// Marks the current session expired. The cookie is still presented; the
  /// next authenticated request returns 401. There is no local timer.
  void expireSession() {
    final id = _jarId ?? _latestSessionId;
    final session = id == null ? null : _sessions[id];
    if (session == null) return;
    session.expired = true;
  }

  @override
  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? query,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) =>
      _send('GET', path, null, options, query: query);

  @override
  Future<ApiResponse> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) =>
      _send('POST', path, body, options, query: query);

  @override
  Future<ApiResponse> put(
    String path, {
    Object? body,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) =>
      _send('PUT', path, body, options);

  @override
  Future<ApiResponse> patch(
    String path, {
    Object? body,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) =>
      _send('PATCH', path, body, options);

  @override
  Future<ApiResponse> delete(
    String path, {
    Object? body,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) =>
      _send('DELETE', path, body, options);

  /// One HTTP exchange for the interceptor's adapter. Does not call [bindGateway].
  Future<FakeHttpResult> serveHttp({
    required String method,
    required String path,
    Object? data,
    Map<String, dynamic>? query,
    Map<String, String> headers = const {},
    bool authenticated = true,
  }) async {
    final setCookie = <String>[];
    try {
      final response = await _handle(
        method,
        path,
        data,
        ApiRequestOptions(authenticated: authenticated, headers: headers),
        query: query,
        setCookie: setCookie,
        enforceTransportContract: true,
      );
      return FakeHttpResult(
        status: response.statusCode,
        body: _successWire(response.data),
        setCookie: setCookie,
      );
    } on NetworkException {
      // A simulated lost reply is a transport failure, not an HTTP answer.
      rethrow;
    } on ApiException catch (error) {
      return FakeHttpResult(
        status: error.statusCode ?? 401,
        body: jsonEncode({
          'ok': false,
          'error': {
            'code': error.code,
            'message': error.message,
            'details': error.details ?? <String, Object?>{},
            'correlationId': error.correlationId ?? 'fake',
          },
        }),
        setCookie: setCookie,
      );
    }
  }

  Future<ApiResponse> _send(
    String method,
    String path,
    Object? body,
    ApiRequestOptions options, {
    Map<String, dynamic>? query,
  }) {
    final gateway = _gateway;
    if (gateway == null) {
      return _handle(method, path, body, options, query: query);
    }
    return switch (method) {
      'GET' => gateway.get(path, query: query, options: options),
      'POST' => gateway.post(path, body: body, query: query, options: options),
      'PUT' => gateway.put(path, body: body, options: options),
      'PATCH' => gateway.patch(path, body: body, options: options),
      _ => gateway.delete(path, body: body, options: options),
    };
  }

  String _successWire(Object? data) {
    if (data == null) return '{"ok":true,"data":null}';
    return '{"ok":true,"data":${jsonEncode(data)}}';
  }

  ApiResponse _ok(Object? data, {int status = 200}) {
    ApiReachability.instance.recordSuccess();
    return ApiResponse(
      statusCode: status,
      // Same decode path as the real client: fixtures -> JSON text -> PreciseJson.
      data: data == null ? null : PreciseJson.decode(jsonEncode(data)),
      correlationId: 'fake',
    );
  }

  Never _fail(
    int status,
    String code,
    String message, {
    bool authenticated = true,
    Map<String, Object?>? details,
  }) {
    if (code == 'NETWORK_UNAVAILABLE' || code == 'TIMEOUT') {
      ApiReachability.instance.recordTransportFailure();
    }
    throw _err.fromResponse(
      status,
      {
        'ok': false,
        'error': {
          'code': code,
          'message': message,
          'details': details ?? <String, Object?>{},
          'correlationId': 'fake',
        },
      },
      null,
      authenticated,
    );
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

  /// `GET /api/financial-ledger` is admin-only. The contract code is
  /// `PERMISSION_DENIED`, not the fake's generic `FORBIDDEN`.
  void _requireFinancialLedger() {
    if (!_access.fullAccess) _fail(403, 'PERMISSION_DENIED', _adminOnly);
  }

  static const _notFound = 'العنصر غير موجود';

  /// 🔶 Query names the fake treats as an employee id. Own data is not read
  /// through these names.
  static const _employeeQueryKeys = ['employeeId', 'userId', 'employeeUserId'];

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
        _requireFullAccess();
        return;
      case 'financial-ledger':
        _requireFinancialLedger();
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
      _requireRead(SectionKey.collections);
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
    // 🔶 404 for an id the caller does not own, including an id that does not
    // exist. Same body either way. Full access does not see another user's row.
    final owner = _notificationOwner(id);
    if (owner == null || owner != _userId) {
      _fail(404, 'NOT_FOUND', _notFound);
    }
  }

  String? _notificationOwner(String id) {
    _ensureNotices();
    if (_large) {
      for (final userId in FakeLargeCatalog.noticeUsers) {
        if (FakeLargeCatalog.noticeOrNull(userId, id) != null) return userId;
      }
    }
    for (final entry in _notices.entries) {
      for (final item in entry.value) {
        if ('${item['id']}' == id) return entry.key;
      }
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
    return _ok(
      FakeFixtures.employeeTotals(
        from: _queryText(query, 'from'),
        to: _queryText(query, 'to'),
      ),
    );
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
      sectionAccess: sectionAccessFromJson(section),
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

  /// Extra cards tests append. Empty in ordinary use. Merged with later writes.
  final List<({String section, Map<String, dynamic> card})>
      appendedAccountCards = [];

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
    for (final extra in appendedAccountCards) {
      if (extra.section == head && extra.card['id'] == id) {
        return Map<String, dynamic>.from(extra.card);
      }
    }
    if (_large) {
      final generated = FakeLargeCatalog.cardOrNull(head, id);
      if (generated != null) return Map<String, dynamic>.from(generated);
    }
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
    List<String>? setCookie,
    bool enforceTransportContract = false,
  }) async {
    await Future<void>.delayed(latency);
    lastRequestHeaders = Map<String, String>.from(options.headers);
    // Same serialization as the real client, then decoded like a server would.
    // The interceptor path already encoded the body.
    if (body is String) {
      lastWireBody = body;
    } else {
      lastWireBody =
          body == null ? null : WireJson.encode(body, rateWireFormat);
    }
    final decoded = lastWireBody == null ? null : jsonDecode(lastWireBody!);
    final b = decoded is Map ? decoded : const {};
    final seg = path
        .split('/')
        .where((s) => s.isNotEmpty)
        .skip(1)
        .toList(); // drop "api"
    final head = seg.isEmpty ? '' : seg.first;
    final unsafe = method != 'GET' && method != 'HEAD';

    if (method == 'POST' && path == '/api/auth/login') {
      if (enforceTransportContract) _requireClientApiVersion(options);
      if (b['password'] == 'wrong') {
        _fail(
          401,
          'INVALID_CREDENTIALS',
          'بيانات الدخول غير صحيحة',
          authenticated: false,
        );
      }
      final username = '${b['username']}';
      if (username.startsWith('mfa.')) {
        final id = 'mfa-${++_sessionSeq}';
        _mfaChallenges[id] = _MfaChallenge(
          username,
          DateTime.now().toUtc().add(const Duration(minutes: 5)),
        );
        setCookie?.add(
          '${ApiConfig.mfaCookieName}=$id; Path=/api/auth; HttpOnly; Secure; SameSite=Lax; Max-Age=300',
        );
        _fail(401, 'MFA_REQUIRED', 'أدخل رمز التحقق', authenticated: false);
      }
      final previous = _jarId;
      if (previous != null) {
        _sessions.remove(previous);
      }
      _activate(FakeFixtures.meFor('${b['username']}'));
      final id = 'fake-session-${++_sessionSeq}';
      final csrfToken = _allocateCsrf();
      _sessions[id] = _FakeSession(id: id, me: _me, csrfToken: csrfToken);
      _latestSessionId = id;
      _jarId = id;
      setCookie?.add(
        '${ApiConfig.sessionCookieName}=$id; Path=/; HttpOnly; Secure; SameSite=Strict',
      );
      return _ok({..._me, 'csrfToken': csrfToken});
    }
    if (method == 'POST' && path == ApiEndpoints.mfaVerify) {
      return _verifyMfa(options, b, setCookie);
    }
    if (path == '/api/auth/csrf') {
      return _rotateCsrf(options);
    }
    if (options.authenticated) _ensureSession(options);
    // 401 from the session check stays ahead of 409 and 403.
    if (enforceTransportContract && unsafe) {
      _requireClientApiVersion(options);
    }
    if (enforceTransportContract && unsafe && options.authenticated) {
      _requireCurrentCsrf(options);
    }
    final scriptedFailure = failNextResponse;
    if (scriptedFailure != null &&
        path != '/api/auth/login' &&
        path != '/api/auth/csrf') {
      failNextResponse = null;
      _fail(
        scriptedFailure.status,
        scriptedFailure.code,
        scriptedFailure.message,
        authenticated: options.authenticated,
      );
    }
    if (method == 'GET') {
      final gate = pauseGets[path];
      if (gate != null) await gate.future;
      if (failGetPaths.contains(path)) {
        _fail(503, 'NETWORK_UNAVAILABLE', 'تعذر تحميل الكارت.');
      }
      final scripted = scriptedGetJson.remove(path);
      if (scripted != null) {
        return ApiResponse(
          statusCode: 200,
          data: PreciseJson.decode(scripted),
          correlationId: 'fake',
        );
      }
    } else {
      final scripted = scriptedMutationJson.remove(path);
      if (scripted != null) {
        // The stored rows are not changed. Keep the request text for tests
        // that pause the follow-up GET, which replaces [lastWireBody].
        if (lastWireBody != null) mutationBodies.add(lastWireBody!);
        return ApiResponse(
          statusCode: 200,
          data: PreciseJson.decode(scripted),
          correlationId: 'fake',
        );
      }
    }
    if (path == '/api/auth/logout') {
      final id = _presentedSessionId(options);
      if (id != null) _sessions.remove(id);
      if (_jarId == id) _jarId = null;
      _userId = null;
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

    // 🔶 Existing proposed route. Not a new API. Accepted here so a successful
    // registration can be told apart from a failure. The token is not stored.
    if (method == 'POST' && path == ApiEndpoints.proposedMobilePushDevices) {
      return _mobilePushDevices(b);
    }

    if (method != 'GET' &&
        head != 'notifications' &&
        head != 'notification-preferences') {
      // 537f073 collections routes do not replay by requestId (unlinked
      // receipts and payroll entries do, inside the collections engine).
      // A shared replay here would hide the server's own rules.
      if (seg.isNotEmpty && seg.first == 'collections') {
        return _mutateWithoutRequestId(
          b,
          method,
          path,
          seg,
          head,
          query,
          () => _route(method, b, seg, head, query),
          () => _ensureSession(options),
        );
      }
      return _mutate(
        b,
        method,
        path,
        seg,
        head,
        query,
        () => _route(method, b, seg, head, query),
        () => _ensureSession(options),
      );
    }
    return _route(method, b, seg, head, query);
  }

  /// Proposed `POST /api/mobile-push/devices`. The body is not kept.
  Future<ApiResponse> _mobilePushDevices(Map<dynamic, dynamic> body) async {
    if (body['unregister'] == true) return _ok(const <String, Object?>{});
    mobilePushRegisterPosts++;
    if (failMobilePushDevicesRemaining > 0) {
      failMobilePushDevicesRemaining--;
      _fail(503, 'NETWORK_UNAVAILABLE', 'تعذر تسجيل الجهاز.');
    }
    return _ok(const <String, Object?>{});
  }

  ApiResponse _verifyMfa(
    ApiRequestOptions options,
    Map b,
    List<String>? setCookie,
  ) {
    final id = _namedCookie(options, ApiConfig.mfaCookieName);
    final challenge = id == null ? null : _mfaChallenges[id];
    if (challenge == null ||
        !DateTime.now().toUtc().isBefore(challenge.expiresAt)) {
      if (id != null) _mfaChallenges.remove(id);
      setCookie?.add('${ApiConfig.mfaCookieName}=; Path=/api/auth; Max-Age=0');
      _fail(401, 'MFA_INVALID', 'انتهت صلاحية التحقق', authenticated: false);
    }
    final code = b['code'];
    if (code is! String || code != FakeFixtures.mfaFixtureCode) {
      challenge.failures += 1;
      if (challenge.failures >= 8) {
        _fail(
          429,
          'LOGIN_RATE_LIMITED',
          'محاولات كثيرة. أعد المحاولة لاحقًا.',
          authenticated: false,
        );
      }
      _fail(401, 'MFA_INVALID', 'رمز التحقق غير صحيح', authenticated: false);
    }
    _mfaChallenges.remove(id);
    setCookie?.add('${ApiConfig.mfaCookieName}=; Path=/api/auth; Max-Age=0');
    final previous = _jarId;
    if (previous != null) _sessions.remove(previous);
    _activate(FakeFixtures.meFor(challenge.username));
    final sessionId = 'fake-session-${++_sessionSeq}';
    final csrfToken = _allocateCsrf();
    _sessions[sessionId] =
        _FakeSession(id: sessionId, me: _me, csrfToken: csrfToken);
    _latestSessionId = sessionId;
    _jarId = sessionId;
    setCookie?.add(
      '${ApiConfig.sessionCookieName}=$sessionId; Path=/; HttpOnly; Secure; SameSite=Strict',
    );
    return _ok({..._me, 'csrfToken': csrfToken});
  }

  String? _namedCookie(ApiRequestOptions options, String name) {
    final raw =
        _hasHeader(options, 'cookie') ? _header(options, 'cookie') : null;
    if (raw == null) return null;
    for (final part in raw.split(';')) {
      final piece = part.trim();
      final eq = piece.indexOf('=');
      if (eq <= 0) continue;
      if (piece.substring(0, eq).trim().toLowerCase() == name) {
        final value = piece.substring(eq + 1).trim();
        return value.isEmpty ? null : value;
      }
    }
    return null;
  }

  /// Cookie session check. A missing, revoked, or expired cookie is 401
  /// before any permission decision.
  void _ensureSession(ApiRequestOptions options) {
    final forced = failNextAuthenticatedStatus;
    if (forced != null) {
      failNextAuthenticatedStatus = null;
      if (forced == 419) {
        _fail(419, 'PAGE_EXPIRED', 'يجب تسجيل الدخول أولًا.');
      }
      _fail(forced, 'AUTH_REQUIRED', 'يجب تسجيل الدخول أولًا.');
    }
    final id = _presentedSessionId(options);
    final session = id == null ? null : _sessions[id];
    if (session == null || session.expired) {
      _fail(401, 'AUTH_REQUIRED', 'يجب تسجيل الدخول أولًا.');
    }
    final user = session.me['user'];
    if (user is Map && user['id'] != null) _userId = '${user['id']}';
  }

  String? _presentedSessionId(ApiRequestOptions options) {
    if (_hasHeader(options, 'cookie')) {
      return _sessionIdFromCookie(_header(options, 'cookie'));
    }
    return _jarId;
  }

  bool _hasHeader(ApiRequestOptions options, String name) {
    final wanted = name.toLowerCase();
    return options.headers.keys.any((key) => key.toLowerCase() == wanted);
  }

  String? _header(ApiRequestOptions options, String name) {
    final wanted = name.toLowerCase();
    for (final entry in options.headers.entries) {
      if (entry.key.toLowerCase() == wanted) {
        final value = entry.value.trim();
        return value.isEmpty ? null : value;
      }
    }
    return null;
  }

  String? _sessionIdFromCookie(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final part in raw.split(';')) {
      final piece = part.trim();
      final eq = piece.indexOf('=');
      if (eq <= 0) continue;
      final name = piece.substring(0, eq).trim().toLowerCase();
      if (name == ApiConfig.sessionCookieName) {
        return piece.substring(eq + 1).trim();
      }
    }
    return null;
  }

  /// First issued token stays `fake-csrf` so existing header assertions hold.
  /// Later issues, including a CSRF rotation, are distinct and the previous
  /// value is no longer accepted.
  String _allocateCsrf() {
    final token = _csrfSeq == 0 ? 'fake-csrf' : 'fake-csrf-$_csrfSeq';
    _csrfSeq++;
    return token;
  }

  void _requireClientApiVersion(ApiRequestOptions options) {
    final version = _header(options, ApiConfig.clientApiVersionHeader);
    if (version == ApiConfig.clientApiVersion) return;
    _fail(
      409,
      'CLIENT_VERSION_MISMATCH',
      'إصدار العميل غير مدعوم.',
      details: const <String, Object?>{
        'requiredApiVersion': ApiConfig.clientApiVersion,
      },
    );
  }

  _FakeSession? _liveSession(ApiRequestOptions options) {
    final id = _presentedSessionId(options);
    if (id == null) return null;
    final session = _sessions[id];
    if (session == null || session.expired) return null;
    return session;
  }

  ApiResponse _rotateCsrf(ApiRequestOptions options) {
    final session = _liveSession(options);
    if (session == null) {
      _fail(401, 'AUTH_REQUIRED', 'يجب تسجيل الدخول أولًا.');
    }
    session.csrfToken = _allocateCsrf();
    return _ok({'csrfToken': session.csrfToken});
  }

  void _requireCurrentCsrf(ApiRequestOptions options) {
    final session = _liveSession(options);
    if (session == null) {
      _fail(401, 'AUTH_REQUIRED', 'يجب تسجيل الدخول أولًا.');
    }
    final sent = _header(options, 'x-csrf-token');
    if (sent == null || sent != session.csrfToken) {
      _fail(403, 'CSRF_REJECTED', 'تم رفض طلب الحماية.');
    }
  }

  /// A repeated [requestId] for this user returns the original success and
  /// does not apply the operation again. A failure is not remembered, so a
  /// retry of the same id can still succeed. Each attempt checks the cookie
  /// session first, then permission, then the stored success. A dead session
  /// is checked again after [pauseMutations], so an in-flight write cannot
  /// skip a 401. A purchase-entry write on a finalized day is rejected here
  /// as well, so a stored success cannot skip that check.
  Future<ApiResponse> _mutate(
    Map b,
    String method,
    String path,
    List<String> seg,
    String head,
    Map<String, dynamic>? query,
    Future<ApiResponse> Function() send,
    void Function() ensureSession,
  ) async {
    _requireMutationMeta(b);
    ensureSession();
    _authorize(method, seg, head, query);
    final requestId = '${b['requestId']}';
    final key = '${_userId ?? ''}|$requestId';
    if (_completedMutations.containsKey(key)) {
      ensureSession();
      _authorize(method, seg, head, query);
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
      ensureSession();
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

  /// Collection decision and cash-received. The contract has no `requestId`
  /// and no `expectedVersion`. Session, permission, and the test failure gate
  /// still run. A second call is not a stored replay; the row status decides.
  Future<ApiResponse> _mutateWithoutRequestId(
    Map b,
    String method,
    String path,
    List<String> seg,
    String head,
    Map<String, dynamic>? query,
    Future<ApiResponse> Function() send,
    void Function() ensureSession,
  ) async {
    ensureSession();
    _authorize(method, seg, head, query);
    // Recorded for tests only; these routes do not replay by it.
    final requestId = b['requestId'];
    if (requestId != null) mutationRequestIds.add('$requestId');
    mutationPaths.add(path);
    if (lastWireBody != null) mutationBodies.add(lastWireBody!);
    final paused = pauseMutations;
    if (paused != null) await paused.future;
    ensureSession();
    _authorize(method, seg, head, query);
    if (failMutationsRemaining > 0) {
      failMutationsRemaining--;
      _fail(400, 'MUTATION_FAILED', 'تعذر تنفيذ الطلب.');
    }
    final response = await send();
    if (loseCollectionRepliesRemaining > 0) {
      loseCollectionRepliesRemaining--;
      throw const NetworkException();
    }
    return response;
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
        return _collections(method, seg, b, query);
      case 'masraweya':
        if (method == 'GET') {
          _requireRead(SectionKey.masraweya);
          return _ok(_masraweyaView(query));
        }
        _requireWrite(SectionKey.masraweya);
        if (method == 'PUT') return _saveMasraweyaDay(b);
        return _ok(_masraweyaView(query));
      case 'purchases':
        if (method == 'GET') {
          _requireRead(SectionKey.purchases);
          if (query != null) {
            purchaseQueries.add(Map<String, dynamic>.from(query));
          }
          final before = _queryInt(query, 'before');
          if (before != null && failOlderRemaining > 0) {
            failOlderRemaining--;
            _fail(503, 'NETWORK_UNAVAILABLE', 'تعذر تحميل الأقدم.');
          }
          return _ok(_purchasesView(seg.length > 1 ? seg[1] : '', before));
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
        final rowWrite = (method == 'PATCH' || method == 'DELETE') &&
            seg.length > 3 &&
            seg[2] == 'entries';
        if (rowWrite) {
          // Production needs the row's own `expectedVersion` next to
          // `expectedDayVersion` on edit and delete.
          if (b['expectedVersion'] is! int) {
            _fail(
              400,
              'INVALID_PURCHASE_VALUE',
              'إصدار المعاملة يجب أن يكون رقمًا صحيحًا بدون كسور.',
            );
          }
          return _ok({'entryId': seg[3], 'eventSequences': const []});
        }
        // Production create answers `{entryId, sequence, eventSequences}`.
        return _ok({
          'entryId': 'pe_new',
          'sequence': 99,
          'eventSequences': const [],
        });
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
        _requireFinancialLedger();
        final section = _queryText(query, 'section');
        financialLedgerQueries.add(
          FinancialLedgerQuery(
            section: section,
            sectionKey: _queryText(query, 'sectionKey'),
          ),
        );
        final page = FakeFixtures.financialLedger(
          sectionKey: section ?? _queryText(query, 'sectionKey'),
        );
        return _ok(_filterLedgerPage(page, query));
      case 'notifications':
        return _notifications(method, seg, b, query);
      case 'notification-preferences':
        return _ok({'soundEnabled': true, 'speechEnabled': false});
      case 'event-changes':
        return _ok({'events': [], 'latest': 0, 'fullResync': false});
      case 'health':
        return _ok(FakeFixtures.health());
      case 'audit-log':
        return _ok(FakeFixtures.auditLog());
      case 'account-requests':
        return _accountRequests(method, seg, b);
      case 'users':
        return _loginUsers(method, seg, b);
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
        if (_large && FakeLargeCatalog.pagesAccounts(head)) {
          final generated = FakeLargeCatalog.accountPage(
            section: head,
            cursor: cursor,
            limit: _pageLimit(query),
            q: q,
            filter: filter,
          );
          return _ok(_overlayCards(head, generated));
        }
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
        return _ok(_ledgerView(head, before, accountId: seg[1]));
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
    if (method == 'POST' &&
        seg.length == 5 &&
        seg[2] == 'transactions' &&
        seg[4] == 'corrections') {
      return _applyTxCorrection(head, seg[1], b);
    }
    if (method == 'PATCH' && seg.length == 3 && seg[2] == 'pin') {
      return _applyPin(head, seg[1], b);
    }
    if (method == 'POST' && seg.length == 3 && seg[2] == 'zero-review') {
      return _applyZeroReview(head, seg[1], b);
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
    Map<String, dynamic>? query,
  ) async {
    if (method == 'GET' && seg.length == 1) {
      _requireRead(SectionKey.collections);
      collectionOverviewReads++;
      if (_large) return _ok(_largeCollections(query));
      return _engine(() => collectionsEngine.overview(_collectionsCaller));
    }
    if (method == 'GET' && _isSalaryPath(seg)) {
      return _ok(_salaryRecord(seg[3]));
    }
    if (method == 'GET' && seg.length > 1 && seg[1] == 'payroll') {
      if (!_managesPayroll && !_access.canWrite(SectionKey.collections)) {
        _fail(403, 'FORBIDDEN', _denied);
      }
      return _engine(() => collectionsEngine.payroll(_payrollCaller));
    }
    if (method == 'GET' && seg.length > 1 && seg[1] == 'assignees') {
      _requireAction(ManagementAction.collectionsAssign);
      return _engine(collectionsEngine.assignees);
    }
    if (method == 'GET' && seg.length > 1 && seg[1] == 'link-candidates') {
      _requireAction(ManagementAction.collectionsDecide);
      return _engine(
        () => collectionsEngine.linkCandidates(_queryText(query, 'q')),
      );
    }
    if (method == 'GET' && seg.length == 2 && seg[1] == 'assignments') {
      _requireAction(ManagementAction.collectionsAssign);
      return _engine(
        () => {
          'items':
              collectionsEngine.overview(_collectionsCaller)['assignments'],
        },
      );
    }
    if (method == 'GET') {
      _requireRead(SectionKey.collections);
      // 537f073 has no /workspace or /mine route.
      _fail(404, 'ROUTE_NOT_FOUND', 'المسار المطلوب غير موجود.');
    }
    if (method == 'PUT' && _isSalaryPath(seg)) {
      _requireAction(ManagementAction.payrollManage);
      return _engine(
        () => collectionsEngine.setSalary(_payrollCaller, seg[3], b),
      );
    }
    _requireCollectionMutation(seg);
    final engine = collectionsEngine;
    if (seg.length == 4 && seg[1] == 'submissions' && seg[3] == 'decision') {
      return _engine(() => engine.decide(seg[2], b));
    }
    if (seg.length == 4 &&
        seg[1] == 'submissions' &&
        seg[3] == 'cash-received') {
      return _engine(() => engine.cashReceived(seg[2]));
    }
    if (seg.length == 4 &&
        seg[1] == 'unlinked-receipts' &&
        seg[3] == 'decision') {
      return _engine(() => engine.decideUnlinked(seg[2], b));
    }
    if (seg.length == 4 &&
        seg[1] == 'unlinked-receipts' &&
        seg[3] == 'cash-received') {
      return _engine(() => engine.unlinkedCashReceived(seg[2]));
    }
    // CollectionsRepository.closeDay posts /api/collections/days/close.
    if (seg.length == 3 && seg[1] == 'days' && seg[2] == 'close') {
      return _engine(() => engine.closeDay(b));
    }
    if (method == 'POST' && seg.length == 2 && seg[1] == 'assignments') {
      // 537f073 answers 201 `{ok, data: {assignmentIds, eventSequences}}`.
      return _engine(() => engine.assign(b), status: 201);
    }
    if (seg.length == 4 && seg[1] == 'assignments' && seg[3] == 'submissions') {
      return _engine(() => engine.submit(_collectionsCaller, seg[2], b));
    }
    if (seg.length == 2 && seg[1] == 'unlinked-receipts') {
      return _engine(() => engine.createUnlinked(_collectionsCaller, b));
    }
    if (seg.length == 3 && seg[1] == 'payroll' && seg[2] == 'entries') {
      return _engine(() => engine.addPayrollEntry(_payrollCaller, b));
    }
    if (seg.length == 5 &&
        seg[1] == 'payroll' &&
        seg[2] == 'entries' &&
        seg[4] == 'confirm') {
      return _engine(
        () => engine.confirmPayrollEntry(_payrollCaller, seg[3]),
      );
    }
    _fail(404, 'ROUTE_NOT_FOUND', 'المسار المطلوب غير موجود.');
  }

  FakeCollectionCard? _collectionCard(String section, String id) {
    final base = _cardOrNull(section, id);
    if (base == null) return null;
    final card = _cardView(section, id);
    final balance = card['balanceUnits'];
    if (balance is! int) return null;
    return FakeCollectionCard(
      id: id,
      section: section,
      name: '${card['name']}',
      phone: card['phone'] as String?,
      balanceUnits: balance,
      version: card['version'] as int?,
    );
  }

  int _postCollectionDelta(String section, String id, int delta) {
    final card = _cardView(section, id);
    final stored = (card['balanceUnits'] as int) + delta;
    final version = card['version'];
    _cardState['$section|$id'] = {
      ...?_cardState['$section|$id'],
      'balanceUnits': stored,
      'version': version is int ? version + 1 : 1,
    };
    return stored;
  }

  /// The 537f073 collections rules (see [FakeCollectionsEngine]).
  late final FakeCollectionsEngine collectionsEngine = FakeCollectionsEngine(
    _FakeCollectionCardsBridge(this),
    demoEmployeeId: FakeFixtures.demoEmployeeId,
    otherEmployeeId: FakeFixtures.otherEmployeeId,
  );

  FakeCollectionsCaller get _collectionsCaller => FakeCollectionsCaller(
        id: _userId,
        name: _displayName() ?? '',
        seesEverything: _seesEveryCollection,
      );

  /// Payroll is admin-scoped by the payroll manage action, not by decide.
  FakeCollectionsCaller get _payrollCaller => FakeCollectionsCaller(
        id: _userId,
        name: _displayName() ?? '',
        seesEverything: _managesPayroll,
      );

  ApiResponse _engine(
    Map<String, dynamic> Function() run, {
    int status = 200,
  }) {
    try {
      return _ok(run(), status: status);
    } on FakeCollectionsFailure catch (failure) {
      _fail(
        failure.status,
        failure.code,
        failure.message,
        details: failure.details,
      );
    }
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
      // 537f073: the employee confirms their own entry; admin may not.
      _requireRead(SectionKey.collections);
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
    _overlayAssignee(section, card);
    return card;
  }

  /// `activeAssigneeName` derived from the engine's active assignments, as
  /// on 537f073 (the fixture does not hard-code it).
  void _overlayAssignee(String section, Map<String, dynamic> card) {
    if (section != 'customers' && section != 'companies') return;
    final assignee =
        collectionsEngine.activeAssigneeName(section, '${card['id']}');
    if (assignee == null) {
      card.remove('activeAssigneeName');
    } else {
      card['activeAssigneeName'] = assignee;
    }
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
      _overlayAssignee(section, card);
      items.add(card);
    }
    for (final extra in appendedAccountCards) {
      if (extra.section != section) continue;
      final card = Map<String, dynamic>.from(extra.card);
      final state = _cardState['$section|${card['id']}'];
      if (state != null) card.addAll(state);
      _overlayAssignee(section, card);
      items.insert(0, card);
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

  Map<String, dynamic> _ledgerView(
    String section,
    String? before, {
    String? accountId,
  }) {
    if (_large &&
        accountId != null &&
        FakeLargeCatalog.isLongLedger(section, accountId)) {
      return FakeLargeCatalog.ledgerPage(before: before);
    }
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
    final previous = card['balanceUnits'];
    final version = (card['version'] as int) + 1;
    _cardState['$section|${card['id']}'] = {
      'balanceUnits': 0,
      'version': version,
    };
    return _ok(
      _ledgerWriteData(
        version: version,
        section: section,
        request: b,
        balanceUnits: 0,
        amountUnits: previous is int && previous > 0 ? previous : 0,
      ),
    );
  }

  /// Debt or partial payment. The version is the card's stored version.
  ///
  /// A direct partial payment stores `previous - inputValue` and returns that
  /// integer as `balanceUnits`. A larger integer is accepted (DEF-031): the
  /// contract does not reject it and does not use an `OVERPAYMENT` code. The
  /// stored balance may be negative. The app does not calculate it. A
  /// rate-based movement only bumps the version; this fake does not turn a
  /// factor into an amount, and it does not compare that factor with the
  /// balance. The ack then echoes the balance still stored on the card.
  ApiResponse _applyMovement(String section, String id, Map b) {
    final card = _cardView(section, id);
    _requireVersion(b['expectedVersion'], card['version']);
    final previous = card['balanceUnits'];
    final entered = b['inputValue'];
    final version = (card['version'] as int) + 1;
    final state = <String, dynamic>{'version': version};
    Object? balance = previous is int ? previous : null;
    Object? amount;
    if (b['type'] == 'payment' &&
        b['paymentMode'] == 'partial' &&
        b['calculationMode'] == 'direct' &&
        previous is int &&
        entered is int) {
      final stored = previous - entered;
      balance = stored;
      amount = entered;
      state['balanceUnits'] = stored;
      _extraLedger.putIfAbsent(section, () => []).add({
        'id': 'tx_partial_$version',
        'sequence': version,
        'type': 'payment',
        'status': 'posted',
        'paymentMode': 'partial',
        'transactionDate': b['date'],
        'amountUnits': entered,
        'inputValue': entered,
        'calculationMode': 'direct',
        'balanceAfterUnits': stored,
        'createdByName': 'مدير تجريبي',
      });
    }
    _cardState['$section|${card['id']}'] = state;
    return _ok(
      _ledgerWriteData(
        version: version,
        section: section,
        request: b,
        balanceUnits: balance,
        amountUnits: amount,
      ),
    );
  }

  /// Contract ledger-write `data`, plus the top-level `id` and `version` this
  /// fake already returned. [balanceUnits] is written only when it is an int.
  /// A missing balance is omitted, not sent as 0.
  Map<String, dynamic> _ledgerWriteData({
    required int version,
    required String section,
    required Map request,
    required Object? balanceUnits,
    Object? amountUnits,
    String id = 'tx_new',
  }) {
    final data = <String, dynamic>{
      'id': id,
      'version': version,
      'customerVersion': version,
      'transaction': <String, dynamic>{
        'id': id,
        'type': request['type'],
        if (amountUnits is int) 'amountUnits': amountUnits,
        'currency': section == 'egyptian-deposits' ? 'EGP' : 'LYD',
        if (request['paymentMode'] != null)
          'paymentMode': request['paymentMode'],
        if (request['calculationMode'] != null)
          'calculationMode': request['calculationMode'],
        if (request['inputValue'] is int) 'inputValue': request['inputValue'],
        'factorMicros': null,
        if (request['date'] != null) 'transactionDate': request['date'],
        if (request['note'] != null) 'note': request['note'],
        'actorName': 'مدير تجريبي',
        'sequence': version,
        'status': 'posted',
        'correctsTransactionId': null,
      },
    };
    if (balanceUnits is int) data['balanceUnits'] = balanceUnits;
    return data;
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
    // Production checks cancel against the CARD version (`customerVersion`).
    final card = _cardView(section, accountId);
    if (b['expectedVersion'] == null) {
      _fail(
        400,
        'EXPECTED_VERSION_REQUIRED',
        'يلزم إرسال expectedVersion لمنع استبدال تعديل أحدث.',
      );
    }
    _requireVersion(b['expectedVersion'], card['version']);
    final key = '$section|$txId';
    _reversedTx.add(key);
    final lineVersion = entry['version'];
    if (lineVersion is int) _txVersion[key] = lineVersion + 1;
    final version = (card['version'] as int) + 1;
    final stored = _latestPostedBalance(section);
    _cardState['$section|${card['id']}'] = {
      'balanceUnits': stored,
      'version': version,
    };
    return _ok({
      'id': 'tx_new',
      'version': version,
      'transactionId': txId,
      'status': 'reversed',
      'customerVersion': version,
      'balanceUnits': stored,
    });
  }

  /// Correction of one line. Production checks the CARD version, like
  /// cancel, and answers with the new `customerVersion`. The amount is not
  /// recomputed here; the stored card balance is echoed.
  ApiResponse _applyTxCorrection(String section, String accountId, Map b) {
    final card = _cardView(section, accountId);
    if (b['expectedVersion'] == null) {
      _fail(
        400,
        'EXPECTED_VERSION_REQUIRED',
        'يلزم إرسال expectedVersion لمنع استبدال تعديل أحدث.',
      );
    }
    _requireVersion(b['expectedVersion'], card['version']);
    final version = (card['version'] as int) + 1;
    _cardState['$section|${card['id']}'] = {
      ...?_cardState['$section|${card['id']}'],
      'version': version,
    };
    return _ok(
      _ledgerWriteData(
        version: version,
        section: section,
        request: b,
        balanceUnits: card['balanceUnits'],
      ),
    );
  }

  /// PATCH /{section}/{id}/pin `{expectedVersion, isPinned}`. Production
  /// rejects any other body (for example `pinned`) with 400
  /// `INVALID_PIN_STATE`.
  ApiResponse _applyPin(String section, String accountId, Map b) {
    final pinned = b['isPinned'];
    if (pinned is! bool) {
      _fail(400, 'INVALID_PIN_STATE', 'حالة التثبيت غير صالحة.');
    }
    final card = _cardView(section, accountId);
    _requireVersion(b['expectedVersion'], card['version']);
    final version = (card['version'] as int) + 1;
    _cardState['$section|${card['id']}'] = {
      ...?_cardState['$section|${card['id']}'],
      'version': version,
      'isPinned': pinned,
      'pinned': pinned,
    };
    return _ok({
      'customerId': card['id'],
      'isPinned': pinned,
      'customerVersion': version,
    });
  }

  /// POST /customers/{id}/zero-review. Stores the documented closed review
  /// (`pending: false`) so the next list read is the server status. Does not
  /// change the balance.
  ApiResponse _applyZeroReview(String section, String accountId, Map b) {
    if (section != 'customers') {
      _fail(404, 'NOT_FOUND', 'المسار غير موجود في الخادم التجريبي');
    }
    final card = _cardView(section, accountId);
    if (!b.containsKey('expectedFinancialVersion')) {
      _fail(400, 'INVALID_REVIEW_VERSION', 'الإصدار المالي مطلوب.');
    }
    final review = card['zeroReview'];
    final financial = review is Map && review['financialVersion'] is int
        ? review['financialVersion'] as int
        : null;
    if (financial != null && b['expectedFinancialVersion'] != financial) {
      _fail(
        409,
        'ZERO_REVIEW_CHANGED',
        'تغيرت الحالة المالية؛ حدّث بيانات الكارت.',
      );
    }
    if (financial == null) {
      _requireVersion(b['expectedFinancialVersion'], card['version']);
    }
    final version = card['version'] is int ? card['version'] as int : 0;
    final closed = {
      'pending': false,
      'financialVersion': version,
      'reviewedAt': '2026-10-22T22:00:00.000Z',
      'reviewedByName': _displayName() ?? 'مدير تجريبي',
    };
    _cardState['$section|$accountId'] = {
      ...?_cardState['$section|$accountId'],
      'zeroReview': closed,
    };
    return _ok({'zeroReview': closed});
  }

  String? _displayName() {
    final user = _me['user'];
    if (user is Map && user['displayName'] is String) {
      final name = user['displayName'] as String;
      if (name.isNotEmpty) return name;
    }
    return null;
  }

  /// Open day after stored finalize, correction, fixture status, and opening.
  /// Opening amounts land on the day. The contract has no `opening` object.
  Map<String, dynamic>? _openPurchaseDay(String book) {
    final raw = _copy(FakeFixtures.purchases())['day'];
    if (raw is! Map) return null;
    final day = Map<String, dynamic>.from(raw);
    final state = _purchaseDays['$book|${day['id']}'];
    if (state != null) {
      day.addAll(state);
    } else if (purchaseFixtureStatus != null) {
      _paintPurchaseStatus(day, purchaseFixtureStatus!);
    }
    final opening = _openingByBook[book];
    if (opening != null) {
      day['previousDebtUnits'] = opening['previousDebtUnits'];
      day['previousVodafoneUnits'] = opening['previousVodafoneUnits'];
    }
    return day;
  }

  /// `correction` is the test hook for `correctionOpen` on a finalized day.
  void _paintPurchaseStatus(Map<String, dynamic> day, String status) {
    if (status == 'correction') {
      day['status'] = 'finalized';
      day['correctionOpen'] = true;
      return;
    }
    day['status'] = status;
    day['correctionOpen'] = false;
  }

  Map<String, dynamic> _purchasesView(String book, int? before) {
    final body = _copy(FakeFixtures.purchases());
    final merchant = body['merchant'];
    if (merchant is Map) {
      merchant['key'] = book;
      merchant['name'] = book == PurchaseBook.simsim.path
          ? PurchaseBook.simsim.label
          : PurchaseBook.alBayan.label;
    }
    final day = _openPurchaseDay(book);
    if (day != null) body['day'] = day;
    if (before != null) {
      final older = purchaseOlderPages[before];
      final rawEntries = older?['entries'];
      body['entries'] = day == null || rawEntries is! List
          ? <Map<String, dynamic>>[]
          : [
              for (final raw in rawEntries)
                if (raw is Map)
                  _entryOnThisPage(Map<String, dynamic>.from(raw), day),
            ];
      final next = older?['nextBefore'];
      body['nextBefore'] = next is int ? next : null;
      return body;
    }
    final entries = body['entries'];
    if (day != null && entries is List) {
      body['entries'] = [
        for (final raw in entries)
          if (raw is Map) _entryOnThisPage(Map<String, dynamic>.from(raw), day),
      ];
    }
    if (purchaseFirstNextBefore != null) {
      body['nextBefore'] = purchaseFirstNextBefore;
    }
    return body;
  }

  /// The open day's rows take that day's id and version. A row from another
  /// day keeps the fixture `dayId` and `dayVersion`.
  Map<String, dynamic> _entryOnThisPage(
    Map<String, dynamic> entry,
    Map<String, dynamic> day,
  ) {
    if ('${entry['dayId']}' != '${day['id']}') return entry;
    return _paintPurchaseEntry(entry, day);
  }

  Map<String, dynamic> _paintPurchaseEntry(
    Map<String, dynamic> entry,
    Map<String, dynamic> day,
  ) {
    entry['dayId'] = day['id'];
    entry['dayNumber'] = day['dayNumber'];
    entry['dayStatus'] = day['status'];
    entry['dayVersion'] = day['version'];
    entry['correctionOpen'] = day['correctionOpen'] == true;
    return entry;
  }

  ApiResponse _applyOpening(String book, Map b) {
    final day = _openPurchaseDay(book);
    final current = day?['version'];
    _requireVersion(b['expectedDayVersion'], current);
    _openingByBook[book] = {
      'previousDebtUnits': b['previousDebtUnits'],
      'previousVodafoneUnits': b['previousVodafoneUnits'],
    };
    return _ok({'id': 'opening', 'version': current});
  }

  ApiResponse _applyCorrection(String book, String dayId, Map b) {
    final day = _openPurchaseDay(book);
    if (day == null || '${day['id']}' != dayId) {
      _fail(404, 'NOT_FOUND', 'اليوم غير موجود');
    }
    // API docs: this route takes `expectedVersion` (the day version).
    _requireVersion(b['expectedVersion'], day['version']);
    final open = b['open'] == true;
    _purchaseDays['$book|$dayId'] = {
      ...?_purchaseDays['$book|$dayId'],
      'status': 'finalized',
      'correctionOpen': open,
    };
    return _ok({
      'id': dayId,
      'version': day['version'],
      'correctionOpen': open,
    });
  }

  Map<String, dynamic> _masraweyaView([Map<String, dynamic>? query]) {
    final requested = query?['date'];
    final date = requested == null || '$requested'.isEmpty
        ? masraweyaToday
        : '$requested';
    _masraweyaByDate ??= {masraweyaToday: _copy(FakeFixtures.masraweyaDay())};
    final stored = _masraweyaByDate![date];
    final day = stored == null ? _emptyMasraweyaDay(date) : _copy(stored);
    return _decorateMasraweya(day, date);
  }

  /// Contract-shaped empty day. Totals are the documented empty example (0),
  /// not a sum of rows. `openingEditable` is false: the contract says opening
  /// is automatic except the first seed day.
  Map<String, dynamic> _emptyMasraweyaDay(String date) => {
        'businessDate': date,
        'version': 0,
        'previousValueUnits': 0,
        'purchasesUnits': 0,
        'entries': <Map<String, dynamic>>[],
        'workTotalUnits': 0,
        'remainingUnits': 0,
        'finalUnits': 0,
        'historicalAdjustmentUnits': 0,
        'openingEditable': false,
        'status': 'open',
      };

  Map<String, dynamic> _decorateMasraweya(
      Map<String, dynamic> day, String date) {
    final today = DateTime.parse(masraweyaToday);
    final earliest = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 7));
    final parsed = DateTime.tryParse(date);
    final dayDate =
        parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
    final end = DateTime(today.year, today.month, today.day);
    final editable =
        dayDate != null && !dayDate.isBefore(earliest) && !dayDate.isAfter(end);
    day['businessDate'] = date;
    day['today'] = masraweyaToday;
    day['earliestEditableDate'] = '${earliest.year.toString().padLeft(4, '0')}-'
        '${earliest.month.toString().padLeft(2, '0')}-'
        '${earliest.day.toString().padLeft(2, '0')}';
    day['editable'] = editable;
    day.putIfAbsent('openingEditable', () => date == masraweyaToday);
    if (!day.containsKey('finalUnits') && day.containsKey('remainingUnits')) {
      day['finalUnits'] = day['remainingUnits'];
    }
    return day;
  }

  /// Persists the submitted day. Version, idempotency, and the permission
  /// check are the caller's: [_mutate] stores the first success for
  /// `requestId`, and the route calls [_requireWrite] before this method.
  /// A mismatched `expectedVersion` is 409 and does not change the stored day.
  /// A date outside the documented current-and-previous-7 window is 403 and
  /// does not change any day. Other dates are not updated.
  ApiResponse _saveMasraweyaDay(Map b) {
    final businessDate = b['businessDate'];
    if (businessDate == null || '$businessDate'.isEmpty) {
      _fail(400, 'INVALID_FIELD', 'businessDate مطلوب');
    }
    final date = '$businessDate';
    final current = _masraweyaView({'date': date});
    if (current['editable'] != true) {
      _fail(403, 'FORBIDDEN', 'هذا اليوم غير قابل للتعديل.');
    }
    _requireVersion(b['expectedVersion'], current['version']);
    final version = current['version'];
    if (version is! int) {
      _fail(400, 'VALIDATION_ERROR', 'expectedVersion مطلوب');
    }
    final next = _copy(current);
    next['version'] = version + 1;
    next['businessDate'] = date;
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
    // Totals stay as stored. Do not recompute and do not touch other dates.
    _masraweyaByDate![date] = next;
    return _ok(_decorateMasraweya(next, date));
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

  /// Status `finalized` with `correctionOpen` false is what [_applyFinalize]
  /// stores. An open correction stays writable. The check does not read an
  /// entry version (P-05).
  void _rejectIfPurchaseDayFinalized(List<String> seg) {
    final day = _openPurchaseDay(seg.length > 1 ? seg[1] : '');
    if (day == null) return;
    final closed =
        day['status'] == 'finalized' && day['correctionOpen'] != true;
    if (!closed) return;
    _failDayFinalized();
  }

  Never _failDayFinalized() =>
      _fail(409, dayFinalizedCode, dayFinalizedMessage);

  ApiResponse _applyFinalize(String book, Map b) {
    final day = _openPurchaseDay(book);
    if (day == null) _fail(404, 'NOT_FOUND', 'اليوم غير موجود');
    _requireVersion(b['expectedDayVersion'], day['version']);
    final version = (day['version'] as int) + 1;
    _purchaseDays['$book|${day['id']}'] = {
      'status': 'finalized',
      'version': version,
      'correctionOpen': false,
    };
    return _ok({'id': 'ok', 'version': version});
  }

  /// Fixture treasury, with version and running cash from a stored entry.
  ///
  /// [treasuryTotalsPatch] is applied last. A null value stays in the JSON.
  /// [omitTreasuryTotalKeys] then deletes keys. Neither derives a conversion.
  Map<String, dynamic> _treasuryView() {
    final body = _copy(FakeFixtures.treasury());
    final state = _treasuryState;
    if (state != null) {
      body['cashVersion'] = state['cashVersion'];
      final totals = Map<String, dynamic>.from(body['totals'] as Map);
      totals['activeCashUnits'] = state['activeCashUnits'];
      totals['netUnits'] = state['netUnits'];
      body['totals'] = totals;
    }
    final patch = treasuryTotalsPatch;
    if (patch != null && patch.isNotEmpty) {
      final totals = Map<String, dynamic>.from(body['totals'] as Map);
      for (final entry in patch.entries) {
        totals[entry.key] = entry.value;
      }
      body['totals'] = totals;
    }
    if (omitTreasuryTotalKeys.isNotEmpty) {
      final totals = Map<String, dynamic>.from(body['totals'] as Map);
      for (final key in omitTreasuryTotalKeys) {
        totals.remove(key);
      }
      body['totals'] = totals;
    }
    lastTreasuryJson = jsonEncode(body);
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
    // Production checks `expectedVersion` against `cashVersion`.
    _requireVersion(b['expectedVersion'], treasury['cashVersion']);
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
    final version = (treasury['cashVersion'] as int) + 1;
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
      'cashVersion': version,
      'activeCashUnits': runningCash,
      'netUnits': runningNet,
    };
    return _ok({'id': entry['id'], 'cashVersion': version});
  }

  Map<String, dynamic> _overlayCards(
    String section,
    Map<String, dynamic> page,
  ) {
    final items = <Map<String, dynamic>>[];
    for (final raw in page['items'] as List) {
      final card = Map<String, dynamic>.from(raw as Map);
      final state = _cardState['$section|${card['id']}'];
      if (state != null) card.addAll(state);
      items.add(card);
    }
    return {...page, 'items': items};
  }

  int _pageLimit(Map<String, dynamic>? query) {
    final raw = query?['limit'];
    final parsed = raw is int ? raw : int.tryParse('${raw ?? ''}');
    final limit = parsed ?? FakeLargeCatalog.pageSize;
    if (limit < 1) return 1;
    if (limit > FakeLargeCatalog.pageSize) return FakeLargeCatalog.pageSize;
    return limit;
  }

  /// First page of the large catalog, with fixture metrics left as stored
  /// literals. Assignments and submissions come from the page, not a sum.
  Map<String, dynamic> _largeCollections(Map<String, dynamic>? query) {
    final page = FakeLargeCatalog.collectionsPage(
      cursor: _queryText(query, 'cursor'),
      limit: _pageLimit(query),
      seesAll: _seesEveryCollection,
      userId: _userId,
    );
    final body = _copy(FakeFixtures.collections());
    body['assignments'] = page['assignments'];
    body['submissions'] = page['submissions'];
    body['nextCursor'] = page['nextCursor'];
    body['assignedCount'] = page['visibleCount'];
    body['historyPageCount'] = page['historyPageCount'];
    if (_seesEveryCollection) return body;
    final id = _userId;
    body['unlinkedReceipts'] = const [];
    body['employeeTotals'] = _owned(body['employeeTotals'], 'userId', id);
    if (id == FakeFixtures.demoEmployeeId) {
      body['metrics'] = Map<String, dynamic>.from(
        FakeFixtures.ownCollectionMetrics,
      );
    } else {
      body['metrics'] = {
        'collectedUnits': 0,
        'dayTotalUnits': 0,
        'pendingCount': 0,
        'unlinkedPendingCount': 0,
        'cashOutstandingUnits': 0,
      };
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

  Map<String, dynamic> _salaryRecord(String employeeId) {
    for (final raw in FakeFixtures.payroll()['employees'] as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      if ('${row['userId']}' == employeeId) return {'employee': row};
    }
    _fail(404, 'NOT_FOUND', _notFound);
  }

  ApiResponse _notifications(
    String method,
    List<String> seg,
    Map b,
    Map<String, dynamic>? query,
  ) {
    _ensureNotices();
    if (seg.length > 1 && seg[1] == 'unread-count') {
      if (method != 'GET') _fail(404, 'NOT_FOUND', _notFound);
      if (failUnreadCountRemaining > 0) {
        failUnreadCountRemaining--;
        _fail(404, 'NOT_FOUND', _notFound);
      }
      // 🔶 Response shape is proposed.
      return _ok({'unreadCount': _unreadByUser[_userId] ?? 0});
    }
    if (method == 'GET') {
      final forced = failNextNotificationListStatus;
      if (forced != null) {
        failNextNotificationListStatus = null;
        if (forced == 404) _fail(404, 'NOT_FOUND', _notFound);
        if (forced == 401) {
          _fail(401, 'AUTH_REQUIRED', 'يجب تسجيل الدخول أولًا.');
        }
        _fail(forced, 'NETWORK_UNAVAILABLE', 'تعذر تحميل الإشعارات.');
      }
      final data = _notificationsPage(query);
      if (omitUnreadCount) data.remove('unreadCount');
      return _ok(data);
    }
    if (method == 'POST' && seg.length > 1 && seg[1] == 'read-all') {
      return _ok(_markAllRead(b));
    }
    if (method == 'PATCH' && seg.length > 2 && seg[2] == 'read') {
      return _ok(_markOneRead(seg[1], b));
    }
    _fail(404, 'NOT_FOUND', _notFound);
  }

  void _ensureNotices() {
    if (_noticesReady) return;
    _noticesReady = true;
    if (_large) {
      _unreadByUser.addAll(FakeLargeCatalog.unreadLiterals);
      return;
    }
    for (final raw in FakeFixtures.notificationCatalog()) {
      final item = Map<String, dynamic>.from(raw);
      final owner = '${item['recipientUserId']}';
      (_notices[owner] ??= []).add(item);
    }
    _unreadByUser.addAll(FakeFixtures.notificationUnreadCounts);
  }

  Map<String, dynamic> _notificationsPage(Map<String, dynamic>? query) {
    if (_large && FakeLargeCatalog.hasNotices(_userId)) {
      final generated = FakeLargeCatalog.notificationPage(
        userId: _userId!,
        before: query?['before']?.toString(),
      );
      final items = <Map<String, dynamic>>[];
      for (final raw in generated['items'] as List) {
        final item = Map<String, dynamic>.from(raw as Map);
        if (_largeAllRead || _largeReadIds.contains('${item['id']}')) {
          item['readAt'] = _noticeReadStamp;
        }
        items.add(item);
      }
      return {
        'items': items,
        'unreadCount': _unreadByUser[_userId] ?? 0,
        'nextBefore': generated['nextBefore'],
        'historyPageCount': generated['historyPageCount'],
      };
    }
    final own = _notices[_userId] ?? const <Map<String, dynamic>>[];
    final sorted = [...own]..sort(_noticeOrder);
    final before = query?['before']?.toString();
    var page = sorted;
    if (before != null && before.isNotEmpty) {
      final index = sorted.indexWhere((item) => '${item['id']}' == before);
      page = index < 0
          ? const <Map<String, dynamic>>[]
          : sorted.skip(index + 1).toList(growable: false);
    }
    return {
      'items': [for (final item in page) Map<String, dynamic>.from(item)],
      'unreadCount': _unreadByUser[_userId] ?? 0,
      // 🔶 No extra page in the fixture, so the cursor is absent.
      'nextBefore': null,
    };
  }

  int _noticeOrder(Map<String, dynamic> a, Map<String, dynamic> b) {
    final at = DateTime.tryParse('${a['createdAt']}') ?? DateTime.utc(1970);
    final bt = DateTime.tryParse('${b['createdAt']}') ?? DateTime.utc(1970);
    final byTime = bt.compareTo(at);
    if (byTime != 0) return byTime;
    return '${a['id']}'.compareTo('${b['id']}');
  }

  Map<String, dynamic> _markOneRead(String id, Map b) {
    final stored = _storedNotificationReplay(b);
    if (stored != null) return stored;
    _failNextNotificationWrite();
    final found = _ownNotice(id);
    if (found == null) _fail(404, 'NOT_FOUND', _notFound);
    final item = found;
    if (item['readAt'] == null) {
      item['readAt'] = _noticeReadStamp;
      if (_large) _largeReadIds.add(id);
      _decrementUnread(_userId!);
    }
    notificationMutationApplies++;
    final result = <String, dynamic>{
      'unreadCount': _unreadByUser[_userId] ?? 0,
      'readAt': item['readAt'],
      'notification': Map<String, dynamic>.from(item),
    };
    if (omitNotificationWriteUnreadCount) result.remove('unreadCount');
    _storeNotificationReplay(b, result);
    return result;
  }

  Map<String, dynamic> _markAllRead(Map b) {
    final stored = _storedNotificationReplay(b);
    if (stored != null) return stored;
    _failNextNotificationWrite();
    if (_large) {
      _largeAllRead = true;
      _unreadByUser[_userId!] = 0;
      notificationMutationApplies++;
      final result = <String, dynamic>{
        'unreadCount': 0,
        'readAt': _noticeReadStamp,
      };
      if (omitNotificationWriteUnreadCount) result.remove('unreadCount');
      _storeNotificationReplay(b, result);
      return result;
    }
    final own = _notices[_userId] ?? const <Map<String, dynamic>>[];
    for (final item in own) {
      if (item['readAt'] == null) item['readAt'] = _noticeReadStamp;
    }
    _unreadByUser[_userId!] = 0;
    notificationMutationApplies++;
    final result = <String, dynamic>{
      'unreadCount': 0,
      'readAt': _noticeReadStamp,
    };
    if (omitNotificationWriteUnreadCount) result.remove('unreadCount');
    _storeNotificationReplay(b, result);
    return result;
  }

  /// Test hook. Adds one row without counting it into the stored unread total.
  /// [unreadCount] replaces that owner's stored total when passed.
  void stageNotification(Map<String, dynamic> item, {int? unreadCount}) {
    _ensureNotices();
    final copy = Map<String, dynamic>.from(item);
    final owner = '${copy['recipientUserId'] ?? _userId}';
    copy['recipientUserId'] = owner;
    (_notices[owner] ??= []).add(copy);
    if (unreadCount != null) _unreadByUser[owner] = unreadCount;
  }

  void _failNextNotificationWrite() {
    if (failNotificationWritesRemaining <= 0) return;
    failNotificationWritesRemaining--;
    _fail(500, 'SERVER_ERROR', 'تعذر تحديث الإشعار.');
  }

  void _decrementUnread(String userId) {
    final current = _unreadByUser[userId] ?? 0;
    _unreadByUser[userId] = current > 0 ? current - 1 : 0;
  }

  Map<String, dynamic>? _ownNotice(String id) {
    if (_large) {
      final generated = FakeLargeCatalog.noticeOrNull(_userId, id);
      if (generated != null) {
        final item = Map<String, dynamic>.from(generated);
        if (_largeAllRead || _largeReadIds.contains(id)) {
          item['readAt'] = _noticeReadStamp;
        }
        return item;
      }
    }
    final own = _notices[_userId];
    if (own == null) return null;
    for (final item in own) {
      if ('${item['id']}' == id) return item;
    }
    return null;
  }

  /// 🔶 Honored only when the caller includes requestId. The repository does not.
  Map<String, dynamic>? _storedNotificationReplay(Map b) {
    final requestId = b['requestId'];
    if (requestId == null || '$requestId'.isEmpty) return null;
    final stored = _notificationReplays['${_userId ?? ''}|$requestId'];
    if (stored == null) return null;
    return jsonDecode(jsonEncode(stored)) as Map<String, dynamic>;
  }

  void _storeNotificationReplay(Map b, Map<String, dynamic> result) {
    final requestId = b['requestId'];
    if (requestId == null || '$requestId'.isEmpty) return;
    _notificationReplays['${_userId ?? ''}|$requestId'] =
        jsonDecode(jsonEncode(result)) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>>? _loginUserRows;
  List<Map<String, dynamic>>? _accountRequestRows;

  bool get _isPrimaryOwner {
    final user = _me['user'];
    if (user is! Map) return false;
    return user['isOwner'] == true;
  }

  List<Map<String, dynamic>> get _loginUserStore =>
      _loginUserRows ??= FakeFixtures.loginUsers()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

  List<Map<String, dynamic>> get _accountRequestStore =>
      _accountRequestRows ??= FakeFixtures.accountRequests()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

  ApiResponse _loginUsers(String method, List<String> seg, Map b) {
    if (method == 'POST' && seg.length == 1) {
      if (!_isPrimaryOwner) {
        _fail(403, 'FORBIDDEN', 'إنشاء الحسابات للمدير الأساسي فقط.');
      }
      final username = b['username'];
      final displayName = b['displayName'];
      final role = b['role'];
      final password = b['password'];
      if (username is! String || username.trim().isEmpty) {
        _fail(400, 'INVALID_INPUT', 'اسم الدخول مطلوب.');
      }
      if (displayName is! String || displayName.trim().isEmpty) {
        _fail(400, 'INVALID_INPUT', 'الاسم الظاهر مطلوب.');
      }
      if (!PermissionService.isDirectoryRole(role)) {
        _fail(400, 'INVALID_INPUT', 'الدور يجب أن يكون إدارة أو موظفًا.');
      }
      if (password is! String || password.length < 10) {
        _fail(400, 'PASSWORD_POLICY', 'كلمة المرور المؤقتة أقصر من المطلوب.');
      }
      if (PermissionService.isDirectoryAdmin(role) &&
          (b['email'] is! String || '${b['email']}'.isEmpty)) {
        _fail(400, 'INVALID_INPUT', 'بريد الإدارة مطلوب عند إنشاء مدير.');
      }
      for (final row in _loginUserStore) {
        if (row['username'] == username) {
          _fail(409, 'CONFLICT', 'اسم الدخول مستخدم.');
        }
      }
      final permissions = b['permissions'];
      final codes = permissions is List
          ? [for (final code in permissions) '$code']
          : <String>[];
      for (final code in codes) {
        if (!FakeFixtures.assignablePermissions.contains(code)) {
          _fail(400, 'INVALID_INPUT', 'صلاحية غير قابلة للتعيين.');
        }
      }
      final created = <String, dynamic>{
        'id': 'u_new_${_loginUserStore.length}',
        'username': username,
        'displayName': displayName,
        'role': role,
        'isOwner': false,
        'isActive': true,
        'version': 1,
        'email': b['email'] is String ? b['email'] : null,
        'mustChangePassword': !PermissionService.isDirectoryAdmin(role),
        'permissions': codes,
        'sectionAccess': {
          for (final key in const [
            'customerDebts',
            'companyDebts',
            'libyanDeposits',
            'egyptianDeposits',
            'masraweya',
            'purchases',
            'treasury',
            'reports',
          ])
            key: _sectionAccessValue(b['${key}Access']),
        },
      };
      _loginUserStore.add(created);
      return _ok({'user': created});
    }
    if (method == 'GET' && seg.length == 1) {
      return _ok({
        'items': _loginUserStore,
        'assignablePermissions': FakeFixtures.assignablePermissions,
      });
    }
    if (method == 'PATCH' && seg.length == 2) {
      final row = _loginUserStore.cast<Map<String, dynamic>?>().firstWhere(
            (item) => item?['id'] == seg[1],
            orElse: () => null,
          );
      if (row == null) _fail(404, 'NOT_FOUND', _notFound);
      final expected = b['expectedVersion'];
      if (expected is int && expected != row['version']) {
        _fail(409, 'CONFLICT', 'تغيّر الحساب. أعد التحميل.');
      }
      final protected = row['isOwner'] == true ||
          PermissionService.isDirectoryAdmin(row['role']);
      if (protected && !_isPrimaryOwner) {
        _fail(403, 'FORBIDDEN', 'تعديل حساب الإدارة للمدير الأساسي فقط.');
      }
      if (b['displayName'] is String && '${b['displayName']}'.isNotEmpty) {
        row['displayName'] = b['displayName'];
      }
      if (b['isActive'] is bool) row['isActive'] = b['isActive'];
      if (b['permissions'] is List) {
        row['permissions'] = [
          for (final code in b['permissions'] as List) '$code',
        ];
      }
      final access = row['sectionAccess'] is Map
          ? Map<String, dynamic>.from(row['sectionAccess'] as Map)
          : <String, dynamic>{};
      var accessTouched = false;
      for (final key in const [
        'customerDebts',
        'companyDebts',
        'libyanDeposits',
        'egyptianDeposits',
        'masraweya',
        'purchases',
        'treasury',
        'reports',
      ]) {
        final field = '${key}Access';
        if (!b.containsKey(field)) continue;
        access[key] = _sectionAccessValue(b[field]);
        accessTouched = true;
      }
      if (accessTouched) row['sectionAccess'] = access;
      row['version'] = (row['version'] as int? ?? 1) + 1;
      return _ok({'user': row});
    }
    return _adminCatalog('users', seg);
  }

  String _sectionAccessValue(Object? raw) {
    if (raw == 'read' || raw == 'manage' || raw == 'none') {
      return raw! as String;
    }
    if (raw == null) return 'none';
    _fail(400, 'INVALID_INPUT', 'مستوى القسم غير معروف.');
  }

  ApiResponse _accountRequests(String method, List<String> seg, Map b) {
    if (seg.length >= 3 && seg[2] == 'decision' && method != 'POST') {
      return _ok({'id': seg[1], 'status': 'pending'});
    }
    if (method == 'POST' && seg.length >= 3 && seg[2] == 'decision') {
      final row = _accountRequestStore.cast<Map<String, dynamic>?>().firstWhere(
            (item) => item?['id'] == seg[1],
            orElse: () => null,
          );
      if (row == null) _fail(404, 'NOT_FOUND', _notFound);
      final decision = b['decision'];
      if (decision != 'approve' && decision != 'reject') {
        _fail(400, 'INVALID_INPUT', 'القرار غير معروف.');
      }
      final expected = b['expectedVersion'];
      if (expected is int && expected != row['version']) {
        _fail(409, 'CONFLICT', 'تغيّر الطلب. أعد التحميل.');
      }
      row['status'] = decision == 'approve' ? 'approved' : 'rejected';
      row['decisionNote'] = b['note'];
      row['decidedAt'] = '2026-10-22T22:01:00.000Z';
      row['version'] = (row['version'] as int? ?? 1) + 1;
      return _ok({'request': row});
    }
    return _ok({'items': _accountRequestStore});
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
}

class _MfaChallenge {
  _MfaChallenge(this.username, this.expiresAt);

  final String username;
  DateTime expiresAt;
  int failures = 0;
}

/// One in-memory cookie session. Lifetime is not counted down locally.
class _FakeSession {
  _FakeSession({
    required this.id,
    required this.me,
    required this.csrfToken,
  });

  final String id;
  final Map<String, dynamic> me;
  String csrfToken;
  bool expired = false;
}

/// Wire body returned to the auth interceptor. Not an [ApiResponse].
class FakeHttpResult {
  const FakeHttpResult({
    required this.status,
    required this.body,
    this.setCookie = const [],
  });

  final int status;
  final String body;
  final List<String> setCookie;
}

Map<String, dynamic> _filterLedgerPage(
  Map<String, dynamic> page,
  Map<String, dynamic>? query,
) {
  final currency = _queryText(query, 'currency');
  final q = _queryText(query, 'q');
  if (currency == null && (q == null || q.isEmpty)) return page;
  final raw = page['items'];
  final items = <Map<String, dynamic>>[
    for (final row in raw is List ? raw : const [])
      if (row is Map &&
          (currency == null || row['currency'] == currency) &&
          (q == null ||
              q.isEmpty ||
              '${row['counterpartyName'] ?? ''}${row['description'] ?? ''}'
                  .contains(q)))
        Map<String, dynamic>.from(row),
  ];
  final totals = <String, int>{};
  for (final row in items) {
    final code = row['currency'];
    final effect = row['effectUnits'];
    if (code is String && effect is int) {
      totals[code] = (totals[code] ?? 0) + effect;
    }
  }
  return {...page, 'items': items, 'pageTotals': totals};
}

int? _queryInt(Map<String, dynamic>? query, String key) {
  final value = query?[key];
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

String? _queryText(Map<String, dynamic>? query, String key) {
  final value = query?[key];
  if (value == null) return null;
  final text = '$value';
  if (text.isEmpty) return null;
  return text;
}

/// One recorded `GET /api/financial-ledger` (tests).
class FinancialLedgerQuery {
  const FinancialLedgerQuery({this.section, this.sectionKey});

  final String? section;
  final String? sectionKey;
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

class _FakeCollectionCardsBridge implements FakeCollectionCards {
  _FakeCollectionCardsBridge(this._client);
  final FakeApiClient _client;

  static const _sections = [
    'customers',
    'companies',
    'libyan-deposits',
    'egyptian-deposits',
  ];

  @override
  FakeCollectionCard? card(String section, String id) =>
      _client._collectionCard(section, id);

  @override
  int post(String section, String id, int deltaUnits) =>
      _client._postCollectionDelta(section, id, deltaUnits);

  @override
  List<FakeCollectionCard> search(String query) {
    final tokens = query
        .split(RegExp(r'\s+'))
        .where((token) => token.length >= 2)
        .toList();
    final found = <FakeCollectionCard>[];
    for (final section in _sections) {
      final items = FakeFixtures.accountsFor(section)['items'] as List;
      for (final raw in items) {
        if (raw is! Map) continue;
        final name = '${raw['name']}';
        if (!tokens.any(name.contains)) continue;
        final card = this.card(section, '${raw['id']}');
        if (card != null) found.add(card);
      }
    }
    return found;
  }
}
