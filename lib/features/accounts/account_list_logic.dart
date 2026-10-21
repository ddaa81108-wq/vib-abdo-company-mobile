import 'package:flutter_api_layer/api_layer.dart';

import '../../ui/strings.dart';
import '../../ui/widgets/common.dart';

/// Token read from server `allowedActions` for مراجعة التصفير.
///
/// TODO(pending server answer): the contract notes in this repo do not name
/// this token. It is the path segment of `POST /api/customers/{id}/zero-review`.
/// The proposed permission code `debts.zero_review` is a different string and
/// is not accepted here.
const zeroReviewRecordAction = 'zero-review';

/// Which summary integer, if any, is printed on a filter chip.
enum AccountFilterCount { activeCards, pendingReview }

/// One filter chip. [id] is the `filter` query sent to `GET /api/{section}`.
/// Null is the server's default page (no `filter` parameter).
class AccountListFilter {
  const AccountListFilter({required this.id, required this.label, this.count});

  final String? id;
  final String label;
  final AccountFilterCount? count;
}

/// Filter chips for every card section, including Egyptian deposits.
///
/// `GET /api/{section}?filter` is the same contract for all four sections.
/// The app sends that value and does not filter or total the returned rows.
List<AccountListFilter> accountListFilters(AccountSection section) {
  return [
    AccountListFilter(
      id: null,
      label: section == AccountSection.libyanDeposits
          ? AppStrings.smartTab
          : AppStrings.activeTab,
      count: AccountFilterCount.activeCards,
    ),
    const AccountListFilter(id: 'today', label: AppStrings.todayTab),
    const AccountListFilter(id: 'debts', label: AppStrings.debtsTab),
    const AccountListFilter(id: 'settled', label: AppStrings.settledTab),
    const AccountListFilter(id: 'pinned', label: AppStrings.pinnedTab),
    if (section == AccountSection.customers)
      const AccountListFilter(
        id: 'pendingReview',
        label: AppStrings.zeroTab,
        count: AccountFilterCount.pendingReview,
      ),
  ];
}

int? accountFilterCount(AccountsSummaryDto summary, AccountFilterCount? kind) {
  return switch (kind) {
    AccountFilterCount.activeCards => summary.activeCards,
    AccountFilterCount.pendingReview => summary.pendingReviewCount,
    null => null,
  };
}

/// Whether مراجعة التصفير may be shown on this card.
///
/// Customers only, and never on a system-managed card.
///
/// When the server sent `allowedActions`, that list is the record decision
/// through [PermissionService.canOnRecord] and replaces the balance and
/// `zeroReview` checks. When the list is absent, the control is shown only if
/// the role may run the proposed `debts.zero_review` action, [canOnRecord]
/// allows the section write fallback, the server `balanceUnits` is exactly 0,
/// and [readZeroReview] is pending.
///
/// TODO(pending server answer): `debts.zero_review` is a proposed management
/// code (🔶). [canOnRecord] with no `allowedActions` falls back to section
/// write, so a role that has only the proposed code and cannot write the
/// section does not see the control until the server sends `allowedActions`.
/// `balanceUnits == 0` is the server balance. `ageStatus == 'zero'` alone does
/// not count, and a missing balance is not treated as zero.
bool showCustomerZeroReview({
  required PermissionService permissions,
  required AccountSection section,
  required AccountCardDto card,
}) {
  if (section != AccountSection.customers || card.systemManaged) return false;
  if (card.allowedActions != null) {
    return permissions.canOnRecord(
      action: zeroReviewRecordAction,
      allowedActions: card.allowedActions,
      section: SectionKey.customers,
    );
  }
  if (!permissions.canDo(ManagementAction.customerZeroReview)) return false;
  if (!permissions.canOnRecord(
    action: zeroReviewRecordAction,
    allowedActions: null,
    section: SectionKey.customers,
  )) {
    return false;
  }
  if (card.balanceUnits != 0) return false;
  return readZeroReview(card.zeroReview) == ZeroReviewRead.pending;
}

/// System-managed cards are read-only and cannot be chosen as a routing target.
bool canSelectAccountForAssignment(AccountCardDto card) => !card.systemManaged;

/// Selected ids that are still on screen and are allowed routing targets.
List<String> assignmentTargetIds(
  Iterable<String> selected,
  Iterable<AccountCardDto> cards,
) {
  final allowed = {
    for (final card in cards)
      if (canSelectAccountForAssignment(card)) card.id,
  };
  return [
    for (final id in selected)
      if (allowed.contains(id)) id,
  ];
}

/// Empty name is a name error. [AppStrings.integerOnly] is only for a
/// non-empty opening balance that is not a whole number of server units.
String? createAccountValidationMessage({
  required String name,
  required String opening,
}) {
  if (name.trim().isEmpty) return AppStrings.nameRequired;
  if (opening.trim().isNotEmpty && parseUnits(opening) == null) {
    return AppStrings.integerOnly;
  }
  return null;
}

/// Null when the field is empty. Otherwise the parsed server units.
int? openingBalanceOrNull(String opening) {
  if (opening.trim().isEmpty) return null;
  return parseUnits(opening);
}
