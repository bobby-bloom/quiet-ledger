import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/app/ui/board/arrange_board.dart';
import 'package:personal_finance/app/ui/board/board_labels.dart';
import 'package:personal_finance/app/ui/board/board_menu.dart';
import 'package:personal_finance/app/ui/board/card_board.dart';
import 'package:personal_finance/core/board/board_layout.dart';
import 'package:personal_finance/core/board/board_state.dart';
import 'package:personal_finance/core/board/board_storage.dart';
import 'package:personal_finance/features/dashboard/domain/dashboard_view.dart';

import '../../../helpers/test_app.dart';

List<BoardRow> _rows(int fits) => [
  const BoardRow(
    split: RowSplit.halves,
    columns: [
      ['a', 'b'],
      ['c'],
    ],
  ),
];

/// A board of three cards, as another screen would declare it.
const _board = BoardDefinition(
  id: 'test',
  cards: ['a', 'b', 'c'],
  compactDefaults: ['a', 'c'],
  defaultRows: _rows,
);

final _labels = BoardLabels(
  menu: 'Test layout',
  menuCustom: 'Test layout · Custom',
  autoHint: 'auto',
  customHint: 'custom',
  orderAutoHint: 'order auto',
  orderCustomHint: 'order custom',
  arrangeMenu: 'Arrange cards…',
  arrangeTitle: 'Arrange cards',
  addMenu: 'Add card…',
  addTitle: 'Add card',
  emptyColumn: 'Drag a card here',
  removeFromBoard: 'Remove from test',
  notOnBoard: 'Not here',
  orderTitle: 'Order',
  resetDone: 'Reset',
  cardName: (id) => 'Card ${id.toUpperCase()}',
  cardTitle: (id) => 'Card ${id.toUpperCase()}',
  cardIcon: (_) => Icons.square_outlined,
  cardDescription: (id) => 'About $id',
);

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) => CardBoard(
        def: _board,
        labels: _labels,
        width: constraints.maxWidth - 64,
        card: (context, id, scene) =>
            Card(child: SizedBox(height: 80, child: Text('Body $id'))),
        builder: (context, scene, arrangeBar, board) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          children: [
            arrangeBar ??
                Align(
                  alignment: Alignment.centerRight,
                  child: BoardLayoutButton(
                    def: _board,
                    labels: _labels,
                    view: scene.view,
                    saved: scene.saved,
                    layout: scene.layout,
                    focusNode: scene.layoutButtonFocus,
                  ),
                ),
            board,
          ],
        ),
      ),
    ),
  );
}

void main() {
  test('a board stores its views under its own keys', () {
    expect(_board.storageKey(BoardView.expanded), 'test.expanded.v2');
    expect(
      _board.unreadableKey(BoardView.compact),
      'test.compact.v2.unreadable',
    );
    expect(_board.defaultOrder, ['a', 'c', 'b']);
    // The dashboard keeps the keys it had before boards were shared.
    expect(dashboardBoard.storageKey(BoardView.expanded), 'expanded.v2');
    expect(dashboardBoard.cards, [
      for (final t in DashboardWidgetType.values) t.name,
    ]);
  });

  testWidgets('another screen shows, arranges and saves its own board', (
    tester,
  ) async {
    final db = newTestDb();
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(const _Screen(), db: db));
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    try {
      await settle();
      // Its default rows: a and b stacked beside c.
      expect(
        tester.getTopLeft(find.text('Body c')).dx,
        greaterThan(tester.getTopLeft(find.text('Body a')).dx),
      );

      await tester.tap(find.byTooltip('Test layout'));
      await settle();
      await tester.tap(find.text('Arrange cards…'));
      await settle();
      expect(find.byType(ArrangeBoard), findsOneWidget);
      expect(find.textContaining('Drag to move'), findsOneWidget);

      await tester.tap(find.byTooltip('Move “Card C”'));
      await settle();
      await tester.tap(find.text('One column left'));
      await settle();
      await tester.tap(find.text('Done'));
      await settle();

      final context = tester.element(find.byType(_Screen));
      final repo = ProviderScope.containerOf(context)
          .read(boardRepositoryProvider);
      final saved = (await tester.runAsync(
        () => repo.read(_board, BoardView.expanded),
      ))!;
      expect(saved.mode, LayoutMode.custom);
      // "One column left" keeps its place in the column: on top.
      expect(saved.rows!.single.columns.first, ['c', 'a', 'b']);
      final rows = (await tester.runAsync(
        () => db.select(db.dashboardLayouts).get(),
      ))!;
      expect(rows.map((r) => r.breakpoint), ['test.expanded.v2']);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      unawaited(db.close());
      await tester.pump(const Duration(seconds: 1));
    }
  });
}
