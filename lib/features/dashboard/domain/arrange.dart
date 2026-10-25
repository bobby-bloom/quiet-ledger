import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/features/dashboard/domain/board_layout.dart';

// The pure half of arrange mode (docs/DASHBOARD.md): where a widget is as
// the person sees it, and what a drop, a Move or a row edit does to the
// working rows. The rows are the placed arrangement — hidden widgets keep
// their slots, saved splits stay even where the window squeezes a row — so
// Done writes what the person built, not what the window allowed. Ported
// from keeper's card board.

/// One step of the Move menu and of the screen reader's actions. [start]
/// and [end] go one column towards the start or the end of the reading
/// direction.
enum CardMove { up, down, start, end }

/// Where a widget shows in arrange mode: the [row] of the working rows, the
/// [column] on screen (a squeezed row shows fewer than it has), and its
/// [index] among the [count] widgets present in that column.
@immutable
class ArrangePosition {
  const ArrangePosition({
    required this.row,
    required this.column,
    required this.index,
    required this.count,
  });

  final int row;
  final int column;
  final int index;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is ArrangePosition &&
      other.row == row &&
      other.column == column &&
      other.index == index &&
      other.count == count;

  @override
  int get hashCode => Object.hash(row, column, index, count);

  @override
  String toString() => 'ArrangePosition($row, $column, $index of $count)';
}

/// Where a dragged or moved widget can land.
@immutable
sealed class ArrangeTarget {
  const ArrangeTarget();
}

/// Before the [index]th widget present in [column] (as shown) of [row] —
/// counted without the one that moves; at or past the end, after the last.
final class ColumnTarget extends ArrangeTarget {
  const ColumnTarget({
    required this.row,
    required this.column,
    required this.index,
  });

  final int row;
  final int column;
  final int index;

  @override
  bool operator ==(Object other) =>
      other is ColumnTarget &&
      other.row == row &&
      other.column == column &&
      other.index == index;

  @override
  int get hashCode => Object.hash(row, column, index);

  @override
  String toString() => 'ColumnTarget($row, $column, $index)';
}

/// A new one-column row inserted before the row at [at] (after the last
/// with [at] = the row count).
final class NewRowTarget extends ArrangeTarget {
  const NewRowTarget(this.at);

  final int at;

  @override
  bool operator ==(Object other) => other is NewRowTarget && other.at == at;

  @override
  int get hashCode => at.hashCode;

  @override
  String toString() => 'NewRowTarget($at)';
}

/// How many columns [row] shows when [fits] columns fit.
int shownColumnCount(BoardRow row, int fits) =>
    math.min(row.split.columnCount, math.max(1, fits));

/// The split [row] renders with: its own, or its first [fits] weights.
RowSplit shownSplit(BoardRow row, int fits) {
  final count = shownColumnCount(row, fits);
  return count == row.split.columnCount
      ? row.split
      : RowSplit(row.split.weights.sublist(0, count));
}

/// The ids [present] in each column [row] shows; the last column of a
/// squeezed row holds the ids of every column it stands for, in order.
List<List<String>> shownColumns(BoardRow row, Set<String> present, int fits) {
  final count = shownColumnCount(row, fits);
  return [
    for (var c = 0; c < count; c++)
      [
        for (final ids
            in c == count - 1 ? row.columns.sublist(c) : [row.columns[c]])
          for (final id in ids)
            if (present.contains(id)) id,
      ],
  ];
}

/// Where [id] shows in [rows], or null when it is not there or not present.
ArrangePosition? positionOf(
  List<BoardRow> rows,
  String id, {
  required Set<String> present,
  required int fits,
}) {
  for (final (r, row) in rows.indexed) {
    for (final (c, ids) in shownColumns(row, present, fits).indexed) {
      final index = ids.indexOf(id);
      if (index >= 0) {
        return ArrangePosition(
          row: r,
          column: c,
          index: index,
          count: ids.length,
        );
      }
    }
  }
  return null;
}

