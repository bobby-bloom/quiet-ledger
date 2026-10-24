import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/features/dashboard/data/dashboard_layout.dart';
import 'package:personal_finance/features/dashboard/domain/board_layout.dart';
import 'package:personal_finance/features/dashboard/domain/dashboard_view.dart';

import '../../helpers/test_app.dart';

const compact = DashboardView.compact;
const expanded = DashboardView.expanded;

String legacy(List<(String, bool)> cards) => jsonEncode([
  for (final (type, wide) in cards)
    {'type': type, 'size': wide ? 'wide' : 'normal'},
]);

void main() {
  group('what shows', () {
    test('nothing saved: the defaults of each view', () {
      const s = DashboardViewState.empty;
      expect(s.shown(expanded), DashboardWidgetType.values);
      expect(s.shown(compact), hasLength(6));
      expect(s.shows(compact, DashboardWidgetType.goals), isFalse);
      expect(s.isNew(compact, DashboardWidgetType.goals), isFalse);
    });

    test('removed keeps its options; new types join Auto, wait on Custom', () {
      final removed = DashboardViewState.empty
          .withOptions(expanded, DashboardWidgetType.forecast, {
            'accountId': 'a',
          })
          .withVisible(expanded, DashboardWidgetType.forecast, visible: false);
      expect(removed.shows(expanded, DashboardWidgetType.forecast), isFalse);
      expect(removed.optionsOf(DashboardWidgetType.forecast), {
        'accountId': 'a',
      });
      expect(removed.isNew(expanded, DashboardWidgetType.forecast), isFalse);

      // A type the last save did not know: drop its entry.
      final items = {...removed.items}..remove('goals');
      final auto = removed.copyWith(items: items);
      expect(auto.shows(expanded, DashboardWidgetType.goals), isTrue);
      final custom = auto.copyWith(mode: LayoutMode.custom);
      expect(custom.shows(expanded, DashboardWidgetType.goals), isFalse);
      expect(custom.isNew(expanded, DashboardWidgetType.goals), isTrue);
    });
  });

  group('v2 storage', () {
    test('round trip; unknown ids dropped, duplicates kept once', () {
      final state =
          const DashboardViewState(
            mode: LayoutMode.custom,
            rows: [
              BoardRow(
                split: RowSplit.wideNarrow,
                columns: [
                  ['netWorth'],
                  ['budgets', 'netWorth'],
                ],
              ),
            ],
          ).withOptions(expanded, DashboardWidgetType.recentTransactions, {
            'limit': 10,
          });
      final json = encodeViewState(expanded, state);
      final back = decodeViewState(expanded, json);
      expect(back.mode, LayoutMode.custom);
      expect(back.rows!.single.columns, [
        ['netWorth'],
        ['budgets'],
      ]);
      expect(back.optionsOf(DashboardWidgetType.recentTransactions), {
        'limit': 10,
      });
      expect(back.items.keys, hasLength(DashboardWidgetType.values.length));

      final withUnknown = jsonEncode({
        'v': 2,
        'mode': 'custom',
        'items': {
          'spendingPace': {'visible': true},
        },
        'rows': [
          {
            'split': [1, 1],
            'columns': [
              ['spendingPace', 'goals'],
              ['goals'],
            ],
          },
        ],
      });
      final decoded = decodeViewState(expanded, withUnknown);
      expect(decoded.items, isEmpty);
      expect(decoded.rows!.single.columns, [
        ['goals'],
        <String>[],
      ]);
    });

    test('malformed reads as nothing saved', () {
      expect(decodeViewState(expanded, '{nope'), DashboardViewState.empty);
      expect(decodeViewState(expanded, '[1, 2]'), DashboardViewState.empty);
      expect(
        decodeViewState(
          expanded,
          '{"rows": [{"split": [0], "columns": [[]]}]}',
        ),
        DashboardViewState.empty,
      );
    });

    test('the phone keeps its order, deduplicated', () {
      final json = encodeViewState(
        compact,
        const DashboardViewState(
          mode: LayoutMode.custom,
          order: ['goals', 'netWorth', 'goals', 'gone'],
        ),
      );
      expect(decodeViewState(compact, json).order, ['goals', 'netWorth']);
    });
  });

  group('0.1 migration', () {
    test('the old default goes to Auto', () {
      final s = migrateLegacyLayout(
        expanded,
        legacy([
          ('netWorth', true),
          ('monthSummary', false),
          ('budgets', false),
          ('upcomingBills', false),
          ('forecast', false),
          ('recentTransactions', true),
          ('goals', false),
          ('topCategories', false),
          ('accounts', false),
        ]),
      );
      expect(s.mode, LayoutMode.auto);
      expect(s.shown(expanded), DashboardWidgetType.values);
    });

    test('a saved wide list is packed as the grid did at three columns', () {
      final s = migrateLegacyLayout(
        expanded,
        jsonEncode([
          {'type': 'recentTransactions', 'size': 'wide'},
          {'type': 'goals', 'size': 'normal'},
          {'type': 'budgets', 'size': 'normal'},
          {'type': 'netWorth', 'size': 'wide'},
          {'type': 'netWorth', 'size': 'normal'},
          {'type': 'forecast', 'size': 'wide'},
          {
            'type': 'accounts',
            'size': 'normal',
            'options': {'limit': 3},
          },
          {'type': 'nope', 'size': 'normal'},
        ]),
      );
      expect(s.mode, LayoutMode.custom);
      expect(s.rows, [
        const BoardRow(
          split: RowSplit.wideNarrow,
          columns: [
            ['recentTransactions'],
            ['goals'],
          ],
        ),
        const BoardRow(
          split: RowSplit.narrowWide,
          columns: [
            ['budgets'],
            ['netWorth'],
          ],
        ),
        const BoardRow(
          split: RowSplit.wideNarrow,
          columns: [
            ['forecast'],
            ['accounts'],
          ],
        ),
      ]);
      expect(s.optionsOf(DashboardWidgetType.accounts), {'limit': 3});
      expect(s.shows(expanded, DashboardWidgetType.upcomingBills), isFalse);
    });

    test('short rows: a lone wide card alone, normal ones keep a third', () {
      expect(packAtThreeColumns([('a', true), ('b', true)]), [
        singleColumnRow(['a']),
        singleColumnRow(['b']),
      ]);
      expect(packAtThreeColumns([('a', false), ('b', false)]), [
        const BoardRow(
          split: RowSplit.thirds,
          columns: [
            ['a'],
            ['b'],
            <String>[],
          ],
        ),
      ]);
    });

    test('a saved phone list becomes the custom order', () {
      final s = migrateLegacyLayout(
        compact,
        legacy([('goals', false), ('netWorth', false)]),
      );
      expect(s.mode, LayoutMode.custom);
      expect(s.order!.take(2), ['goals', 'netWorth']);
      expect(s.shown(compact), [
        DashboardWidgetType.netWorth,
        DashboardWidgetType.goals,
      ]);
    });
  });

  test('repository: the 0.1 row is read until a v2 row is written, then '
      'left alone', () async {
    final db = newTestDb();
    addTearDown(db.close);
    final c = testContainer(db);
    addTearDown(c.dispose);
    final repo = c.read(dashboardLayoutRepositoryProvider);
    expect(await repo.read(compact), DashboardViewState.empty);

    await c
        .read(syncWriterProvider)
        .insert(
          db.dashboardLayouts,
          DashboardLayoutsCompanion(
            breakpoint: const Value('compact'),
            widgets: Value(legacy([('goals', false)])),
          ),
        );
    expect((await repo.read(compact)).shown(compact), [
      DashboardWidgetType.goals,
    ]);

    final next = (await repo.read(compact))
        .withVisible(compact, DashboardWidgetType.netWorth, visible: true);
    await repo.save(compact, next);
    expect((await repo.read(compact)).shown(compact), [
      DashboardWidgetType.netWorth,
      DashboardWidgetType.goals,
    ]);
    final rows = await db.select(db.dashboardLayouts).get();
    expect(
      rows.map((r) => r.breakpoint),
      unorderedEquals(['compact', 'compact.v2']),
    );
    expect(
      rows.firstWhere((r) => r.breakpoint == 'compact').widgets,
      legacy([('goals', false)]),
    );
  });
}
