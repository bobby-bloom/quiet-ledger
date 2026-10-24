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

/// Where a stored value this build cannot read in full is kept before a
/// save replaces it (one row per distinct value).
String unreadableKey(DashboardView view) => '${storageKey(view)}.unreadable';

/// At most this many copies are kept aside per view.
const _maxKeptAside = 10;

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
  Stream<DashboardViewState> watch(DashboardView view) =>
      _rows([storageKey(view), view.name]).watch().map((r) => _decode(view, r));

  /// The saved state of [view] now.
  Future<DashboardViewState> read(DashboardView view) async =>
      _decode(view, await _rows([storageKey(view), view.name]).get());

  /// Writes [state] as the saved state of [view] in one write.
  Future<void> save(DashboardView view, DashboardViewState state) =>
      update(view, (_) => state);

  /// Changes the saved state of [view] by [change], reading it inside the
  /// write's transaction so two changes in quick succession never undo each
  /// other. Returns the state before and after.
  Future<(DashboardViewState, DashboardViewState)> update(
    DashboardView view,
    DashboardViewState Function(DashboardViewState current) change,
  ) {
    final writer = _ref.read(syncWriterProvider);
    final key = storageKey(view);
    return writer.transaction(() async {
      final rows = await _rows([key, view.name]).get();
      final before = _decode(view, rows);
      final after = change(before);
      final json = encodeViewState(view, after);
      final v2 = _current(rows.where((r) => r.breakpoint == key));
      if (v2 == null) {
        await writer.insert(
          _db.dashboardLayouts,
          DashboardLayoutsCompanion(
            breakpoint: Value(key),
            widgets: Value(json),
          ),
        );
        return (before, after);
      }
      // Nothing to write when the stored value already says the same, in
      // whatever key order another build wrote it.
      if (v2.widgets == json ||
          (readsInFull(view, v2.widgets) &&
              encodeViewState(view, decodeViewState(view, v2.widgets)) ==
                  json)) {
        return (before, after);
      }

      // Nothing this build cannot read in full is lost: a copy of each such
      // value stays before the save replaces it.
      if (!readsInFull(view, v2.widgets)) await _keepAside(view, v2.widgets);
      // Two devices that each started a v2 row before they synced keep
      // both: every device picks the same one to read and write (_current),
      // the other stays as it is — nothing is moved or deleted.
      await writer.update(
        _db.dashboardLayouts,
        v2.id,
        DashboardLayoutsCompanion(widgets: Value(json)),
      );
      return (before, after);
    });
  }

  Future<void> _keepAside(DashboardView view, String widgets) async {
    final kept = await _rows([unreadableKey(view)]).get();
    if (kept.any((r) => r.widgets == widgets)) return;
    if (kept.length >= _maxKeptAside) {
      _logMalformed(view, 'a copy: $_maxKeptAside are kept already');
      return;
    }
    await _ref
        .read(syncWriterProvider)
        .insert(
          _db.dashboardLayouts,
          DashboardLayoutsCompanion(
            breakpoint: Value(unreadableKey(view)),
            widgets: Value(widgets),
          ),
        );
  }

  static DashboardViewState _decode(
    DashboardView view,
    List<DashboardLayout> rows,
  ) {
    final v2 = _current(rows.where((r) => r.breakpoint == storageKey(view)));
    if (v2 != null) return decodeViewState(view, v2.widgets);
    final v1 = _current(rows.where((r) => r.breakpoint == view.name));
    if (v1 != null) return migrateLegacyLayout(view, v1.widgets);
    return DashboardViewState.empty;
  }

  /// The row that counts among [rows] of one key: one that reads as a
  /// state at all before one that does not, then the last written (HLC
  /// stamps sort as text), then the smallest id.
  static DashboardLayout? _current(Iterable<DashboardLayout> rows) {
    DashboardLayout? best;
    var bestReadable = false;
    for (final r in rows) {
      final readable = isReadableViewState(r.widgets);
      if (best == null) {
        (best, bestReadable) = (r, readable);
        continue;
      }
      if (readable != bestReadable) {
        if (readable) (best, bestReadable) = (r, readable);
        continue;
      }
      final byTime = r.updatedAt.compareTo(best.updatedAt);
      if (byTime > 0 || (byTime == 0 && r.id.compareTo(best.id) < 0)) {
        best = r;
      }
    }
    return best;
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
/// "order"}`. Ids of types this build does not know are written back as
/// they were read.
String encodeViewState(DashboardView view, DashboardViewState state) {
  final s = state.normalized(view);
  final rows = s.rows == null
      ? null
      : [
          for (final r in withoutDuplicates(s.rows!))
            if (r.cardIds.isNotEmpty) r,
        ];
  final order = s.order == null
      ? null
      : [
          ...{...s.order!},
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

/// Whether [json] is a v2 state at all (a JSON object).
bool isReadableViewState(String json) {
  try {
    return jsonDecode(json) is Map;
  } on FormatException {
    return false;
  }
}

/// Whether this build reads all of [json] as a state of [view] — nothing
/// skipped, nothing it does not know (another version, more fields, a field
/// of the other view) — so writing over it loses nothing.
bool readsInFull(DashboardView view, String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException {
    return false;
  }
  bool strings(Object? list) =>
      list is List && list.every((id) => id is String);
  bool onlyKeys(Map<Object?, Object?> map, Set<String> keys) =>
      map.keys.every(keys.contains);
  final arrangement = view == DashboardView.expanded ? 'rows' : 'order';
  if (raw is! Map ||
      !onlyKeys(raw, {'v', 'mode', 'items', arrangement}) ||
      raw['v'] != 2 ||
      !const {null, 'auto', 'custom'}.contains(raw['mode'])) {
    return false;
  }
  final items = raw['items'];
  if (items != null) {
    if (items is! Map) return false;
    for (final MapEntry(:key, :value) in items.entries) {
      if (key is! String ||
          value is! Map ||
          !onlyKeys(value, const {'visible', 'options'}) ||
          (value['visible'] != null && value['visible'] is! bool) ||
          (value['options'] != null &&
              (value['options'] is! Map ||
                  (value['options'] as Map).keys.any((k) => k is! String)))) {
        return false;
      }
    }
  }
  final rows = raw['rows'];
  final ids = <String>[];
  if (rows != null) {
    if (rows is! List) return false;
    for (final r in rows) {
      if (r is! Map || !onlyKeys(r, const {'split', 'columns'})) return false;
      final split = r['split'];
      final columns = r['columns'];
      if (split is! List ||
          split.isEmpty ||
          split.any((w) => w is! int || w < 1) ||
          columns is! List ||
          columns.length != split.length ||
          !columns.every(strings)) {
        return false;
      }
      for (final c in columns) {
        ids.addAll((c as List).cast<String>());
      }
    }
  }
  final order = raw['order'];
  if (order != null) {
    if (!strings(order)) return false;
    ids.addAll((order as List).cast<String>());
  }
  return ids.length == ids.toSet().length;
}

var _loggedMalformed = false;

void _logMalformed(DashboardView view, Object what) {
  if (_loggedMalformed) return;
  _loggedMalformed = true;
  debugPrint('Dashboard layout ${storageKey(view)}: skipped $what');
}

/// The state stored in [json] for [view]. Only what is malformed is
/// skipped — an entry, a row, an id — the rest reads as saved (logged
/// once); a value that is no JSON object reads as nothing saved. A type
/// listed twice keeps its first slot. Ids of types this build does not know
/// are kept: they never show, and a newer build finds them again.
DashboardViewState decodeViewState(DashboardView view, String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    _logMalformed(view, e);
    return DashboardViewState.empty;
  }
  if (raw is! Map) {
    _logMalformed(view, 'a value that is not an object');
    return DashboardViewState.empty;
  }

  final items = <String, WidgetEntry>{};
  if (raw['items'] case final Map<Object?, Object?> rawItems) {
    for (final MapEntry(:key, :value) in rawItems.entries) {
      if (key is! String || value is! Map) {
        _logMalformed(view, 'item $key');
        continue;
      }
      final options = value['options'];
      items[key] = WidgetEntry(
        visible: value['visible'] != false,
        options: {
          if (options is Map)
            for (final MapEntry(:key, :value) in options.entries)
              if (key is String) key: value,
        },
      );
    }
  }

  final mode = raw['mode'] == LayoutMode.custom.name
      ? LayoutMode.custom
      : LayoutMode.auto;
  List<BoardRow>? rows;
  if (raw['rows'] case final List<Object?> rawRows) {
    rows = withoutDuplicates([
      for (final r in rawRows) ?_decodeRow(r) ?? _skipped(view, 'a row'),
    ]);
  }
  List<String>? order;
  if (raw['order'] case final List<Object?> rawOrder) {
    order = [
      ...{
        for (final id in rawOrder)
          if (id is String) id,
      },
    ];
  }
  return DashboardViewState(
    mode: mode,
    items: items,
    rows: rows == null || rows.isEmpty ? null : rows,
    order: order,
  );
}

BoardRow? _skipped(DashboardView view, String what) {
  _logMalformed(view, what);
  return null;
}

/// One stored row, or null when its split is unusable. Non-string ids are
/// skipped; columns beyond the split join its last column, as a squeezed
/// row does, so no widget loses its slot.
BoardRow? _decodeRow(Object? raw) {
  if (raw is! Map) return null;
  final rawSplit = raw['split'];
  final rawColumns = raw['columns'];
  if (rawSplit is! List || rawSplit.isEmpty) return null;
  final weights = <int>[];
  for (final w in rawSplit) {
    if (w is! int || w < 1) return null;
    weights.add(w);
  }
  final columns = [
    if (rawColumns is List)
      for (final c in rawColumns)
        [
          if (c is List)
            for (final id in c)
              if (id is String) id,
        ],
  ];
  final last = weights.length - 1;
  return BoardRow(
    split: RowSplit(weights),
    columns: [
      for (var c = 0; c < last; c++)
        if (c < columns.length) columns[c] else <String>[],
      [for (final ids in columns.skip(last)) ...ids],
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
