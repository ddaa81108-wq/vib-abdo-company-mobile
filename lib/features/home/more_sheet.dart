import 'package:flutter/material.dart';

import '../../ui/strings.dart';
import '../../ui/theme.dart';
import 'home_ceramic_style.dart';
import 'home_nav_item.dart';
import 'more_sheet_row.dart';

/// Presentation of the shell's already-permitted destinations, in the same order.
class MoreSheet extends StatelessWidget {
  const MoreSheet({
    required this.sections,
    required this.accountItems,
    required this.location,
    required this.onSelect,
    super.key,
  });
  final List<NavItem> sections, accountItems;
  final String location;
  final ValueChanged<NavItem> onSelect;

  @override
  Widget build(BuildContext context) {
    final count = sections.length + accountItems.length;
    final roomy =
        MediaQuery.sizeOf(context).height < 550 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final initial = roomy ? .94 : (.25 + count * .075).clamp(.38, .88);
    final ink = HomeCeramicStyle.ink(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: initial,
      minChildSize: .28,
      maxChildSize: .96,
      builder: (context, controller) => ColoredBox(
        color: HomeCeramicStyle.background(context),
        child: ListView(
          key: const Key('more-sheet'),
          controller: controller,
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            MediaQuery.paddingOf(context).bottom + 16,
          ),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: HomeCeramicStyle.edge,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.more, style: cairo(22, 700, color: ink)),
                      const SizedBox(height: 3),
                      Text(
                        'انتقل إلى القسم المطلوب',
                        style: cairo(12, 500, color: ink.withValues(alpha: .8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('more-close'),
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: ink),
                ),
              ],
            ),
            if (sections.isNotEmpty) ...[
              _groupTitle(context, 'باقي الأقسام'),
              for (final item in sections) _row(item),
            ],
            if (accountItems.isNotEmpty) ...[
              _groupTitle(context, 'الحساب والإعدادات'),
              for (final item in accountItems) _row(item),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(NavItem item) => MoreSheetRow(
    item: item,
    selected: location == item.path || location.startsWith('${item.path}/'),
    onTap: () => onSelect(item),
  );

  Widget _groupTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(top: 17, bottom: 10),
    child: Row(
      children: [
        Text(
          title,
          style: cairo(12, 700, color: HomeCeramicStyle.ink(context)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: HomeCeramicStyle.edge.withValues(alpha: .4),
          ),
        ),
      ],
    ),
  );
}
