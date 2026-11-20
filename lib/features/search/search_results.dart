import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';

import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';

class SearchResults extends StatelessWidget {
  const SearchResults({
    super.key,
    required this.busy,
    required this.failed,
    required this.items,
    required this.onLedger,
    required this.onCard,
  });

  final bool busy;
  final bool failed;
  final List<GlobalAccountHit> items;
  final ValueChanged<GlobalAccountHit> onLedger;
  final ValueChanged<GlobalAccountHit> onCard;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('search-results'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (busy)
          const Padding(
            padding: EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: Text(AppStrings.searchBusy, key: Key('search-loading')),
          ),
        if (!busy && !failed && items.isEmpty)
          const Text(AppStrings.searchNoAccounts, key: Key('search-empty')),
        for (final item in items)
          _Hit(item: item, onLedger: onLedger, onCard: onCard),
      ],
    );
  }
}

class _Hit extends StatelessWidget {
  const _Hit({
    required this.item,
    required this.onLedger,
    required this.onCard,
  });

  final GlobalAccountHit item;
  final ValueChanged<GlobalAccountHit> onLedger;
  final ValueChanged<GlobalAccountHit> onCard;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final debt =
        item.section == AccountSection.customers ||
        item.section == AccountSection.companies;
    final assigned =
        item.activeAssignmentId != null || item.activeAssigneeName != null;
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.name, style: cairo(15, 800, color: look.ink)),
        Text(
          searchSectionTitle(item.section),
          style: cairo(12, 600, color: look.muted),
        ),
        if (debt)
          Text(
            assigned
                ? 'موجّه إلى: ${item.activeAssigneeName ?? AppStrings.searchAssigneeFallback}'
                : AppStrings.searchUnassigned,
            style: cairo(12, 600, color: look.muted),
          ),
      ],
    );
    final balance = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            _amount(item),
            textDirection: TextDirection.ltr,
            style: cairo(16, 800, color: look.ink),
          ),
        ),
        Text(item.currency.symbol, style: cairo(11, 700, color: look.muted)),
      ],
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: look.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: look.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              key: Key('search-hit-${item.section.path}-${item.id}'),
              onTap: () => onLedger(item),
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final scale = MediaQuery.textScalerOf(context).scale(1);
                    if (constraints.maxWidth / scale < 300) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          identity,
                          const SizedBox(height: AppSpacing.sm),
                          balance,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: identity),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: balance),
                      ],
                    );
                  },
                ),
              ),
            ),
            if (debt)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: Key('search-card-${item.section.path}-${item.id}'),
                  onPressed: () => onCard(item),
                  child: const Text(AppStrings.searchShowCard),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String searchSectionTitle(AccountSection section) => switch (section) {
  AccountSection.customers => 'قسم ديون العملاء',
  AccountSection.companies => 'قسم ديون الشركات',
  AccountSection.libyanDeposits => 'أمانات ليبية',
  AccountSection.egyptianDeposits => 'أمانات مصرية',
};

String _amount(GlobalAccountHit hit) {
  final balance = hit.balanceUnits;
  if (balance == null) return AppStrings.dash;
  if (balance.isInvalid) return MoneyValue.invalidLabel;
  final units = balance.asInt;
  if (units == null) return AppStrings.dash;
  final raw = units.toString();
  final digits = raw.startsWith('-') ? raw.substring(1) : raw;
  return const MoneyFormatter().formatNumber(int.parse(digits));
}
