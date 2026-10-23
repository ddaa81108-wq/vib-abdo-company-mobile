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
/// `finalized` is rejected with 409 [dayFinalizedCode]. The README and the
/// in-repo API notes do not name this status or code. `PurchaseDayDto.status`
/// is still marked proposed, so this code is an open stand-in, not a confirmed
/// contract field. A stored success for the same `requestId` does not skip the
/// check.
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

  /// Notification writes that changed state. A requestId replay is not counted.
  int notificationMutationApplies = 0;

  /// `POST .../decision` when the row is no longer pending.
  static const submissionAlreadyDecidedMessage =
      'تمت مراجعة هذا الاستلام من قبل.';

  /// `POST .../cash-received` when the row is not approved.
  static const submissionNotApprovedMessage =
      'استلام النقدية متاح للاستلام المعتمد فقط.';

  /// When set, purchases days without a stored finalize or correction use this
  /// status on the next GET (tests).
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

  /// When set, the first account-list page reports this `nextCursor` (tests).
  String? accountNextCursor;

  /// Items returned for an account-list read that sends `cursor` (tests).
  List<Map<String, dynamic>> accountNextItems = const [];

  /// One-shot raw `data` JSON for a GET, decoded with [PreciseJson].
  ///
  /// Fractions and oversized integers stay non-integers. The body is not logged.
  /// Authenticated calls still require a session. Tests only.
  final Map<String, String> scriptedGetJson = {};

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
  int _sessionSeq = 0;
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

  /// Submission fields changed by a decision or cash receipt. Keyed by id.
  final Map<String, Map<String, dynamic>> _submissionState = {};

  /// Unlinked receipt fields changed by a decision or cash receipt. Keyed by id.
  final Map<String, Map<String, dynamic>> _unlinkedState = {};

  /// Rows stored by assignment submit and unlinked-receipt submit.
  ///
  /// Each row keeps the fields the request sent. `status` is `pending` and
  /// `version` is 1, matching an undecided fixture row. `submittedByUserId`
  /// is the same owner id the fixture already stores so the caller still sees
  /// their own row. `cashStatus` is not written: that wire field is proposed.
  /// Overview metrics stay the stored literals; these rows are not summed.
  final List<Map<String, dynamic>> _extraSubmissions = [];
  final List<Map<String, dynamic>> _extraUnlinked = [];

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

  /// Direct partial payment larger than the stored card balance.
  ///
  /// Whether the real server rejects this is an open question for the
  /// backend owner. This fake refuses the write so the stored balance cannot
  /// change, using the same HTTP 400 `VALIDATION_ERROR` envelope as its other
  /// rejected inputs. That code is not a confirmed server contract.
  static const amountAboveRemainingMessage = 'المبلغ أكبر من المتبقي المسجّل.';

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
      final scripted = scriptedGetJson.remove(path);
      if (scripted != null) {
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
      // Decision and cash-received have no requestId. A shared null replay
      // key would collapse distinct calls onto one stored success.
      if (_collectionStatusPath(seg)) {
        return _mutateWithoutRequestId(
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
    return send();
  }

  /// `POST /api/collections/{submissions|unlinked-receipts}/{id}/{decision|cash-received}`.
  bool _collectionStatusPath(List<String> seg) {
    if (seg.length != 4 || seg.first != 'collections') return false;
    final kind = seg[1];
    final action = seg[3];
    if (kind != 'submissions' && kind != 'unlinked-receipts') return false;
    return action == 'decision' || action == 'cash-received';
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
        return _notifications(method, seg, b, query);
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
      return _ok(_collectionsForCaller(query));
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
    if (seg.length == 4 && seg[1] == 'submissions' && seg[3] == 'decision') {
      return _applyDecision(seg[2], b);
    }
    if (seg.length == 4 &&
        seg[1] == 'submissions' &&
        seg[3] == 'cash-received') {
      return _applyCash(seg[2], unlinked: false);
    }
    if (seg.length == 4 &&
        seg[1] == 'unlinked-receipts' &&
        seg[3] == 'decision') {
      return _applyUnlinkedDecision(seg[2], b);
    }
    if (seg.length == 4 &&
        seg[1] == 'unlinked-receipts' &&
        seg[3] == 'cash-received') {
      return _applyCash(seg[2], unlinked: true);
    }
    // CollectionsRepository.closeDay posts /api/collections/days/close.
    if (seg.length == 3 && seg[1] == 'days' && seg[2] == 'close') {
      return _applyClose(b);
    }
    if (seg.length == 4 && seg[1] == 'assignments' && seg[3] == 'submissions') {
      return _applyAssignmentSubmission(seg[2], b);
    }
    if (seg.length == 2 && seg[1] == 'unlinked-receipts') {
      return _applyUnlinkedCreate(b);
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
  /// received `inputValue` applied when that integer is not larger than the
  /// stored balance. A larger integer is refused and the stored balance is
  /// left as it was. The app does not calculate the new balance. A rate-based
  /// movement only bumps the version; this fake does not turn a factor into
  /// an amount, and it does not compare that factor with the balance.
  ApiResponse _applyMovement(String section, String id, Map b) {
    final card = _cardView(section, id);
    _requireVersion(b['expectedVersion'], card['version']);
    final previous = card['balanceUnits'];
    final entered = b['inputValue'];
    if (b['type'] == 'payment' &&
        b['paymentMode'] == 'partial' &&
        b['calculationMode'] == 'direct' &&
        previous is int &&
        entered is int &&
        entered > previous) {
      _fail(400, 'VALIDATION_ERROR', amountAboveRemainingMessage);
    }
    final version = (card['version'] as int) + 1;
    final state = <String, dynamic>{'version': version};
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
      item.remove('version');
      items.add(item);
    }
    for (final extra in _extraSubmissions) {
      final item = Map<String, dynamic>.from(extra);
      final state = _submissionState['${item['id']}'];
      if (state != null) item.addAll(state);
      item.remove('version');
      items.add(item);
    }
    body['submissions'] = items;
    final receipts = <Map<String, dynamic>>[];
    for (final raw in body['unlinkedReceipts'] as List) {
      final item = Map<String, dynamic>.from(raw as Map);
      final state = _unlinkedState['${item['id']}'];
      if (state != null) item.addAll(state);
      item.remove('version');
      receipts.add(item);
    }
    for (final extra in _extraUnlinked) {
      final item = Map<String, dynamic>.from(extra);
      final state = _unlinkedState['${item['id']}'];
      if (state != null) item.addAll(state);
      item.remove('version');
      receipts.add(item);
    }
    body['unlinkedReceipts'] = receipts;
    final batch = _batchState;
    if (batch != null) body.addAll(batch);
    return body;
  }

  /// Stores one submission on an assignment the caller can see.
  ///
  /// An assignment outside that set is 404, the same body as a missing id.
  /// The amount is the integer the request sent. This does not copy the
  /// assignment balance and does not change overview metrics.
  ApiResponse _applyAssignmentSubmission(String assignmentId, Map b) {
    _requireVisibleAssignment(assignmentId);
    final mode = b['mode'];
    if (mode != 'full' && mode != 'partial') {
      _fail(400, 'VALIDATION_ERROR', 'mode غير معروف');
    }
    int? amount;
    if (mode == 'partial') {
      final raw = b['amountUnits'];
      if (raw is! int) _fail(400, 'VALIDATION_ERROR', 'amountUnits مطلوب');
      amount = raw;
    } else if (b['amountUnits'] is int) {
      amount = b['amountUnits'] as int;
    }
    final id = 'sb_posted_${_extraSubmissions.length + 1}';
    final name = _displayName();
    _extraSubmissions.add({
      'id': id,
      'mode': mode,
      if (amount != null) 'amountUnits': amount,
      'status': 'pending',
      if (_userId != null) 'submittedByUserId': _userId,
      if (name != null) 'submittedByName': name,
    });
    return _ok({'id': id, 'version': 1});
  }

  /// Stores one unlinked receipt for the signed-in caller.
  ApiResponse _applyUnlinkedCreate(Map b) {
    final name = b['customerName'];
    if (name is! String || name.trim().isEmpty) {
      _fail(400, 'VALIDATION_ERROR', 'customerName مطلوب');
    }
    final amount = b['amountUnits'];
    if (amount is! int) _fail(400, 'VALIDATION_ERROR', 'amountUnits مطلوب');
    final id = 'ur_posted_${_extraUnlinked.length + 1}';
    _extraUnlinked.add({
      'id': id,
      'customerName': name,
      'amountUnits': amount,
      'status': 'pending',
      if (_userId != null) 'submittedByUserId': _userId,
    });
    return _ok({'id': id, 'version': 1});
  }

  void _requireVisibleAssignment(String id) {
    final assignments = _collectionsForCaller()['assignments'];
    if (assignments is List) {
      for (final raw in assignments) {
        if (raw is Map && raw['id'] == id) return;
      }
    }
    _fail(404, 'NOT_FOUND', _notFound);
  }

  String? _displayName() {
    final user = _me['user'];
    if (user is Map && user['displayName'] is String) {
      final name = user['displayName'] as String;
      if (name.isNotEmpty) return name;
    }
    return null;
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
    if (submission['status'] != 'pending') {
      _fail(
        409,
        'SUBMISSION_ALREADY_DECIDED',
        submissionAlreadyDecidedMessage,
      );
    }
    final status = _decisionStatus(b['decision']);
    final next = {...?_submissionState[id], 'status': status};
    next.remove('version');
    _submissionState[id] = next;
    return _decisionAck(id, status, submission);
  }

  ApiResponse _applyCash(String id, {required bool unlinked}) {
    final view = _collectionsView();
    final items =
        (unlinked ? view['unlinkedReceipts'] : view['submissions']) as List;
    final current = _recordById(
      items,
      id,
      unlinked ? 'الإيصال غير موجود' : 'الاستلام غير موجود',
    );
    if (current['status'] != 'approved') {
      _fail(409, 'SUBMISSION_NOT_APPROVED', submissionNotApprovedMessage);
    }
    final store = unlinked ? _unlinkedState : _submissionState;
    final receivedAt = current['cashReceivedAt'];
    if (current['cashStatus'] == 'received' ||
        (receivedAt is String && receivedAt.isNotEmpty)) {
      return _ok({
        'id': id,
        'cashReceivedAt': receivedAt,
        'eventSequences': <int>[4],
        'replayed': true,
      });
    }
    const at = '2026-10-22T22:00:00.000Z';
    final next = {
      ...?store[id],
      'cashStatus': 'received',
      'cashPending': false,
      'cashReceivedAt': at,
    };
    next.remove('version');
    store[id] = next;
    return _ok({
      'id': id,
      'cashReceivedAt': at,
      'eventSequences': <int>[4],
    });
  }

  ApiResponse _applyUnlinkedDecision(String id, Map b) {
    final current = _recordById(
      _collectionsView()['unlinkedReceipts'] as List,
      id,
      'الإيصال غير موجود',
    );
    if (current['status'] != 'pending') {
      _fail(
        409,
        'SUBMISSION_ALREADY_DECIDED',
        submissionAlreadyDecidedMessage,
      );
    }
    final status = _decisionStatus(b['decision']);
    final customerId = b['customerId'];
    final next = {
      ...?_unlinkedState[id],
      'status': status,
      if (customerId != null) 'customerId': customerId,
    };
    next.remove('version');
    _unlinkedState[id] = next;
    return _decisionAck(id, status, current);
  }

  String _decisionStatus(Object? decision) {
    final status = switch (decision) {
      'approve' => 'approved',
      'reject' => 'rejected',
      _ => null,
    };
    if (status == null) _fail(400, 'VALIDATION_ERROR', 'قرار غير معروف');
    return status;
  }

  /// Approve includes the illustrative ledger ack. Reject is id, status, and
  /// events only. Nothing here posts a customer balance or a cash movement.
  ApiResponse _decisionAck(String id, String status, Map current) {
    if (status != 'approved') {
      return _ok({
        'id': id,
        'status': status,
        'eventSequences': <int>[3],
      });
    }
    final amount = current['amountUnits'];
    return _ok({
      'id': id,
      'status': status,
      'transactionId': 'collection-$id',
      if (amount is int) 'balanceUnits': amount,
      'eventSequences': <int>[3],
    });
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
  ///
  /// [treasuryTotalsPatch] is applied last. A null value stays in the JSON.
  /// [omitTreasuryTotalKeys] then deletes keys. Neither derives a conversion.
  Map<String, dynamic> _treasuryView() {
    final body = _copy(FakeFixtures.treasury());
    final state = _treasuryState;
    if (state != null) {
      body['version'] = state['version'];
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
      body['metrics'] =
          Map<String, dynamic>.from(FakeFixtures.ownCollectionMetrics);
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

  Map<String, dynamic> _collectionsForCaller([Map<String, dynamic>? query]) {
    if (_large) return _largeCollections(query);
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
      'items': [
        for (final item in page) Map<String, dynamic>.from(item),
      ],
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
