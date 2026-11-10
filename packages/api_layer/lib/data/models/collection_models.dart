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
      this.assignedBalanceUnits,
      this.assigneeName,
      this.assigneeUserId,
      this.status,
      this.batchId,
      this.businessDate,
      this.assignedAt,
      this.hasPending = false,
      this.latestMode,
      this.latestStatus,
      this.latestCashReceivedAt,
      this.latestDecisionAt,
      this.latestSubmissionAt,
      this.externalFinancialUpdatedAt,
      this.cashOutstandingCount = 0,
      this.raw = const {}});
  final String id;
  final String customerId;
  final String customerName;
  final String?
      section; // customers | companies | libyan-deposits | egyptian-deposits
  final String? phone;
  final MoneyValue? balanceUnits;

  /// Value the assignment was given (`assignedBalanceUnits`). Null when the
  /// server omits it; the card then shows «غير مسجلة» for that line.
  final MoneyValue? assignedBalanceUnits;
  final String? assigneeName;
  final String? assigneeUserId;
  final String? status;
  final String? batchId;
  final String? businessDate;

  /// Server timestamps, kept as the ISO text the server sent. The card tone
  /// compares them as text, the same as the website (`collectionCardState`).
  final String? assignedAt;

  /// `hasPending` (0/1 on 537f073): a pending submission exists, so the
  /// server refuses a new one (PENDING_SUBMISSION_EXISTS).
  final bool hasPending;
  final String? latestMode; // full | partial
  final String? latestStatus; // pending | approved | rejected
  final String? latestCashReceivedAt;
  final String? latestDecisionAt;
  final String? latestSubmissionAt;
  final String? externalFinancialUpdatedAt;
  final int cashOutstandingCount;
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
        assignedBalanceUnits: unitsOrNull(
          j['assignedBalanceUnits'],
          fieldPath: 'assignedBalanceUnits',
          rowId: strOrNull(j['id']),
        ),
        assigneeName: strOrNull(j['assigneeName']),
        assigneeUserId: strOrNull(j['assigneeUserId']),
        status: strOrNull(j['status']),
        batchId: strOrNull(j['batchId']),
        businessDate: strOrNull(j['businessDate']),
        assignedAt: strOrNull(j['assignedAt']),
        hasPending: serverFlag(j['hasPending']),
        latestMode: strOrNull(j['latestMode']),
        latestStatus: strOrNull(j['latestStatus']),
        latestCashReceivedAt: strOrNull(j['latestCashReceivedAt']),
        latestDecisionAt: strOrNull(j['latestDecisionAt']),
        latestSubmissionAt: strOrNull(j['latestSubmissionAt']),
        externalFinancialUpdatedAt: strOrNull(j['externalFinancialUpdatedAt']),
        cashOutstandingCount: intOrNull(j['cashOutstandingCount']) ?? 0,
        raw: j,
      );
}

/// SQLite `EXISTS(...)` arrives as 0/1. A JSON boolean is accepted too.
bool serverFlag(Object? v) => v == true || v == 1;

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
      this.assignmentId,
      this.customerId,
      this.customerName,
      this.collectorUserId,
      this.phone,
      this.batchId,
      this.businessDate,
      this.decidedAt,
      this.decisionNote,
      this.raw = const {}});
  final String id;
  final String mode; // full | partial
  final MoneyValue? amountUnits;
  final String
      status; // pending | approved | rejected (server value, shown as-is)
  /// Not sent by the 537f073 server. Kept only so an older payload parses.
  /// The UI reads [awaitingCash], which uses fields the server does send.
  final CashStatus? cashStatus;
  final DateTime? cashReceivedAt;

  /// Omitted by the collections contract. A present integer is still parsed.
  /// It is not sent as `expectedVersion` on decision or cash-received.
  final int? version;

  /// `collectorName` on 537f073.
  final String? submittedByName;

  /// `submittedAt` on 537f073.
  final DateTime? createdAt;
  final String? assignmentId;
  final String? customerId;
  final String? customerName;
  final String? collectorUserId;
  final String? phone;
  final String? batchId;
  final String? businessDate;
  final DateTime? decidedAt;
  final String? decisionNote;
  final Json raw;

  /// «ينتظر استلام النقدية»: approved and no `cashReceivedAt`. This is the
  /// server's own rule (its `cashOutstandingUnits` sums exactly these rows).
  bool get awaitingCash => status == 'approved' && cashReceivedAt == null;

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
        submittedByName: strOrNull(
            j['collectorName'] ?? j['submittedByName'] ?? j['employeeName']),
        createdAt: dateOrNull(j['submittedAt'] ?? j['createdAt']),
        assignmentId: strOrNull(j['assignmentId']),
        customerId: strOrNull(j['customerId']),
        customerName: strOrNull(j['customerName']),
        collectorUserId:
            strOrNull(j['collectorUserId'] ?? j['submittedByUserId']),
        phone: strOrNull(j['phone']),
        batchId: strOrNull(j['batchId']),
        businessDate: strOrNull(j['businessDate']),
        decidedAt: dateOrNull(j['decidedAt']),
        decisionNote: strOrNull(j['decisionNote']),
        raw: j,
      );
}

