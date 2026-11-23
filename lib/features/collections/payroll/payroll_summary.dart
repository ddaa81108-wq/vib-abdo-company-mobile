import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';

import '../../../ui/theme.dart';
import '../../../ui/widgets/common.dart';
import '../collections_strings.dart';

/// Presentation only: amounts are supplied by the server.
class PayrollSummary extends StatelessWidget {
  const PayrollSummary({
    required this.employee,
    required this.money,
    super.key,
  });
  final PayrollEmployeeDto employee;
  final MoneyFormatter money;
  static const gold = Color(0xFFCCAC65);
  static const navy = Color(0xFF142438);

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final rows = <(String, MoneyValue?, Color)>[
      (CollectionsText.base, employee.baseSalaryUnits, look.ink),
      (
        employee.showOpeningCarry
            ? CollectionsText.carryOld
            : CollectionsText.carryPrevious,
        employee.openingCarryUnits,
        look.ink,
      ),
      (CollectionsText.commissions, employee.commissionsUnits, look.success),
      (CollectionsText.withdrawals, employee.withdrawalsUnits, look.danger),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: navy,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: gold),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.badge_outlined,
                      color: gold,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      employee.name,
                      style: cairo(17, 700, color: const Color(0xFFF7F4EC)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                CollectionsText.remaining,
                style: cairo(12, 500, color: const Color(0xFFD2D8DF)),
              ),
              const SizedBox(height: 3),
              MoneyText(
                money.formatOrDash(employee.remainingUnits, Currency.lyd),
                style: cairo(
                  29,
                  700,
                  color: (employee.remainingUnits?.asInt ?? 0) < 0
                      ? const Color(0xFFFFADA5)
                      : const Color(0xFFF2D99C),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: look.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: look.cardBorder),
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final columns =
                  box.maxWidth >= 270 &&
                      MediaQuery.textScalerOf(context).scale(1) < 1.4
                  ? 2
                  : 1;
              return Wrap(
                children: [
                  for (var i = 0; i < rows.length; i++)
                    SizedBox(
                      width: box.maxWidth / columns,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: BorderDirectional(
                            bottom: i < rows.length - columns
                                ? BorderSide(color: look.cardBorder)
                                : BorderSide.none,
                            end: columns == 2 && i.isEven
                                ? BorderSide(color: look.cardBorder)
                                : BorderSide.none,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rows[i].$1,
                              style: cairo(11, 500, color: look.muted),
                            ),
                            const SizedBox(height: 5),
                            MoneyText(
                              money.formatOrDash(rows[i].$2, Currency.lyd),
                              style: cairo(17, 700, color: rows[i].$3),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
