// Staging negative checks for the permission matrix.
//
// Self-test: tool/staging_negative_tests/run.sh --dry-run
// That path does not open a socket. The required CI job calls it when this
// file exists. Live mode is for the bot machine only. It refuses any
// non-empty CI or GITHUB_ACTIONS value, and it uses the same origin rules as
// `classify_origin` in the preflight: https only, a non-TLD label of
// staging/stage/test/testing, and no *.invalid placeholder. GitHub does not
// store the usernames or passwords.
//
// Live mode is read-only unless --allow-sandbox-writes is passed. Write
// methods (POST, PUT, PATCH, DELETE) are skipped without that flag. The flag
// is for a clean sandbox, not shared staging data, and needs Ali's explicit
// approval each time. It is not an environment variable. Login is not a
// negative write case: each account is logged in once per run and the
// session is reused. Logout runs after the other cases so it does not
// invalidate that session early.
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

/// Printed when a write probe is not sent. Live mode and `--dry-run` both use
/// this sentence.
const writeSkipDetail = 'skipped: write case, requires --allow-sandbox-writes';

/// Process status for a live run that GitHub must not host.
const liveCiExitCode = 2;

const _employeeNegativeProbes = <_ProbeSpec>[
  _ProbeSpec('GET', '/api/admin/employee-totals', {403}),
  _ProbeSpec('GET', '/api/financial-ledger', {403, 404}),
  _ProbeSpec('GET', '/api/statements/pdf', {403, 404}),
  _ProbeSpec('GET', '/api/account-requests', {403, 404}),
  _ProbeSpec('POST', '/api/collections/assignments', {403, 404}),
  _ProbeSpec('POST', '/api/collections/days/close', {403, 404}),
  _ProbeSpec('POST', '/api/collections/payroll/entries', {403, 404}),
  _ProbeSpec(
    'POST',
    '/api/collections/submissions/staging-negative-other/decision',
    {403, 404},
  ),
  _ProbeSpec(
    'POST',
    '/api/collections/submissions/staging-negative-other/cash-received',
    {403, 404},
  ),
  _ProbeSpec(
    'POST',
    '/api/collections/unlinked-receipts/staging-negative-other/decision',
    {403, 404},
  ),
  _ProbeSpec(
    'PUT',
    '/api/collections/payroll/employees/staging-negative-other/salary',
    {403, 404},
  ),
];

const _foreignWritePath = '/api/collections/<foreign-id>';

