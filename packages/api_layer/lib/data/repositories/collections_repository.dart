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

  /// Approve or reject. The contract body is `decision` and an optional `note`.
  /// [meta] is not sent: these rows have no `version`, and the server does not
  /// read `requestId` or `expectedVersion` here.
  Future<MutationAck> decide(String submissionId, CollectionDecision decision,
      {String? note, required MutationMeta meta});

  /// Mark cash received. The contract has no request body.
  /// [meta] is not sent.
  Future<MutationAck> markCashReceived(String submissionId, MutationMeta meta);

  Future<MutationAck> createUnlinkedReceipt(
      {required String customerName,
      required int amountUnits,
      required MutationMeta meta});
  Future<List<Json>> linkCandidates(String q);

  /// Approve or reject an unlinked receipt. The contract body is `decision`
  /// plus optional `note`, `customerId`, `entryType`, and `newAccountKind`.
  /// [meta] is not sent.
  Future<MutationAck> decideUnlinked(String receiptId,
      {required CollectionDecision decision,
      String? customerId,
      String? entryType,
      String? note,
      String? newAccountKind,
      required MutationMeta meta});

  /// Mark an unlinked receipt's cash received. The contract has no request body.
  /// [meta] is not sent.
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

  /// Cash-received has no JSON body. A null body is omitted on the wire.
  Future<MutationAck> _postEmpty(String path) async =>
      MutationAck.fromData((await _api.post(path)).data);

  @override
  Future<CollectionsOverviewDto> overview() async {
    const path = ApiEndpoints.collections;
    final data = (await _api.get(path)).data;
    return runWithMoneyEndpoint(
      path,
      () => CollectionsOverviewDto.fromData(data),
    );
  }

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
        'decision': decision.name,
        if (note != null) 'note': note,
      });

  @override
  Future<MutationAck> markCashReceived(
          String submissionId, MutationMeta meta) =>
      _postEmpty(ApiEndpoints.collectionSubmissionCashReceived(submissionId));

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
        'decision': decision.name,
        if (customerId != null) 'customerId': customerId,
        if (entryType != null) 'entryType': entryType,
        if (note != null) 'note': note,
        if (newAccountKind != null) 'newAccountKind': newAccountKind,
      });

  @override
  Future<MutationAck> markUnlinkedCashReceived(
          String receiptId, MutationMeta meta) =>
      _postEmpty(ApiEndpoints.collectionUnlinkedCashReceived(receiptId));

  @override
  Future<MutationAck> closeDay(
          {required String batchId, required MutationMeta meta}) =>
      _post(ApiEndpoints.collectionDaysClose,
          {...meta.toBody(), 'batchId': batchId, 'confirmed': true});

  @override
  Future<PayrollDto> payroll() async {
    const path = ApiEndpoints.payroll;
    final data = (await _api.get(path)).data;
    return runWithMoneyEndpoint(path, () => PayrollDto.fromData(data));
  }

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
