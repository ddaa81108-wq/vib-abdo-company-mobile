// Staging negative checks for the permission matrix.
//
// CI runs: tool/staging_negative_tests/run.sh --dry-run
// That path does not open a socket. Live mode refuses CI=true and any host
// that is not loopback or an https host whose name contains "staging".
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const caseNames = <String>[
  'employee-management-endpoints',
  'employee-foreign-resource-ids',
  'cookie-after-logout',
  'csrf-missing-and-invalid',
  'limited-manager-employee-totals',
];

const _requiredEnv = <String>[
  'STAGING_API_BASE',
  'STAGING_ADMIN_USERNAME',
  'STAGING_ADMIN_PASSWORD',
  'STAGING_EMPLOYEE_USERNAME',
  'STAGING_EMPLOYEE_PASSWORD',
  'STAGING_EMPLOYEE2_USERNAME',
  'STAGING_EMPLOYEE2_PASSWORD',
];

class CaseResult {
  CaseResult(this.name, this.status, this.detail);

  final String name;
  final String status;
  final String detail;

  bool get failed => status == 'FAIL';
}

class StagingConfig {
  StagingConfig({
    required this.base,
    required this.adminUsername,
    required this.adminPassword,
    required this.employeeUsername,
    required this.employeePassword,
    required this.employee2Username,
    required this.employee2Password,
    this.limitedUsername,
    this.limitedPassword,
  });

  final Uri base;
  final String adminUsername;
  final String adminPassword;
  final String employeeUsername;
  final String employeePassword;
  final String employee2Username;
  final String employee2Password;
  final String? limitedUsername;
  final String? limitedPassword;
}

class ConfigProblem implements Exception {
  ConfigProblem(this.message);
  final String message;
}

class ProbeResult {
  ProbeResult(this.status, this.body);
  final int status;
  final String body;

  bool get ok => status >= 200 && status < 300;
}

Future<void> main(List<String> args) async {
  final parsed = _parseArgs(args);
  if (parsed.dryRun) {
    final results = _selfTest();
    _printTable(results);
    if (parsed.junitPath != null) {
      await File(parsed.junitPath!).writeAsString(_junit(results));
    }
    exit(results.any((row) => row.failed) ? 1 : 0);
  }
  if (Platform.environment['CI'] == 'true') {
    stderr.writeln(
      'Refusing to contact a network because CI=true. CI runs this suite with --dry-run only.',
    );
    exit(2);
  }
  late final StagingConfig config;
  try {
    config = requireConfig(Platform.environment);
  } on ConfigProblem catch (error) {
    stderr.writeln(error.message);
    exit(2);
  }
  final results = await _runLive(config);
  _printTable(results);
  if (parsed.junitPath != null) {
    await File(parsed.junitPath!).writeAsString(_junit(results));
  }
  exit(results.any((row) => row.failed) ? 1 : 0);
}

class _Args {
  _Args({required this.dryRun, this.junitPath});
  final bool dryRun;
  final String? junitPath;
}

_Args _parseArgs(List<String> args) {
  var dryRun = false;
  String? junit;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--dry-run') {
      dryRun = true;
    } else if (arg == '--junit') {
      if (i + 1 >= args.length) {
        stderr.writeln('--junit needs a file path');
        exit(2);
      }
      junit = args[++i];
    } else {
      stderr.writeln('Unknown argument: $arg');
      exit(2);
    }
  }
  return _Args(dryRun: dryRun, junitPath: junit);
}

