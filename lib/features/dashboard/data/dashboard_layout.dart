import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/features/dashboard/domain/arrange.dart';
import 'package:personal_finance/features/dashboard/domain/board_layout.dart';
import 'package:personal_finance/features/dashboard/domain/dashboard_view.dart';

export 'package:personal_finance/features/dashboard/domain/dashboard_view.dart'
    show DashboardView, DashboardWidgetType;

/// One widget as it is built: its type and its options, e.g.
/// `{'accountId': '...'}` for the forecast or `{'limit': 5}` for lists.
@immutable
class DashboardItem {
  const DashboardItem(this.type, {this.options = const {}});

  final DashboardWidgetType type;
  final Map<String, Object?> options;

  DashboardItem copyWith({Map<String, Object?>? options}) =>
      DashboardItem(type, options: options ?? this.options);
}

/// The `dashboard_layouts` row of each view (docs/DASHBOARD.md, Storage).
/// The `compact` / `expanded` rows of 0.1 stay as they were: an older build
/// reads them and would fail on the new shape.
String storageKey(DashboardView view) => '${view.name}.v2';

/// The dashboard's saved views, synced and backed up like any table.
class DashboardLayoutRepository {
  DashboardLayoutRepository(this._ref);

  final Ref _ref;

  AppDatabase get _db => _ref.read(databaseProvider);

  SimpleSelectStatement<$DashboardLayoutsTable, DashboardLayout> _rows(
    Iterable<String> keys,
  ) =>
      _db.select(_db.dashboardLayouts)
        ..where((l) => l.breakpoint.isIn(keys) & l.deletedAt.isNull());

  /// The saved state of [view]: the v2 row, else the 0.1 row migrated, else
  /// nothing saved (Auto, the defaults).
  Stream<DashboardViewState> watch(DashboardView view) {
    final legacy = view.name;
    return _rows([storageKey(view), legacy]).watch().map((rows) {
      final v2 = rows.where((r) => r.breakpoint == storageKey(view));
      if (v2.isNotEmpty) return decodeViewState(view, v2.first.widgets);
      final v1 = rows.where((r) => r.breakpoint == legacy);
      if (v1.isNotEmpty) return migrateLegacyLayout(view, v1.first.widgets);
      return DashboardViewState.empty;
    });
  }

  /// The saved state of [view] now.
  Future<DashboardViewState> read(DashboardView view) => watch(view).first;

  /// Writes [state] as the saved state of [view] in one write: an entry for
  /// every known type, rows without unknown ids and empty rows.
  Future<void> save(DashboardView view, DashboardViewState state) async {
    final writer = _ref.read(syncWriterProvider);
    final json = encodeViewState(view, state);
    final key = storageKey(view);
    await writer.transaction(() async {
      final existing = await _rows([key]).getSingleOrNull();
      if (existing == null) {
        await writer.insert(
          _db.dashboardLayouts,
          DashboardLayoutsCompanion(
            breakpoint: Value(key),
            widgets: Value(json),
          ),
        );
      } else if (existing.widgets != json) {
        await writer.update(
          _db.dashboardLayouts,
          existing.id,
          DashboardLayoutsCompanion(widgets: Value(json)),
        );
      }
    });
  }
}

final dashboardLayoutRepositoryProvider = Provider(
  DashboardLayoutRepository.new,
);

final dashboardViewProvider =
    StreamProvider.family<DashboardViewState, DashboardView>(
      (ref, view) => ref.watch(dashboardLayoutRepositoryProvider).watch(view),
    );

final _known = {for (final t in DashboardWidgetType.values) t.name};

/// [state] as stored for [view]: `{"v": 2, "mode", "items", "rows" |
/// "order"}`.
String encodeViewState(DashboardView view, DashboardViewState state) {
  final s = state.normalized(view);
  final rows = s.rows == null ? null : finishedRows(s.rows!, _known);
  final order = s.order == null
      ? null
      : [
          for (final id in {...s.order!})
            if (_known.contains(id)) id,
        ];
  return jsonEncode({
    'v': 2,
    'mode': s.mode.name,
    'items': {
      for (final MapEntry(:key, :value) in s.items.entries)
        key: {
          'visible': value.visible,
          if (value.options.isNotEmpty) 'options': value.options,
        },
    },
    if (view == DashboardView.expanded && rows != null && rows.isNotEmpty)
      'rows': [
        for (final r in rows) {'split': r.split.weights, 'columns': r.columns},
      ],
    if (view == DashboardView.compact && order != null) 'order': order,
  });
}

