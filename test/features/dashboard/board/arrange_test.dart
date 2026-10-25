import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/dashboard/domain/arrange.dart';
import 'package:personal_finance/features/dashboard/domain/board_layout.dart';

BoardRow row(List<int> split, List<List<String>> columns) =>
    BoardRow(split: RowSplit(split), columns: columns);

void main() {
  // Row 0: [a, b] | [c]; row 1: [d] | [e] | [f].
  final rows = [
    row(
      [1, 1],
      [
        ['a', 'b'],
        ['c'],
      ],
    ),
    row(
      [1, 1, 1],
      [
        ['d'],
        ['e'],
        ['f'],
      ],
    ),
  ];
  final present = {'a', 'b', 'c', 'd', 'e', 'f'};

  group('Move menu', () {
    Set<CardMove> moves(String id, {int fits = 3}) =>
        possibleMoves(rows, id, present: present, fits: fits);

    test('moves that apply at the edges', () {
      expect(moves('a'), {CardMove.down, CardMove.end});
      expect(moves('f'), {CardMove.up, CardMove.start});
      expect(moves('e'), {CardMove.up, CardMove.start, CardMove.end});
    });

    test('Up from the top of a column lands at the bottom of the row '
        'above, the column clamped', () {
      final target = moveTarget(
        rows,
        'f',
        CardMove.up,
        present: present,
        fits: 3,
      );
      expect(target, const ColumnTarget(row: 0, column: 1, index: 1));
      final moved = dropCard(rows, 'f', target!, present: present, fits: 3);
      expect(moved.first.columns[1], ['c', 'f']);
      expect(moved.last.columns[2], isEmpty);
    });

    test('Down from the bottom lands at the top of the row below', () {
      final target = moveTarget(
        rows,
        'b',
        CardMove.down,
        present: present,
        fits: 3,
      );
      expect(target, const ColumnTarget(row: 1, column: 0, index: 0));
      final moved = dropCard(rows, 'b', target!, present: present, fits: 3);
      expect(moved.last.columns.first, ['b', 'd']);
    });

    test('Right keeps the index, clamped', () {
      final target = moveTarget(
        rows,
        'b',
        CardMove.end,
        present: present,
        fits: 3,
      );
      expect(target, const ColumnTarget(row: 0, column: 1, index: 1));
    });
  });

  group('dropCard', () {
    test('a drop back in place returns the rows as they are', () {
      final same = dropCard(
        rows,
        'b',
        const ColumnTarget(row: 0, column: 0, index: 1),
        present: present,
        fits: 3,
      );
      expect(identical(same, rows), isTrue);
    });

    test('a new row between rows holds the widget alone', () {
      final moved = dropCard(
        rows,
        'c',
        const NewRowTarget(1),
        present: present,
        fits: 3,
      );
      expect(moved.length, 3);
      expect(moved[1], singleColumnRow(['c']));
      expect(moved.first.columns[1], isEmpty);
    });

    test('into a squeezed last column it takes over the columns it stands '
        'for', () {
      final moved = dropCard(
        rows,
        'a',
        const ColumnTarget(row: 1, column: 1, index: 0),
        present: present,
        fits: 2,
      );
      expect(moved.last.columns, [
        ['d'],
        ['a', 'e', 'f'],
        <String>[],
      ]);
    });

    test('hidden widgets keep their slot when a visible one moves past', () {
      final withHidden = [
        row(
          [1],
          [
            ['a', 'h', 'b'],
          ],
        ),
      ];
      final moved = dropCard(
        withHidden,
        'a',
        const ColumnTarget(row: 0, column: 0, index: 1),
        present: {'a', 'b'},
        fits: 3,
      );
      expect(moved.single.columns.single, ['h', 'b', 'a']);
    });
  });

  group('row edits', () {
    test('more columns add empty ones; fewer append to the last', () {
      final wider = changeSplit(rows, 0, RowSplit.thirds);
      expect(wider.first.columns, [
        ['a', 'b'],
        ['c'],
        <String>[],
      ]);
      final narrower = changeSplit(rows, 1, RowSplit.one);
      expect(narrower.last.columns, [
        ['d', 'e', 'f'],
      ]);
    });

    test('remove row moves its widgets up; the first row moves down', () {
      final removed = removeRow(rows, 1);
      expect(removed.single.columns, [
        ['a', 'b', 'd'],
        ['c', 'e', 'f'],
      ]);
      final first = removeRow(rows, 0);
      expect(first.single.columns, [
        ['a', 'b', 'd'],
        ['c', 'e'],
        ['f'],
      ]);
      expect(removeRow([rows.first], 0), [rows.first]);
    });

    test('add row is 1:1, or 1 when one column fits', () {
      expect(addRow(rows, 3).last.split, RowSplit.halves);
      expect(addRow(rows, 1).last.split, RowSplit.one);
    });

    test('Done drops empty rows and unknown ids, keeps empty columns', () {
      final finished = finishedRows([
        ...rows,
        row([1, 1], [<String>[], <String>[]]),
        row(
          [1],
          [
            ['gone'],
          ],
        ),
      ], present);
      expect(finished, rows);
      expect(
        finishedRows([
          row(
            [1, 1],
            [
              ['a'],
              <String>[],
            ],
          ),
        ], present).single.columns,
        [
          ['a'],
          <String>[],
        ],
      );
    });

    test('duplicates keep their first slot', () {
      final dup = withoutDuplicates([
        row(
          [1, 1],
          [
            ['a', 'b'],
            ['a'],
          ],
        ),
      ]);
      expect(dup.single.columns, [
        ['a', 'b'],
        <String>[],
      ]);
    });
  });

  test('moveRowTo: gaps counted before the row is taken out', () {
    final three = [
      for (final id in ['a', 'b', 'c']) singleColumnRow([id]),
    ];
    List<String> ids(List<BoardRow> rows) => [
      for (final r in rows) r.cardIds.single,
    ];
    expect(ids(moveRowTo(three, 2, 0)), ['c', 'a', 'b']);
    expect(ids(moveRowTo(three, 0, 3)), ['b', 'c', 'a']);
    expect(ids(moveRowTo(three, 0, 2)), ['b', 'a', 'c']);
    // Next to itself, or out of range: as they are.
    expect(identical(moveRowTo(three, 1, 1), three), isTrue);
    expect(identical(moveRowTo(three, 1, 2), three), isTrue);
    expect(identical(moveRowTo(three, 5, 0), three), isTrue);
  });
}