/// Unlinked receipt (استلام غير مربوط). `version` is optional and is not
/// required by the decision or cash-received contract.
class UnlinkedReceiptDto {
  const UnlinkedReceiptDto(
      {required this.id,
      required this.customerName,
      this.amountUnits,
      required this.status,
      this.cashStatus,
      this.cashReceivedAt,
      this.version,
      this.collectorName,
      this.submittedAt,
      this.businessDate,
      this.batchId,
      this.linkedCustomerId,
      this.entryType,
      this.decidedAt,
      this.raw = const {}});
  final String id;
  final String customerName;
  final MoneyValue? amountUnits;
  final String status;

  /// Not sent by the 537f073 server; see [CollectionSubmissionDto.cashStatus].
  final CashStatus? cashStatus;
  final DateTime? cashReceivedAt;
  final int? version;
  final String? collectorName;
  final DateTime? submittedAt;
  final String? businessDate;
  final String? batchId;
  final String? linkedCustomerId;
  final String? entryType; // debt | payment
  final DateTime? decidedAt;
  final Json raw;

  /// Approved and not yet handed over. A rejected receipt never waits for cash.
  bool get awaitingCash => status == 'approved' && cashReceivedAt == null;

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
        collectorName: strOrNull(j['collectorName']),
        submittedAt: dateOrNull(j['submittedAt']),
        businessDate: strOrNull(j['businessDate']),
        batchId: strOrNull(j['batchId']),
        linkedCustomerId: strOrNull(j['linkedCustomerId']),
        entryType: strOrNull(j['entryType']),
        decidedAt: dateOrNull(j['decidedAt']),
        raw: j,
      );
}

/// One open work batch (`openBatches[]`).
class CollectionBatchDto {
  const CollectionBatchDto(
      {required this.id, this.businessDate, this.batchNumber, this.openedAt});
  final String id;
  final String? businessDate;
  final int? batchNumber;
  final String? openedAt;
  factory CollectionBatchDto.fromJson(Json j) => CollectionBatchDto(
        id: str(j['id']),
        businessDate: strOrNull(j['businessDate']),
        batchNumber: intOrNull(j['batchNumber']),
        openedAt: strOrNull(j['openedAt']),
      );
}

/// Approved cash on a cancelled assignment that is still owed
/// (`outstandingCancelledSubmissions[]`, «نقدية سابقة لم تُسلّم»).
class OutstandingCashDto {
  const OutstandingCashDto(
      {required this.id,
      required this.customerName,
      this.collectorName,
      this.amountUnits});
  final String id;
  final String customerName;
  final String? collectorName;
  final MoneyValue? amountUnits;
  factory OutstandingCashDto.fromJson(Json j) => OutstandingCashDto(
        id: str(j['id']),
        customerName: str(j['customerName']),
        collectorName: strOrNull(j['collectorName']),
        amountUnits: unitsOrNull(
          j['amountUnits'],
          fieldPath: 'outstandingCancelledSubmissions.amountUnits',
          rowId: strOrNull(j['id']),
        ),
      );
}

/// `GET /api/collections/link-candidates?q=` row. Search is server-side only.
class CollectionLinkCandidateDto {
  const CollectionLinkCandidateDto(
      {required this.id,
      required this.name,
      this.balanceUnits,
      this.sectionKey,
      this.raw = const {}});
  final String id;
  final String name;
  final MoneyValue? balanceUnits;

  /// customer_debts | company_debts | libyan_deposits | egyptian_deposits
  final String? sectionKey;
  final Json raw;
  factory CollectionLinkCandidateDto.fromJson(Json j) =>
      CollectionLinkCandidateDto(
        id: str(j['id']),
        name: str(j['name']),
        balanceUnits: unitsOrNull(
          j['balanceUnits'],
          fieldPath: 'link-candidates.balanceUnits',
          rowId: strOrNull(j['id']),
        ),
        sectionKey: strOrNull(j['sectionKey']),
        raw: j,
      );
}

/// What the deployed collections server supports. Staging runs 537f073
/// (schema 50): none of these routes or fields exist there, so every flag is
/// off and the app shows none of these features. Nothing reads them as on yet.
class CollectionsCapabilities {
  const CollectionsCapabilities({
    this.workspaces = false,
    this.cancelAssignment = false,
    this.cancelApproval = false,
    this.exceptionalClose = false,
    this.receiptCurrency = false,
  });

  /// The server deployed on staging (537f073).
  static const deployed = CollectionsCapabilities();

  final bool workspaces; // GET /workspace, GET /mine
  final bool
      cancelAssignment; // POST /assignments/{id}/cancel, activeAssignmentId
  final bool cancelApproval; // POST .../cancel-approval
  final bool exceptionalClose; // days/close allowOutstandingCash
  final bool receiptCurrency; // currency / currencyMismatch
}

