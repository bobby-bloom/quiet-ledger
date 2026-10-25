import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/board/board_layout.dart';
import 'package:personal_finance/features/dashboard/domain/dashboard_view.dart';

BoardRow row(List<int> split, List<List<String>> columns) =>
    BoardRow(split: RowSplit(split), columns: columns);

List<String> all = [for (final t in DashboardWidgetType.values) t.name];

void main() {
  group('fittingColumns', () {
    test('320 dp columns with 20 dp gaps', () {
      expect(fittingColumns(659), 1);
      expect(fittingColumns(660), 2);
      expect(fittingColumns(999), 2);
      expect(fittingColumns(1000), 3);
      expect(fittingColumns(100), 1);
    });
  });

  group('resolveBoardLayout', () {
    BoardLayout resolve({
      required int fits,
      LayoutMode mode = LayoutMode.auto,
      List<BoardRow>? saved,
      List<String>? present,
    }) => resolveBoardLayout(
      mode: mode,
      saved: saved,
      defaultRows: defaultRows(fits),
      present: present ?? all,
      fits: fits,
    );

    test('Auto renders the default rows at three and two columns', () {
      final three = resolve(fits: 3);
      expect(three.mode, LayoutMode.auto);
      expect(three.rows.map((r) => r.split), [
        RowSplit.wideNarrow,
        RowSplit.thirds,
        RowSplit.wideNarrow,
      ]);
      expect(three.rows.first.columns, [
        ['netWorth'],
        ['monthSummary', 'forecast'],
      ]);
      final two = resolve(fits: 2);
      expect(two.rows.map((r) => r.split.columnCount), [1, 2, 1, 2]);
      expect(two.canArrange, isTrue);
    });

    test('one column reads the two-column rows row by row, column by '
        'column', () {
      final one = resolve(fits: 1);
      expect(one.order, [
        'netWorth',
        'monthSummary',
        'budgets',
        'forecast',
        'upcomingBills',
        'recentTransactions',
        'goals',
        'accounts',
        'topCategories',
      ]);
      expect(one.canArrange, isFalse);
    });

    test('a saved row too wide is squeezed and the saved rows stay', () {
      final saved = [
        row(
          [1, 1, 1],
          [
            ['budgets'],
            ['goals'],
            ['accounts'],
          ],
        ),
      ];
      final layout = resolve(
        mode: LayoutMode.custom,
        saved: saved,
        present: ['budgets', 'goals', 'accounts'],
        fits: 2,
      );
      expect(layout.isSqueezed, isTrue);
      expect(layout.rows.single.columns, [
        ['budgets'],
        ['goals', 'accounts'],
      ]);
      expect(layout.placed, saved);
    });

    test('hidden widgets keep their slot; rows left empty disappear', () {
      final saved = [
        row(
          [1, 1],
          [
            ['budgets'],
            ['goals'],
          ],
        ),
        row(
          [1],
          [
            ['accounts'],
          ],
        ),
      ];
      final layout = resolve(
        mode: LayoutMode.custom,
        saved: saved,
        present: ['budgets'],
        fits: 3,
      );
      expect(layout.rows, [
        row(
          [1, 1],
          [
            ['budgets'],
            [],
          ],
        ),
      ]);
      expect(layout.placed.expand((r) => r.cardIds), contains('goals'));
    });

    test('a widget without a slot goes after its nearest default '
        'predecessor', () {
      final saved = [
        row(
          [1, 1],
          [
            ['netWorth', 'budgets'],
            ['upcomingBills'],
          ],
        ),
      ];
      // monthSummary comes after netWorth in the default reading order.
      final layout = resolve(
        mode: LayoutMode.custom,
        saved: saved,
        present: ['netWorth', 'budgets', 'upcomingBills', 'monthSummary'],
        fits: 3,
      );
      expect(layout.rows.single.columns.first, [
        'netWorth',
        'monthSummary',
        'budgets',
      ]);
    });
  });

  group('columnWidths', () {
    test('share by weight with gaps', () {
      expect(columnWidths(RowSplit.thirds, 1040), [
        moreOrLessEquals(333.33, epsilon: 0.01),
        moreOrLessEquals(333.33, epsilon: 0.01),
        moreOrLessEquals(333.33, epsilon: 0.01),
      ]);
    });

    test('2:1 leans towards equal rather than going under 320 dp', () {
      final widths = columnWidths(RowSplit.wideNarrow, 700);
      expect(widths.last, 320);
      expect(widths.first, 360);
    });
  });

  test('dealRow balances in reading order', () {
    expect(dealRow(all, 3).columns.map((c) => c.length), [3, 3, 3]);
    expect(dealRow(all, 2).columns.map((c) => c.length), [5, 4]);
    expect(dealRow(all, 2).columns.first.first, 'netWorth');
  });

  test('moveInOrder keeps hidden ids in place', () {
    expect(moveInOrder(['a', 'h', 'b', 'c'], ['a', 'b', 'c'], 'c', 0), [
      'c',
      'a',
      'h',
      'b',
    ]);
    expect(moveInOrder(['a', 'h', 'b', 'c'], ['a', 'b', 'c'], 'a', 2), [
      'h',
      'b',
      'c',
      'a',
    ]);
  });

  group('Layout control', () {
    final equal = [dealRow(all, 2)];
    final multi = defaultRows(3);

    test('selected segment', () {
      expect(selectedSegment(LayoutMode.auto, multi), LayoutSegment.auto);
      expect(selectedSegment(LayoutMode.custom, equal), LayoutSegment.two);
      expect(selectedSegment(LayoutMode.custom, multi), LayoutSegment.custom);
    });

    test('Custom only for several rows or an unequal split', () {
      expect(offersCustom(null), isFalse);
      expect(offersCustom(equal), isFalse);
      expect(offersCustom(multi), isTrue);
      expect(
        offersCustom([
          row(
            [2, 1],
            [
              ['a'],
              ['b'],
            ],
          ),
        ]),
        isTrue,
      );
    });
  });
}