var _loggedMalformed = false;

/// The state stored in [json] for [view]. Unknown types are dropped and a
/// type listed twice keeps its first slot; anything malformed reads as
/// nothing saved (logged once).
DashboardViewState decodeViewState(DashboardView view, String json) {
  try {
    final map = (jsonDecode(json) as Map).cast<String, Object?>();
    final rawItems = (map['items'] as Map?) ?? const {};
    final items = <String, WidgetEntry>{
      for (final MapEntry(:key, :value) in rawItems.entries)
        if (_known.contains(key))
          key as String: WidgetEntry(
            visible: (value as Map)['visible'] as bool? ?? true,
            options: ((value['options'] as Map?) ?? const {})
                .cast<String, Object?>(),
          ),
    };
    final mode = map['mode'] == LayoutMode.custom.name
        ? LayoutMode.custom
        : LayoutMode.auto;
    final rawRows = map['rows'] as List?;
    final rows = rawRows == null
        ? null
        : withoutDuplicates(
            dropUnknownCards([
              for (final r in rawRows)
                _row(
                  [for (final w in (r as Map)['split'] as List) w as int],
                  [
                    for (final c in r['columns'] as List)
                      [for (final id in c as List) id as String],
                  ],
                ),
            ], _known),
          );
    final rawOrder = map['order'] as List?;
    final order = rawOrder == null
        ? null
        : [
            for (final id in {for (final id in rawOrder) id as String})
              if (_known.contains(id)) id,
          ];
    return DashboardViewState(
      mode: mode,
      items: items,
      rows: rows == null || rows.isEmpty ? null : rows,
      order: order,
    );
  } on Object catch (e) {
    if (!_loggedMalformed) {
      _loggedMalformed = true;
      debugPrint('Dashboard layout ${storageKey(view)} unreadable: $e');
    }
    return DashboardViewState.empty;
  }
}

BoardRow _row(List<int> weights, List<List<String>> columns) {
  if (weights.isEmpty || weights.any((w) => w < 1)) {
    throw const FormatException('bad split');
  }
  // One list per weight: missing columns are empty, extra ones dropped.
  return BoardRow(
    split: RowSplit(weights),
    columns: [
      for (var c = 0; c < weights.length; c++)
        if (c < columns.length) columns[c] else <String>[],
    ],
  );
}

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
            _known.contains(e['type']) &&
            seen.add(e['type'] as String))
          (
            e['type'] as String,
            e['size'] == 'wide',
            ((e['options'] as Map?) ?? const {}).cast<String, Object?>(),
          ),
    ];
  } on Object {
    return DashboardViewState.empty;
  }

  final items = {
    for (final t in DashboardWidgetType.values)
      t.name: const WidgetEntry(visible: false),
    for (final (type, _, options) in list) type: WidgetEntry(options: options),
  };
  final legacyDefault = _legacyDefaults[view]!;
  final isDefault =
      list.length == legacyDefault.length &&
      list.indexed.every(
        (e) =>
            e.$2.$1 == legacyDefault[e.$1].$1 &&
            e.$2.$2 == legacyDefault[e.$1].$2,
      );
  if (isDefault) return DashboardViewState(items: items);

  final ids = [for (final (type, _, _) in list) type];
  return switch (view) {
    DashboardView.compact => DashboardViewState(
      mode: LayoutMode.custom,
      items: items,
      order: [
        ...ids,
        for (final id in defaultPhoneOrder())
          if (!ids.contains(id)) id,
      ],
    ),
    DashboardView.expanded =>
      list.isEmpty
          ? DashboardViewState(items: items)
          : DashboardViewState(
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
