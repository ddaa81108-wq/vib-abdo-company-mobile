import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import 'home_ceramic_style.dart';

class HomeTile extends StatelessWidget {
  const HomeTile({
    required this.tileKey,
    required this.labelKey,
    required this.mark,
    required this.label,
    required this.path,
    this.fontSize = 15,
    this.gap = AppSpacing.sm,
    super.key,
  });
  final Key tileKey, labelKey;
  final Widget mark;
  final String label, path;
  final double fontSize, gap;

  @override
  Widget build(BuildContext context) {
    final dark = HomeCeramicStyle.dark(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: HomeCeramicStyle.edge, width: 1.2),
          color: HomeCeramicStyle.bar(context),
          boxShadow: [
            BoxShadow(
              color: (dark ? Colors.black : const Color(0xFF24334A)).withValues(
                alpha: .10,
              ),
              offset: const Offset(0, 2),
              blurRadius: 5,
            ),
          ],
        ),
        padding: const EdgeInsets.all(2),
        child: Material(
          borderRadius: BorderRadius.circular(17),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: HomeCeramicStyle.surfaces(context),
              ),
              border: Border.all(
                color: dark ? const Color(0xFF3C4959) : Colors.white,
              ),
            ),
            child: InkWell(
              key: tileKey,
              onTap: () => context.go(path),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        mark,
                        SizedBox(height: gap),
                        Text(
                          label,
                          key: labelKey,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: cairo(
                            fontSize,
                            700,
                            color: HomeCeramicStyle.ink(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
