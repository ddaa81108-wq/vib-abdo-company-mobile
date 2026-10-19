import 'dart:async';

import '../../core/network/api_client.dart';
import '../../core/network/error_mapper.dart';
import 'fake_fixtures.dart';

/// In-memory fake of the REAL API shapes so the UI can be built with zero contact
/// with the production system. Same ApiClient interface => Remote*Repository run unchanged.
/// Login as a username starting with "admin" -> admin role; anything else -> collections employee.
/// Password "wrong" -> 401. It only returns canned values; it never computes money.
class FakeApiClient implements ApiClient {
  FakeApiClient({this.latency = const Duration(milliseconds: 250)});

  final Duration latency;
  bool _loggedIn = false;
  bool _admin = false;
  int _unread = 1; // canned server-side state, set (not computed) per action
  static const _err = ErrorMapper();

  @override
  Future<ApiResponse> get(String path,
          {Map<String, dynamic>? query,
          ApiRequestOptions options = const ApiRequestOptions()}) =>
      _handle('GET', path, null, options);
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

  ApiResponse _ok(Object? data, {int status = 200}) =>
      ApiResponse(statusCode: status, data: data, correlationId: 'fake');

  Never _fail(int status, String code, String message) =>
      throw _err.fromResponse(status, {
        'ok': false,
        'error': {
          'code': code,
          'message': message,
          'details': {},
          'correlationId': 'fake'
        },
      });

  void _requireAdmin() {
    if (!_admin) _fail(403, 'FORBIDDEN', 'هذا الإجراء للإدارة فقط');
  }

  void _requireMutationMeta(Map b) {
    if (b['requestId'] == null) {
      _fail(400, 'REQUEST_ID_REQUIRED', 'requestId مطلوب');
    }
  }

  Future<ApiResponse> _handle(String method, String path, Object? body,
      ApiRequestOptions options) async {
    await Future<void>.delayed(latency);
    final b = body is Map ? body : const {};
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
      _admin = '${b['username']}'.startsWith('admin');
      return _ok({...FakeFixtures.me(admin: _admin), 'csrfToken': 'fake-csrf'});
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
    if (path == '/api/me') return _ok(FakeFixtures.me(admin: _admin));

    if (method != 'GET' &&
        head != 'notifications' &&
        head != 'notification-preferences') {
      _requireMutationMeta(b);
    }

    switch (head) {
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
          return _ok({'items': []});
        }
        if (method == 'GET' && seg.length == 3 && seg[2] == 'ledger') {
          return _ok(FakeFixtures.ledger());
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
        if (method == 'GET') return _ok({'items': []});
        final employeeAllowed = (seg.length > 2 &&
                seg[1] == 'assignments' &&
                seg.last == 'submissions') ||
            (seg.length == 2 && seg[1] == 'unlinked-receipts') ||
            (seg.length > 3 && seg[1] == 'payroll' && seg.last == 'confirm');
        if (!employeeAllowed) _requireAdmin();
        return _ok({'id': 'ok', 'version': 1});
      case 'masraweya':
        return _ok(FakeFixtures.masraweyaDay());
      case 'purchases':
        if (method == 'GET') return _ok(FakeFixtures.purchases());
        return _ok({'id': 'pe_new', 'version': 4});
      case 'treasury':
        if (method == 'GET' && seg.length == 1) {
          return _ok(FakeFixtures.treasury());
        }
        if (method == 'GET') return _ok(FakeFixtures.cashLedger());
        return _ok({'id': 'ce_new', 'version': 8});
      case 'reports':
        return _ok(FakeFixtures.reports());
      case 'financial-ledger':
        _requireAdmin();
        return _ok({
          'items': [],
          'scopeTotals': {'LYD': 0, 'EGP': 0}
        });
      case 'notifications':
        if (method == 'GET') return _ok(FakeFixtures.notifications(_unread));
        _unread = 0; // fake server state reset (single notification fixture)
        return _ok({});
      case 'notification-preferences':
        return _ok({'soundEnabled': true, 'speechEnabled': false});
      case 'event-changes':
        return _ok({'events': [], 'latest': 0, 'fullResync': false});
    }
    _fail(404, 'NOT_FOUND', 'المسار غير موجود في الخادم التجريبي');
  }
}
