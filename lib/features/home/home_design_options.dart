import 'package:flutter/material.dart';

import '../../ui/section_labels.dart';
import '../../ui/theme.dart';

import 'package:flutter_api_layer/api_layer.dart';

/// Review-only home layouts. The live dashboard stays [HomeDashboard].
class HomeDesignOption extends StatelessWidget {
  const HomeDesignOption({required this.option, super.key});

  final int option;

  static const _sections = SectionKey.values;

  @override
  Widget build(BuildContext context) {
    return switch (option) {
      1 => const _CircleGrid(),
      2 => const _HeroRows(),
      3 => const _CompactList(),
      _ => const _Bento(),
    };
  }
}

class _CircleGrid extends StatelessWidget {
  const _CircleGrid();

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
          for (final section in HomeDesignOption._sections)
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE4E8F1)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E3A8A),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        _icon(section),
                        color: const Color(0xFFF5C542),
                      ),
                    ),
                  ),
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

class _HeroRows extends StatelessWidget {
  const _HeroRows();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0B1020),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF4C1D95)],
              ),
            ),
            child: Text('الأقسام', style: cairo(20, 800, color: Colors.white)),
          ),
          const SizedBox(height: 12),
          for (final section in HomeDesignOption._sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF131A2C),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: Icon(_icon(section), color: const Color(0xFFF5C542)),
                  title: Text(
                    sectionLabel(section),
                    style: cairo(14, 700, color: Colors.white),
                  ),
                  trailing: const Icon(
                    Icons.chevron_left,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactList extends StatelessWidget {
  const _CompactList();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFFFBF0),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final section in HomeDesignOption._sections)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE7AE12)),
              ),
              child: Row(
                children: [
                  Icon(_icon(section), color: const Color(0xFF1E3A8A)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      sectionLabel(section),
                      style: cairo(14, 800, color: const Color(0xFF211600)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Bento extends StatelessWidget {
  const _Bento();

  @override
  Widget build(BuildContext context) {
    final sections = HomeDesignOption._sections;
    return ColoredBox(
      color: const Color(0xFFF1F5F9),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(flex: 2, child: _tile(sections.first, tall: true)),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _tile(sections[1])),
                  const SizedBox(width: 8),
                  Expanded(child: _tile(sections[2])),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final section in sections.skip(3)) _tile(section),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(SectionKey section, {bool tall = false}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tall ? const Color(0xFF1E3A8A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _icon(section),
              color: tall ? const Color(0xFFF5C542) : const Color(0xFF1E3A8A),
            ),
            const Spacer(),
            Text(
              sectionLabel(section),
              style: cairo(
                tall ? 16 : 11,
                800,
                color: tall ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _icon(SectionKey section) => switch (section) {
  SectionKey.customers => Icons.person_outline,
  SectionKey.collections => Icons.payments_outlined,
  SectionKey.companies => Icons.apartment_outlined,
  SectionKey.libyanDeposits => Icons.account_balance_wallet_outlined,
  SectionKey.egyptianDeposits => Icons.currency_exchange,
  SectionKey.masraweya => Icons.menu_book_outlined,
  SectionKey.purchases => Icons.shopping_bag_outlined,
  SectionKey.treasury => Icons.account_balance_outlined,
  SectionKey.reports => Icons.insights_outlined,
};
