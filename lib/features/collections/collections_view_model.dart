import 'package:flutter_api_layer/api_layer.dart';

import 'collection_card_tone.dart';

/// Phone-side view of the 537f073 collections overview.
///
/// Every figure here is read from `GET /api/collections` or derived from
/// its lists on the phone; nothing is invented. The derivation of each
/// number is written beside it and in the deliverable's table.

/// The admin's filter card: batch (`openBatches`), employee, free text.
class CollectionsFilter {
  const CollectionsFilter({this.batchId, this.employee, this.query = ''});

  /// An id from `openBatches`. Null: no open batch, so nothing is narrowed.
  final String? batchId;

  /// An employee's display name (assigneeName / collectorName on 537).
  /// Null: كل الموظفين.
  final String? employee;
  final String query;

  bool inBatch(String? id) => batchId == null || id == null || id == batchId;

  bool byEmployee(String? name) => employee == null || name == employee;

  /// Customer, employee or phone contains [query] (trimmed, any case).
  bool matches(Iterable<String?> fields) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return fields.any((f) => f != null && f.toLowerCase().contains(q));
  }
}

int units(MoneyValue? value) => value?.asInt ?? 0;

/// The four admin summary cards for the chosen batch and employee.
/// Search and tab do not change them.
class CollectionsSummary {
  const CollectionsSummary({
    required this.approvedUnits,
    required this.cashReceivedUnits,
    required this.remainingUnits,
    required this.pendingCount,
    required this.unlinkedPendingCount,
  });

  /// Σ amountUnits of submissions and standalone receipts with status
  /// `approved` (537 `metrics.collectedUnits`, narrowed to the filter).
  final int approvedUnits;

  /// The approved ones with `cashReceivedAt` set.
  final int cashReceivedUnits;

  /// The approved ones without `cashReceivedAt`
  /// (537 `metrics.cashOutstandingUnits`, narrowed). = approved − received.
  final int remainingUnits;

  /// Count of `pending` submissions plus `pending` standalone receipts.
  final int pendingCount;

  /// The standalone (unlinked) part of [pendingCount].
  final int unlinkedPendingCount;

  /// [separatePrevious]: leave out `outstandingCancelledSubmissions`
  /// (cash of cancelled cards), which has its own tab («نقدية سابقة»).
  static CollectionsSummary of(
    CollectionsOverviewDto data,
    CollectionsFilter filter, {
    bool separatePrevious = true,
  }) {
    final previous = separatePrevious
        ? {for (final o in data.outstandingCash) o.id}
        : const <String>{};
    var approved = 0, received = 0, pending = 0, unlinkedPending = 0;
    for (final s in data.submissions) {
      if (!filter.inBatch(s.batchId) || !filter.byEmployee(s.submittedByName)) {
        continue;
      }
      if (previous.contains(s.id)) continue;
      if (s.status == 'approved') {
        approved += units(s.amountUnits);
        if (s.cashReceivedAt != null) received += units(s.amountUnits);
      } else if (s.status == 'pending') {
        pending++;
      }
    }
    for (final r in data.unlinkedReceipts) {
      if (!filter.inBatch(r.batchId) || !filter.byEmployee(r.collectorName)) {
        continue;
      }
      if (r.status == 'approved') {
        approved += units(r.amountUnits);
        if (r.cashReceivedAt != null) received += units(r.amountUnits);
      } else if (r.status == 'pending') {
        pending++;
        unlinkedPending++;
      }
    }
    return CollectionsSummary(
      approvedUnits: approved,
      cashReceivedUnits: received,
      remainingUnits: approved - received,
      pendingCount: pending,
      unlinkedPendingCount: unlinkedPending,
    );
  }
}

/// What still blocks closing [batchId] (the whole batch, every employee),
/// as 537's close check counts it (COLLECTION_DAY_NOT_SETTLED).
class BatchSettlement {
  const BatchSettlement({required this.reviewCount, required this.cashUnits});

  /// Pending submissions + pending standalone receipts in the batch.
  final int reviewCount;

  /// Σ approved, cash not yet received, in the batch.
  final int cashUnits;

  static BatchSettlement of(CollectionsOverviewDto data, String? batchId) {
    // 537 counts every row of the batch, cancelled cards included.
    final all = CollectionsSummary.of(
      data,
      CollectionsFilter(batchId: batchId),
      separatePrevious: false,
    );
    return BatchSettlement(
      reviewCount: all.pendingCount,
      cashUnits: all.remainingUnits,
    );
  }
}

/// Employee names for the filter: assignees, collectors and
/// `employeeTotals`, each once, in first-seen order.
List<String> employeeOptions(CollectionsOverviewDto data) {
  final names = <String>{};
  void add(String? name) {
    final n = name?.trim() ?? '';
    if (n.isNotEmpty) names.add(n);
  }

  for (final e in data.employeeTotals) {
    add(e.employeeName);
  }
  for (final a in data.assignments) {
    add(a.assigneeName);
  }
  for (final s in data.submissions) {
    add(s.submittedByName);
  }
  for (final r in data.unlinkedReceipts) {
    add(r.collectorName);
  }
  return names.toList(growable: false);
}

