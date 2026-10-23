import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';

/// In-process HTTP boundary. The real Dio client, interceptors, and
/// repositories stay in place. Nothing here opens a socket.
class Phase7Transport implements HttpClientAdapter {
  final List<RecordedCall> calls = [];

  Map<String, dynamic> user = Map<String, dynamic>.from(phase7AdminUser);

  int csrfTokenVersion = 1;
  String get csrfToken => 'csrf-phase7-$csrfTokenVersion';

  /// Login status override. Null keeps the success envelope.
  int? loginStatus;
  String loginCode = 'INVALID_CREDENTIALS';
  String loginMessage = 'بيانات الدخول غير صحيحة';
  int? loginRetryAfterSeconds;

  /// Next authenticated response (not login, not CSRF) fails once.
  int? failNextStatus;
  String? failNextCode;
  Object? failNextDetails;
  Map<String, List<String>> failNextHeaders = const {};

  /// Every authenticated response fails with this status until cleared.
  int? failAuthenticatedStatus;
  String failAuthenticatedCode = 'AUTH_REQUIRED';

  /// Remaining CSRF failures on unsafe calls. Each one is HTTP 419.
  int csrfFailuresRemaining = 0;

  /// Throw a connection error instead of answering.
  int connectionErrorsRemaining = 0;

