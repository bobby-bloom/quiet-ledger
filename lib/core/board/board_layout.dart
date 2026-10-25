import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

// The pure half of a card board (docs/BOARD.md): rows with a
// split, fitting them to the window and reconciling them with the cards
// that show. Ported from keeper's card board; cards only render the
// result, so arrange mode builds on the same functions.

/// The narrowest a board column may be: a budget row with its amount, an
/// "over" chip and the name needs about this much.
const double minBoardColumnWidth = 320;

/// The space between cards, columns and rows on wide screens.
const double boardGap = 20;

/// A row template: one weight per column, left to right — `[2, 1]` is a
/// wide column and a narrow one. Kept as weights rather than a template
/// name, so a stored split the app no longer offers still renders.
@immutable
class RowSplit {
  const RowSplit(this.weights);

  /// [columns] equal columns.
  factory RowSplit.equal(int columns) =>
      RowSplit(List.unmodifiable(List.filled(columns, 1)));

  final List<int> weights;

  static const one = RowSplit([1]);
  static const halves = RowSplit([1, 1]);
  static const wideNarrow = RowSplit([2, 1]);
  static const narrowWide = RowSplit([1, 2]);
  static const thirds = RowSplit([1, 1, 1]);

  /// The splits offered, in picker order.
  static const templates = [one, halves, wideNarrow, narrowWide, thirds];

  int get columnCount => weights.length;

  /// Whether every column is as wide as the others.
  bool get isEqual => weights.every((w) => w == weights.first);

  @override
  bool operator ==(Object other) =>
      other is RowSplit &&
      const ListEquality<Object?>().equals(other.weights, weights);

  @override
  int get hashCode => Object.hashAll(weights);

  @override
  String toString() => 'RowSplit(${weights.join(':')})';
}

/// One row: its [split] and, per column of the split, the card ids
/// stacked in it top to bottom. A column may be empty.
@immutable
class BoardRow {
  const BoardRow({required this.split, required this.columns});

  final RowSplit split;
  final List<List<String>> columns;

  /// The ids of the row in reading order, column by column.
  Iterable<String> get cardIds => columns.expand((c) => c);

  @override
  bool operator ==(Object other) =>
      other is BoardRow &&
      other.split == split &&
      other.columns.length == columns.length &&
      columns.indexed.every(
        (e) => const ListEquality<Object?>().equals(other.columns[e.$1], e.$2),
      );

  @override
  int get hashCode =>
      Object.hash(split, Object.hashAll(columns.map(Object.hashAll)));

  @override
  String toString() => 'BoardRow($split, $columns)';
}

/// Whether the board shows the app's responsive default ([auto]) or the
/// arrangement the person saved ([custom]). Switching to [auto] keeps the
/// saved one.
enum LayoutMode { auto, custom }

/// What the wide board renders at one width: whose arrangement ([mode]),
/// the [rows] to draw (only cards that show, squeezed to the window,
/// empty rows left out) and how many equal columns [fits].
///
/// [placed] is the arrangement behind [rows] before anything is hidden or
/// squeezed: hidden ids keep their slots. Arrange mode seeds from it.
@immutable
class BoardLayout {
  const BoardLayout({
    required this.mode,
    required this.rows,
    required this.placed,
    required this.fits,
    this.isSqueezed = false,
  });

  final LayoutMode mode;
  final List<BoardRow> rows;
  final List<BoardRow> placed;
  final int fits;

  /// Whether a saved row is wider than the window fits.
  final bool isSqueezed;

  /// Arranging needs two columns: one column is the reading order.
  bool get canArrange => fits >= 2;

  /// The cards shown, in reading order.
  List<String> get order => [for (final row in rows) ...row.cardIds];
}

/// The wide layout for [present] cards (in their own order): the saved
/// [saved] rows on [LayoutMode.custom], squeezed to the [fits] columns,
/// else [defaultRows]. New cards that show but have no slot go after
/// their nearest default predecessor.
BoardLayout resolveBoardLayout({
  required LayoutMode mode,
  required List<BoardRow>? saved,
  required List<BoardRow> defaultRows,
  required List<String> present,
  required int fits,
}) {
  final defaults = defaultOrder(defaultRows, present);
  final custom = mode == LayoutMode.custom && saved != null && saved.isNotEmpty;
  final placed = placeNewCards(custom ? saved : defaultRows, present, defaults);
  final visible = visibleRows(placed, present);

  return BoardLayout(
    mode: custom ? LayoutMode.custom : LayoutMode.auto,
    rows: visibleRows(squeezeRows(placed, fits), present),
    placed: placed,
    fits: fits,
    // Only what shows counts: a too-wide row of hidden cards squeezes nothing.
    isSqueezed: custom && visible.any((r) => r.split.columnCount > fits),
  );
}