StagingConfig requireConfig(Map<String, String> env) {
  final missing = [
    for (final key in _requiredEnv)
      if ((env[key] ?? '').trim().isEmpty) key,
  ];
  if (missing.isNotEmpty) {
    throw ConfigProblem(
      'Refusing to run. Set ${missing.join(', ')}. No default host is used.',
    );
  }
  final limitedUser = (env['STAGING_LIMITED_MANAGER_USERNAME'] ?? '').trim();
  final limitedPassword = (env['STAGING_LIMITED_MANAGER_PASSWORD'] ?? '')
      .trim();
  if (limitedUser.isEmpty != limitedPassword.isEmpty) {
    throw ConfigProblem(
      'Set both STAGING_LIMITED_MANAGER_USERNAME and STAGING_LIMITED_MANAGER_PASSWORD, or neither.',
    );
  }
  final base = _requireStagingBase(env['STAGING_API_BASE']!.trim());
  return StagingConfig(
    base: base,
    adminUsername: env['STAGING_ADMIN_USERNAME']!.trim(),
    adminPassword: env['STAGING_ADMIN_PASSWORD']!,
    employeeUsername: env['STAGING_EMPLOYEE_USERNAME']!.trim(),
    employeePassword: env['STAGING_EMPLOYEE_PASSWORD']!,
    employee2Username: env['STAGING_EMPLOYEE2_USERNAME']!.trim(),
    employee2Password: env['STAGING_EMPLOYEE2_PASSWORD']!,
    limitedUsername: limitedUser.isEmpty ? null : limitedUser,
    limitedPassword: limitedPassword.isEmpty ? null : limitedPassword,
  );
}

Uri _requireStagingBase(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw ConfigProblem('STAGING_API_BASE must be an absolute origin.');
  }
  if (uri.userInfo.isNotEmpty) {
    throw ConfigProblem('STAGING_API_BASE must not contain user info.');
  }
  if (uri.query.isNotEmpty || uri.fragment.isNotEmpty) {
    throw ConfigProblem(
      'STAGING_API_BASE must not contain a query or fragment.',
    );
  }
  if (uri.path.isNotEmpty && uri.path != '/') {
    throw ConfigProblem('STAGING_API_BASE must be an origin with no path.');
  }
  final host = uri.host.toLowerCase();
  if (_productionLabel(host)) {
    throw ConfigProblem(
      'Refusing host "$host": a production label is never a target.',
    );
  }
  final loopback = host == 'localhost' || host == '127.0.0.1' || host == '::1';
  if (loopback) {
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw ConfigProblem('Loopback STAGING_API_BASE must be http or https.');
    }
    return uri;
  }
  if (uri.scheme != 'https' || !host.contains('staging')) {
    throw ConfigProblem(
      'Refusing host "$host". Live mode allows https hosts whose name contains "staging", or loopback.',
    );
  }
  return uri;
}

bool _productionLabel(String host) {
  final labels = host.split(RegExp(r'[.\-]'));
  return labels.any((label) => label == 'prod' || label == 'production');
}

