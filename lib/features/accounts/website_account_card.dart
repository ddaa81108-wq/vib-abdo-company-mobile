import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';

import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import 'website_ledger_tone.dart';

/// Status line on a website account card (`DebtAccountsView.cardLabel`).
///
/// Deposits use the section sign labels. Customers and companies use أمانة,
/// حساب صفر, then the age bands. A system card is «مرتبط تلقائيًا». A missing
/// balance is a dash: the website reads `balanceUnits` and this does not
/// invent a status for it. A missing `debtAgeDays` follows the website
/// (`?? 0`), so a positive balance with no age is «دين جديد».
String websiteCardStatus(AccountSection section, AccountCardDto card) {
  if (card.systemManaged) return 'مرتبط تلقائيًا';
  final units = card.balanceUnits?.asInt;
  if (card.balanceUnits != null && card.balanceUnits!.isInvalid) {
    return AppStrings.dash;
  }
  if (units == null) return AppStrings.dash;
  final deposits =
      section == AccountSection.libyanDeposits ||
      section == AccountSection.egyptianDeposits;
  if (deposits) return depositCardLabel(section, units);
  if (units < 0) return 'أمانة';
  if (units == 0) return 'حساب صفر';
  final days = card.debtAgeDays ?? 0;
  if (days >= 7) return 'دين متأخر';
  if (days >= 3) return 'مرّ عليه 3 أيام';
  return 'دين جديد';
}

/// Ownership colours from `account-balance-colors.css`. Age does not change
/// the fill. Egyptian deposits swap the red and the green.
LinearGradient websiteCardGradient(AccountSection section, int? units) {
  const red = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFBD3B47), Color(0xFF781425), Color(0xFF350D16)],
    stops: [0, 0.55, 1],
  );
  const green = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF219E6D), Color(0xFF075534), Color(0xFF092B20)],
    stops: [0, 0.55, 1],
  );
  const black = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF343434), Color(0xFF080808)],
  );
  if (units == null || units == 0) return black;
  final customerOwns = section == AccountSection.libyanDeposits
      ? units > 0
      : units < 0;
  if (section == AccountSection.egyptianDeposits) {
    return customerOwns ? red : green;
  }
  return customerOwns ? green : red;
}

/// Absolute grouped digits, ar-LY style (`2.198`), then the currency.
/// No minus. Invalid and missing stay the existing labels.
String websiteCardAmount(MoneyFormatter money, AccountCardDto card) {
  final balance = card.balanceUnits;
  if (balance == null) return '—';
  if (balance.isInvalid) return MoneyValue.invalidLabel;
  final units = balance.asInt;
  if (units == null) return '—';
  final raw = units.toString();
  final digits = raw.startsWith('-') ? raw.substring(1) : raw;
  final grouped = MoneyFormatter(groupSeparator: '.')
      .formatNumber(int.parse(digits));
  return '$grouped ${card.currency.symbol}';
}

/// «آخر حركة: yyyy/mm/dd, h:mm ص/م». A missing `lastActivityAt` is a dash.
/// The API card has no separate `updatedAt`; this uses `lastActivityAt`.
String websiteCardMovement(DateTime? value) {
  if (value == null) return '${AppStrings.lastActivity}: ${AppStrings.dash}';
  final local = value.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour < 12 ? 'ص' : 'م';
  return '${AppStrings.lastActivity}: $y/$m/$d, $hour12:$minute $suffix';
}

/// The shared website card body. Height follows the text. Nothing is ellipsized.
class WebsiteAccountCardBody extends StatelessWidget {
  const WebsiteAccountCardBody({
    required this.card,
    required this.status,
    required this.amount,
    required this.movement,
    required this.ink,
    this.showAssignee = false,
    this.wide = false,
    this.pin,
    this.zero,
    super.key,
  });

  final AccountCardDto card;
  final String status;
  final String amount;
  final String movement;
  final Color ink;
  final bool showAssignee;

  /// One card across the row. Type is larger; nothing is ellipsized.
  final bool wide;
  final Widget? pin;
  final Widget? zero;

  @override
  Widget build(BuildContext context) {
    final assignee = card.activeAssigneeName?.trim() ?? '';
    final amountSize = wide ? 30.0 : 20.0;
    final amountStyle = context.textExtras.amountLarge.copyWith(
      color: Colors.white,
      fontSize: amountSize,
      fontWeight: FontWeight.w800,
    );
    final small = cairo(wide ? 13 : 10, 700, color: const Color(0xFFFFE7A8));
    return Padding(
      padding: EdgeInsets.fromLTRB(
        wide ? 14 : 8,
        wide ? 12 : 6,
        wide ? 14 : 8,
        wide ? 12 : 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ?pin,
              const Spacer(),
              ?zero,
              if (showAssignee && assignee.isNotEmpty)
                Flexible(
                  child: Container(
                    key: Key('account-assignee-${card.id}'),
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101214),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.black),
                    ),
                    child: Text(
                      '${AppStrings.withEmployee}: $assignee',
                      textDirection: TextDirection.rtl,
                      softWrap: true,
                      style: cairo(11, 800, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            status,
            key: Key('account-age-${card.id}'),
            textAlign: TextAlign.center,
            softWrap: true,
            style: cairo(wide ? 14 : 11, 800, color: const Color(0xFFFFE2E9)),
          ),
          SizedBox(height: wide ? 6 : 2),
          Text(
            card.name,
            textAlign: TextAlign.center,
            softWrap: true,
            style: cairo(wide ? 20 : 15, 800, color: ink),
          ),
          const SizedBox(height: 2),
          if (amount == MoneyValue.invalidLabel)
            MoneyText(amount, align: TextAlign.center, style: amountStyle)
          else
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: amount.contains(' ')
                        ? amount.substring(0, amount.lastIndexOf(' '))
                        : amount,
                    style: amountStyle,
                  ),
                  if (amount.contains(' '))
                    TextSpan(
                      text: amount.substring(amount.lastIndexOf(' ')),
                      style: small,
                    ),
                ],
              ),
              key: Key('account-amount-${card.id}'),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 4),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: ink.withValues(alpha: 0.25)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                movement,
                key: Key('account-movement-${card.id}'),
                textAlign: TextAlign.center,
                softWrap: true,
                style: cairo(
                  wide ? 13 : 10.5,
                  700,
                  color: ink.withValues(alpha: 0.92),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
