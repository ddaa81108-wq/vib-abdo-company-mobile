import 'common.dart';

/// Collections (استلامات الديون) — LYD. Response shapes beyond field names are 🔶
/// (only seen in frontend code); parsing is defensive and keeps `raw`.

class CollectionAssignmentDto {
  const CollectionAssignmentDto(
      {required this.id,
      required this.customerId,
      required this.customerName,
      this.section,
      this.phone,
      this.balanceUnits,
      this.assigneeName,
      this.status,
      this.raw = const {}});
  final String id;
  final String customerId;
  final String customerName;
  final String?
      section; // customers | companies | libyan-deposits | egyptian-deposits
  final String? phone;
  final MoneyValue? balanceUnits;
  final String? assigneeName;
  final String? status;
  final Json raw;
  factory CollectionAssignmentDto.fromJson(Json j) => CollectionAssignmentDto(
        id: str(j['id']),
        customerId: str(j['customerId']),
        customerName: str(j['customerName'] ?? j['name']),
        section: strOrNull(j['section']),
        phone: strOrNull(j['phone']),
        balanceUnits: unitsOrNull(
          j['balanceUnits'],
          fieldPath: 'balanceUnits',
          rowId: strOrNull(j['id']),
        ),
        assigneeName: strOrNull(j['assigneeName']),
        status: strOrNull(j['status']),
        raw: j,
      );
}

/// "ينتظر النقد" status — server-provided only (per API contract).
/// Proposed wire fields: `cashStatus: "pending"|"received"|"not_applicable"` and/or
/// `cashPending: bool`. The app NEVER derives it from `status` + `cashReceivedAt`.
enum CashStatus {
  pending('pending'),
  received('received'),
  notApplicable('not_applicable');

  const CashStatus(this.wire);
  final String wire;

  /// Uses `cashStatus` if present, else the boolean `cashPending` (true -> pending only).
  /// Absent -> null (no "awaiting cash" badge, neutral display).
  static CashStatus? fromServer(Json j) {
    final s = j['cashStatus'];
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return j['cashPending'] == true ? CashStatus.pending : null;
  }
}

class CollectionSubmissionDto {
  const CollectionSubmissionDto(
      {required this.id,
      required this.mode,
      this.amountUnits,
      required this.status,
      this.cashStatus,
      this.cashReceivedAt,
      this.version,
      this.submittedByName,
      this.createdAt,
      this.raw = const {}});
  final String id;
  final String mode; // full | partial
  final MoneyValue? amountUnits;
  final String
      status; // pending | approved | rejected (server value, shown as-is)
  final CashStatus?
      cashStatus; // server-provided only (null until the server adds it)
  final DateTime?
      cashReceivedAt; // shown as a timestamp only; not used to derive status
  /// Required from the server, per API contract: sent back as `expectedVersion` on decision / cash-received.
  final int? version;
  final String? submittedByName;
  final DateTime? createdAt;
  final Json raw;
  factory CollectionSubmissionDto.fromJson(Json j) => CollectionSubmissionDto(
        id: str(j['id']),
        mode: str(j['mode']),
        amountUnits: unitsOrNull(
          j['amountUnits'],
          fieldPath: 'amountUnits',
          rowId: strOrNull(j['id']),
        ),
        status: str(j['status']),
        cashStatus: CashStatus.fromServer(j),
        cashReceivedAt: dateOrNull(j['cashReceivedAt']),
        version: intOrNull(j['version']),
        submittedByName: strOrNull(j['submittedByName'] ?? j['employeeName']),
        createdAt: dateOrNull(j['createdAt']),
        raw: j,
      );
}

/// Unlinked receipt (استلام غير مربوط) — same server-only cash status + version rules.
class UnlinkedReceiptDto {
  const UnlinkedReceiptDto(
      {required this.id,
      required this.customerName,
      this.amountUnits,
      required this.status,
      this.cashStatus,
      this.cashReceivedAt,
      this.version,
      this.raw = const {}});
  final String id;
  final String customerName;
  final MoneyValue? amountUnits;
  final String status;
  final CashStatus? cashStatus;
  final DateTime? cashReceivedAt;
  final int? version;
  final Json raw;
  factory UnlinkedReceiptDto.fromJson(Json j) => UnlinkedReceiptDto(
        id: str(j['id']),
        customerName: str(j['customerName'] ?? j['name']),
        amountUnits: unitsOrNull(
          j['amountUnits'],
          fieldPath: 'amountUnits',
          rowId: strOrNull(j['id']),
        ),
        status: str(j['status']),
        cashStatus: CashStatus.fromServer(j),
        cashReceivedAt: dateOrNull(j['cashReceivedAt']),
        version: intOrNull(j['version']),
        raw: j,
      );
}

class EmployeeTotalDto {
  const EmployeeTotalDto(
      {required this.employeeName,
      this.collectedUnits,
      this.approvedCount,
      this.pendingCount});
  final String employeeName;
  final MoneyValue? collectedUnits;
  final int? approvedCount;
  final int? pendingCount;
  factory EmployeeTotalDto.fromJson(Json j) => EmployeeTotalDto(
        employeeName: str(j['employeeName'] ?? j['displayName']),
        collectedUnits: unitsOrNull(
          j['collectedUnits'],
          fieldPath: 'collectedUnits',
          rowId: strOrNull(j['userId'] ?? j['employeeId']),
        ),
        approvedCount: intOrNull(j['approvedCount']),
        pendingCount: intOrNull(j['pendingCount']),
      );
}