class EmployeeTotalDto {
  const EmployeeTotalDto(
      {required this.employeeName,
      this.employeeId,
      this.collectedUnits,
      this.approvedCount,
      this.pendingCount});
  final String employeeName;
  final String? employeeId;
  final MoneyValue? collectedUnits;
  final int? approvedCount;
  final int? pendingCount;
  factory EmployeeTotalDto.fromJson(Json j) => EmployeeTotalDto(
        employeeName: str(j['employeeName'] ?? j['displayName']),
        employeeId: strOrNull(j['employeeId'] ?? j['userId']),
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
    this.executedCount,
    this.batchId,
    this.openBatches = const [],
    this.outstandingCash = const [],
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

  /// `metrics.executedCount` («المنفذ»): approved linked + unlinked rows.
  final int? executedCount;

  /// The newest open batch: `batchId` if sent, else `openBatches[0].id`.
  final String? batchId;
  final List<CollectionBatchDto> openBatches;

  /// `outstandingCancelledSubmissions` («نقدية سابقة لم تُسلّم»).
  final List<OutstandingCashDto> outstandingCash;
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
      executedCount: intOrNull(metrics['executedCount']),
      batchId: strOrNull(d['batchId'] ??
          asJson(d['batch'])['id'] ??
          (asJsonList(d['openBatches']).isEmpty
              ? null
              : asJsonList(d['openBatches']).first['id'])),
      openBatches: asJsonList(d['openBatches'])
          .map(CollectionBatchDto.fromJson)
          .toList(growable: false),
      outstandingCash: asJsonList(d['outstandingCancelledSubmissions'])
          .map(OutstandingCashDto.fromJson)
          .toList(growable: false),
      raw: d,
    );
  }
}

enum CollectionDecision { approve, reject }

/// One payroll movement (`employees[].entries[]`).
class PayrollEntryDto {
  const PayrollEntryDto(
      {required this.id,
      required this.kind,
      this.amountUnits,
      this.reason,
      this.createdAt,
      this.createdByName,
      this.confirmedAt,
      this.confirmedByName});
  final String id;
  final String kind; // withdrawal | commission
  final MoneyValue? amountUnits;
  final String? reason;
  final DateTime? createdAt;
  final String? createdByName;
  final DateTime? confirmedAt;
  final String? confirmedByName;
  factory PayrollEntryDto.fromJson(Json j) => PayrollEntryDto(
        id: str(j['id']),
        kind: str(j['kind']),
        amountUnits: unitsOrNull(
          j['amountUnits'],
          fieldPath: 'payroll.entries.amountUnits',
          rowId: strOrNull(j['id']),
        ),
        reason: strOrNull(j['reason']),
        createdAt: dateOrNull(j['createdAt']),
        createdByName: strOrNull(j['createdByName']),
        confirmedAt: dateOrNull(j['confirmedAt']),
        confirmedByName: strOrNull(j['confirmedByName']),
      );
}

/// Payroll of collection employees — every figure from the server.
/// 537f073 sends `employeeId` / `employeeName`; older names still parse.
class PayrollEmployeeDto {
  const PayrollEmployeeDto(
      {required this.userId,
      required this.name,
      this.baseSalaryUnits,
      this.openingCarryUnits,
      this.showOpeningCarry = false,
      this.commissionsUnits,
      this.withdrawalsUnits,
      this.remainingUnits,
      this.entries = const []});
  final String userId;
  final String name;
  final MoneyValue? baseSalaryUnits;
  final MoneyValue? openingCarryUnits;

  /// True: the carry is «الباقي من الشهر القديم»; else «المرحل السابق».
  final bool showOpeningCarry;
  final MoneyValue? commissionsUnits;
  final MoneyValue? withdrawalsUnits;
  final MoneyValue? remainingUnits; // "الباقي من المرتب" — server only
  final List<Json> entries;

  List<PayrollEntryDto> get movements =>
      entries.map(PayrollEntryDto.fromJson).toList(growable: false);

  factory PayrollEmployeeDto.fromJson(Json j) {
    final id = strOrNull(
        j['employeeId'] ?? j['userId'] ?? j['employeeUserId'] ?? j['id']);
    MoneyValue? units(String key) =>
        unitsOrNull(j[key], fieldPath: key, rowId: id);
    return PayrollEmployeeDto(
      userId: id ?? '',
      name: str(j['employeeName'] ?? j['displayName'] ?? j['name']),
      baseSalaryUnits: units('baseSalaryUnits'),
      openingCarryUnits: units('openingCarryUnits'),
      showOpeningCarry: j['showOpeningCarry'] == true,
      commissionsUnits: units('commissionsUnits'),
      withdrawalsUnits: units('withdrawalsUnits'),
      remainingUnits: units('remainingUnits'),
      entries: asJsonList(j['entries']),
    );
  }
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
