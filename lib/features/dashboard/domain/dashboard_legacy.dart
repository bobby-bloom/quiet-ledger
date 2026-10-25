import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:personal_finance/core/board/board_layout.dart';
import 'package:personal_finance/features/dashboard/domain/dashboard_view.dart';

// The dashboard's 0.1 layouts (docs/DASHBOARD.md, Storage): a flat list per
// view, read while no v2 row exists. They are never written.

/// The 0.1 layouts' defaults (type, wide): a saved list equal to one of
/// them goes to Auto, its options kept.
const _legacyDefaults = <DashboardView, List<(String, bool)>>{
  DashboardView.compact: [
    ('netWorth', false),
    ('monthSummary', false),
    ('budgets', false),
    ('upcomingBills', false),
    ('forecast', false),
    ('recentTransactions', false),
  ],
  DashboardView.expanded: [
    ('netWorth', true),
    ('monthSummary', false),
    ('budgets', false),
    ('upcomingBills', false),
    ('forecast', false),
    ('recentTransactions', true),
    ('goals', false),
    ('topCategories', false),
    ('accounts', false),
  ],
};

/// The 0.1 flat list `[{type, size, options}]` in [json] as a v2 state for
/// [view]. A wide list is packed the way the old grid laid it out at three
/// columns, so people keep what they saw on a large window; listed widgets
/// show with their options, the others are hidden. A list equal to the old
/// default goes to Auto.
DashboardViewState migrateLegacyLayout(DashboardView view, String json) {
  final List<(String, bool, Map<String, Object?>)> list;
  try {
    final seen = <String>{};
    list = [
      for (final e in jsonDecode(json) as List)
        if (e is Map &&
            dashboardBoard.cards.contains(e['type']) &&
            seen.add(e['type'] as String))
          (
            e['type'] as String,
            e['size'] == 'wide',
            ((e['options'] as Map?) ?? const {}).cast<String, Object?>(),
          ),
    ];
  } on Object {
    return emptyDashboard;
  }

  final items = {
    for (final t in DashboardWidgetType.values)
      t.name: const BoardEntry(visible: false),
    for (final (type, _, options) in list) type: BoardEntry(options: options),
  };
  final legacyDefault = _legacyDefaults[view]!;
  final isDefault =
      list.length == legacyDefault.length &&
      list.indexed.every(
        (e) =>
            e.$2.$1 == legacyDefault[e.$1].$1 &&
            e.$2.$2 == legacyDefault[e.$1].$2,
      );
  if (isDefault) return BoardState(dashboardBoard, items: items);

  final ids = [for (final (type, _, _) in list) type];
  return switch (view) {
    DashboardView.compact => BoardState(
      dashboardBoard,
      mode: LayoutMode.custom,
      items: items,
      order: [
        ...ids,
        for (final id in dashboardBoard.defaultOrder)
          if (!ids.contains(id)) id,
      ],
    ),
    DashboardView.expanded =>
      list.isEmpty
          ? BoardState(dashboardBoard, items: items)
          : BoardState(
              dashboardBoard,
              mode: LayoutMode.custom,
              items: items,
              rows: packAtThreeColumns([
                for (final (t, wide, _) in list) (t, wide),
              ]),
            ),
  };
}

/// [cards] (id, wide) packed greedily into rows of three columns, as the
/// 0.1 grid did: a wide card spans two. A full row keeps its spans as
/// weights (`2:1`, `1:2`, `1:1:1`); a lone wide card gets a row of its own;
/// a short row of normal cards keeps their width with empty columns.
@visibleForTesting
List<BoardRow> packAtThreeColumns(List<(String, bool)> cards) {
  final rows = <List<(String, int)>>[];
  var current = <(String, int)>[];
  var used = 0;
  for (final (id, wide) in cards) {
    final span = wide ? 2 : 1;
    if (used + span > 3 && current.isNotEmpty) {
      rows.add(current);
      current = [];
      used = 0;
    }
    current.add((id, span));
    used += span;
  }
  if (current.isNotEmpty) rows.add(current);

  return [
    for (final row in rows)
      if (row.fold(0, (sum, c) => sum + c.$2) == 3)
        BoardRow(
          split: RowSplit([for (final (_, span) in row) span]),
          columns: [
            for (final (id, _) in row) [id],
          ],
        )
      else if (row.length == 1 && row.single.$2 == 2)
        singleColumnRow([row.single.$1])
      else
        BoardRow(
          split: RowSplit.thirds,
          columns: [
            for (var c = 0; c < 3; c++)
              if (c < row.length) [row[c].$1] else <String>[],
          ],
        ),
  ];
}