  /// Holds matching paths, then fails them as a dropped connection.
  String? holdPath;
  Future<void>? hold;
  bool releaseHoldAsConnectionError = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final call = RecordedCall(options);
    calls.add(call);
    if (hold != null && (holdPath == null || call.path == holdPath)) {
      await hold;
      if (releaseHoldAsConnectionError) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'simulated-offline',
        );
      }
    }
    if (connectionErrorsRemaining > 0) {
      connectionErrorsRemaining--;
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'simulated-offline',
      );
    }
    if (call.path == ApiEndpoints.login && loginStatus != null) {
      return _fail(
        loginStatus!,
        loginCode,
        loginMessage,
        headers: {
          if (loginRetryAfterSeconds != null)
            'retry-after': ['$loginRetryAfterSeconds'],
        },
      );
    }
    if (call.path == ApiEndpoints.csrf) {
      csrfTokenVersion++;
      return _ok({'csrfToken': csrfToken});
    }
    if (call.method != 'GET' &&
        call.method != 'HEAD' &&
        call.path != ApiEndpoints.login &&
        csrfFailuresRemaining > 0) {
      csrfFailuresRemaining--;
      return _fail(419, 'CSRF_INVALID', 'رمز CSRF غير مطابق');
    }
    if (call.path != ApiEndpoints.login && failAuthenticatedStatus != null) {
      return _fail(
        failAuthenticatedStatus!,
        failAuthenticatedCode,
        'يجب تسجيل الدخول أولًا.',
      );
    }
    if (call.path != ApiEndpoints.login &&
        call.path != ApiEndpoints.csrf &&
        failNextStatus != null) {
      final status = failNextStatus!;
      final code = failNextCode ?? _defaultCode(status);
      final details = failNextDetails;
      final headers = failNextHeaders;
      failNextStatus = null;
      failNextCode = null;
      failNextDetails = null;
      failNextHeaders = const {};
      return _fail(status, code, _defaultMessage(status),
          details: details, headers: headers);
    }
    final cookie = call.path == ApiEndpoints.login
        ? <String>[
            '${ApiConfig.sessionCookieName}=phase7-session; Path=/; HttpOnly; Secure; SameSite=Strict',
          ]
        : null;
    return _ok(_successData(call), setCookie: cookie);
  }

  @override
  void close({bool force = false}) {}

  List<RecordedCall> matching(String method, String path) => calls
      .where((call) => call.method == method && call.path == path)
      .toList(growable: false);

  Object? _successData(RecordedCall call) {
    final path = call.path;
    final method = call.method;
    if (path == ApiEndpoints.login) {
      return {'user': user, 'csrfToken': csrfToken};
    }
    if (path == ApiEndpoints.me) return {'user': user};
    if (path == ApiEndpoints.health) return {'status': 'ok'};
    if (path == ApiEndpoints.setupStatus) return {'ready': true};
    if (path.endsWith('/suggestions')) {
      return {
        'items': [
          {'id': 's1', 'name': 'اقتراح تجريبي'},
        ],
      };
    }
    if (path.endsWith('/ledger')) {
      return {
        'items': [
          {
            'id': 'tx1',
            'type': 'debt',
            'status': 'posted',
            'amountUnits': 10,
            'balanceAfterUnits': 10,
          },
        ],
        'currency': 'LYD',
      };
    }
    if (path == ApiEndpoints.egyptianExchangeRate) {
      return {'egpPerLyd': '9.5', 'version': 2};
    }
    if (path == ApiEndpoints.collections) {
      return {
        'metrics': {'collectedUnits': 5, 'dayTotalUnits': 5},
        'batchId': 'b1',
        'assignedCount': 1,
      };
    }
    if (path == ApiEndpoints.collectionAssignees ||
        path == ApiEndpoints.collectionLinkCandidates) {
      return {
        'items': [
          {'id': 'u_12', 'displayName': 'موظف تجريبي'},
        ],
      };
    }
    if (path == ApiEndpoints.payroll) {
      return {
        'period': '2026-10',
        'employees': [
          {
            'userId': 'u_12',
            'displayName': 'موظف تجريبي',
            'baseSalaryUnits': 10,
          },
        ],
      };
    }
    if (path == ApiEndpoints.masraweyaDay) {
      return {
        'businessDate': '2026-10-21',
        'version': 1,
        'workTotalUnits': 3,
        'remainingUnits': 1,
      };
    }
    if (path.startsWith('/api/purchases/')) {
      return {'days': <Object>[]};
    }
    if (path == ApiEndpoints.treasury) {
      return {
        'totals': {'receivablesUnits': 1, 'activeCashUnits': 2},
        'version': 1,
      };
    }
    if (path == ApiEndpoints.treasuryCashLedger) {
      return {
        'items': [
          {'id': 'ce1', 'direction': 'in', 'amountUnits': 2},
        ],
      };
    }
    if (path == ApiEndpoints.reports) {
      return {
        'items': <Object>[],
        'methodology': {'formula': 'server-formula'},
      };
    }
    if (path == ApiEndpoints.financialLedger) {
      return {
        'items': <Object>[],
        'scopeTotals': {'LYD': 1},
      };
    }
    if (path == ApiEndpoints.employeeTotals) {
      return {
        'from': '2026-10-01',
        'to': '2026-10-02',
        'items': [
          {
            'employeeId': 'u_12',
            'employeeName': 'موظف تجريبي',
            'collectedUnits': 1,
          },
        ],
        'totals': {'collectedUnits': 1},
      };
    }
    if (path == ApiEndpoints.notifications) {
      return {
        'items': [
          {'id': 'n1', 'action': 'approve', 'title': 'عنوان'},
        ],
        'unreadCount': 1,
      };
    }
    if (path == ApiEndpoints.notificationPreferences) {
      return {'soundEnabled': true};
    }
    if (path == ApiEndpoints.proposedUnreadCount) return {'unreadCount': 2};
    if (path == ApiEndpoints.proposedHome) {
      return {
        'businessDate': '2026-10-21',
        'summaries': [
          {
            'key': 'customers.net',
            'section': 'customers',
            'title': 'ديون',
            'valueUnits': 10,
            'currency': 'LYD',
          },
        ],
      };
    }
    if (path == ApiEndpoints.statementPdf) {
      return {
        'filename': 'statement.pdf',
        'contentBase64': base64Encode(const [1, 2, 3]),
      };
    }
    if (_isAccountList(path) && method == 'GET') {
      return {
        'items': [_card],
        'totalItems': 1,
        'summary': {'netBalanceUnits': 1500, 'totalDebtUnits': 1500},
      };
    }
    if (_isAccountCard(path) && method == 'GET') return _card;
    if (method == 'GET') return {'id': 'row-1', 'version': 1};
    return {'id': 'ack-1', 'version': 5};
  }

  static const _card = {
    'id': 'c1',
    'name': 'زبون تجريبي',
    'balanceUnits': 1500,
    'currency': 'LYD',
    'version': 4,
  };
}

bool _isAccountList(String path) {
  const sections = {
    '/api/customers',
    '/api/companies',
    '/api/libyan-deposits',
    '/api/egyptian-deposits',
  };
  return sections.contains(path);
}

bool _isAccountCard(String path) {
  final parts = path.split('/').where((part) => part.isNotEmpty).toList();
  if (parts.length != 3 || parts.first != 'api') return false;
  return const {
    'customers',
    'companies',
    'libyan-deposits',
    'egyptian-deposits',
  }.contains(parts[1]);
}

class RecordedCall {
  RecordedCall(RequestOptions options)
    : method = options.method.toUpperCase(),
      path = _pathOf(options),
      query = Map<String, dynamic>.from(options.queryParameters),
      headers = _headersOf(options),
      jsonBody = _bodyOf(options);