/// How many equal columns of at least [minColumnWidth] fit into [width]
/// with [gap] between them; at least one.
int fittingColumns(
  double width, {
  double gap = boardGap,
  double minColumnWidth = minBoardColumnWidth,
}) => math.max(1, ((width + gap) / (minColumnWidth + gap)).floor());

/// [rows] with every row of more than [maxColumns] columns cut to its
/// first [maxColumns] weights, the cards of the cut columns appended, in
/// order, to the last kept one. Non-destructive: the saved rows stay and
/// come back when the window widens. One column is the reading order.
List<BoardRow> squeezeRows(List<BoardRow> rows, int maxColumns) => [
  for (final row in rows)
    if (row.split.columnCount <= maxColumns)
      row
    else
      BoardRow(
        split: RowSplit(row.split.weights.sublist(0, maxColumns)),
        columns: [
          ...row.columns.sublist(0, maxColumns - 1),
          [for (final c in row.columns.sublist(maxColumns - 1)) ...c],
        ],
      ),
];

/// The widths of the columns of [split] in [width]: shared by weight, but
/// no column narrower than [minColumnWidth] while the width allows it — a
/// `2:1` row on a window that just fits two columns leans towards equal
/// instead of squeezing its narrow column.
List<double> columnWidths(
  RowSplit split,
  double width, {
  double gap = boardGap,
  double minColumnWidth = minBoardColumnWidth,
}) {
  final weights = split.weights;
  final available = math.max<double>(0, width - gap * (weights.length - 1));
  if (available < minColumnWidth * weights.length) {
    final total = weights.fold(0, (sum, w) => sum + w);
    return [for (final w in weights) available * w / total];
  }

  // Columns that would fall under the minimum get it; the others share
  // what is left by weight, until none falls under it any more.
  final pinned = <int>{};
  while (true) {
    final shared = available - minColumnWidth * pinned.length;
    final total = weights.indexed
        .where((e) => !pinned.contains(e.$1))
        .fold(0, (sum, e) => sum + e.$2);
    final widths = [
      for (final (i, w) in weights.indexed)
        if (pinned.contains(i)) minColumnWidth else shared * w / total,
    ];
    final under = [
      for (final (i, w) in widths.indexed)
        if (!pinned.contains(i) && w < minColumnWidth) i,
    ];
    if (under.isEmpty) return widths;
    pinned.addAll(under);
  }
}

/// The reading order of [defaultRows] — row by row, column by column, top
/// to bottom — followed by the [present] ids the defaults do not list.
/// What "the nearest default predecessor" refers to.
List<String> defaultOrder(List<BoardRow> defaultRows, List<String> present) {
  final seen = <String>{};
  return [
    for (final id in [for (final r in defaultRows) ...r.cardIds, ...present])
      if (seen.add(id)) id,
  ];
}

/// [rows] with the ids that are [present] but nowhere in them placed right
/// after their nearest predecessor in [defaultOrder] that is present and
/// placed; with none, at the top of the first column of the first row. Ids
/// that are not present keep their slots, so a card that comes back
/// finds its place.
List<BoardRow> placeNewCards(
  List<BoardRow> rows,
  List<String> present,
  List<String> defaultOrder,
) {
  final placed = {for (final r in rows) ...r.cardIds};
  final presentIds = present.toSet();
  final missing = [
    for (final id in defaultOrder)
      if (presentIds.contains(id) && !placed.contains(id)) id,
    for (final id in present)
      if (!placed.contains(id) && !defaultOrder.contains(id)) id,
  ];
  if (missing.isEmpty) return rows;

  final columns = [
    for (final r in rows) [for (final c in r.columns) c.toList()],
  ];
  if (columns.isEmpty) columns.add([<String>[]]);

  for (final id in missing) {
    final (row, column, index) = _slotAfterPredecessor(
      id,
      columns,
      presentIds,
      defaultOrder,
    );
    columns[row][column].insert(index, id);
  }

  return [
    for (final (i, row) in columns.indexed)
      BoardRow(
        split: i < rows.length ? rows[i].split : RowSplit.one,
        columns: row,
      ),
  ];
}

/// [placeNewCards] on a flat one-column [order].
List<String> placeNewCardsInOrder(
  List<String> order,
  List<String> present,
  List<String> defaultOrder,
) => placeNewCards(
  [singleColumnRow(order)],
  present,
  defaultOrder,
).single.columns.single;