List<CaseResult> _selfTest() {
  final results = <CaseResult>[];
  void check(String name, void Function() body) {
    try {
      body();
      results.add(CaseResult(name, 'PASS', ''));
    } on Object catch (error) {
      results.add(CaseResult(name, 'FAIL', '$error'));
    }
  }

  check('dry-run does not require env', () {
    var threw = false;
    try {
      requireConfig(const {});
    } on ConfigProblem {
      threw = true;
    }
    if (!threw) throw StateError('empty env was accepted');
  });
  check('catalogue lists the live cases', () {
    if (caseNames.length != 5) throw StateError('case list changed');
    const expected = {
      'employee-management-endpoints',
      'employee-foreign-resource-ids',
      'cookie-after-logout',
      'csrf-missing-and-invalid',
      'limited-manager-employee-totals',
    };
    if (caseNames.toSet().length != expected.length ||
        !expected.containsAll(caseNames)) {
      throw StateError('case names drifted');
    }
  });
  check('production and non-staging hosts are refused', () {
    const filled = {
      'STAGING_ADMIN_USERNAME': 'a',
      'STAGING_ADMIN_PASSWORD': 'a',
      'STAGING_EMPLOYEE_USERNAME': 'e',
      'STAGING_EMPLOYEE_PASSWORD': 'e',
      'STAGING_EMPLOYEE2_USERNAME': 'e2',
      'STAGING_EMPLOYEE2_PASSWORD': 'e2',
    };
    for (final host in const [
      'https://api.example.com',
      'https://production.example.com',
      'https://prod.example.com',
      'http://staging.example.com',
      'https://user:pw@staging.example.com',
      'https://staging.example.com/api',
      'https://staging.prod.example.com',
    ]) {
      var threw = false;
      try {
        requireConfig({...filled, 'STAGING_API_BASE': host});
      } on ConfigProblem {
        threw = true;
      }
      if (!threw) throw StateError('accepted $host');
    }
  });
  check('staging https and loopback are accepted', () {
    final staging = requireConfig({
      'STAGING_API_BASE': 'https://staging.example.invalid',
      'STAGING_ADMIN_USERNAME': 'a',
      'STAGING_ADMIN_PASSWORD': 'a',
      'STAGING_EMPLOYEE_USERNAME': 'e',
      'STAGING_EMPLOYEE_PASSWORD': 'e',
      'STAGING_EMPLOYEE2_USERNAME': 'e2',
      'STAGING_EMPLOYEE2_PASSWORD': 'e2',
    });
    if (staging.base.host != 'staging.example.invalid') {
      throw StateError('host mutated');
    }
    if (staging.limitedUsername != null) {
      throw StateError('limited manager should be unset');
    }
    final loopback = requireConfig({
      'STAGING_API_BASE': 'http://127.0.0.1:9',
      'STAGING_ADMIN_USERNAME': 'a',
      'STAGING_ADMIN_PASSWORD': 'a',
      'STAGING_EMPLOYEE_USERNAME': 'e',
      'STAGING_EMPLOYEE_PASSWORD': 'e',
      'STAGING_EMPLOYEE2_USERNAME': 'e2',
      'STAGING_EMPLOYEE2_PASSWORD': 'e2',
      'STAGING_LIMITED_MANAGER_USERNAME': 'm',
      'STAGING_LIMITED_MANAGER_PASSWORD': 'm',
    });
    if (loopback.limitedUsername != 'm') {
      throw StateError('limited manager was dropped');
    }
  });
  check('junit records a failure', () {
    final xml = _junit([
      CaseResult('sample', 'FAIL', 'a < b & "c"'),
      CaseResult('skipped', 'SKIP', 'unset'),
    ]);
    if (!xml.contains('<failure')) throw StateError('no failure element');
    if (!xml.contains('a &lt; b &amp; &quot;c&quot;')) {
      throw StateError('xml was not escaped');
    }
    if (!xml.contains('skipped="1"')) throw StateError('skip not counted');
  });
  return results;
}

Future<List<CaseResult>> _runLive(StagingConfig config) async {
  final http = HttpClient();
  http.connectionTimeout = const Duration(seconds: 20);
  http.findProxy = HttpClient.findProxyFromEnvironment;
  try {
    final results = <CaseResult>[];
    results.add(await _employeeManagement(http, config));
    results.add(await _foreignIds(http, config));
    results.add(await _afterLogout(http, config));
    results.add(await _csrf(http, config));
    results.add(await _limitedManager(http, config));
    return results;
  } finally {
    http.close(force: true);
  }
}