/// Static catalogue. Dry-run prints this. The live runner uses the same
/// methods and paths for the fixed probes.
const plannedProbes = <PlannedProbe>[
  PlannedProbe(
    'employee-management-endpoints',
    'GET',
    '/api/admin/employee-totals',
    note: 'admin',
  ),
  PlannedProbe(
    'employee-management-endpoints',
    'GET',
    '/api/admin/employee-totals',
    note: 'employee',
  ),
  PlannedProbe('employee-management-endpoints', 'GET', '/api/financial-ledger'),
  PlannedProbe('employee-management-endpoints', 'GET', '/api/statements/pdf'),
  PlannedProbe('employee-management-endpoints', 'GET', '/api/account-requests'),
  PlannedProbe(
    'employee-management-endpoints',
    'POST',
    '/api/collections/assignments',
  ),
  PlannedProbe(
    'employee-management-endpoints',
    'POST',
    '/api/collections/days/close',
  ),
  PlannedProbe(
    'employee-management-endpoints',
    'POST',
    '/api/collections/payroll/entries',
  ),
  PlannedProbe(
    'employee-management-endpoints',
    'POST',
    '/api/collections/submissions/staging-negative-other/decision',
  ),
  PlannedProbe(
    'employee-management-endpoints',
    'POST',
    '/api/collections/submissions/staging-negative-other/cash-received',
  ),
  PlannedProbe(
    'employee-management-endpoints',
    'POST',
    '/api/collections/unlinked-receipts/staging-negative-other/decision',
  ),
  PlannedProbe(
    'employee-management-endpoints',
    'PUT',
    '/api/collections/payroll/employees/staging-negative-other/salary',
  ),
  PlannedProbe(
    'employee-foreign-resource-ids',
    'GET',
    '/api/collections',
    note: 'employee 2',
  ),
  PlannedProbe(
    'employee-foreign-resource-ids',
    'GET',
    '/api/collections',
    note: 'employee 1',
  ),
  PlannedProbe(
    'employee-foreign-resource-ids',
    'POST',
    _foreignWritePath,
    note: 'discovered resource',
  ),
  PlannedProbe('cookie-after-logout', 'POST', '/api/auth/logout'),
  PlannedProbe(
    'cookie-after-logout',
    'GET',
    '/api/me',
    note: 'after logout',
    partOfWriteCase: true,
  ),
  PlannedProbe(
    'cookie-after-logout',
    'POST',
    '/api/collections/unlinked-receipts',
    note: 'after logout',
  ),
  PlannedProbe(
    'csrf-missing-and-invalid',
    'POST',
    '/api/collections/unlinked-receipts',
    note: 'missing CSRF',
  ),
  PlannedProbe(
    'csrf-missing-and-invalid',
    'POST',
    '/api/collections/unlinked-receipts',
    note: 'invalid CSRF',
  ),
  PlannedProbe(
    'limited-manager-employee-totals',
    'GET',
    '/api/admin/employee-totals',
    note: 'limited manager',
  ),
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

/// Live mode must not run on GitHub. Any non-empty value blocks the run.
/// Empty and unset are the only values that may proceed. `--dry-run` does
/// not call this on the way to a socket.
bool githubHostsLiveRun(Map<String, String> env) {
  bool blocks(String key) => (env[key] ?? '').trim().isNotEmpty;
  return blocks('CI') || blocks('GITHUB_ACTIONS');
}

/// Null when a live run may continue. Otherwise the message main prints
/// before exiting [liveCiExitCode].
String? liveRunRefusal(Map<String, String> env) {
  if (!githubHostsLiveRun(env)) return null;
  return 'Refusing a live staging permission check on GitHub. '
      'CI or GITHUB_ACTIONS is set to a non-empty value. '
      'Run it on the bot machine. GitHub does not store staging usernames or passwords.';
}

bool isReadMethod(String method) {
  final upper = method.toUpperCase();
  return upper == 'GET' || upper == 'HEAD';
}

String caseAccess(String name) {
  final probes = plannedProbes.where((probe) => probe.caseName == name);
  final skipped = probes.where((probe) => probe.skippedByDefault).length;
  final total = probes.length;
  if (total == 0) return 'read';
  if (skipped == 0) return 'read';
  if (skipped == total) return 'write';
  return 'mixed';
}

String planRow(PlannedProbe probe, {required bool allowSandboxWrites}) {
  final action = probe.skippedByDefault && !allowSandboxWrites
      ? writeSkipDetail
      : 'run';
  final note = probe.note.isEmpty ? '' : ' (${probe.note})';
  return '| ${probe.caseName} | ${caseAccess(probe.caseName)} | ${probe.method} | ${probe.path}$note | $action |';
}

List<String> probePlanLines({required bool allowSandboxWrites}) => [
  for (final probe in plannedProbes)
    planRow(probe, allowSandboxWrites: allowSandboxWrites),
];

void _printProbePlan({required bool allowSandboxWrites}) {
  final reads = plannedProbes.where((probe) => !probe.skippedByDefault).length;
  final writes = plannedProbes.where((probe) => probe.skippedByDefault).length;
  print('live case plan:');
  if (allowSandboxWrites) {
    print(
      '--allow-sandbox-writes is set. Write probes would run on a live run. This dry-run opens no socket.',
    );
  } else {
    print(
      'read-only default. Write probes are not sent unless --allow-sandbox-writes is set.',
    );
  }
  print('| case | access | method | path | default |');
  for (final row in probePlanLines(allowSandboxWrites: allowSandboxWrites)) {
    print(row);
  }
  if (allowSandboxWrites) {
    print(
      'probes: $reads read, $writes write. Write probes would run. They still need a clean sandbox and Ali\'s approval.',
    );
  } else {
    print('probes: $reads read, $writes write. Write probes $writeSkipDetail');
  }
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
    final results = await _selfTest();
    _printTable(results);
    print('');
    _printProbePlan(allowSandboxWrites: parsed.allowSandboxWrites);
    if (parsed.junitPath != null) {
      await File(parsed.junitPath!).writeAsString(_junit(results));
    }
    exit(results.any((row) => row.failed) ? 1 : 0);
  }
  final refusal = liveRunRefusal(Platform.environment);
  if (refusal != null) {
    stderr.writeln(refusal);
    exit(liveCiExitCode);
  }
  late final StagingConfig config;
  try {
    config = requireConfig(Platform.environment);
  } on ConfigProblem catch (error) {
    stderr.writeln(error.message);
    exit(2);
  }
  final results = await _runLive(
    config,
    allowSandboxWrites: parsed.allowSandboxWrites,
  );
  _printTable(results);
  if (parsed.junitPath != null) {
    await File(parsed.junitPath!).writeAsString(_junit(results));
  }
  exit(results.any((row) => row.failed) ? 1 : 0);
}

class _Args {
  _Args({
    required this.dryRun,
    required this.allowSandboxWrites,
    this.junitPath,
  });
  final bool dryRun;
  final bool allowSandboxWrites;
  final String? junitPath;
}