/// The moves that apply to [id]: Up and Down while a widget or a row is
/// above or below it, Start and End while its row shows a column there.
Set<CardMove> possibleMoves(
  List<BoardRow> rows,
  String id, {
  required Set<String> present,
  required int fits,
}) {
  final p = positionOf(rows, id, present: present, fits: fits);
  if (p == null) return const {};
  return {
    if (p.index > 0 || p.row > 0) CardMove.up,
    if (p.index < p.count - 1 || p.row < rows.length - 1) CardMove.down,
    if (p.column > 0) CardMove.start,
    if (p.column < shownColumnCount(rows[p.row], fits) - 1) CardMove.end,
  };
}

/// Where [move] takes [id], or null when it does not apply. Up from the top
/// of a column continues at the bottom of the same column index in the row
/// above, Down from the bottom at the top of the row below (clamped to the
/// columns that row shows); Start and End keep the index, clamped.
ColumnTarget? moveTarget(
  List<BoardRow> rows,
  String id,
  CardMove move, {
  required Set<String> present,
  required int fits,
}) {
  final p = positionOf(rows, id, present: present, fits: fits);
  if (p == null ||
      !possibleMoves(rows, id, present: present, fits: fits).contains(move)) {
    return null;
  }

  final (row, column, index) = (p.row, p.column, p.index);
  int clamped(int r) => math.min(column, shownColumnCount(rows[r], fits) - 1);

  return switch (move) {
    CardMove.up when index > 0 => ColumnTarget(
      row: row,
      column: column,
      index: index - 1,
    ),
    CardMove.up => ColumnTarget(
      row: row - 1,
      column: clamped(row - 1),
      index: shownColumns(
        rows[row - 1],
        present,
        fits,
      )[clamped(row - 1)].length,
    ),
    CardMove.down when index < p.count - 1 => ColumnTarget(
      row: row,
      column: column,
      index: index + 1,
    ),
    CardMove.down => ColumnTarget(
      row: row + 1,
      column: clamped(row + 1),
      index: 0,
    ),
    CardMove.start => ColumnTarget(row: row, column: column - 1, index: index),
    CardMove.end => ColumnTarget(row: row, column: column + 1, index: index),
  };
}

/// [rows] with [id] taken from where it was and put at [target]. Dropped
/// into the last column of a squeezed row, it lands in the last column that
/// fits, which takes over the ids of the columns it stood for, so what the
/// person sees is what is kept. A drop back where it is — its own place, or
/// a new row next to the row it has to itself — returns [rows] as they are.
List<BoardRow> dropCard(
  List<BoardRow> rows,
  String id,
  ArrangeTarget target, {
  required Set<String> present,
  required int fits,
}) {
  if (_isInPlace(rows, id, target, present: present, fits: fits)) return rows;

  final without = [
    for (final row in rows)
      BoardRow(
        split: row.split,
        columns: [
          for (final c in row.columns) [...c.where((other) => other != id)],
        ],
      ),
  ];

  switch (target) {
    case NewRowTarget(:final at):
      return [
        ...without.sublist(0, at),
        singleColumnRow([id]),
        ...without.sublist(at),
      ];

    case ColumnTarget(:final row, :final column, :final index):
      final columns = without[row].columns;
      if (column == shownColumnCount(without[row], fits) - 1 &&
          column < columns.length - 1) {
        columns[column] = [for (final ids in columns.sublist(column)) ...ids];
        for (var squeezed = column + 1; squeezed < columns.length; squeezed++) {
          columns[squeezed] = [];
        }
      }

      final cells = columns[column];
      final shown = [
        for (final other in cells)
          if (present.contains(other)) other,
      ];
      cells.insert(
        index < shown.length ? cells.indexOf(shown[index]) : cells.length,
        id,
      );
      return without;
  }
}

bool _isInPlace(
  List<BoardRow> rows,
  String id,
  ArrangeTarget target, {
  required Set<String> present,
  required int fits,
}) {
  switch (target) {
    case ColumnTarget(:final row, :final column, :final index):
      final p = positionOf(rows, id, present: present, fits: fits);
      return p != null &&
          p.row == row &&
          p.column == column &&
          p.index == index;

    case NewRowTarget(:final at):
      final own = rows.indexWhere(
        (r) => const ListEquality<Object?>().equals(r.cardIds.toList(), [id]),
      );
      return own >= 0 && (at == own || at == own + 1);
  }
}

