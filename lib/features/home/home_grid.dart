import 'package:flutter/material.dart';

/// Equal rows that share the free height. Each cell is at least 48dp.
class HomeFillGrid extends StatelessWidget {
  const HomeFillGrid({
    required this.tiles,
    required this.columns,
    required this.rowHeight,
    required this.gap,
    super.key,
  });

  final List<Widget> tiles;
  final int columns;
  final double rowHeight;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += columns) {
      if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
      rows.add(
        SizedBox(
          height: rowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) SizedBox(width: gap),
                Expanded(
                  child: i + c < tiles.length
                      ? tiles[i + c]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      key: const Key('home-tile-grid'),
      mainAxisAlignment: MainAxisAlignment.start,
      children: rows,
    );
  }
}