enum AdminTab { all, review, cash, previous }

enum EmployeeTab { cards, receipts, cash }

/// The rows of one admin tab, after batch, employee and search.
class AdminTabRows {
  const AdminTabRows({
    this.assignments = const [],
    this.unlinked = const [],
    this.outstanding = const [],
  });

  final List<CollectionAssignmentDto> assignments;
  final List<UnlinkedReceiptDto> unlinked;
  final List<OutstandingCashDto> outstanding;

  int get count => assignments.length + unlinked.length + outstanding.length;
  bool get isEmpty => count == 0;
}

/// كل الكروت: every card and standalone receipt.
/// بانتظار المراجعة: cards with a `pending` receipt, pending standalone.
/// بانتظار تسليم النقدية: cards with an approved receipt whose cash is not
/// received, and such standalone receipts.
/// نقدية سابقة: `outstandingCancelledSubmissions` (cash of cancelled cards).
AdminTabRows adminTabRows(
  CollectionsOverviewDto data,
  CollectionsFilter filter,
  AdminTab tab,
) {
  bool card(CollectionAssignmentDto a) =>
      filter.inBatch(a.batchId) &&
      filter.byEmployee(a.assigneeName) &&
      filter.matches([a.customerName, a.assigneeName, a.phone]);
  bool receipt(UnlinkedReceiptDto r) =>
      filter.inBatch(r.batchId) &&
      filter.byEmployee(r.collectorName) &&
      filter.matches([r.customerName, r.collectorName]);
  List<CollectionSubmissionDto> history(CollectionAssignmentDto a) =>
      collectionCardHistory(data, a.id);

  switch (tab) {
    case AdminTab.all:
      return AdminTabRows(
        assignments: data.assignments.where(card).toList(),
        unlinked: data.unlinkedReceipts.where(receipt).toList(),
      );
    case AdminTab.review:
      return AdminTabRows(
        assignments: data.assignments
            .where(
              (a) =>
                  card(a) &&
                  (a.hasPending ||
                      history(a).any((s) => s.status == 'pending')),
            )
            .toList(),
        unlinked: data.unlinkedReceipts
            .where((r) => receipt(r) && r.status == 'pending')
            .toList(),
      );
    case AdminTab.cash:
      return AdminTabRows(
        assignments: data.assignments
            .where((a) => card(a) && history(a).any((s) => s.awaitingCash))
            .toList(),
        unlinked: data.unlinkedReceipts
            .where((r) => receipt(r) && r.awaitingCash)
            .toList(),
      );
    case AdminTab.previous:
      return AdminTabRows(
        outstanding: data.outstandingCash
            .where(
              (o) =>
                  filter.byEmployee(o.collectorName) &&
                  filter.matches([o.customerName, o.collectorName]),
            )
            .toList(),
      );
  }
}

/// The rows of one employee tab, after search (name or phone).
class EmployeeTabRows {
  const EmployeeTabRows({
    this.assignments = const [],
    this.submissions = const [],
    this.unlinked = const [],
    this.outstanding = const [],
  });

  final List<CollectionAssignmentDto> assignments;
  final List<CollectionSubmissionDto> submissions;
  final List<UnlinkedReceiptDto> unlinked;
  final List<OutstandingCashDto> outstanding;

  int get count =>
      assignments.length +
      submissions.length +
      unlinked.length +
      outstanding.length;
  bool get isEmpty => count == 0;
}

/// كروتي: own assigned cards. تحصيلاتي: own receipts (537 lists only the
/// caller's) and own standalone receipts. النقدية: own approved receipts
/// whose cash is not received yet, plus earlier cash of cancelled cards.
EmployeeTabRows employeeTabRows(
  CollectionsOverviewDto data,
  String query,
  EmployeeTab tab,
) {
  final filter = CollectionsFilter(query: query);
  switch (tab) {
    case EmployeeTab.cards:
      return EmployeeTabRows(
        assignments: data.assignments
            .where((a) => filter.matches([a.customerName, a.phone]))
            .toList(),
      );
    case EmployeeTab.receipts:
      return EmployeeTabRows(
        submissions: data.submissions
            .where((s) => filter.matches([s.customerName, s.phone]))
            .toList(),
        unlinked: data.unlinkedReceipts
            .where((r) => filter.matches([r.customerName]))
            .toList(),
      );
    case EmployeeTab.cash:
      // A cancelled card's receipt is listed once, as earlier cash.
      final previous = {for (final o in data.outstandingCash) o.id};
      return EmployeeTabRows(
        submissions: data.submissions
            .where(
              (s) =>
                  s.awaitingCash &&
                  !previous.contains(s.id) &&
                  filter.matches([s.customerName, s.phone]),
            )
            .toList(),
        unlinked: data.unlinkedReceipts
            .where((r) => r.awaitingCash && filter.matches([r.customerName]))
            .toList(),
        outstanding: data.outstandingCash
            .where((o) => filter.matches([o.customerName]))
            .toList(),
      );
  }
}
