/// Environment configuration. Values come from --dart-define, never hardcoded.
enum AuthStrategyKind {
  /// Current real system: session cookie + X-CSRF-Token (default).
  cookieCsrf,

  /// 🔶 Pending the server owner's answer about a mobile token scheme. Stub only.
  bearerToken,
}

/// How rate/factor values (`DecimalString`) are encoded ON THE WIRE only.
/// Inside the app they are always decimal text with no operations.
enum RateWireFormat {
  /// JSON number literal written from the exact digits (e.g. `9.5`), no float conversion.
  /// Default: the current server sends and expects JSON numbers for rates (per API contract).
  number,

  /// JSON string (e.g. `"9.5"`) — per API contract, the target wire form.
  string,
}

/// Thrown before any socket is opened when real mode has no usable origin.
class ApiConfigException implements Exception {
  const ApiConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 30),
    this.useFakeApi = false,
    this.enableDebugLogging = false,
    this.authStrategy = AuthStrategyKind.cookieCsrf,
    this.pollingInterval = const Duration(seconds: 4),
    this.moneyUnitScale = 0,
    this.rateWireFormat = RateWireFormat.number,
  });

  /// Origin only, e.g. https://host — paths in ApiEndpoints already start with /api.
  /// Empty in fake mode. Real mode is rejected unless this is an http(s) origin.
  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final bool useFakeApi;
  final bool enableDebugLogging;
  final AuthStrategyKind authStrategy;

  /// Fallback polling of /api/event-changes when SSE is down (web client: 4s while visible).
  final Duration pollingInterval;

  /// Number of fractional digits encoded in `*Units` integers. Observed web display
  /// uses maximumFractionDigits: 0 -> assumed 0 (whole dinar/pound). 🔶 to confirm.
  final int moneyUnitScale;

  /// Wire encoding for DecimalString values in request bodies (serialization layer only).
  final RateWireFormat rateWireFormat;

  /// Compile-time defines. Fake mode is the default and does not read a host.
  /// Real mode (`USE_FAKE_API=false`) throws [ApiConfigException] when `API_BASE`
  /// is missing or not an origin. The value is never given a placeholder host.
  factory ApiConfig.fromEnvironment() {
    const useFakeApi = bool.fromEnvironment('USE_FAKE_API', defaultValue: true);
    const apiBase = String.fromEnvironment('API_BASE');
    const debug = bool.fromEnvironment('API_DEBUG_LOG');
    const bearer = bool.fromEnvironment('AUTH_BEARER');
    const scale = int.fromEnvironment('MONEY_UNIT_SCALE', defaultValue: 0);
    const rate = String.fromEnvironment('RATE_WIRE_FORMAT');
    return ApiConfig.fromDefines(
      useFakeApi: useFakeApi,
      apiBase: apiBase,
      enableDebugLogging: debug,
      authStrategy:
          bearer ? AuthStrategyKind.bearerToken : AuthStrategyKind.cookieCsrf,
      moneyUnitScale: scale,
      rateWireFormat:
          rate == 'string' ? RateWireFormat.string : RateWireFormat.number,
    );
  }

  /// Same rules as [fromEnvironment], with explicit values so tests can cover
  /// real mode without rebuilding under a different `--dart-define`.
  factory ApiConfig.fromDefines({
    required bool useFakeApi,
    required String apiBase,
    bool enableDebugLogging = false,
    AuthStrategyKind authStrategy = AuthStrategyKind.cookieCsrf,
    int moneyUnitScale = 0,
    RateWireFormat rateWireFormat = RateWireFormat.number,
    Duration connectTimeout = const Duration(seconds: 15),
    Duration receiveTimeout = const Duration(seconds: 30),
    Duration pollingInterval = const Duration(seconds: 4),
  }) {
    return ApiConfig(
      // Fake mode never opens a socket, so a host is neither required nor kept.
      baseUrl: useFakeApi ? '' : requireRealBaseUrl(apiBase),
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      useFakeApi: useFakeApi,
      enableDebugLogging: enableDebugLogging,
      authStrategy: authStrategy,
      pollingInterval: pollingInterval,
      moneyUnitScale: moneyUnitScale,
      rateWireFormat: rateWireFormat,
    );
  }

  /// Absolute http(s) origin with no userinfo, query, fragment, or path.
  /// The raw value is never copied into the error text (it may contain a secret).
  static String requireRealBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const ApiConfigException(
        'API_BASE is required when USE_FAKE_API=false. '
        'Pass --dart-define=API_BASE=https://<staging-host> '
        '(origin only, no path, query, or credentials).',
      );
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty || !uri.isAbsolute) {
      throw const ApiConfigException(
        'API_BASE must be an absolute http or https origin, '
        'for example https://staging.example.com.',
      );
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const ApiConfigException('API_BASE must use http or https.');
    }
    if (uri.userInfo.isNotEmpty) {
      throw const ApiConfigException(
        'API_BASE must not include a username or password.',
      );
    }
    if (uri.query.isNotEmpty || uri.fragment.isNotEmpty) {
      throw const ApiConfigException(
        'API_BASE must be an origin only, with no query or fragment.',
      );
    }
    if (uri.path.isNotEmpty && uri.path != '/') {
      throw const ApiConfigException(
        'API_BASE must be an origin only. Request paths already start with /api.',
      );
    }
    final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://$host$port';
  }
}
