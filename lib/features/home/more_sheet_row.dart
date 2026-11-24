import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../../ui/widgets/soft_tile.dart';
import 'home_ceramic_style.dart';
import 'home_nav_item.dart';

class MoreSheetRow extends StatelessWidget {
  const MoreSheetRow({
    required this.item,
    required this.selected,
    required this.onTap,
    super.key,
  });
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: HomeCeramicStyle.edge.withValues(alpha: selected ? 1 : .6),
          width: selected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: HomeCeramicStyle.surfaces(context),
            ),
          ),
          child: InkWell(
            key: Key('more-${item.id}'),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF14213D),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0xFFE7AE12)),
                    ),
                    child: Icon(
                      item.icon,
                      size: 22,
                      color: const Color(0xFFF6E7A8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: cairo(
                        14,
                        700,
                        color: HomeCeramicStyle.ink(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconTheme(
                    data: IconThemeData(
                      size: 22,
                      color: HomeCeramicStyle.ink(context),
                    ),
                    child: forwardChevron(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