_Args _parseArgs(List<String> args) {
  var dryRun = false;
  var allowSandboxWrites = false;
  String? junit;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--dry-run') {
      dryRun = true;
    } else if (arg == '--allow-sandbox-writes') {
      allowSandboxWrites = true;
    } else if (arg == '--junit') {
      if (i + 1 >= args.length) {
        stderr.writeln('--junit needs a file path');
        exit(2);
      }
      junit = args[++i];
    } else {
      stderr.writeln('Unknown argument: $arg');
      stderr.writeln(
        'usage: run.sh [--dry-run] [--junit <file>] [--allow-sandbox-writes]',
      );
      exit(2);
    }
  }
  return _Args(
    dryRun: dryRun,
    allowSandboxWrites: allowSandboxWrites,
    junitPath: junit,
  );
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

/// Same accept/reject set as `classify_origin` in PR #32's preflight.
/// `ok` may run. `prod` and `not-staging` are refused. A non-default port is ok.
String classifyOrigin(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || !uri.hasScheme) return 'not-staging';
  final host = uri.host.toLowerCase().replaceAll(RegExp(r'\.$'), '');
  final labels = host.split('.').where((label) => label.isNotEmpty).toList();
  if (labels.any(_prodLabel)) return 'prod';
  if (uri.scheme != 'https') return 'not-staging';
  if (uri.userInfo.isNotEmpty) return 'not-staging';
  if (uri.query.isNotEmpty || uri.fragment.isNotEmpty) return 'not-staging';
  if (uri.path.isNotEmpty && uri.path != '/') return 'not-staging';
  if (host.isEmpty || _placeholder(host) || labels.isEmpty) {
    return 'not-staging';
  }
  // The final label is the TLD. `api.company.test` is not a staging origin.
  final markers = labels.sublist(0, labels.length - 1);
  if (markers.any(_stagingLabel)) return 'ok';
  return 'not-staging';
}

bool _prodLabel(String label) {
  if (label == 'prod' || label == 'production' || label == 'live') return true;
  if (label.contains('production')) return true;
  return label.startsWith('prod-') ||
      label.startsWith('production-') ||
      label.startsWith('live-') ||
      label.endsWith('-prod') ||
      label.endsWith('-production') ||
      label.endsWith('-live');
}

bool _stagingLabel(String label) {
  if (label == 'staging' ||
      label == 'stage' ||
      label == 'test' ||
      label == 'testing') {
    return true;
  }
  if (label.contains('staging') || label.contains('testing')) return true;
  return label.startsWith('stage-') ||
      label.startsWith('test-') ||
      label.endsWith('-stage') ||
      label.endsWith('-test');
}

bool _placeholder(String host) {
  if (host == 'example.com' ||
      host == 'example.org' ||
      host == 'example.net' ||
      host == 'localhost') {
    return true;
  }
  if (host.endsWith('.example') ||
      host.endsWith('.invalid') ||
      host.endsWith('.example.com') ||
      host.endsWith('.localhost')) {
    return true;
  }
  return host.contains('placeholder') ||
      host.contains('changeme') ||
      host.contains('replace-me') ||
      host.contains('replace_me');
}

Uri _requireStagingBase(String raw) {
  final kind = classifyOrigin(raw);
  if (kind == 'prod') {
    throw ConfigProblem(
      'Refusing STAGING_API_BASE: a production label is never a target.',
    );
  }
  if (kind != 'ok') {
    throw ConfigProblem(
      'Refusing STAGING_API_BASE. Live mode allows https origins whose host '
      'has a non-TLD label of staging, stage, test, or testing. '
      'Placeholders such as *.invalid are refused. '
      'This matches classify_origin in the staging preflight.',
    );
  }
  return Uri.parse(raw.trim());
}

