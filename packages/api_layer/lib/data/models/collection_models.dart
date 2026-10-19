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
  final int? balanceUnits;
  final String? assigneeName;
  final String? status;
  final Json raw;
  factory CollectionAssignmentDto.fromJson(Json j) => CollectionAssignmentDto(
        id: str(j['id']),
        customerId: str(j['customerId']),
        customerName: str(j['customerName'] ?? j['name']),
        section: strOrNull(j['section']),
        phone: strOrNull(j['phone']),
        balanceUnits: unitsOrNull(j['balanceUnits']),
        assigneeName: strOrNull(j['assigneeName']),
        status: strOrNull(j['status']),
        raw: j,
      );
}

class CollectionSubmissionDto {
  const CollectionSubmissionDto(
      {required this.id,
      required this.mode,
      this.amountUnits,
      required this.status,
      this.cashReceived = false,
      this.submittedByName,
      this.createdAt,
      this.raw = const {}});
  final String id;
  final String mode; // full | partial
  final int? amountUnits;
  final String status; // pending | approved | rejected (🔶)
  final bool cashReceived;
  final String? submittedByName;
  final DateTime? createdAt;
  final Json raw;
  factory CollectionSubmissionDto.fromJson(Json j) => CollectionSubmissionDto(
        id: str(j['id']),
        mode: str(j['mode']),
        amountUnits: unitsOrNull(j['amountUnits']),
        status: str(j['status']),
        cashReceived: boolOf(j['cashReceived']) || j['cashReceivedAt'] != null,
        submittedByName: strOrNull(j['submittedByName'] ?? j['employeeName']),
        createdAt: dateOrNull(j['createdAt']),
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
  final int? collectedUnits;
  final int? approvedCount;
  final int? pendingCount;
  factory EmployeeTotalDto.fromJson(Json j) => EmployeeTotalDto(
        employeeName: str(j['employeeName'] ?? j['displayName']),
        collectedUnits: unitsOrNull(j['collectedUnits']),
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
    this.batchId,
    this.raw = const {},
  });
  final List<CollectionAssignmentDto> assignments;
  final List<CollectionSubmissionDto> submissions;
  final List<Json> unlinkedReceipts;
  final List<EmployeeTotalDto> employeeTotals;
  final int? collectedUnits; // metrics.collectedUnits

  /// REQUIRED FROM SERVER (contract §12): web client sums the PDF day total locally.
  final int? dayTotalUnits;
  final String? batchId;
  final Json raw;

  Currency get currency => Currency.lyd;

  factory CollectionsOverviewDto.fromData(Object? data) {
    final d = asJson(data);
    final metrics = asJson(d['metrics']);
    return CollectionsOverviewDto(
      assignments: asJsonList(d['assignments'])
          .map(CollectionAssignmentDto.fromJson)
          .toList(growable: false),
      submissions: asJsonList(d['submissions'])
          .map(CollectionSubmissionDto.fromJson)
          .toList(growable: false),
      unlinkedReceipts: asJsonList(d['unlinkedReceipts']),
      employeeTotals: asJsonList(d['employeeTotals'])
          .map(EmployeeTotalDto.fromJson)
          .toList(growable: false),
      collectedUnits: unitsOrNull(metrics['collectedUnits']),
      dayTotalUnits:
          unitsOrNull(metrics['dayTotalUnits'] ?? d['dayTotalUnits']),
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
  final int? baseSalaryUnits;
  final int? openingCarryUnits;
  final int? commissionsUnits;
  final int? withdrawalsUnits;
  final int? remainingUnits; // "الباقي من المرتب" — server only
  final List<Json> entries;
  factory PayrollEmployeeDto.fromJson(Json j) => PayrollEmployeeDto(
        userId: str(j['userId'] ?? j['employeeUserId'] ?? j['id']),
        name: str(j['displayName'] ?? j['name']),
        baseSalaryUnits: unitsOrNull(j['baseSalaryUnits']),
        openingCarryUnits: unitsOrNull(j['openingCarryUnits']),
        commissionsUnits: unitsOrNull(j['commissionsUnits']),
        withdrawalsUnits: unitsOrNull(j['withdrawalsUnits']),
        remainingUnits: unitsOrNull(j['remainingUnits']),
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
