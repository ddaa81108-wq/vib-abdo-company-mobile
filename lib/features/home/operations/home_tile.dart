import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/theme.dart';
import 'operations_style.dart';

class HomeTile extends StatelessWidget {
  const HomeTile({
    required this.tileKey,
    required this.labelKey,
    required this.mark,
    required this.label,
    required this.path,
    this.featured = false,
    this.note = '',
    super.key,
  });
  final Key tileKey, labelKey;
  final Widget mark;
  final String label, path, note;
  final bool featured;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: featured ? OperationsStyle.navy : context.look.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: featured ? OperationsStyle.gold : context.look.cardBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: tileKey,
        onTap: () => context.go(path),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 102),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: AlignmentDirectional.centerEnd, child: mark),
                const SizedBox(height: 7),
                Text(
                  label,
                  key: labelKey,
                  style: cairo(
                    14,
                    700,
                    color: featured ? Colors.white : context.look.ink,
                  ),
                ),
                if (note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      note,
                      style: cairo(
                        10,
                        500,
                        color: featured
                            ? const Color(0xFFD0DAE4)
                            : context.look.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
