import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';

import '../../ui/section_labels.dart';
import '../../ui/theme.dart';

/// Review-only icon styles on the one home layout Ali kept (option 1).
/// The live dashboard is unchanged.
class HomeDesignOption extends StatelessWidget {
  const HomeDesignOption({required this.option, super.key});

  /// 1 duotone, 2 gradient glass, 3 outlined premium, 4 filled depth.
  final int option;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF5F7FB),
      child: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: [
          for (final section in SectionKey.values)
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE4E8F1)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _IconStyle(option: option, icon: _icon(section)),
                  const SizedBox(height: 8),
                  Text(
                    sectionLabel(section),
                    textAlign: TextAlign.center,
                    style: cairo(13, 800, color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _IconStyle extends StatelessWidget {
  const _IconStyle({required this.option, required this.icon});

  final int option;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return switch (option) {
      2 => _glass(icon),
      3 => _outlined(icon),
      4 => _depth(icon),
      _ => _duotone(icon),
    };
  }
}

Widget _duotone(IconData icon) => DecoratedBox(
  decoration: const BoxDecoration(
    color: Color(0xFF1E3A8A),
    shape: BoxShape.circle,
  ),
  child: SizedBox(
    width: 52,
    height: 52,
    child: Icon(icon, color: const Color(0xFFF5C542)),
  ),
);

Widget _glass(IconData icon) => DecoratedBox(
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xCCFFFFFF), Color(0x66DBEAFE)],
    ),
    border: Border.all(color: const Color(0xFF93C5FD), width: 1.4),
    boxShadow: const [
      BoxShadow(color: Color(0x332563EB), blurRadius: 12, offset: Offset(0, 4)),
    ],
  ),
  child: SizedBox(
    width: 52,
    height: 52,
    child: Icon(icon, color: const Color(0xFF1D4ED8)),
  ),
);

Widget _outlined(IconData icon) => DecoratedBox(
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    border: Border.all(color: const Color(0xFFE7AE12), width: 1.6),
  ),
  child: SizedBox(
    width: 52,
    height: 52,
    child: Icon(icon, color: const Color(0xFF1E3A8A)),
  ),
);

Widget _depth(IconData icon) => DecoratedBox(
  decoration: const BoxDecoration(
    shape: BoxShape.circle,
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF166534), Color(0xFF052E16)],
    ),
    boxShadow: [
      BoxShadow(color: Color(0x66052E16), blurRadius: 0, offset: Offset(0, 4)),
    ],
  ),
  child: SizedBox(
    width: 52,
    height: 52,
    child: Icon(icon, color: Colors.white),
  ),
);

IconData _icon(SectionKey section) => switch (section) {
  SectionKey.customers => Icons.person_rounded,
  SectionKey.collections => Icons.payments_rounded,
  SectionKey.companies => Icons.apartment_rounded,
  SectionKey.libyanDeposits => Icons.account_balance_wallet_rounded,
  SectionKey.egyptianDeposits => Icons.currency_exchange_rounded,
  SectionKey.masraweya => Icons.menu_book_rounded,
  SectionKey.purchases => Icons.shopping_bag_rounded,
  SectionKey.treasury => Icons.account_balance_rounded,
  SectionKey.reports => Icons.insights_rounded,
};