Future<CaseResult> _employeeManagement(
  HttpClient http,
  StagingConfig config,
) async {
  const name = 'employee-management-endpoints';
  try {
    final admin = await _login(
      http,
      config,
      config.adminUsername,
      config.adminPassword,
    );
    final adminTotals = await _send(
      http,
      config.base,
      method: 'GET',
      path: '/api/admin/employee-totals',
      session: admin,
    );
    final adminAllowed =
        adminTotals.status == 404 ||
        (adminTotals.status >= 200 && adminTotals.status < 300);
    if (!adminAllowed) {
      return CaseResult(
        name,
        'FAIL',
        'admin employee-totals -> ${adminTotals.status}',
      );
    }
    final session = await _login(
      http,
      config,
      config.employeeUsername,
      config.employeePassword,
    );
    final checks = <(String, String, Set<int>)>[
      ('GET', '/api/admin/employee-totals', {403}),
      ('GET', '/api/financial-ledger', {403, 404}),
      ('GET', '/api/statements/pdf', {403, 404}),
      ('GET', '/api/account-requests', {403, 404}),
      ('POST', '/api/collections/assignments', {403, 404}),
      ('POST', '/api/collections/days/close', {403, 404}),
      ('POST', '/api/collections/payroll/entries', {403, 404}),
      (
        'POST',
        '/api/collections/submissions/staging-negative-other/decision',
        {403, 404},
      ),
      (
        'POST',
        '/api/collections/submissions/staging-negative-other/cash-received',
        {403, 404},
      ),
      (
        'POST',
        '/api/collections/unlinked-receipts/staging-negative-other/decision',
        {403, 404},
      ),
      (
        'PUT',
        '/api/collections/payroll/employees/staging-negative-other/salary',
        {403, 404},
      ),
    ];
    final lines = <String>['admin employee-totals ${adminTotals.status}'];
    for (final check in checks) {
      final probe = await _send(
        http,
        config.base,
        method: check.$1,
        path: check.$2,
        session: session,
        jsonBody: check.$1 == 'GET' ? null : _writeBody(check.$2),
      );
      if (!check.$3.contains(probe.status) || probe.ok) {
        return CaseResult(
          name,
          'FAIL',
          '${check.$1} ${check.$2} -> ${probe.status}, expected ${check.$3.join('/')}',
        );
      }
      lines.add('${check.$2} ${probe.status}');
    }
    return CaseResult(name, 'PASS', lines.join('; '));
  } on _ProbeProblem catch (error) {
    return CaseResult(name, 'FAIL', error.message);
  }
}

Future<CaseResult> _foreignIds(HttpClient http, StagingConfig config) async {
  const name = 'employee-foreign-resource-ids';
  try {
    final other = await _login(
      http,
      config,
      config.employee2Username,
      config.employee2Password,
    );
    final overview = await _send(
      http,
      config.base,
      method: 'GET',
      path: '/api/collections',
      session: other,
    );
    if (overview.status == 401) {
      return CaseResult(name, 'FAIL', 'employee2 collections returned 401');
    }
    final ids = _ids(overview.body);
    final employee = await _login(
      http,
      config,
      config.employeeUsername,
      config.employeePassword,
    );
    final own = await _send(
      http,
      config.base,
      method: 'GET',
      path: '/api/collections',
      session: employee,
    );
    if (own.ok && _leaks(own.body, other)) {
      return CaseResult(
        name,
        'FAIL',
        'GET /api/collections included the other employee',
      );
    }
    if (own.ok && _totalsPresent(own.body)) {
      return CaseResult(
        name,
        'FAIL',
        'employee GET /api/collections included employeeTotals',
      );
    }
    if (ids.isEmpty) {
      return CaseResult(
        name,
        'FAIL',
        'employee2 collections response had no resource id to probe',
      );
    }
    final lines = <String>[];
    for (final id in ids) {
      final probe = await _send(
        http,
        config.base,
        method: 'POST',
        path: id.path,
        session: employee,
        jsonBody: _writeBody(id.path),
      );
      if (probe.ok || (probe.status != 403 && probe.status != 404)) {
        return CaseResult(
          name,
          'FAIL',
          'POST ${id.path} -> ${probe.status}, expected 403 or 404',
        );
      }
      if (_leaks(probe.body, other)) {
        return CaseResult(
          name,
          'FAIL',
          'POST ${id.path} body included the other employee',
        );
      }
      lines.add('${id.path} ${probe.status}');
    }
    return CaseResult(name, 'PASS', lines.join('; '));
  } on _ProbeProblem catch (error) {
    return CaseResult(name, 'FAIL', error.message);
  }
}

