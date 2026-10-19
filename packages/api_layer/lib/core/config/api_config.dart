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

  /// JSON string (e.g. `"9.5"`) — the contract's target (§2.6, question 13).
  string,
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

  /// 🔶 Real base URL is intentionally NOT defaulted to production. The app must be
  /// pointed at a staging/test copy explicitly via --dart-define=API_BASE=...
  factory ApiConfig.fromEnvironment() => const ApiConfig(
        baseUrl: String.fromEnvironment('API_BASE',
            defaultValue: 'https://staging.example.invalid'),
        useFakeApi: bool.fromEnvironment('USE_FAKE_API', defaultValue: true),
        enableDebugLogging: bool.fromEnvironment('API_DEBUG_LOG'),
        authStrategy: bool.fromEnvironment('AUTH_BEARER')
            ? AuthStrategyKind.bearerToken
            : AuthStrategyKind.cookieCsrf,
        moneyUnitScale:
            int.fromEnvironment('MONEY_UNIT_SCALE', defaultValue: 0),
        rateWireFormat: String.fromEnvironment('RATE_WIRE_FORMAT') == 'string'
            ? RateWireFormat.string
            : RateWireFormat.number,
      );
}
