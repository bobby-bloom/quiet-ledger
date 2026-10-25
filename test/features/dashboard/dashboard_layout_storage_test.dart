import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/board/board_layout.dart';
import 'package:personal_finance/core/board/board_storage.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/features/dashboard/data/dashboard_layout.dart';
import 'package:personal_finance/features/dashboard/domain/dashboard_legacy.dart';
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
      const s = emptyDashboard;
      expect(shownWidgets(s, expanded), DashboardWidgetType.values);
      expect(shownWidgets(s, compact), hasLength(6));
      expect(s.shows(compact, DashboardWidgetType.goals.name), isFalse);
      expect(s.isNew(compact, DashboardWidgetType.goals.name), isFalse);
    });

    test('removed keeps its options; new types join Auto, wait on Custom', () {
      final removed = emptyDashboard
          .withOptions(expanded, DashboardWidgetType.forecast.name, {
            'accountId': 'a',
          })
          .withVisible(
            expanded,
            DashboardWidgetType.forecast.name,
            visible: false,
          );
      expect(
        removed.shows(expanded, DashboardWidgetType.forecast.name),
        isFalse,
      );
      expect(removed.optionsOf(DashboardWidgetType.forecast.name), {
        'accountId': 'a',
      });
      expect(
        removed.isNew(expanded, DashboardWidgetType.forecast.name),
        isFalse,
      );

      // A type the last save did not know: drop its entry.
      final items = {...removed.items}..remove('goals');
      final auto = removed.copyWith(items: items);
      expect(auto.shows(expanded, DashboardWidgetType.goals.name), isTrue);
      final custom = auto.copyWith(mode: LayoutMode.custom);
      expect(custom.shows(expanded, DashboardWidgetType.goals.name), isFalse);
      expect(custom.isNew(expanded, DashboardWidgetType.goals.name), isTrue);
    });
  });

  group('v2 storage', () {
    test('round trip; unknown ids dropped, duplicates kept once', () {
      final state =
          const DashboardViewState(
            dashboardBoard,
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
          ).withOptions(expanded, DashboardWidgetType.recentTransactions.name, {
            'limit': 10,
          });
      final json = encodeViewState(expanded, state);
      final back = decodeViewState(dashboardBoard, expanded, json);
      expect(back.mode, LayoutMode.custom);
      expect(back.rows!.single.columns, [
        ['netWorth'],
        ['budgets'],
      ]);
      expect(back.optionsOf(DashboardWidgetType.recentTransactions.name), {
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
      // A newer build's widget: never shown here, but nothing of it is lost.
      final decoded = decodeViewState(dashboardBoard, expanded, withUnknown);
      expect(decoded.items.keys, ['spendingPace']);
      expect(decoded.rows!.single.columns, [
        ['spendingPace', 'goals'],
        <String>[],
      ]);
      final again = decodeViewState(
        dashboardBoard,
        expanded,
        encodeViewState(expanded, decoded),
      );
      expect(again.items['spendingPace'], const WidgetEntry());
      expect(again.rows, decoded.rows);
      expect(shownWidgets(again, expanded), isNot(contains('spendingPace')));
    });

    test('only what is malformed is skipped', () {
      final json = jsonEncode({
        'v': 2,
        'mode': 'custom',
        'items': {
          'goals': 'garbage',
          'forecast': {
            'visible': 'yes',
            'options': {'accountId': 'a'},
          },
          'accounts': {'visible': false},
        },
        'rows': [
          {
            'split': [0],
            'columns': [
              ['budgets'],
            ],
          },
          {
            'split': [1, 1],
            'columns': [
              ['netWorth', 3],
              ['forecast'],
              ['accounts'],
            ],
          },
        ],
      });
      final s = decodeViewState(dashboardBoard, expanded, json);
      expect(s.mode, LayoutMode.custom);
      expect(s.items.containsKey('goals'), isFalse);
      expect(s.optionsOf(DashboardWidgetType.forecast.name), {
        'accountId': 'a',
      });
      expect(s.shows(expanded, DashboardWidgetType.accounts.name), isFalse);
      // Extra columns join the last one, as a squeezed row does.
      expect(s.rows!.single.columns, [
        ['netWorth'],
        ['forecast', 'accounts'],
      ]);
    });

    test('malformed reads as nothing saved', () {
      expect(
        decodeViewState(dashboardBoard, expanded, '{nope'),
        emptyDashboard,
      );
      expect(
        decodeViewState(dashboardBoard, expanded, '[1, 2]'),
        emptyDashboard,
      );
    });

    test('the phone keeps its order, deduplicated, unknown ids kept', () {
      final json = encodeViewState(
        compact,
        const DashboardViewState(
          dashboardBoard,
          mode: LayoutMode.custom,
          order: ['goals', 'netWorth', 'goals', 'gone'],
        ),
      );
      expect(decodeViewState(dashboardBoard, compact, json).order, [
        'goals',
        'netWorth',
        'gone',
      ]);
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
      expect(shownWidgets(s, expanded), DashboardWidgetType.values);
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
      expect(s.optionsOf(DashboardWidgetType.accounts.name), {'limit': 3});
      expect(
        s.shows(expanded, DashboardWidgetType.upcomingBills.name),
        isFalse,
      );
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
      expect(shownWidgets(s, compact), [
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
    expect(await repo.read(compact), emptyDashboard);

    await c
        .read(syncWriterProvider)
        .insert(
          db.dashboardLayouts,
          DashboardLayoutsCompanion(
            breakpoint: const Value('compact'),
            widgets: Value(legacy([('goals', false)])),
          ),
        );
    expect(shownWidgets(await repo.read(compact), compact), [
      DashboardWidgetType.goals,
    ]);

    final next = (await repo.read(compact))
        .withVisible(compact, DashboardWidgetType.netWorth.name, visible: true);
    await repo.save(compact, next);
    expect(shownWidgets(await repo.read(compact), compact), [
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

  group('repository', () {
    late AppDatabase db;
    late DashboardLayoutRepository repo;

    setUp(() {
      db = newTestDb();
      final c = testContainer(db);
      addTearDown(c.dispose);
      addTearDown(db.close);
      repo = c.read(dashboardLayoutRepositoryProvider);
    });

    test('two changes at once both land', () async {
      await Future.wait([
        repo.update(
          expanded,
          (s) => s.withVisible(
            expanded,
            DashboardWidgetType.goals.name,
            visible: false,
          ),
        ),
        repo.update(
          expanded,
          (s) => s.withVisible(
            expanded,
            DashboardWidgetType.accounts.name,
            visible: false,
          ),
        ),
      ]);
      final s = await repo.read(expanded);
      expect(s.shows(expanded, DashboardWidgetType.goals.name), isFalse);
      expect(s.shows(expanded, DashboardWidgetType.accounts.name), isFalse);
    });

    test('an unreadable row is kept aside before a save replaces it', () async {
      await repo.save(expanded, emptyDashboard);
      final row = await db.select(db.dashboardLayouts).getSingle();
      await (db.update(db.dashboardLayouts)..where((r) => r.id.equals(row.id)))
          .write(const DashboardLayoutsCompanion(widgets: Value('[oops')));
      expect(await repo.read(expanded), emptyDashboard);
      await repo.save(
        expanded,
        emptyDashboard.copyWith(mode: LayoutMode.custom),
      );
      final rows = await db.select(db.dashboardLayouts).get();
      final kept = rows.singleWhere(
        (r) => r.breakpoint == unreadableKey(expanded),
      );
      expect(kept.widgets, '[oops');
    });

    test('two v2 rows after a sync: the newest wins, the other goes', () async {
      await repo.save(
        expanded,
        emptyDashboard.withVisible(
          expanded,
          DashboardWidgetType.goals.name,
          visible: false,
        ),
      );
      final first = await db.select(db.dashboardLayouts).getSingle();
      await db
          .into(db.dashboardLayouts)
          .insert(
            DashboardLayoutsCompanion.insert(
              id: 'other-device',
              createdAt: 1,
              updatedAt: '${first.updatedAt}z',
              originDeviceId: 'b',
              breakpoint: storageKey(expanded),
              widgets: encodeViewState(
                expanded,
                emptyDashboard.withVisible(
                  expanded,
                  DashboardWidgetType.accounts.name,
                  visible: false,
                ),
              ),
            ),
          );
      final s = await repo.read(expanded);
      expect(s.shows(expanded, DashboardWidgetType.accounts.name), isFalse);
      expect(s.shows(expanded, DashboardWidgetType.goals.name), isTrue);

      await repo.update(expanded, (s) => s.copyWith(mode: LayoutMode.custom));
      final live = await (db.select(
        db.dashboardLayouts,
      )..where((r) => r.deletedAt.isNull())).get();
      // Both rows stay where they are; the change went to the one that
      // counts, which every device picks alike.
      expect(live.map((r) => r.breakpoint).toSet(), {storageKey(expanded)});
      final changed = live.singleWhere((r) => r.id == 'other-device');
      expect(
        decodeViewState(dashboardBoard, expanded, changed.widgets).mode,
        LayoutMode.custom,
      );
      expect(live.singleWhere((r) => r.id == first.id).widgets, first.widgets);
    });

    Future<void> insertRaw(String id, String updatedAt, String widgets) => db
        .into(db.dashboardLayouts)
        .insert(
          DashboardLayoutsCompanion.insert(
            id: id,
            createdAt: 1,
            updatedAt: updatedAt,
            originDeviceId: 'x',
            breakpoint: storageKey(expanded),
            widgets: widgets,
          ),
        );

    Future<List<DashboardLayout>> live() => (db.select(
      db.dashboardLayouts,
    )..where((r) => r.deletedAt.isNull())).get();

    test('a readable row counts before a newer unreadable one, and neither '
        'is lost', () async {
      final custom = encodeViewState(
        expanded,
        DashboardViewState(
          dashboardBoard,
          mode: LayoutMode.custom,
          rows: defaultRows(2),
        ),
      );
      await insertRaw('mine', '1', custom);
      await insertRaw('broken', '2', '{"v": 3, oops');
      expect((await repo.read(expanded)).mode, LayoutMode.custom);

      // A change that alters nothing writes nothing and moves nothing.
      await repo.update(expanded, (s) => s);
      expect((await live()).length, 2);

      await repo.update(
        expanded,
        (s) => s.withVisible(
          expanded,
          DashboardWidgetType.goals.name,
          visible: false,
        ),
      );
      final rows = await live();
      final current = rows.singleWhere((r) => r.id == 'mine');
      expect(
        decodeViewState(dashboardBoard, expanded, current.widgets).rows,
        defaultRows(2),
      );
      expect(
        rows.singleWhere((r) => r.id == 'broken').widgets,
        '{"v": 3, oops',
      );
      expect(rows.map((r) => r.breakpoint).toSet(), {storageKey(expanded)});
    });

    test(
      'a value read only in part is kept aside, each distinct one once',
      () async {
        String partly(int n) => jsonEncode({
          'v': 2,
          'mode': 'custom',
          'items': {'goals': true},
          'rows': [
            {
              'split': [2.0, 1],
              'columns': [
                ['goals'],
                ['netWorth'],
              ],
            },
          ],
          'seen': [n],
        });
        expect(readsInFull(expanded, partly(1)), isFalse);
        expect(
          readsInFull(expanded, encodeViewState(expanded, emptyDashboard)),
          isTrue,
        );

        await insertRaw('row', '1', partly(1));
        await repo.update(expanded, (s) => s.copyWith(mode: LayoutMode.auto));
        final kept = [
          for (final r in await live())
            if (r.breakpoint == unreadableKey(expanded)) r.widgets,
        ];
        expect(kept, [partly(1)]);

        // Another value read only in part, later: kept too.
        await (db.update(db.dashboardLayouts)..where((r) => r.id.equals('row')))
            .write(DashboardLayoutsCompanion(widgets: Value(partly(2))));
        await repo.update(expanded, (s) => s.copyWith(mode: LayoutMode.custom));
        await repo.update(expanded, (s) => s.copyWith(mode: LayoutMode.auto));
        expect([
          for (final r in await live())
            if (r.breakpoint == unreadableKey(expanded)) r.widgets,
        ], unorderedEquals([partly(1), partly(2)]));
      },
    );

    test(
      'a field of the other view counts as unknown and is kept aside',
      () async {
        final withOrder = jsonEncode({
          'v': 2,
          'mode': 'custom',
          'items': <String, Object?>{},
          'order': ['goals', 'netWorth'],
        });
        expect(readsInFull(expanded, withOrder), isFalse);
        expect(readsInFull(compact, withOrder), isTrue);
        await insertRaw('row', '1', withOrder);
        await repo.update(expanded, (s) => s.copyWith(mode: LayoutMode.auto));
        expect(
          [
            for (final r in await live())
              if (r.breakpoint == unreadableKey(expanded)) r.widgets,
          ],
          [withOrder],
        );
      },
    );

    test('the same state in another key order is no change', () async {
      final ours = encodeViewState(expanded, emptyDashboard);
      final reordered = jsonEncode(
        Map.fromEntries(
          (jsonDecode(ours) as Map<String, Object?>).entries.toList().reversed,
        ),
      );
      await insertRaw('row', '1', reordered);
      await repo.update(expanded, (s) => s);
      expect((await live()).single.widgets, reordered);
    });
  });
}