Future<CaseResult> _afterLogout(HttpClient http, StagingConfig config) async {
  const name = 'cookie-after-logout';
  try {
    final session = await _login(
      http,
      config,
      config.employeeUsername,
      config.employeePassword,
    );
    final logout = await _send(
      http,
      config.base,
      method: 'POST',
      path: '/api/auth/logout',
      session: session,
    );
    if (!logout.ok && logout.status != 204) {
      return CaseResult(name, 'FAIL', 'logout -> ${logout.status}');
    }
    final me = await _send(
      http,
      config.base,
      method: 'GET',
      path: '/api/me',
      session: session,
    );
    final write = await _send(
      http,
      config.base,
      method: 'POST',
      path: '/api/collections/unlinked-receipts',
      session: session,
      jsonBody: _writeBody('/api/collections/unlinked-receipts'),
    );
    if (me.status != 401 || write.status != 401) {
      return CaseResult(
        name,
        'FAIL',
        'after logout /api/me ${me.status}, write ${write.status}, expected 401',
      );
    }
    return CaseResult(name, 'PASS', 'me 401; write 401');
  } on _ProbeProblem catch (error) {
    return CaseResult(name, 'FAIL', error.message);
  }
}

Future<CaseResult> _csrf(HttpClient http, StagingConfig config) async {
  const name = 'csrf-missing-and-invalid';
  try {
    final session = await _login(
      http,
      config,
      config.employeeUsername,
      config.employeePassword,
    );
    final missing = await _send(
      http,
      config.base,
      method: 'POST',
      path: '/api/collections/unlinked-receipts',
      session: _Session(
        session.cookie,
        '',
        session.userId,
        session.displayName,
      ),
      jsonBody: _writeBody('/api/collections/unlinked-receipts'),
      sendCsrf: false,
    );
    final invalid = await _send(
      http,
      config.base,
      method: 'POST',
      path: '/api/collections/unlinked-receipts',
      session: _Session(
        session.cookie,
        'staging-negative-invalid-csrf',
        session.userId,
        session.displayName,
      ),
      jsonBody: _writeBody('/api/collections/unlinked-receipts'),
    );
    const allowed = {400, 403, 419};
    if (!allowed.contains(missing.status) || missing.ok) {
      return CaseResult(name, 'FAIL', 'missing CSRF -> ${missing.status}');
    }
    if (!allowed.contains(invalid.status) || invalid.ok) {
      return CaseResult(name, 'FAIL', 'invalid CSRF -> ${invalid.status}');
    }
    return CaseResult(
      name,
      'PASS',
      'missing ${missing.status}; invalid ${invalid.status}',
    );
  } on _ProbeProblem catch (error) {
    return CaseResult(name, 'FAIL', error.message);
  }
}

Future<CaseResult> _limitedManager(
  HttpClient http,
  StagingConfig config,
) async {
  const name = 'limited-manager-employee-totals';
  if (config.limitedUsername == null || config.limitedPassword == null) {
    return CaseResult(
      name,
      'SKIP',
      'STAGING_LIMITED_MANAGER_USERNAME / STAGING_LIMITED_MANAGER_PASSWORD unset',
    );
  }
  try {
    final session = await _login(
      http,
      config,
      config.limitedUsername!,
      config.limitedPassword!,
    );
    final probe = await _send(
      http,
      config.base,
      method: 'GET',
      path: '/api/admin/employee-totals',
      session: session,
    );
    if (probe.status != 403) {
      return CaseResult(
        name,
        'FAIL',
        'limited manager employee-totals -> ${probe.status}, expected 403 until DEF-002',
      );
    }
    return CaseResult(name, 'PASS', '403');
  } on _ProbeProblem catch (error) {
    return CaseResult(name, 'FAIL', error.message);
  }
}

class _Session {
  _Session(this.cookie, this.csrf, this.userId, this.displayName);
  final String cookie;
  final String csrf;
  final String userId;
  final String displayName;
}

class _IdRef {
  _IdRef(this.path);
  final String path;
}

class _ProbeProblem implements Exception {
  _ProbeProblem(this.message);
  final String message;
}

