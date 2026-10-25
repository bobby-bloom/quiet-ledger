import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/board/arrange.dart';
import 'package:personal_finance/core/board/board_layout.dart';
import 'package:personal_finance/core/board/board_state.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';

/// At most this many copies are kept aside per view.
const _maxKeptAside = 10;

/// The saved views of every board, in the `dashboard_layouts` table: synced
/// and backed up like any table (docs/BOARD.md, Storage).
class BoardRepository {
  BoardRepository(this._ref);

  final Ref _ref;

  AppDatabase get _db => _ref.read(databaseProvider);

  SimpleSelectStatement<$DashboardLayoutsTable, DashboardLayout> _rows(
    Iterable<String> keys,
  ) =>
      _db.select(_db.dashboardLayouts)
        ..where((l) => l.breakpoint.isIn(keys) & l.deletedAt.isNull());

  List<String> _keys(BoardDefinition def, BoardView view) => [
    def.storageKey(view),
    if (def.legacyKey case final legacy?) legacy(view),
  ];

  /// The saved state of [view] of the board [def]: its v2 row, else an
  /// older row migrated ([BoardDefinition.migrateLegacy]), else nothing
  /// saved (Auto, the defaults).
  Stream<BoardState> watch(BoardDefinition def, BoardView view) =>
      _rows(_keys(def, view)).watch().map((r) => _decode(def, view, r));

  /// The saved state of [view] now.
  Future<BoardState> read(BoardDefinition def, BoardView view) async =>
      _decode(def, view, await _rows(_keys(def, view)).get());

  /// Writes [state] as the saved state of [view] in one write.
  Future<void> save(BoardDefinition def, BoardView view, BoardState state) =>
      update(def, view, (_) => state);

  /// Changes the saved state of [view] by [change], reading it inside the
  /// write's transaction so two changes in quick succession never undo each
  /// other. Returns the state before and after.
  Future<(BoardState, BoardState)> update(
    BoardDefinition def,
    BoardView view,
    BoardState Function(BoardState current) change,
  ) {
    final writer = _ref.read(syncWriterProvider);
    final key = def.storageKey(view);
    return writer.transaction(() async {
      final rows = await _rows(_keys(def, view)).get();
      final before = _decode(def, view, rows);
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
              encodeViewState(view, decodeViewState(def, view, v2.widgets)) ==
                  json)) {
        return (before, after);
      }

      // Nothing this build cannot read in full is lost: a copy of each such
      // value stays before the save replaces it.
      if (!readsInFull(view, v2.widgets)) {
        await _keepAside(def, view, v2.widgets);
      }
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

  Future<void> _keepAside(
    BoardDefinition def,
    BoardView view,
    String widgets,
  ) async {
    final kept = await _rows([def.unreadableKey(view)]).get();
    if (kept.any((r) => r.widgets == widgets)) return;
    if (kept.length >= _maxKeptAside) {
      _logMalformed(def, view, 'a copy: $_maxKeptAside are kept already');
      return;
    }
    await _ref
        .read(syncWriterProvider)
        .insert(
          _db.dashboardLayouts,
          DashboardLayoutsCompanion(
            breakpoint: Value(def.unreadableKey(view)),
            widgets: Value(widgets),
          ),
        );
  }

  static BoardState _decode(
    BoardDefinition def,
    BoardView view,
    List<DashboardLayout> rows,
  ) {
    final key = def.storageKey(view);
    final v2 = _current(rows.where((r) => r.breakpoint == key));
    if (v2 != null) return decodeViewState(def, view, v2.widgets);
    final legacyKey = def.legacyKey?.call(view);
    final migrate = def.migrateLegacy;
    final v1 = _current(rows.where((r) => r.breakpoint == legacyKey));
    if (v1 != null && migrate != null) return migrate(view, v1.widgets);
    return BoardState(def);
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

final boardRepositoryProvider = Provider(BoardRepository.new);

/// The saved state of a view of a board, kept up to date.
final boardStateProvider =
    StreamProvider.family<BoardState, (BoardDefinition, BoardView)>(
      (ref, key) => ref.watch(boardRepositoryProvider).watch(key.$1, key.$2),
    );

/// [state] as stored for [view]: `{"v": 2, "mode", "items", "rows" |
/// "order"}`. Ids of types this build does not know are written back as
/// they were read.
String encodeViewState(BoardView view, BoardState state) {
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
    if (view == BoardView.expanded && rows != null && rows.isNotEmpty)
      'rows': [
        for (final r in rows) {'split': r.split.weights, 'columns': r.columns},
      ],
    if (view == BoardView.compact && order != null) 'order': order,
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
bool readsInFull(BoardView view, String json) {
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
  final arrangement = view == BoardView.expanded ? 'rows' : 'order';
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

void _logMalformed(BoardDefinition def, BoardView view, Object what) {
  if (_loggedMalformed) return;
  _loggedMalformed = true;
  debugPrint('Board layout ${def.storageKey(view)}: skipped $what');
}

/// The state stored in [json] for [view]. Only what is malformed is
/// skipped — an entry, a row, an id — the rest reads as saved (logged
/// once); a value that is no JSON object reads as nothing saved. A type
/// listed twice keeps its first slot. Ids of types this build does not know
/// are kept: they never show, and a newer build finds them again.
BoardState decodeViewState(BoardDefinition def, BoardView view, String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    _logMalformed(def, view, e);
    return BoardState(def);
  }
  if (raw is! Map) {
    _logMalformed(def, view, 'a value that is not an object');
    return BoardState(def);
  }

  final items = <String, BoardEntry>{};
  if (raw['items'] case final Map<Object?, Object?> rawItems) {
    for (final MapEntry(:key, :value) in rawItems.entries) {
      if (key is! String || value is! Map) {
        _logMalformed(def, view, 'item $key');
        continue;
      }
      final options = value['options'];
      items[key] = BoardEntry(
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
      for (final r in rawRows) ?_decodeRow(r) ?? _skipped(def, view, 'a row'),
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
  return BoardState(
    def,
    mode: mode,
    items: items,
    rows: rows == null || rows.isEmpty ? null : rows,
    order: order,
  );
}

BoardRow? _skipped(BoardDefinition def, BoardView view, String what) {
  _logMalformed(def, view, what);
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