/// [placedOrder] with [id] moved to [position] (from 0) among the ids that
/// show, [visible]: right before the shown id that will follow it, or right
/// after the last one. Hidden ids keep their place among the others.
List<String> moveInOrder(
  List<String> placedOrder,
  List<String> visible,
  String id,
  int position,
) {
  final others = [...visible]..remove(id);
  if (others.isEmpty) return placedOrder;

  final order = [...placedOrder]..remove(id);
  final index = position.clamp(0, others.length);
  final at = index < others.length
      ? order.indexOf(others[index])
      : order.indexOf(others.last) + 1;
  return order..insert(at, id);
}

/// One row of one column holding [order].
BoardRow singleColumnRow(List<String> order) =>
    BoardRow(split: RowSplit.one, columns: [order]);

/// [rows] with only the ids [present], each once (its first slot), and
/// without the rows left with none. Empty columns of a remaining row stay
/// and keep their width.
List<BoardRow> visibleRows(List<BoardRow> rows, List<String> present) {
  final presentIds = present.toSet();
  final seen = <String>{};
  final visible = [
    for (final row in rows)
      BoardRow(
        split: row.split,
        columns: [
          for (final c in row.columns)
            [
              for (final id in c)
                if (presentIds.contains(id) && seen.add(id)) id,
            ],
        ],
      ),
  ];
  return [
    for (final row in visible)
      if (row.cardIds.isNotEmpty) row,
  ];
}

/// [rows] without the ids outside [known] (card types the app no longer
/// has). Hidden ids are known and keep their slots; a column left empty
/// stays.
List<BoardRow> dropUnknownCards(List<BoardRow> rows, Set<String> known) => [
  for (final row in rows)
    BoardRow(
      split: row.split,
      columns: [
        for (final c in row.columns) [...c.where(known.contains)],
      ],
    ),
];

/// [order] dealt into one row of [columns] equal columns: contiguous and
/// balanced by count — the first columns take one more while the ids do
/// not divide evenly — in reading order.
BoardRow dealRow(List<String> order, int columns) {
  final base = order.length ~/ columns;
  final extra = order.length % columns;
  var start = 0;
  return BoardRow(
    split: RowSplit.equal(columns),
    columns: [
      for (var c = 0; c < columns; c++)
        order.sublist(start, start += base + (c < extra ? 1 : 0)),
    ],
  );
}

/// A segment of the board menu's Layout control: the app's responsive
/// [auto], a page of one to three equal [columns], or the person's
/// [custom] layout of several rows or an unequal split.
enum LayoutSegment {
  auto(null),
  one(1),
  two(2),
  three(3),
  custom(null);

  LayoutSegment(this.columns);

  /// The column count of a number segment; null for [auto] and [custom].
  final int? columns;

  static const numbers = [one, two, three];

  static LayoutSegment ofColumns(int columns) => numbers[columns - 1];
}

/// The column count of [rows] when they are one row of equal columns a
/// number segment stands for (1–3), else null.
int? equalRowColumns(List<BoardRow>? rows) {
  if (rows == null || rows.length != 1) return null;
  final split = rows.single.split;
  return split.isEqual && split.columnCount <= LayoutSegment.numbers.length
      ? split.columnCount
      : null;
}

/// Whether the Layout control offers Custom: while saved [rows] exist that
/// no number stands for (several rows, an unequal split).
bool offersCustom(List<BoardRow>? rows) =>
    rows != null && rows.isNotEmpty && equalRowColumns(rows) == null;

/// The segment that shows what renders: the control is also the indicator.
LayoutSegment selectedSegment(LayoutMode mode, List<BoardRow>? saved) {
  if (mode == LayoutMode.auto) return LayoutSegment.auto;
  final columns = equalRowColumns(saved);
  return columns == null
      ? LayoutSegment.custom
      : LayoutSegment.ofColumns(columns);
}

/// Where [id] goes in [columns]: right after its nearest predecessor in
/// [defaultOrder] that is present and placed, else the top of the first
/// column of the first row.
(int, int, int) _slotAfterPredecessor(
  String id,
  List<List<List<String>>> columns,
  Set<String> present,
  List<String> defaultOrder,
) {
  final at = defaultOrder.indexOf(id);
  final before = at < 0 ? defaultOrder : defaultOrder.sublist(0, at);
  for (final predecessor in before.reversed) {
    if (!present.contains(predecessor)) continue;
    for (final (r, row) in columns.indexed) {
      for (final (c, column) in row.indexed) {
        final index = column.indexOf(predecessor);
        if (index >= 0) return (r, c, index + 1);
      }
    }
  }
  return (0, 0, 0);
}