Future<_Session> _login(
  HttpClient http,
  StagingConfig config,
  String username,
  String password,
) async {
  final probe = await _send(
    http,
    config.base,
    method: 'POST',
    path: '/api/auth/login',
    jsonBody: {'username': username, 'password': password},
  );
  if (!probe.ok) {
    throw _ProbeProblem('login failed with status ${probe.status}');
  }
  final json = _decodeObject(probe.body);
  final data = json['data'] is Map
      ? (json['data'] as Map).cast<String, Object?>()
      : json;
  final token = data['csrfToken'];
  final user = data['user'] is Map
      ? (data['user'] as Map).cast<String, Object?>()
      : const <String, Object?>{};
  final cookie = probe.cookieHeader;
  if (cookie == null || cookie.isEmpty) {
    throw _ProbeProblem('login response had no Set-Cookie');
  }
  var csrf = token is String ? token : '';
  if (csrf.isEmpty) {
    final fetched = await _send(
      http,
      config.base,
      method: 'GET',
      path: '/api/auth/csrf',
      session: _Session(cookie, '', '', ''),
    );
    final fetchedJson = _decodeObject(fetched.body);
    final fetchedData = fetchedJson['data'] is Map
        ? (fetchedJson['data'] as Map).cast<String, Object?>()
        : fetchedJson;
    final fetchedToken = fetchedData['csrfToken'];
    if (fetchedToken is String) csrf = fetchedToken;
  }
  if (csrf.isEmpty) {
    throw _ProbeProblem('login response had no csrfToken');
  }
  final id = user['id'] ?? user['userId'];
  final name = user['displayName'] ?? user['name'] ?? user['username'];
  return _Session(cookie, csrf, '$id', '$name');
}

Future<ProbeResult> _send(
  HttpClient http,
  Uri base, {
  required String method,
  required String path,
  _Session? session,
  Object? jsonBody,
  bool sendCsrf = true,
}) async {
  final uri = base.replace(path: path);
  late final HttpClientRequest request;
  try {
    request = await http.openUrl(method, uri);
  } on SocketException catch (error) {
    throw _ProbeProblem('network: ${error.message}');
  } on HandshakeException {
    throw _ProbeProblem('tls handshake failed');
  } on HttpException {
    throw _ProbeProblem('http connection failed');
  }
  request.followRedirects = false;
  request.headers.set(HttpHeaders.acceptHeader, 'application/json');
  if (session != null && session.cookie.isNotEmpty) {
    request.headers.set(HttpHeaders.cookieHeader, session.cookie);
  }
  if (sendCsrf &&
      session != null &&
      session.csrf.isNotEmpty &&
      method != 'GET' &&
      method != 'HEAD') {
    request.headers.set('X-CSRF-Token', session.csrf);
  }
  if (jsonBody != null) {
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(jsonBody));
  }
  late final HttpClientResponse response;
  try {
    response = await request.close().timeout(const Duration(seconds: 30));
  } on SocketException catch (error) {
    throw _ProbeProblem('network: ${error.message}');
  } on TimeoutException {
    throw _ProbeProblem('request timed out');
  }
  final body = await response.transform(utf8.decoder).join();
  final result = ProbeResult(response.statusCode, body);
  result.cookieHeader = _cookieHeader(response.headers);
  return result;
}

String? _cookieHeader(HttpHeaders headers) {
  final values = headers[HttpHeaders.setCookieHeader];
  if (values == null || values.isEmpty) return null;
  final pairs = <String>[];
  for (final value in values) {
    final pair = value.split(';').first.trim();
    if (pair.contains('=')) pairs.add(pair);
  }
  if (pairs.isEmpty) return null;
  return pairs.join('; ');
}

Map<String, Object?> _decodeObject(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) return decoded.cast<String, Object?>();
  } on FormatException {
    return const {};
  }
  return const {};
}

Map<String, Object?> _writeBody(String path) => {
  'requestId': 'staging-negative-${path.hashCode}',
  if (path.endsWith('/decision') || path.endsWith('/cash-received'))
    'expectedVersion': 1,
  if (path.endsWith('/decision')) 'decision': 'reject',
  if (path.endsWith('/close')) 'batchId': 'staging-negative',
  if (path.endsWith('/close')) 'confirmed': true,
  if (path.endsWith('/assignments'))
    'customerIds': <String>['staging-negative'],
  if (path.endsWith('/assignments')) 'assigneeUserId': 'staging-negative',
  if (path.endsWith('/assignments')) 'section': 'customers',
  if (path.endsWith('/entries')) 'employeeUserId': 'staging-negative',
  if (path.endsWith('/entries')) 'kind': 'withdrawal',
  if (path.endsWith('/entries')) 'amountUnits': 1,
  if (path.endsWith('/entries')) 'reason': 'staging-negative',
  if (path.endsWith('/salary')) 'baseSalaryUnits': 1,
  if (path.endsWith('/unlinked-receipts')) 'customerName': 'staging-negative',
  if (path.endsWith('/unlinked-receipts')) 'amountUnits': 1,
  if (path.endsWith('/submissions')) 'mode': 'partial',
  if (path.endsWith('/submissions')) 'amountUnits': 1,
};