  /// Snapshotted at send time. A CSRF replay mutates the same [RequestOptions].
  final String method;
  final String path;
  final Map<String, dynamic> query;
  final Map<String, String?> headers;
  final Map<String, dynamic>? jsonBody;

  String? header(String name) => headers[name.toLowerCase()];
}

String _pathOf(RequestOptions options) {
  final uriPath = options.uri.path;
  return uriPath.isEmpty ? options.path : uriPath;
}

Map<String, String?> _headersOf(RequestOptions options) {
  final headers = <String, String?>{};
  options.headers.forEach((key, value) {
    if (value == null) {
      headers[key.toLowerCase()] = null;
    } else if (value is List) {
      headers[key.toLowerCase()] = value.join(',');
    } else {
      headers[key.toLowerCase()] = '$value';
    }
  });
  return headers;
}

Map<String, dynamic>? _bodyOf(RequestOptions options) {
  final data = options.data;
  if (data is Map) return Map<String, dynamic>.from(data);
  if (data is String && data.isNotEmpty) {
    final decoded = jsonDecode(data);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  }
  return null;
}

const phase7AdminUser = {
  'id': 'u_1',
  'username': 'admin@example.invalid',
  'displayName': 'مدير تجريبي',
  'role': 'admin',
  'permissions': <String>[],
  'mustChangePassword': false,
};

class RecordingPush implements PushService {
  int deletes = 0;

  @override
  Future<String?> getToken() async => 'push-demo-token';

  @override
  Stream<PushMessage> get messages => const Stream.empty();

  @override
  Future<void> deleteToken() async {
    deletes++;
  }
}

class Phase7Harness {
  Phase7Harness({
    required this.layer,
    required this.transport,
    required this.cookies,
    required this.tokens,
    required this.push,
    required this.cacheClears,
  });

  final ApiLayer layer;
  final Phase7Transport transport;
  final InMemoryCookieStore cookies;
  final InMemoryTokenStorage tokens;
  final RecordingPush push;
  final Phase7Counter cacheClears;

  static Future<Phase7Harness> open() async {
    final transport = Phase7Transport();
    final cookies = InMemoryCookieStore();
    final tokens = InMemoryTokenStorage();
    final push = RecordingPush();
    final clears = Phase7Counter();
    final layer = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://api.example.invalid',
        useFakeApi: false,
      ),
      cookieStore: cookies,
      tokenStorage: tokens,
      push: push,
      httpClientAdapter: transport,
      cleanups: [() async => clears.value++],
    );
    return Phase7Harness(
      layer: layer,
      transport: transport,
      cookies: cookies,
      tokens: tokens,
      push: push,
      cacheClears: clears,
    );
  }

  Future<void> login({
    String username = 'admin',
    String password = 'demo-only',
  }) {
    return layer.session.login(username: username, password: password);
  }

  Future<void> dispose() => layer.dispose();
}

class Phase7Counter {
  int value = 0;
}

ResponseBody _ok(Object? data, {List<String>? setCookie}) =>
    ResponseBody.fromString(
      jsonEncode({'ok': true, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        'x-correlation-id': ['corr-ok'],
        if (setCookie != null) 'set-cookie': setCookie,
      },
    );

ResponseBody _fail(
  int status,
  String code,
  String message, {
  Object? details,
  Map<String, List<String>> headers = const {},
}) {
  final error = <String, Object?>{
    'code': code,
    'message': message,
    'correlationId': 'corr-$status',
  };
  if (details != null) error['details'] = details;
  return ResponseBody.fromString(
    jsonEncode({'ok': false, 'error': error}),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
      'x-correlation-id': ['corr-$status'],
      ...headers,
    },
  );
}

String _defaultCode(int status) => switch (status) {
  401 => 'AUTH_REQUIRED',
  403 => 'FORBIDDEN',
  404 => 'NOT_FOUND',
  409 => 'VERSION_CONFLICT',
  422 => 'VALIDATION_ERROR',
  423 => 'ACCOUNT_LOCKED',
  429 => 'RATE_LIMITED',
  _ => 'SERVER_ERROR',
};

String _defaultMessage(int status) => switch (status) {
  403 => 'لا تملك صلاحية لهذا الإجراء',
  404 => 'العنصر غير موجود',
  409 => 'تغيرت البيانات على الخادم، يرجى التحديث',
  422 => 'البيانات المدخلة غير صحيحة',
  423 => 'الحساب مقفل',
  429 => 'طلبات كثيرة، حاول لاحقاً',
  _ => 'خطأ في الخادم، حاول لاحقاً',
};
