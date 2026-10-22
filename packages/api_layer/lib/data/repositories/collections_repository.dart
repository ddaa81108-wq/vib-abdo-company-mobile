import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/idempotency.dart';
import '../models/collection_models.dart';
import '../models/common.dart';

/// Collections (= "استلامات الديون" + "الاعتماد والرفض" in the contract). LYD.
/// Admin-only per the existing system: assign, decide, cash-received, close day, payroll entries/salary.
abstract interface class CollectionsRepository {
  Future<CollectionsOverviewDto> overview();
  Future<List<Json>> assignees();
  Future<MutationAck> assign(
      {required List<String> customerIds,
      required String assigneeUserId,
      required String section,
      required MutationMeta meta});

  /// Employee: full / partial receipt on an assigned card.
  Future<MutationAck> submit(String assignmentId,
      {required String mode, int? amountUnits, required MutationMeta meta});

  /// [meta] MUST carry `expectedVersion` = the submission's `version`, per API contract.
  Future<MutationAck> decide(String submissionId, CollectionDecision decision,
      {String? note, required MutationMeta meta});

  /// [meta] MUST carry `expectedVersion`, per API contract.
  Future<MutationAck> markCashReceived(String submissionId, MutationMeta meta);

  Future<MutationAck> createUnlinkedReceipt(
      {required String customerName,
      required int amountUnits,
      required MutationMeta meta});
  Future<List<Json>> linkCandidates(String q);

  /// [meta] MUST carry `expectedVersion`, per API contract.
  Future<MutationAck> decideUnlinked(String receiptId,
      {required CollectionDecision decision,
      String? customerId,
      String? entryType,
      String? note,
      String? newAccountKind,
      required MutationMeta meta});

  /// [meta] MUST carry `expectedVersion`, per API contract.
  Future<MutationAck> markUnlinkedCashReceived(
      String receiptId, MutationMeta meta);
  Future<MutationAck> closeDay(
      {required String batchId, required MutationMeta meta});

  Future<PayrollDto> payroll();
  Future<MutationAck> addPayrollEntry(
      {required String employeeUserId,
      required String kind,
      required int amountUnits,
      required String reason,
      required MutationMeta meta});
  Future<MutationAck> setBaseSalary(
      String employeeUserId, int baseSalaryUnits, MutationMeta meta);
  Future<MutationAck> confirmPayrollEntry(String entryId, MutationMeta meta);
}

class RemoteCollectionsRepository implements CollectionsRepository {
  RemoteCollectionsRepository(this._api);
  final ApiClient _api;

  Future<MutationAck> _post(String path, Json body) async =>
      MutationAck.fromData((await _api.post(path, body: body)).data);

  /// Approval / cash-receipt endpoints require optimistic locking, per API contract.
  /// Refuse to send without a version so two concurrent decisions cannot both pass silently.
  static Json _versioned(MutationMeta meta) {
    if (meta.expectedVersion == null) {
      throw ArgumentError(
          'expectedVersion is required for approval / cash-receipt endpoints, per API contract');
    }
    return meta.toBody();
  }

  @override
  Future<CollectionsOverviewDto> overview() async =>
      CollectionsOverviewDto.fromData(
          (await _api.get(ApiEndpoints.collections)).data);

  @override
  Future<List<Json>> assignees() async => Paged.fromData(
      (await _api.get(ApiEndpoints.collectionAssignees)).data, (j) => j).items;

  @override
  Future<MutationAck> assign(
          {required List<String> customerIds,
          required String assigneeUserId,
          required String section,
          required MutationMeta meta}) =>
      _post(ApiEndpoints.collectionAssignments, {
        ...meta.toBody(),
        'customerIds': customerIds,
        'assigneeUserId': assigneeUserId,
        'section': section
      });

  @override
  Future<MutationAck> submit(String assignmentId,
          {required String mode,
          int? amountUnits,
          required MutationMeta meta}) =>
      _post(ApiEndpoints.collectionSubmissions(assignmentId), {
        ...meta.toBody(),
        'mode': mode,
        if (amountUnits != null) 'amountUnits': amountUnits
      });

  @override
  Future<MutationAck> decide(String submissionId, CollectionDecision decision,
          {String? note, required MutationMeta meta}) =>
      _post(ApiEndpoints.collectionSubmissionDecision(submissionId), {
        ..._versioned(meta),
        'decision': decision.name,
        if (note != null) 'note': note
      });

  @override
  Future<MutationAck> markCashReceived(
          String submissionId, MutationMeta meta) =>
      _post(ApiEndpoints.collectionSubmissionCashReceived(submissionId),
          _versioned(meta));

  @override
  Future<MutationAck> createUnlinkedReceipt(
          {required String customerName,
          required int amountUnits,
          required MutationMeta meta}) =>
      _post(ApiEndpoints.collectionUnlinkedReceipts, {
        ...meta.toBody(),
        'customerName': customerName,
        'amountUnits': amountUnits
      });

  @override
  Future<List<Json>> linkCandidates(String q) async => Paged.fromData(
      (await _api.get(ApiEndpoints.collectionLinkCandidates, query: {'q': q}))
          .data,
      (j) => j).items;

  @override
  Future<MutationAck> decideUnlinked(String receiptId,
          {required CollectionDecision decision,
          String? customerId,
          String? entryType,
          String? note,
          String? newAccountKind,
          required MutationMeta meta}) =>
      _post(ApiEndpoints.collectionUnlinkedDecision(receiptId), {
        ..._versioned(meta),
        'decision': decision.name,
        if (customerId != null) 'customerId': customerId,
        if (entryType != null) 'entryType': entryType,
        if (note != null) 'note': note,
        if (newAccountKind != null) 'newAccountKind': newAccountKind,
      });

  @override
  Future<MutationAck> markUnlinkedCashReceived(
          String receiptId, MutationMeta meta) =>
      _post(ApiEndpoints.collectionUnlinkedCashReceived(receiptId),
          _versioned(meta));

  @override
  Future<MutationAck> closeDay(
          {required String batchId, required MutationMeta meta}) =>
      _post(ApiEndpoints.collectionDaysClose,
          {...meta.toBody(), 'batchId': batchId, 'confirmed': true});

  @override
  Future<PayrollDto> payroll() async =>
      PayrollDto.fromData((await _api.get(ApiEndpoints.payroll)).data);

  @override
  Future<MutationAck> addPayrollEntry(
          {required String employeeUserId,
          required String kind,
          required int amountUnits,
          required String reason,
          required MutationMeta meta}) =>
      _post(ApiEndpoints.payrollEntries, {
        ...meta.toBody(),
        'employeeUserId': employeeUserId,
        'kind': kind,
        'amountUnits': amountUnits,
        'reason': reason
      });

  @override
  Future<MutationAck> setBaseSalary(String employeeUserId, int baseSalaryUnits,
          MutationMeta meta) async =>
      MutationAck.fromData((await _api.put(
              ApiEndpoints.payrollSalary(employeeUserId),
              body: {...meta.toBody(), 'baseSalaryUnits': baseSalaryUnits}))
          .data);

  @override
  Future<MutationAck> confirmPayrollEntry(String entryId, MutationMeta meta) =>
      _post(ApiEndpoints.payrollEntryConfirm(entryId), meta.toBody());
}