List<_IdRef> _ids(String body) {
  final found = <_IdRef>[];
  void walk(Object? node) {
    if (node is Map) {
      final id = node['id'];
      if (id is String && id.isNotEmpty) {
        if (node.containsKey('mode') || node.containsKey('submittedByName')) {
          found.add(_IdRef('/api/collections/submissions/$id/decision'));
        } else if (node.containsKey('customerName') &&
            node.containsKey('status')) {
          found.add(_IdRef('/api/collections/unlinked-receipts/$id/decision'));
        } else if (node.containsKey('customerId') ||
            node.containsKey('assigneeName')) {
          found.add(_IdRef('/api/collections/assignments/$id/submissions'));
        }
      }
      for (final value in node.values) {
        walk(value);
      }
    } else if (node is List) {
      for (final value in node) {
        walk(value);
      }
    }
  }

  try {
    walk(jsonDecode(body));
  } on FormatException {
    return const [];
  }
  final seen = <String>{};
  return [
    for (final id in found)
      if (seen.add(id.path)) id,
  ];
}

bool _totalsPresent(String body) {
  try {
    final decoded = jsonDecode(body);
    final data = decoded is Map && decoded['data'] is Map
        ? decoded['data'] as Map
        : decoded;
    if (data is! Map) return false;
    final totals = data['employeeTotals'];
    return totals is List && totals.isNotEmpty;
  } on FormatException {
    return false;
  }
}

bool _leaks(String body, _Session other) {
  if (other.displayName.length >= 3 && body.contains(other.displayName)) {
    return true;
  }
  if (other.userId.length >= 8 && body.contains(other.userId)) return true;
  return false;
}

void _printTable(List<CaseResult> results) {
  final nameWidth = results.fold<int>(
    'case'.length,
    (width, row) => row.name.length > width ? row.name.length : width,
  );
  final statusWidth = 6;
  String line(String name, String status, String detail) =>
      '| ${name.padRight(nameWidth)} | ${status.padRight(statusWidth)} | $detail';
  print(line('case', 'status', 'detail'));
  print('| ${'-' * nameWidth} | ${'-' * statusWidth} | ${'-' * 8}');
  for (final row in results) {
    print(line(row.name, row.status, row.detail));
  }
  final failed = results.where((row) => row.failed).length;
  final skipped = results.where((row) => row.status == 'SKIP').length;
  print(
    '${results.length - failed - skipped} passed, $failed failed, $skipped skipped',
  );
}

String _junit(List<CaseResult> results) {
  final failed = results.where((row) => row.failed).length;
  final skipped = results.where((row) => row.status == 'SKIP').length;
  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<testsuite name="staging-negative" tests="${results.length}" failures="$failed" skipped="$skipped">',
    );
  for (final row in results) {
    buffer.writeln(
      '  <testcase name="${_xml(row.name)}" classname="staging-negative">',
    );
    if (row.failed) {
      buffer.writeln('    <failure message="${_xml(row.detail)}"/>');
    } else if (row.status == 'SKIP') {
      buffer.writeln('    <skipped message="${_xml(row.detail)}"/>');
    }
    buffer.writeln('  </testcase>');
  }
  buffer.writeln('</testsuite>');
  return buffer.toString();
}

String _xml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

extension on ProbeResult {
  static final _cookies = Expando<String>();
  String? get cookieHeader => _cookies[this];
  set cookieHeader(String? value) {
    if (value != null) _cookies[this] = value;
  }
}