Future<List<CaseResult>> _selfTest() async {
  final results = <CaseResult>[];
  void check(String name, void Function() body) {
    try {
      body();
      results.add(CaseResult(name, 'PASS', ''));
    } on Object catch (error) {
      results.add(CaseResult(name, 'FAIL', '$error'));
    }
  }

  Future<void> checkAsync(String name, Future<void> Function() body) async {
    try {
      await body();
      results.add(CaseResult(name, 'PASS', ''));
    } on Object catch (error) {
      results.add(CaseResult(name, 'FAIL', '$error'));
    }
  }

  check('live mode refuses any non-empty CI value', () {
    const blocked = ['true', '1', 'false', 'yes', 'TRUE', ' false '];
    for (final value in blocked) {
      if (liveRunRefusal(const {}) != null) {
        throw StateError('unset environment was refused');
      }
      if (!githubHostsLiveRun({'CI': value})) {
        throw StateError('CI=$value was allowed');
      }
      if (!githubHostsLiveRun({'GITHUB_ACTIONS': value})) {
        throw StateError('GITHUB_ACTIONS=$value was allowed');
      }
      final refusal = liveRunRefusal({'CI': value});
      if (refusal == null || !refusal.contains('non-empty')) {
        throw StateError('CI=$value had no refusal message');
      }
      if (liveRunRefusal({'GITHUB_ACTIONS': value}) == null) {
        throw StateError('GITHUB_ACTIONS=$value had no refusal message');
      }
    }
    if (githubHostsLiveRun(const {'CI': ''})) {
      throw StateError('empty CI was refused');
    }
    if (githubHostsLiveRun(const {'GITHUB_ACTIONS': ''})) {
      throw StateError('empty GITHUB_ACTIONS was refused');
    }
    if (githubHostsLiveRun(const {'CI': '   ', 'GITHUB_ACTIONS': ' \t '})) {
      throw StateError('blank CI values were refused');
    }
    if (githubHostsLiveRun(const {})) {
      throw StateError('a local shell was refused');
    }
    if (liveRunRefusal(const {}) != null ||
        liveRunRefusal(const {'CI': ''}) != null) {
      throw StateError('empty or unset CI produced a refusal');
    }
    if (liveCiExitCode != 2) {
      throw StateError('live CI exit code drifted from 2');
    }
  });
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
    for (final probe in _employeeNegativeProbes) {
      final planned = plannedProbes.where(
        (row) =>
            row.caseName == 'employee-management-endpoints' &&
            row.method == probe.method &&
            row.path == probe.path,
      );
      if (planned.isEmpty) {
        throw StateError('plan missing ${probe.method} ${probe.path}');
      }
      final skipped = !isReadMethod(probe.method);
      if (planned.any((row) => row.skippedByDefault != skipped)) {
        throw StateError('plan kind drifted for ${probe.method} ${probe.path}');
      }
    }
    if (plannedProbes.any((probe) => probe.path == '/api/auth/login')) {
      throw StateError('login was listed as a negative case');
    }
  });
  check('dry-run lists read and write probes', () {
    if (caseAccess('limited-manager-employee-totals') != 'read') {
      throw StateError('limited manager case is not read');
    }
    if (caseAccess('cookie-after-logout') != 'write') {
      throw StateError('logout case is not write');
    }
    if (caseAccess('csrf-missing-and-invalid') != 'write') {
      throw StateError('csrf case is not write');
    }
    if (caseAccess('employee-management-endpoints') != 'mixed') {
      throw StateError('employee management case is not mixed');
    }
    if (caseAccess('employee-foreign-resource-ids') != 'mixed') {
      throw StateError('foreign id case is not mixed');
    }
    final skipped = probePlanLines(allowSandboxWrites: false);
    final running = probePlanLines(allowSandboxWrites: true);
    if (skipped.length != plannedProbes.length ||
        running.length != plannedProbes.length) {
      throw StateError('plan row count drifted');
    }
    for (var i = 0; i < plannedProbes.length; i++) {
      final probe = plannedProbes[i];
      if (probe.skippedByDefault) {
        if (!skipped[i].contains(writeSkipDetail)) {
          throw StateError('write probe was not skipped: ${skipped[i]}');
        }
        if (running[i].contains(writeSkipDetail) ||
            !running[i].endsWith('| run |')) {
          throw StateError('flag did not enable ${running[i]}');
        }
      } else if (skipped[i].contains(writeSkipDetail) ||
          !skipped[i].contains('| ${caseAccess(probe.caseName)} |') ||
          !skipped[i].endsWith('| run |')) {
        throw StateError('read probe was skipped: ${skipped[i]}');
      }
    }
    final parsed = _parseArgs(const ['--dry-run']);
    if (parsed.allowSandboxWrites || !parsed.dryRun) {
      throw StateError('default dry-run parsed a write flag');
    }
    final enabled = _parseArgs(const ['--dry-run', '--allow-sandbox-writes']);
    if (!enabled.allowSandboxWrites || !enabled.dryRun) {
      throw StateError('write flag was not parsed');
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
      'https://api.company.test',
      'https://production.example.com',
      'https://prod.company.test',
      'https://live.company.test',
      'https://api.production.company.test',
      'https://staging.prod.company.test',
      'http://staging.company.test',
      'https://user:pw@staging.company.test',
      'https://staging.company.test/api',
      'https://staging.example.invalid',
      'http://127.0.0.1:9',
      'https://localhost',
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
  check('staging and test hosts are accepted', () {
    final staging = requireConfig({
      'STAGING_API_BASE': 'https://staging.company.test',
      'STAGING_ADMIN_USERNAME': 'a',
      'STAGING_ADMIN_PASSWORD': 'a',
      'STAGING_EMPLOYEE_USERNAME': 'e',
      'STAGING_EMPLOYEE_PASSWORD': 'e',
      'STAGING_EMPLOYEE2_USERNAME': 'e2',
      'STAGING_EMPLOYEE2_PASSWORD': 'e2',
    });
    if (staging.base.host != 'staging.company.test') {
      throw StateError('host mutated');
    }
    if (staging.limitedUsername != null) {
      throw StateError('limited manager should be unset');
    }
    for (final host in const [
      'https://api-staging.company.test:8443',
      'https://test.company.com',
      'https://testing.company.test',
      'https://stage.company.test',
    ]) {
      final accepted = requireConfig({
        'STAGING_API_BASE': host,
        'STAGING_ADMIN_USERNAME': 'a',
        'STAGING_ADMIN_PASSWORD': 'a',
        'STAGING_EMPLOYEE_USERNAME': 'e',
        'STAGING_EMPLOYEE_PASSWORD': 'e',
        'STAGING_EMPLOYEE2_USERNAME': 'e2',
        'STAGING_EMPLOYEE2_PASSWORD': 'e2',
      });
      if (accepted.base.scheme != 'https') {
        throw StateError('scheme changed for $host');
      }
    }
    final limited = requireConfig({
      'STAGING_API_BASE': 'https://test.company.test',
      'STAGING_ADMIN_USERNAME': 'a',
      'STAGING_ADMIN_PASSWORD': 'a',
      'STAGING_EMPLOYEE_USERNAME': 'e',
      'STAGING_EMPLOYEE_PASSWORD': 'e',
      'STAGING_EMPLOYEE2_USERNAME': 'e2',
      'STAGING_EMPLOYEE2_PASSWORD': 'e2',
      'STAGING_LIMITED_MANAGER_USERNAME': 'm',
      'STAGING_LIMITED_MANAGER_PASSWORD': 'm',
    });
    if (limited.limitedUsername != 'm') {
      throw StateError('limited manager was dropped');
    }
    if (classifyOrigin('https://api-staging.company.test:8443') != 'ok') {
      throw StateError('ported staging host was rejected');
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
  check('short ids match owner fields exactly', () {
    final other = _Session(
      'cookie',
      'csrf',
      'u_20',
      'موظف آخر',
      employeeId: 'e_20',
    );
    String payload(Object value) => jsonEncode(value);
    void expectLeak(Object value, String label) {
      if (!_leaks(payload(value), other)) {
        throw StateError('$label was missed');
      }
    }

    void expectClean(Object value, String label) {
      if (_leaks(payload(value), other)) {
        throw StateError('$label was treated as a leak');
      }
    }

    expectLeak({
      'data': {
        'employeeTotals': [
          {'userId': 'u_20', 'employeeName': 'x'},
        ],
      },
    }, 'employeeTotals userId u_20');
    expectLeak({
      'employeeTotals': [
        {'employeeId': 'e_20'},
      ],
    }, 'employeeTotals employeeId');
    expectLeak({
      'assignments': [
        {'assigneeUserId': 'u_20'},
      ],
    }, 'assigneeUserId');
    expectLeak({
      'submissions': [
        {'submittedByUserId': 'u_20'},
      ],
    }, 'submittedByUserId');
    expectLeak({
      'employees': [
        {'userId': 'u_20'},
      ],
    }, 'payroll userId');
    expectLeak({
      'entries': [
        {'employeeUserId': 'e_20'},
      ],
    }, 'employeeUserId');
    expectClean({
      'employeeTotals': [
        {'userId': 'u_3', 'note': 'u_20 appears only in text'},
      ],
      'message': 'hello u_20',
    }, 'prose mention of u_20');
    expectClean({
      'employeeTotals': [
        {'userId': 'u_200'},
      ],
    }, 'longer id u_200');
  });
  await checkAsync('each account logs in once', () async {
    await _assertLoginOnce(allowSandboxWrites: false);
    await _assertLoginOnce(allowSandboxWrites: true);
  });
  await checkAsync('read-only run does not send write methods', () async {
    final fake = _FakeProbeClient();
    final results = await _runLive(
      _offlineConfig(),
      client: fake,
      allowSandboxWrites: false,
      announceSkips: false,
    );
    if (fake.writeCalls.isNotEmpty) {
      throw StateError('read-only run sent ${fake.writeCalls.join(', ')}');
    }
    if (fake.writeCalls.any((call) => call.contains('unlinked-receipts'))) {
      throw StateError('unlinked receipt write was sent');
    }
    final byName = {for (final row in results) row.name: row};
    for (final name in const [
      'cookie-after-logout',
      'csrf-missing-and-invalid',
    ]) {
      final row = byName[name]!;
      if (row.status != 'SKIP' || row.detail != writeSkipDetail) {
        throw StateError('$name was ${row.status}: ${row.detail}');
      }
    }
    for (final name in const [
      'employee-management-endpoints',
      'employee-foreign-resource-ids',
      'limited-manager-employee-totals',
    ]) {
      final row = byName[name]!;
      if (row.failed) throw StateError('$name failed: ${row.detail}');
      if (!row.detail.contains(writeSkipDetail) &&
          name != 'limited-manager-employee-totals') {
        throw StateError('$name did not record the write skip');
      }
    }
  });
  return results;
}

Future<void> _assertLoginOnce({required bool allowSandboxWrites}) async {
  final fake = _FakeProbeClient();
  final results = await _runLive(
    _offlineConfig(),
    client: fake,
    allowSandboxWrites: allowSandboxWrites,
    announceSkips: false,
  );
  const accounts = ['admin', 'employee', 'employee2', 'limited'];
  for (final account in accounts) {
    final count = fake.loginsByAccount[account] ?? 0;
    if (count != 1) {
      throw StateError(
        '$account login count was $count when allowSandboxWrites=$allowSandboxWrites',
      );
    }
  }
  if (fake.loginsByAccount.length != accounts.length) {
    throw StateError(
      'unexpected login accounts: ${fake.loginsByAccount.keys.join(', ')}',
    );
  }
  if (!allowSandboxWrites) {
    if (fake.writeCalls.isNotEmpty) {
      throw StateError('writes sent without the flag: ${fake.writeCalls}');
    }
    return;
  }
  if (fake.writeCalls.isEmpty) {
    throw StateError('sandbox run sent no write methods');
  }
  if (!fake.writeCalls.any((call) => call.contains('unlinked-receipts'))) {
    throw StateError('sandbox run did not exercise the receipt write');
  }
  for (final row in results) {
    if (row.failed) {
      throw StateError(
        '${row.name} failed in the offline sandbox run: ${row.detail}',
      );
    }
  }
}

StagingConfig _offlineConfig() => StagingConfig(
  base: Uri.parse('https://staging.company.test'),
  adminUsername: 'admin',
  adminPassword: 'admin-pw',
  employeeUsername: 'employee',
  employeePassword: 'employee-pw',
  employee2Username: 'employee2',
  employee2Password: 'employee2-pw',
  limitedUsername: 'limited',
  limitedPassword: 'limited-pw',
);

Future<List<CaseResult>> _runLive(
  StagingConfig config, {
  _ProbeClient? client,
  bool allowSandboxWrites = false,
  bool announceSkips = true,
}) async {
  final owned = client == null;
  final probe = client ?? _IoProbeClient();
  final live = _Live(
    client: probe,
    config: config,
    allowSandboxWrites: allowSandboxWrites,
    announceSkips: announceSkips,
  );
  try {
    // Logout is last so the shared employee session stays valid for the
    // earlier cases. The printed table stays in [caseNames] order.
    final byName = <String, CaseResult>{
      'employee-management-endpoints': await _employeeManagement(live),
      'employee-foreign-resource-ids': await _foreignIds(live),
      'csrf-missing-and-invalid': await _csrf(live),
      'limited-manager-employee-totals': await _limitedManager(live),
      'cookie-after-logout': await _afterLogout(live),
    };
    return [for (final name in caseNames) byName[name]!];
  } finally {
    if (owned) probe.close();
  }
}

Future<CaseResult> _employeeManagement(_Live live) async {
  const name = 'employee-management-endpoints';
  try {
    final admin = await live.account(
      live.config.adminUsername,
      live.config.adminPassword,
    );
    final adminTotals = await live.client.send(
      base: live.config.base,
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
    final session = await live.account(
      live.config.employeeUsername,
      live.config.employeePassword,
    );
    final lines = <String>['admin employee-totals ${adminTotals.status}'];
    for (final check in _employeeNegativeProbes) {
      if (live.blocksWrite(check.method)) {
        live.noteSkip(lines, check.method, check.path);
        continue;
      }
      final probe = await live.client.send(
        base: live.config.base,
        method: check.method,
        path: check.path,
        session: session,
        jsonBody: isReadMethod(check.method) ? null : _writeBody(check.path),
      );
      if (!check.expected.contains(probe.status) || probe.ok) {
        return CaseResult(
          name,
          'FAIL',
          '${check.method} ${check.path} -> ${probe.status}, expected ${check.expected.join('/')}',
        );
      }
      lines.add('${check.path} ${probe.status}');
    }
    return CaseResult(name, 'PASS', lines.join('; '));
  } on _ProbeProblem catch (error) {
    return CaseResult(name, 'FAIL', error.message);
  }
}

Future<CaseResult> _foreignIds(_Live live) async {
  const name = 'employee-foreign-resource-ids';
  try {
    final other = await live.account(
      live.config.employee2Username,
      live.config.employee2Password,
    );
    final overview = await live.client.send(
      base: live.config.base,
      method: 'GET',
      path: '/api/collections',
      session: other,
    );
    if (overview.status == 401) {
      return CaseResult(name, 'FAIL', 'employee2 collections returned 401');
    }
    final ids = _ids(overview.body);
    final employee = await live.account(
      live.config.employeeUsername,
      live.config.employeePassword,
    );
    final own = await live.client.send(
      base: live.config.base,
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
    // Whether the server must omit employeeTotals for an employee is an
    // open question for Ali. A present array is not a failure. An owner
    // field equal to employee 2's userId or employeeId still fails
    // through _leaks above, including ids shorter than 8 characters.
    final lines = <String>[];
    if (!live.allowSandboxWrites) {
      live.noteSkip(lines, 'POST', _foreignWritePath);
      return CaseResult(name, 'PASS', lines.join('; '));
    }
    if (ids.isEmpty) {
      return CaseResult(
        name,
        'FAIL',
        'employee2 collections response had no resource id to probe',
      );
    }
    for (final id in ids) {
      final probe = await live.client.send(
        base: live.config.base,
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

Future<CaseResult> _afterLogout(_Live live) async {
  const name = 'cookie-after-logout';
  if (!live.allowSandboxWrites) return live.skipCase(name);
  try {
    final session = await live.account(
      live.config.employeeUsername,
      live.config.employeePassword,
    );
    final logout = await live.client.send(
      base: live.config.base,
      method: 'POST',
      path: '/api/auth/logout',
      session: session,
    );
    if (!logout.ok && logout.status != 204) {
      return CaseResult(name, 'FAIL', 'logout -> ${logout.status}');
    }
    final me = await live.client.send(
      base: live.config.base,
      method: 'GET',
      path: '/api/me',
      session: session,
    );
    final write = await live.client.send(
      base: live.config.base,
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

Future<CaseResult> _csrf(_Live live) async {
  const name = 'csrf-missing-and-invalid';
  if (!live.allowSandboxWrites) return live.skipCase(name);
  try {
    final session = await live.account(
      live.config.employeeUsername,
      live.config.employeePassword,
    );
    final missing = await live.client.send(
      base: live.config.base,
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
    final invalid = await live.client.send(
      base: live.config.base,
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

Future<CaseResult> _limitedManager(_Live live) async {
  const name = 'limited-manager-employee-totals';
  if (live.config.limitedUsername == null ||
      live.config.limitedPassword == null) {
    return CaseResult(
      name,
      'SKIP',
      'STAGING_LIMITED_MANAGER_USERNAME / STAGING_LIMITED_MANAGER_PASSWORD unset',
    );
  }
  try {
    final session = await live.account(
      live.config.limitedUsername!,
      live.config.limitedPassword!,
    );
    final probe = await live.client.send(
      base: live.config.base,
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

class PlannedProbe {
  const PlannedProbe(
    this.caseName,
    this.method,
    this.path, {
    this.note = '',
    this.partOfWriteCase = false,
  });

  final String caseName;
  final String method;
  final String path;
  final String note;

  /// A read method that only makes sense after a write in the same case.
  /// `GET /api/me` after logout is one. Running it alone is not a read check.
  final bool partOfWriteCase;

  bool get skippedByDefault => !isReadMethod(method) || partOfWriteCase;
}

class _ProbeSpec {
  const _ProbeSpec(this.method, this.path, this.expected);

  final String method;
  final String path;
  final Set<int> expected;
}

class _Live {
  _Live({
    required this.client,
    required this.config,
    required this.allowSandboxWrites,
    required this.announceSkips,
  });

  final _ProbeClient client;
  final StagingConfig config;
  final bool allowSandboxWrites;
  final bool announceSkips;
  final Map<String, _Session> _sessions = {};

  bool blocksWrite(String method) =>
      !allowSandboxWrites && !isReadMethod(method);

  Future<_Session> account(String username, String password) async {
    final cached = _sessions[username];
    if (cached != null) return cached;
    final session = await _login(client, config, username, password);
    _sessions[username] = session;
    return session;
  }

  void noteSkip(List<String> lines, String method, String path) {
    final line = '$writeSkipDetail ($method $path)';
    if (announceSkips) print(line);
    lines.add(line);
  }

  CaseResult skipCase(String name) {
    if (announceSkips) print(writeSkipDetail);
    return CaseResult(name, 'SKIP', writeSkipDetail);
  }
}

/// HTTP for one probe. The live client uses `dart:io`. The dry-run uses
/// [_FakeProbeClient] and must not construct an [HttpClient].
abstract class _ProbeClient {
  Future<ProbeResult> send({
    required Uri base,
    required String method,
    required String path,
    _Session? session,
    Object? jsonBody,
    bool sendCsrf = true,
  });

  void close();
}

class _IoProbeClient implements _ProbeClient {
  _IoProbeClient() {
    _http.connectionTimeout = const Duration(seconds: 20);
    _http.findProxy = HttpClient.findProxyFromEnvironment;
  }

  final HttpClient _http = HttpClient();

  @override
  Future<ProbeResult> send({
    required Uri base,
    required String method,
    required String path,
    _Session? session,
    Object? jsonBody,
    bool sendCsrf = true,
  }) {
    return _send(
      _http,
      base,
      method: method,
      path: path,
      session: session,
      jsonBody: jsonBody,
      sendCsrf: sendCsrf,
    );
  }

  @override
  void close() => _http.close(force: true);
}

/// In-memory host for the offline login-count check. No socket.
class _FakeProbeClient implements _ProbeClient {
  final Map<String, int> loginsByAccount = {};
  final List<String> writeCalls = [];
  final Set<String> _loggedOut = {};

  @override
  Future<ProbeResult> send({
    required Uri base,
    required String method,
    required String path,
    _Session? session,
    Object? jsonBody,
    bool sendCsrf = true,
  }) async {
    if (path == '/api/auth/login') {
      final body = jsonBody is Map ? jsonBody : const {};
      final username = body['username'];
      if (username is! String || username.isEmpty) {
        return ProbeResult(401, '{}');
      }
      loginsByAccount[username] = (loginsByAccount[username] ?? 0) + 1;
      final result = ProbeResult(
        200,
        jsonEncode({
          'data': {
            'csrfToken': 'csrf-$username',
            'user': {
              'id': 'id-$username',
              'userId': 'id-$username',
              'employeeId': 'emp-$username',
              'displayName': username,
            },
          },
        }),
      );
      result.cookieHeader = 'sid=$username';
      return result;
    }
    final upper = method.toUpperCase();
    if (!isReadMethod(upper)) writeCalls.add('$upper $path');
    final cookie = session?.cookie ?? '';
    if (path == '/api/auth/logout') {
      _loggedOut.add(cookie);
      return ProbeResult(204, '');
    }
    if (_loggedOut.contains(cookie)) return ProbeResult(401, '{}');
    if (path == '/api/admin/employee-totals') {
      if (cookie == 'sid=admin') return ProbeResult(200, '{"data":{}}');
      return ProbeResult(403, '{}');
    }
    if (path == '/api/collections' && upper == 'GET') {
      if (cookie == 'sid=employee2') {
        return ProbeResult(
          200,
          jsonEncode({
            'submissions': [
              {'id': 'foreign-sub', 'mode': 'full', 'submittedByName': 'other'},
            ],
          }),
        );
      }
      return ProbeResult(
        200,
        jsonEncode({
          'submissions': [
            {
              'id': 'own-sub',
              'mode': 'full',
              'submittedByUserId': 'id-employee',
            },
          ],
        }),
      );
    }
    if (!sendCsrf || session == null || session.csrf.isEmpty) {
      if (!isReadMethod(upper)) return ProbeResult(403, '{}');
    }
    if (session != null && session.csrf == 'staging-negative-invalid-csrf') {
      return ProbeResult(403, '{}');
    }
    if (!isReadMethod(upper)) return ProbeResult(403, '{}');
    return ProbeResult(403, '{}');
  }

  @override
  void close() {}
}

class _Session {
  _Session(
    this.cookie,
    this.csrf,
    this.userId,
    this.displayName, {
    this.employeeId = '',
    Set<String>? identityIds,
  }) : identityIds = identityIds ?? _identityFrom(userId, employeeId);

  final String cookie;
  final String csrf;
  final String userId;
  final String displayName;
  final String employeeId;

  /// Exact ids compared with row owner fields. Includes [userId] and
  /// [employeeId] when the login payload sent both.
  final Set<String> identityIds;

  static Set<String> _identityFrom(String userId, String employeeId) => {
    if (userId.isNotEmpty) userId,
    if (employeeId.isNotEmpty) employeeId,
  };
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
  _ProbeClient client,
  StagingConfig config,
  String username,
  String password,
) async {
  final probe = await client.send(
    base: config.base,
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
    final fetched = await client.send(
      base: config.base,
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
  final identityIds = {
    for (final key in const ['id', 'userId', 'employeeId'])
      _scalarId(user[key]),
  }..remove('');
  final userId = _scalarId(user['userId'] ?? user['id']);
  final employeeId = _scalarId(user['employeeId']);
  final name = user['displayName'] ?? user['name'] ?? user['username'];
  return _Session(
    cookie,
    csrf,
    userId,
    name is String ? name : '',
    employeeId: employeeId,
    identityIds: identityIds,
  );
}

String _scalarId(Object? value) {
  if (value == null || value is Map || value is List) return '';
  final text = value.toString().trim();
  if (text.isEmpty || text == 'null') return '';
  return text;
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

const _ownerFields = {
  'userId',
  'employeeId',
  'assigneeUserId',
  'submittedByUserId',
  'recipientUserId',
  'employeeUserId',
};

/// True when a structured owner field equals the other employee's user id
/// or employee id. A short id such as `u_20` matches. Text that only
/// mentions the id does not.
bool _leaks(String body, _Session other) {
  if (other.identityIds.isEmpty) return false;
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return false;
  }
  return _ownerMatches(decoded, other.identityIds);
}

bool _ownerMatches(Object? node, Set<String> ids) {
  if (node is Map) {
    for (final field in _ownerFields) {
      if (!node.containsKey(field)) continue;
      final text = _scalarId(node[field]);
      if (text.isNotEmpty && ids.contains(text)) return true;
    }
    for (final value in node.values) {
      if (_ownerMatches(value, ids)) return true;
    }
  } else if (node is List) {
    for (final value in node) {
      if (_ownerMatches(value, ids)) return true;
    }
  }
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