/// GET /api/collections — everything comes from the server, incl. totals.
class CollectionsOverviewDto {
  const CollectionsOverviewDto({
    required this.assignments,
    required this.submissions,
    required this.unlinkedReceipts,
    required this.employeeTotals,
    this.collectedUnits,
    this.dayTotalUnits,
    this.assignedCount,
    this.pendingCount,
    this.unlinkedPendingCount,
    this.cashOutstandingUnits,
    this.batchId,
    this.raw = const {},
  });
  final List<CollectionAssignmentDto> assignments;
  final List<CollectionSubmissionDto> submissions;
  final List<UnlinkedReceiptDto> unlinkedReceipts;
  final List<EmployeeTotalDto> employeeTotals;
  final MoneyValue? collectedUnits; // metrics.collectedUnits

  /// Required from the server, per API contract: the day total is not summed on the device.
  final MoneyValue? dayTotalUnits;
  final int? assignedCount;
  final int? pendingCount;
  final int? unlinkedPendingCount;
  final MoneyValue? cashOutstandingUnits;
  final String? batchId;
  final Json raw;

  Currency get currency => Currency.lyd;

  factory CollectionsOverviewDto.fromData(Object? data) {
    requireJsonObject(data, 'collections');
    final d = asJson(data);
    final metricsRaw = d['metrics'];
    requireJsonObject(metricsRaw, 'metrics');
    final metrics = asJson(metricsRaw);
    return CollectionsOverviewDto(
      assignments: asJsonList(d['assignments'])
          .map(CollectionAssignmentDto.fromJson)
          .toList(growable: false),
      submissions: asJsonList(d['submissions'])
          .map(CollectionSubmissionDto.fromJson)
          .toList(growable: false),
      unlinkedReceipts: asJsonList(d['unlinkedReceipts'])
          .map(UnlinkedReceiptDto.fromJson)
          .toList(growable: false),
      employeeTotals: asJsonList(d['employeeTotals'])
          .map(EmployeeTotalDto.fromJson)
          .toList(growable: false),
      collectedUnits: unitsOrNull(
        metrics['collectedUnits'],
        fieldPath: 'metrics.collectedUnits',
      ),
      dayTotalUnits: metrics.containsKey('dayTotalUnits')
          ? unitsOrNull(
              metrics['dayTotalUnits'],
              fieldPath: 'metrics.dayTotalUnits',
            )
          : unitsOrNull(d['dayTotalUnits'], fieldPath: 'dayTotalUnits'),
      // Top-level in data, per API contract; metrics is only a fallback.
      assignedCount: intOrNull(d['assignedCount'] ?? metrics['assignedCount']),
      pendingCount: intOrNull(metrics['pendingCount']),
      unlinkedPendingCount: intOrNull(metrics['unlinkedPendingCount']),
      cashOutstandingUnits: unitsOrNull(
        metrics['cashOutstandingUnits'],
        fieldPath: 'metrics.cashOutstandingUnits',
      ),
      batchId: strOrNull(d['batchId'] ?? asJson(d['batch'])['id']),
      raw: d,
    );
  }
}

enum CollectionDecision { approve, reject }

/// Payroll of collection employees — every figure from the server.
class PayrollEmployeeDto {
  const PayrollEmployeeDto(
      {required this.userId,
      required this.name,
      this.baseSalaryUnits,
      this.openingCarryUnits,
      this.commissionsUnits,
      this.withdrawalsUnits,
      this.remainingUnits,
      this.entries = const []});
  final String userId;
  final String name;
  final MoneyValue? baseSalaryUnits;
  final MoneyValue? openingCarryUnits;
  final MoneyValue? commissionsUnits;
  final MoneyValue? withdrawalsUnits;
  final MoneyValue? remainingUnits; // "الباقي من المرتب" — server only
  final List<Json> entries;
  factory PayrollEmployeeDto.fromJson(Json j) => PayrollEmployeeDto(
        userId: str(j['userId'] ?? j['employeeUserId'] ?? j['id']),
        name: str(j['displayName'] ?? j['name']),
        baseSalaryUnits: unitsOrNull(
          j['baseSalaryUnits'],
          fieldPath: 'baseSalaryUnits',
          rowId: strOrNull(j['userId'] ?? j['id']),
        ),
        openingCarryUnits: unitsOrNull(
          j['openingCarryUnits'],
          fieldPath: 'openingCarryUnits',
          rowId: strOrNull(j['userId'] ?? j['id']),
        ),
        commissionsUnits: unitsOrNull(
          j['commissionsUnits'],
          fieldPath: 'commissionsUnits',
          rowId: strOrNull(j['userId'] ?? j['id']),
        ),
        withdrawalsUnits: unitsOrNull(
          j['withdrawalsUnits'],
          fieldPath: 'withdrawalsUnits',
          rowId: strOrNull(j['userId'] ?? j['id']),
        ),
        remainingUnits: unitsOrNull(
          j['remainingUnits'],
          fieldPath: 'remainingUnits',
          rowId: strOrNull(j['userId'] ?? j['id']),
        ),
        entries: asJsonList(j['entries']),
      );
}

class PayrollDto {
  const PayrollDto({required this.period, required this.employees});
  final String? period;
  final List<PayrollEmployeeDto> employees;
  factory PayrollDto.fromData(Object? data) {
    final d = asJson(data);
    return PayrollDto(
        period: strOrNull(d['period']),
        employees: asJsonList(d['employees'])
            .map(PayrollEmployeeDto.fromJson)
            .toList(growable: false));
  }
}

enum PayrollEntryKind { withdrawal, commission } // 🔶 exact server values
