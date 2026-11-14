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

/// Cream fill Ali picked from the 080 sheet («كريمي»).
const websiteCardLightFill = Color(0xFFFFF8EE);

/// Light-mode ink. دين is red, أمانة is green, zero is brown. The same
/// sign rules as [websiteCardGradient], including the Egyptian swap.
Color websiteCardNatureInk(AccountSection section, int? units) {
  const debt = Color(0xFFB42318);
  const trust = Color(0xFF0E7A45);
  const zero = Color(0xFF6B4423);
  if (units == null || units == 0) return zero;
  final customerOwns = section == AccountSection.libyanDeposits
      ? units > 0
      : units < 0;
  final amanah = section == AccountSection.egyptianDeposits
      ? !customerOwns
      : customerOwns;
  return amanah ? trust : debt;
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

/// «آخر حركة: yyyy/mm/dd, h:mm ص/م». A missing instant is a dash.
/// [AccountCardDto.lastActivityAt] is the list field the website uses:
/// `updatedAt`, then `createdAt`, unless the server sent a dedicated time.
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
    final hasAssignee = showAssignee && assignee.isNotEmpty;
    final onDark = ink == Colors.white;
    final statusColor = onDark ? const Color(0xFFFFE2E9) : ink;
    final amountColor = onDark ? Colors.white : ink;
    final amountSize = wide ? 28.0 : 20.0;
    final amountStyle = context.textExtras.amountLarge.copyWith(
      color: amountColor,
      fontSize: amountSize,
      fontWeight: FontWeight.w800,
    );
    final small = cairo(
      wide ? 13 : 10,
      700,
      color: onDark ? const Color(0xFFFFE7A8) : ink,
    );
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasAssignee)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              key: Key('account-assignee-${card.id}'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: onDark
                    ? const Color(0xFF101214)
                    : ink.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: onDark ? Colors.black : ink.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                '${AppStrings.withEmployee}: $assignee',
                textDirection: TextDirection.rtl,
                softWrap: true,
                style: cairo(12, 800, color: onDark ? Colors.white : ink),
              ),
            ),
          ),
        Text(
          status,
          key: Key('account-age-${card.id}'),
          textAlign: TextAlign.center,
          softWrap: true,
          style: cairo(wide ? 14 : 11, 800, color: statusColor),
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
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: ink.withValues(alpha: 0.28))),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              movement,
              key: Key('account-movement-${card.id}'),
              textAlign: TextAlign.center,
              softWrap: true,
              style: cairo(
                wide ? 13 : 11,
                700,
                color: ink.withValues(alpha: 0.92),
              ),
            ),
          ),
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        wide ? 14 : 8,
        wide ? 8 : 6,
        wide ? 14 : 8,
        wide ? 10 : 8,
      ),
      child: IconButtonTheme(
        data: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: ink,
            minimumSize: const Size(28, 28),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: pin != null ? 30 : 0,
                end: zero != null ? 30 : 0,
              ),
              child: body,
            ),
            if (pin != null)
              PositionedDirectional(top: 0, start: 0, child: pin!),
            if (zero != null)
              PositionedDirectional(top: 0, end: 0, child: zero!),
          ],
        ),
      ),
    );
  }
}
