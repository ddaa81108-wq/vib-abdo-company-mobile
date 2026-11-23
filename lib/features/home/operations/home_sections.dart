import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';

import '../../../ui/section_labels.dart';
import '../../../ui/strings.dart';
import '../home_design_options.dart';
import '../home_layout.dart';
import '../home_shell.dart';
import 'home_tile.dart';

class HomeSections extends StatelessWidget {
  const HomeSections({
    required this.sections,
    required this.settings,
    required this.settingsKey,
    super.key,
  });
  final List<SectionKey> sections;
  final bool settings;
  final Key settingsKey;
  @override
  Widget build(BuildContext context) {
    const preferred = [
      SectionKey.customers,
      SectionKey.companies,
      SectionKey.libyanDeposits,
      SectionKey.egyptianDeposits,
      SectionKey.purchases,
      SectionKey.treasury,
      SectionKey.collections,
      SectionKey.masraweya,
      SectionKey.reports,
    ];
    final tiles = <Widget>[
      for (final section in preferred.where(sections.contains))
        HomeTile(
          tileKey: HomeShell.sectionKey(section),
          labelKey: Key('home-tile-label-${section.key}'),
          label: sectionLabel(section),
          path: sectionPath(section),
          mark: HomeIconMark(section: section, size: 34),
          featured:
              section == SectionKey.customers || section == SectionKey.treasury,
          note: switch (section) {
            SectionKey.customers => 'الحسابات والتحصيل',
            SectionKey.companies => 'حسابات الشركات',
            SectionKey.libyanDeposits => 'بالدينار الليبي',
            SectionKey.egyptianDeposits => 'بالجنيه المصري',
            SectionKey.collections => 'المتابعة والاعتماد',
            SectionKey.reports => 'الموقف المالي والمقارنة',
            _ => '',
          },
        ),
      if (settings)
        HomeTile(
          tileKey: settingsKey,
          labelKey: const Key('home-tile-label-settings'),
          label: AppStrings.settings,
          path: '/settings',
          mark: const HomeIconMark.settings(size: 34),
        ),
    ];
    if (tiles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(AppStrings.noSections),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final columns = homeTileColumns(
          box.maxWidth,
          MediaQuery.textScalerOf(context).scale(1),
        );
        return Column(
          key: const Key('home-tile-grid'),
          children: [
            for (var offset = 0; offset < tiles.length; offset += columns)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < columns; i++) ...[
                        if (i > 0) const SizedBox(width: 9),
                        Expanded(
                          flex: columns == 2 && offset == 0 && i == 0
                              ? 3
                              : columns == 2 && offset == 0
                              ? 2
                              : 1,
                          child: offset + i < tiles.length
                              ? tiles[offset + i]
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
