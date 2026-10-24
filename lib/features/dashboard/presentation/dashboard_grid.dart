import 'package:flutter/material.dart';

/// Lays out children in rows on wide screens: each child spans 1 or more of
/// [columns] and rows are packed greedily in order. Children are top-aligned
/// (charts cannot report intrinsic heights). With one column it is a plain
/// vertical list.
class DashboardGrid extends StatelessWidget {
  const DashboardGrid({
    required this.children,
    required this.spans,
    required this.columns,
    super.key,
    this.gap = 20,
  }) : assert(children.length == spans.length, 'one span per child');

  final List<Widget> children;
  final List<int> spans;
  final int columns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (columns <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      );
    }
    final rows = <List<int>>[];
    var current = <int>[];
    var used = 0;
    for (var i = 0; i < children.length; i++) {
      final span = spans[i].clamp(1, columns);
      if (used + span > columns && current.isNotEmpty) {
        rows.add(current);
        current = [];
        used = 0;
      }
      current.add(i);
      used += span;
    }
    if (current.isNotEmpty) rows.add(current);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) SizedBox(height: gap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var k = 0; k < rows[r].length; k++) ...[
                if (k > 0) SizedBox(width: gap),
                Expanded(
                  flex: spans[rows[r][k]].clamp(1, columns),
                  child: children[rows[r][k]],
                ),
              ],
              // Keep proportions when a row is not full.
              if (_rowSpan(rows[r]) < columns) ...[
                SizedBox(width: gap),
                Expanded(
                  flex: columns - _rowSpan(rows[r]),
                  child: const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  int _rowSpan(List<int> row) =>
      row.fold(0, (a, i) => a + spans[i].clamp(1, columns));
}
