import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/features/dashboard/data/dashboard_layout.dart';
import 'package:personal_finance/features/dashboard/domain/board_layout.dart';
import 'package:personal_finance/features/dashboard/domain/dashboard_view.dart';
import 'package:personal_finance/features/dashboard/presentation/board/arrange_board.dart';
import 'package:personal_finance/features/dashboard/presentation/board/arrange_card.dart';
import 'package:personal_finance/features/dashboard/presentation/dashboard_screen.dart';
import 'package:personal_finance/features/dashboard/presentation/phone_editor_sheet.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_providers.dart';

import '../../helpers/test_app.dart';

/// Loads Manrope, the app's font, as the screenshot tool does.
Future<void> loadAppFonts() async {
  Future<void> load(String family, String file) async {
    final loader = FontLoader(family)
      ..addFont(
        Future.value(ByteData.sublistView(File(file).readAsBytesSync())),
      );
    await loader.load();
  }

  await load('Manrope', 'assets/fonts/Manrope.ttf');
}

void main() {
  late AppDatabase db;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    unawaited(db.close());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<DashboardLayoutRepository> pumpAt(
    WidgetTester tester,
    Size size, {
    Locale locale = const Locale('en'),
    double textScale = 1,
    Future<void> Function()? seed,
  }) async {
    db = newTestDb();
    if (seed != null) await tester.runAsync(seed);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: const DashboardScreen(),
          ),
        ),
        db: db,
        locale: locale,
        overrides: [
          forecastRunnerProvider.overrideWithValue(
            const ForecastRunner.inline(),
          ),
        ],
      ),
    );
    await settle(tester);
    final context = tester.element(find.byType(DashboardScreen));
    final repo = ProviderScope.containerOf(context)
        .read(dashboardLayoutRepositoryProvider);
    return repo;
  }

  Future<DashboardViewState> saved(
    WidgetTester tester,
    DashboardLayoutRepository repo,
    DashboardView view,
  ) async => (await tester.runAsync(() => repo.read(view)))!;

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.dashboard_customize_outlined).first);
    await settle(tester);
  }

  Finder segment(String label) => find.descendant(
    of: find.byType(SegmentedButton<LayoutSegment>),
    matching: find.text(label),
  );

  Finder arrangeCard(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(ArrangeCard));

  const wide = Size(1440, 1100);

  testWidgets('a column count deals the widgets into one row; picking '
      'another over it offers Undo', (tester) async {
    try {
      final repo = await pumpAt(tester, wide);
      await openMenu(tester);
      await tester.tap(segment('2'));
      await settle(tester);
      var state = await saved(tester, repo, DashboardView.expanded);
      expect(state.mode, LayoutMode.custom);
      expect(state.rows!.single.split, RowSplit.halves);
      expect(find.text('Layout set to 2 columns'), findsNothing);

      // The menu stays open: the control shows what is on screen.
      await tester.tap(segment('3'));
      await settle(tester);
      expect(find.text('Layout set to 3 columns'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      state = await saved(tester, repo, DashboardView.expanded);
      expect(state.rows!.single.split, RowSplit.halves);

      // Auto keeps the saved layout; its number brings it back.
      await openMenu(tester);
      await tester.tap(segment('Auto'));
      await settle(tester);
      state = await saved(tester, repo, DashboardView.expanded);
      expect(state.mode, LayoutMode.auto);
      expect(state.rows, isNotNull);
      expect(tester.takeException(), isNull);
    } finally {
      await teardown(tester);
    }
  });

  testWidgets('arrange: Move, Remove inside the session, Cancel with Undo, '
      'Done writes the rows', (tester) async {
    try {
      final repo = await pumpAt(tester, wide);
      await openMenu(tester);
      await tester.tap(find.text('Arrange widgets…'));
      await settle(tester);
      expect(find.byType(ArrangeBoard), findsOneWidget);
      expect(find.textContaining('Drag to move'), findsOneWidget);

      // Goal progress sits in row 2, column 3; move it one column left.
      await tester.tap(find.byTooltip('Move “Goal progress”'));
      await settle(tester);
      await tester.tap(find.text('One column left'));
      await settle(tester);
      expect(
        tester.getRect(arrangeCard('Goal progress')).left,
        moreOrLessEquals(
          tester.getRect(arrangeCard('Upcoming bills')).left,
          epsilon: 1,
        ),
      );

      // Cancel discards, Undo comes back with the work.
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.byType(ArrangeBoard), findsNothing);
      expect(
        (await saved(tester, repo, DashboardView.expanded)).mode,
        LayoutMode.auto,
      );
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(find.byType(ArrangeBoard), findsOneWidget);

      // Remove inside the session, then Done.
      await tester.tap(find.byTooltip('Move “Top categories”'));
      await settle(tester);
      await tester.tap(find.text('Remove from dashboard'));
      await settle(tester);
      expect(arrangeCard('Top categories'), findsNothing);
      await tester.tap(find.text('Done'));
      await settle(tester);
      expect(find.byType(ArrangeBoard), findsNothing);
      final state = await saved(tester, repo, DashboardView.expanded);
      expect(state.mode, LayoutMode.custom);
      expect(state.rows![1].columns[1], ['goals', 'upcomingBills']);
      expect(
        state.shows(DashboardView.expanded, DashboardWidgetType.topCategories),
        isFalse,
      );
      // Its slot stays for when it comes back.
      expect(state.rows!.expand((r) => r.cardIds), contains('topCategories'));
      expect(tester.takeException(), isNull);
    } finally {
      await teardown(tester);
    }
  });

  testWidgets('arrange: a drag moves a widget to another column and into a '
      'new row', (tester) async {
    try {
      final repo = await pumpAt(tester, wide);
      await openMenu(tester);
      await tester.tap(find.text('Arrange widgets…'));
      await settle(tester);

      Future<void> drag(String title, Offset to) async {
        final gesture = await tester.startGesture(
          tester.getCenter(arrangeCard(title)),
        );
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.moveTo(to);
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.moveTo(to + const Offset(0, 1));
        await tester.pump(const Duration(milliseconds: 300));
        await gesture.up();
        await settle(tester);
      }

      // Budget progress (row 2, column 1) onto the bottom of Goals' column.
      final goals = tester.getRect(arrangeCard('Goal progress'));
      await drag('Budget progress', goals.center + const Offset(0, 12));
      expect(
        tester.getRect(arrangeCard('Budget progress')).left,
        moreOrLessEquals(goals.left, epsilon: 1),
      );

      // Accounts into the gap above the first row: a new first row.
      final firstBand = tester.getRect(arrangeCard('Net worth'));
      await drag('Accounts', Offset(firstBand.center.dx, firstBand.top - 60));
      await tester.tap(find.text('Done'));
      await settle(tester);
      final rows = (await saved(tester, repo, DashboardView.expanded)).rows!;
      expect(rows.first, singleColumnRow(['accounts']));
      expect(rows[2].columns[2], ['goals', 'budgets']);
      expect(tester.takeException(), isNull);
    } finally {
      await teardown(tester);
    }
  });

  testWidgets('a screen-reader action moves a widget', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await pumpAt(tester, wide);
      await openMenu(tester);
      await tester.tap(find.text('Arrange widgets…'));
      await settle(tester);
      final node = tester.getSemantics(arrangeCard('Goal progress'));
      expect(node.label, 'Goal progress: row 2, column 3, position 1 of 1');
      final down = node
          .getSemanticsData()
          .customSemanticsActionIds!
          .map(CustomSemanticsAction.getAction)
          .firstWhere((a) => a!.label == 'Down')!;
      tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.customAction,
        CustomSemanticsAction.getIdentifier(down),
      );
      await settle(tester);
      expect(
        tester.getSemantics(arrangeCard('Goal progress')).label,
        'Goal progress: row 3, column 2, position 1 of 3',
      );
    } finally {
      handle.dispose();
      await teardown(tester);
    }
  });

  testWidgets('Remove from a card menu keeps its options; Undo and Add '
      'bring it back in its slot', (tester) async {
    try {
      final repo = await pumpAt(tester, wide);
      await tester.runAsync(() async {
        final s = await repo.read(DashboardView.expanded);
        await repo.save(
          DashboardView.expanded,
          s.withOptions(DashboardView.expanded, DashboardWidgetType.forecast, {
            'accountId': 'acc-1',
          }),
        );
      });
      await settle(tester);

      Future<void> remove() async {
        final forecast = find.ancestor(
          of: find.textContaining('Forecast').first,
          matching: find.byType(Card),
        );
        await tester.tap(
          find.descendant(of: forecast, matching: find.byIcon(Icons.more_vert)),
        );
        await settle(tester);
        await tester.tap(find.text('Remove').last);
        await settle(tester);
      }

      await remove();
      expect(find.text('Mini forecast removed'), findsOneWidget);
      var state = await saved(tester, repo, DashboardView.expanded);
      expect(
        state.shows(DashboardView.expanded, DashboardWidgetType.forecast),
        isFalse,
      );
      await tester.tap(find.text('Undo'));
      await settle(tester);
      state = await saved(tester, repo, DashboardView.expanded);
      expect(
        state.shows(DashboardView.expanded, DashboardWidgetType.forecast),
        isTrue,
      );

      await remove();
      await openMenu(tester);
      await tester.tap(find.text('Add widget…'));
      await settle(tester);
      expect(
        find.textContaining('Removed · its settings are kept'),
        findsOneWidget,
      );
      await tester.tap(find.text('Mini forecast'));
      await settle(tester);
      state = await saved(tester, repo, DashboardView.expanded);
      expect(
        state.shows(DashboardView.expanded, DashboardWidgetType.forecast),
        isTrue,
      );
      expect(state.optionsOf(DashboardWidgetType.forecast), {
        'accountId': 'acc-1',
      });
      // Back under the month summary, where Auto puts it.
      final month = tester.getRect(find.textContaining('so far').first);
      final forecast = tester.getRect(find.textContaining('Forecast').first);
      expect(forecast.left, moreOrLessEquals(month.left, epsilon: 1));
      expect(tester.takeException(), isNull);
    } finally {
      await teardown(tester);
    }
  });

  testWidgets('phone sheet: ▲ ▼ reorder, Remove and Add apply at once, '
      'Auto goes back', (tester) async {
    try {
      final repo = await pumpAt(tester, const Size(390, 844));
      await tester.tap(find.byTooltip('Dashboard layout'));
      await settle(tester);
      expect(find.byType(PhoneEditorSheet), findsOneWidget);

      await tester.tap(find.byTooltip('Move “Month summary” up'));
      await settle(tester);
      var state = await saved(tester, repo, DashboardView.compact);
      expect(state.mode, LayoutMode.custom);
      expect(state.order!.take(2), ['monthSummary', 'netWorth']);

      await tester.tap(find.byTooltip('Remove “Mini forecast · All accounts”'));
      await settle(tester);
      expect(find.text('Not on your dashboard'), findsOneWidget);
      final addGoals = find.descendant(
        of: find.ancestor(
          of: find.text('Goal progress'),
          matching: find.byType(ListTile),
        ),
        matching: find.text('Add'),
      );
      await tester.ensureVisible(addGoals);
      await settle(tester);
      await tester.tap(addGoals);
      await settle(tester);
      state = await saved(tester, repo, DashboardView.compact);
      expect(
        state.shown(DashboardView.compact),
        containsAll([DashboardWidgetType.goals]),
      );
      expect(
        state.shows(DashboardView.compact, DashboardWidgetType.forecast),
        isFalse,
      );

      final auto = find.descendant(
        of: find.byType(SegmentedButton<LayoutMode>),
        matching: find.text('Auto'),
      );
      await tester.ensureVisible(auto);
      await settle(tester);
      await tester.tap(auto);
      await settle(tester);
      state = await saved(tester, repo, DashboardView.compact);
      expect(state.mode, LayoutMode.auto);
      expect(state.order, isNotNull);
      expect(tester.takeException(), isNull);
    } finally {
      await teardown(tester);
    }
  });

  // From keeper's review findings on the code ported here.
  group('arrange, review checklist', () {
    Future<void> enterArrange(WidgetTester tester) async {
      await openMenu(tester);
      await tester.tap(find.text('Arrange widgets…'));
      await settle(tester);
    }

    testWidgets('a widget let go without moving stays; Done from Auto then '
        'saves nothing', (tester) async {
      try {
        final repo = await pumpAt(tester, wide);
        await enterArrange(tester);
        final before = tester.getRect(arrangeCard('Budget progress'));
        final gesture = await tester.startGesture(before.center);
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.up();
        await settle(tester);
        expect(tester.getRect(arrangeCard('Budget progress')), before);
        await tester.tap(find.text('Done'));
        await settle(tester);
        final state = await saved(tester, repo, DashboardView.expanded);
        expect(state, DashboardViewState.empty);
        expect(tester.takeException(), isNull);
      } finally {
        await teardown(tester);
      }
    });

    testWidgets('one drag at a time: a second finger lifts nothing', (
      tester,
    ) async {
      try {
        await pumpAt(tester, wide);
        await enterArrange(tester);
        final goals = tester.getRect(arrangeCard('Goal progress'));
        final accounts = tester.getRect(arrangeCard('Accounts'));
        final first = await tester.startGesture(
          tester.getCenter(arrangeCard('Budget progress')),
        );
        await first.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 50));
        final second = await tester.startGesture(accounts.center, pointer: 7);
        await second.moveBy(const Offset(-300, 0));
        await tester.pump(const Duration(milliseconds: 50));
        await first.moveTo(goals.center + const Offset(0, 12));
        await tester.pump(const Duration(milliseconds: 300));
        await second.up();
        await first.up();
        await settle(tester);
        // Still in its column (the row below grew with Budget progress).
        expect(tester.getRect(arrangeCard('Accounts')).left, accounts.left);
        expect(
          tester.getRect(arrangeCard('Budget progress')).left,
          moreOrLessEquals(goals.left, epsilon: 1),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await teardown(tester);
      }
    });

    testWidgets('a window too narrow pauses the session mid-drag; it '
        'resumes with the work kept', (tester) async {
      try {
        await pumpAt(tester, wide);
        await enterArrange(tester);
        await tester.tap(find.byTooltip('Move “Goal progress”'));
        await settle(tester);
        await tester.tap(find.text('One column left'));
        await settle(tester);
        final gesture = await tester.startGesture(
          tester.getCenter(arrangeCard('Accounts')),
        );
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump(const Duration(milliseconds: 50));

        tester.view.physicalSize = const Size(700, 1100);
        await settle(tester);
        await gesture.up();
        await settle(tester);
        expect(find.byType(ArrangeBoard), findsNothing);
        expect(find.textContaining('Drag to move'), findsNothing);

        tester.view.physicalSize = wide;
        await settle(tester);
        expect(find.byType(ArrangeBoard), findsOneWidget);
        expect(
          tester.getRect(arrangeCard('Goal progress')).left,
          moreOrLessEquals(
            tester.getRect(arrangeCard('Upcoming bills')).left,
            epsilon: 1,
          ),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await teardown(tester);
      }
    });

    testWidgets('a paused session goes when its saved layout changes', (
      tester,
    ) async {
      try {
        final repo = await pumpAt(tester, wide);
        await enterArrange(tester);
        tester.view.physicalSize = const Size(700, 1100);
        await settle(tester);
        await tester.runAsync(
          () => repo.save(
            DashboardView.expanded,
            DashboardViewState.empty.copyWith(mode: LayoutMode.custom),
          ),
        );
        await settle(tester);
        tester.view.physicalSize = wide;
        await settle(tester);
        expect(find.byType(ArrangeBoard), findsNothing);
      } finally {
        await teardown(tester);
      }
    });
  });

  // Regressions from the independent review.
  group('review fixes', () {
    Future<void> enterArrange(WidgetTester tester) async {
      await openMenu(tester);
      await tester.tap(find.text('Arrange widgets…'));
      await settle(tester);
    }

    Future<void> moveGoalsLeft(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Move “Goal progress”'));
      await settle(tester);
      await tester.tap(find.text('One column left'));
      await settle(tester);
    }

    testWidgets('Done from Auto over a saved layout offers Undo, also when '
        'the bar is gone before the write ends', (tester) async {
      try {
        final repo = await pumpAt(tester, wide);
        await openMenu(tester);
        await tester.tap(segment('2'));
        await settle(tester);
        await tester.tap(segment('Auto'));
        await settle(tester);
        await tester.tapAt(const Offset(5, 5));
        await settle(tester);
        final saved2 = (await saved(tester, repo, DashboardView.expanded)).rows;

        await enterArrange(tester);
        await moveGoalsLeft(tester);
        await tester.tap(find.text('Done'));
        await tester.pump();
        await settle(tester);
        expect(find.text('Layout replaced'), findsOneWidget);
        await tester.tap(find.text('Undo'));
        await settle(tester);
        final state = await saved(tester, repo, DashboardView.expanded);
        expect(state.mode, LayoutMode.auto);
        expect(state.rows, saved2);
      } finally {
        await teardown(tester);
      }
    });

    testWidgets('a type that shows on Auto without an entry stays shown '
        'after Done', (tester) async {
      try {
        final repo = await pumpAt(
          tester,
          wide,
          // As if accounts shipped after this save: no entry for it.
          seed: () => db
              .into(db.dashboardLayouts)
              .insert(
                DashboardLayoutsCompanion.insert(
                  id: 'row',
                  createdAt: 1,
                  updatedAt: '1',
                  originDeviceId: 'test-device',
                  breakpoint: storageKey(DashboardView.expanded),
                  widgets: encodeViewState(
                    DashboardView.expanded,
                    DashboardViewState.empty,
                  ).replaceFirst('"accounts":{"visible":true},', ''),
                ),
              ),
        );
        await settle(tester);
        expect(
          (await saved(
            tester,
            repo,
            DashboardView.expanded,
          )).items.containsKey('accounts'),
          isFalse,
        );
        await enterArrange(tester);
        await moveGoalsLeft(tester);
        await tester.tap(find.text('Done'));
        await settle(tester);
        final state = await saved(tester, repo, DashboardView.expanded);
        expect(state.mode, LayoutMode.custom);
        expect(
          state.shows(DashboardView.expanded, DashboardWidgetType.accounts),
          isTrue,
        );
      } finally {
        await teardown(tester);
      }
    });

    testWidgets('Done on Custom without a change keeps what changed '
        'meanwhile', (tester) async {
      try {
        final repo = await pumpAt(tester, wide);
        await openMenu(tester);
        await tester.tap(segment('2'));
        await settle(tester);
        await tester.tapAt(const Offset(5, 5));
        await settle(tester);
        await enterArrange(tester);
        await tester.runAsync(
          () => repo.update(
            DashboardView.expanded,
            (s) => s.withOptions(
              DashboardView.expanded,
              DashboardWidgetType.forecast,
              {'accountId': 'acc-2'},
            ),
          ),
        );
        await settle(tester);
        await tester.tap(find.text('Done'));
        await settle(tester);
        final state = await saved(tester, repo, DashboardView.expanded);
        expect(state.optionsOf(DashboardWidgetType.forecast), {
          'accountId': 'acc-2',
        });
      } finally {
        await teardown(tester);
      }
    });

    testWidgets('Remove in arrange mode puts focus on the next widget', (
      tester,
    ) async {
      try {
        await pumpAt(tester, wide);
        await enterArrange(tester);
        await tester.tap(find.byTooltip('Move “Upcoming bills”'));
        await settle(tester);
        await tester.tap(find.text('Remove from dashboard'));
        await settle(tester);
        final focused = FocusManager.instance.primaryFocus;
        expect(focused?.debugLabel, 'move goals');
      } finally {
        await teardown(tester);
      }
    });

    for (final (scale, locale) in [
      (2.0, const Locale('de')),
      (1.5, const Locale('de')),
      (2.0, const Locale('en')),
    ]) {
      testWidgets('the arrange bar fits at ${scale}x text '
          '(${locale.languageCode})', (tester) async {
        // The test font draws every glyph a full em wide; widths only mean
        // something with the app's own font.
        await tester.runAsync(loadAppFonts);
        try {
          await pumpAt(
            tester,
            const Size(788, 1100),
            locale: locale,
            textScale: scale,
          );
          await tester.tap(
            find.byIcon(Icons.dashboard_customize_outlined).first,
          );
          await settle(tester);
          await tester.tap(
            find.text(
              locale.languageCode == 'de'
                  ? 'Widgets anordnen…'
                  : 'Arrange widgets…',
            ),
          );
          await settle(tester);
          expect(find.byType(ArrangeBoard), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await teardown(tester);
        }
      });
    }

    testWidgets('a phone move on Auto over a saved order can be undone', (
      tester,
    ) async {
      try {
        final repo = await pumpAt(tester, const Size(390, 844));
        await tester.runAsync(
          () => repo.save(
            DashboardView.compact,
            const DashboardViewState(order: ['recentTransactions', 'netWorth']),
          ),
        );
        await settle(tester);
        await tester.tap(find.byTooltip('Dashboard layout'));
        await settle(tester);
        await tester.tap(find.byTooltip('Move “Month summary” up'));
        await settle(tester);
        expect(find.text('Your earlier order was replaced'), findsOneWidget);
        await tester.tap(find.text('Undo'));
        await settle(tester);
        final state = await saved(tester, repo, DashboardView.compact);
        expect(state.mode, LayoutMode.custom);
        expect(state.order!.take(2), ['recentTransactions', 'netWorth']);
      } finally {
        await teardown(tester);
      }
    });
  });
}
