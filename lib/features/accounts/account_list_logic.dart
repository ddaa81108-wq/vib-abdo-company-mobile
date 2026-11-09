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

/// Customers and companies use the same debt-card design (the website's
/// `customers || companies` branch in DebtAccountsView). Layout only: each
/// section keeps its own server data, labels and rules.
bool isDebtLookSection(AccountSection section) =>
    section == AccountSection.customers || section == AccountSection.companies;

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
        id: 'pending-review',
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
/// The card must carry `zeroReview.pending == true` and `balanceUnits == 0`.
/// A missing `zeroReview` (the server before this route, or a system-linked
/// Egyptian account) shows nothing and does not cause a request. A historical
/// zero is `pending: false` with `reviewedAt: null` and also shows nothing.
/// Customers require the admin role. The other three sections require that
/// role or the section write code. `fullAccess` is not a substitute.
bool showCustomerZeroReview({
  required PermissionService permissions,
  required AccountSection section,
  required AccountCardDto card,
}) {
  if (card.systemManaged) return false;
  final link = card.systemLinkKey;
  if (link != null && link.isNotEmpty) return false;
  if (card.balanceUnits?.asInt != 0) return false;
  if (readZeroReview(card.zeroReview) != ZeroReviewRead.pending) return false;
  return permissions.canReviewZeroBalance(section.sectionKey);
}

/// `expectedFinancialVersion` is `zeroReview.financialVersion`, not the card
/// `version`. The published customer sample carries both, and they differ.
int? zeroReviewFinancialVersion(AccountCardDto card) {
  final value = card.zeroReview?['financialVersion'];
  return value is int ? value : null;
}

/// A zero card the server has settled: reviewed, historical, or system-linked.
/// A nonzero balance stays with the moving cards. A missing `zeroReview` does
/// not move the row.
bool settledZeroCard(AccountCardDto card) {
  if (card.balanceUnits?.asInt != 0) return false;
  if (card.systemManaged) return true;
  final link = card.systemLinkKey;
  if (link != null && link.isNotEmpty) return true;
  return readZeroReview(card.zeroReview) == ZeroReviewRead.closed;
}

/// Server order, then settled zero cards. The first copy of an id is kept.
List<AccountCardDto> settledZeroReviewsLast(List<AccountCardDto> cards) {
  final open = <AccountCardDto>[];
  final closed = <AccountCardDto>[];
  final seen = <String>{};
  for (final card in cards) {
    if (!seen.add(card.id)) continue;
    if (settledZeroCard(card)) {
      closed.add(card);
    } else {
      open.add(card);
    }
  }
  return [...open, ...closed];
}

/// Display order for every card section. Pending and unknown rows stay put.
List<AccountCardDto> customersWithClosedZeroReviewLast(
  List<AccountCardDto> cards,
) => settledZeroReviewsLast(cards);

/// The same card with the `zeroReview` object from a review response.
AccountCardDto cardWithServerZeroReview(
  AccountCardDto card,
  Map<String, dynamic> review,
) => AccountCardDto(
  id: card.id,
  name: card.name,
  phone: card.phone,
  balanceUnits: card.balanceUnits,
  currency: card.currency,
  activeAssigneeName: card.activeAssigneeName,
  lastActivityAt: card.lastActivityAt,
  pinned: card.pinned,
  version: card.version,
  nextSequence: card.nextSequence,
  debtAgeDays: card.debtAgeDays,
  ageStatus: card.ageStatus,
  ageStatusLabel: card.ageStatusLabel,
  zeroReview: review,
  allowedActions: card.allowedActions,
  systemManaged: card.systemManaged,
  systemLinkKey: card.systemLinkKey,
  systemKind: card.systemKind,
);

/// The website rule on 537f073 (`balanceUnits > 0 && !activeAssigneeName`),
/// plus system-managed cards, which are read-only. The server refuses the
/// whole request (409 ASSIGNMENT_REQUIRES_POSITIVE_DEBT or
/// CUSTOMER_ALREADY_ASSIGNED) when any one card breaks it, so such a card
/// gets no checkbox.
bool canSelectAccountForAssignment(AccountCardDto card) {
  if (card.systemManaged) return false;
  final assignee = card.activeAssigneeName?.trim() ?? '';
  if (assignee.isNotEmpty) return false;
  return (card.balanceUnits?.asInt ?? 0) > 0;
}

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
