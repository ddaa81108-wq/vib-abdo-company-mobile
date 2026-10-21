/// Environment configuration. Values come from --dart-define, never hardcoded.
enum AuthStrategyKind {
  /// Current real system: session cookie + X-CSRF-Token (default).
  cookieCsrf,

  /// 🔶 Pending the server owner's answer about a mobile token scheme. Stub only.
  bearerToken,
}

/// 🔶 Which body `EmployeeTotalsRepository` reads. The provider never branches
/// on this. `docs/api-contract-gaps.md` is not in this repo; item 14 names the
/// collections array and is still unconfirmed, as is `/api/admin/employee-totals`.
///
/// `--dart-define=EMPLOYEE_TOTALS_SOURCE=collections` selects the collections
/// array. Any other value, including empty, stays on the standalone endpoint.
enum EmployeeTotalsSource {
  /// GET /api/admin/employee-totals (proposed; no `/api/admin` prefix is confirmed).
  standalone,

  /// `employeeTotals` inside GET /api/collections (contract gap 14, unconfirmed).
  collections,
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
    this.employeeTotalsSource = EmployeeTotalsSource.standalone,
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

  /// 🔶 Source for the admin employee-totals dashboard. See [EmployeeTotalsSource].
  /// Changing this is the only switch when the server confirms a body. The
  /// provider and the UI call `EmployeeTotalsRepository.fetch` either way.
  final EmployeeTotalsSource employeeTotalsSource;

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
        employeeTotalsSource:
            String.fromEnvironment('EMPLOYEE_TOTALS_SOURCE') == 'collections'
                ? EmployeeTotalsSource.collections
                : EmployeeTotalsSource.standalone,
      );
}