/// [rows] with every id in its first slot only: a malformed saved layout
/// that lists a widget twice shows and moves it once.
List<BoardRow> withoutDuplicates(List<BoardRow> rows) {
  final seen = <String>{};
  return [
    for (final row in rows)
      BoardRow(
        split: row.split,
        columns: [
          for (final c in row.columns) [...c.where(seen.add)],
        ],
      ),
  ];
}

/// What Done saves from [rows]: without ids outside [known] and without
/// the rows left with no id at all (hidden ones count); empty columns of a
/// remaining row stay and keep their width.
List<BoardRow> finishedRows(List<BoardRow> rows, Set<String> known) => [
  for (final row in dropUnknownCards(rows, known))
    if (row.cardIds.isNotEmpty) row,
];

// Row edits.

/// Whether [split] fits a window where [fits] equal columns fit.
bool splitFits(RowSplit split, int fits) =>
    split.columnCount <= math.max(1, fits);

/// Whether [row] is saved wider than the window fits.
bool isRowTooWide(BoardRow row, int fits) => !splitFits(row.split, fits);

/// [rows] with the row at [index] split as [split]. More columns add empty
/// ones to drag into; fewer append the ids of the dropped columns, in
/// order, to the last remaining one. The same split returns [rows].
List<BoardRow> changeSplit(List<BoardRow> rows, int index, RowSplit split) {
  final row = rows[index];
  if (row.split == split) return rows;

  final count = split.columnCount;
  final columns = [
    for (var c = 0; c < count; c++)
      if (c >= row.columns.length)
        <String>[]
      else if (c == count - 1)
        [for (final ids in row.columns.sublist(c)) ...ids]
      else
        [...row.columns[c]],
  ];
  return [
    ...rows.sublist(0, index),
    BoardRow(split: split, columns: columns),
    ...rows.sublist(index + 1),
  ];
}

/// [rows] with the row at [index] moved one place up (or down with
/// [down]); [rows] as they are where it cannot go further.
List<BoardRow> moveRow(List<BoardRow> rows, int index, {bool down = false}) {
  final to = down ? index + 1 : index - 1;
  if (to < 0 || to >= rows.length) return rows;
  return [...rows]
    ..[index] = rows[to]
    ..[to] = rows[index];
}

/// [rows] without the row at [index], its ids — hidden ones too, so a row
/// that looks empty keeps its hidden widgets' slots — moved to the row
/// above, at the bottom of the same column index (clamped); for the first
/// row to the top of the row below. The only row stays.
List<BoardRow> removeRow(List<BoardRow> rows, int index) {
  if (rows.length < 2) return rows;

  final removed = rows[index];
  final into = index == 0 ? 1 : index - 1;
  final target = rows[into];
  final columns = [
    for (final c in target.columns) <String>[...c],
  ];
  final moved = [for (final _ in columns) <String>[]];
  for (final (c, ids) in removed.columns.indexed) {
    moved[math.min(c, columns.length - 1)].addAll(ids);
  }

  final merged = BoardRow(
    split: target.split,
    columns: [
      for (final (c, ids) in columns.indexed)
        if (index == 0) [...moved[c], ...ids] else [...ids, ...moved[c]],
    ],
  );
  return [
    for (final (other, row) in rows.indexed)
      if (other == into) merged else if (other != index) row,
  ];
}

/// [rows] with an empty row added under the last: two equal columns, or
/// one when only one fits. Done removes it again if nothing lands in it.
List<BoardRow> addRow(List<BoardRow> rows, int fits) {
  final split = splitFits(RowSplit.halves, fits)
      ? RowSplit.halves
      : RowSplit.one;
  return [
    ...rows,
    BoardRow(
      split: split,
      columns: [for (var i = 0; i < split.columnCount; i++) <String>[]],
    ),
  ];
}
