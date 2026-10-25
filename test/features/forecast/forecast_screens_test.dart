import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide Table, isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/forecast/domain/forecast_pipeline.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_providers.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_screen.dart';
import 'package:personal_finance/features/forecast/presentation/projection_screen.dart';
import 'package:personal_finance/features/scenarios/domain/scenario.dart';
import 'package:personal_finance/features/scenarios/presentation/scenario_editor_screen.dart';
import 'package:personal_finance/features/scenarios/presentation/scenarios_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late AppDatabase db;
  late String checking;
  late String scenarioId;
  final today = DateTime(2026, 10, 23);

  setUp(() async {
    db = newTestDb();
    final writer = SyncWriter(db, testClock(), 'dev-1');
    checking = await writer.insert(
      db.accounts,
      AccountsCompanion(
        name: const Value('Everyday checking'),
        type: const Value(AccountType.checking),
        openingBalanceMinor: const Value(100000),
        openingDate: Value(DateTime(2026)),
        lowBalanceThresholdMinor: const Value(50000),
      ),
    );
    final rent = await writer.insert(
      db.recurringRules,
      RecurringRulesCompanion(
        name: const Value('Rent'),
        rrule: const Value('FREQ=MONTHLY;BYMONTHDAY=1'),
        startDate: Value(DateTime(2026)),
        template: Value(
          jsonEncode(
            TxnDraft(
              accountId: checking,
              amountMinor: -90000,
              date: DateTime(2026),
            ).toJson(),
          ),
        ),
        postingMode: const Value(PostingMode.autoPost),
      ),
    );
    await writer.insert(
      db.recurringRules,
      RecurringRulesCompanion(
        name: const Value('Salary'),
        rrule: const Value('FREQ=MONTHLY;BYMONTHDAY=28'),
        startDate: Value(DateTime(2026)),
        template: Value(
          jsonEncode(
            TxnDraft(
              accountId: checking,
              amountMinor: 250000,
              date: DateTime(2026),
              type: TxnType.income,
            ).toJson(),
          ),
        ),
        postingMode: const Value(PostingMode.autoPost),
      ),
    );
    await LedgerRepository(db, writer).create(
      TxnDraft(
        accountId: checking,
        amountMinor: -250000,
        date: DateTime(2026, 11, 20),
        payee: 'New laptop',
        status: TxnStatus.planned,
      ),
    );
    scenarioId = await writer.insert(
      db.scenarios,
      ScenariosCompanion(
        name: const Value('Pay rent less'),
        enabled: const Value(true),
        adjustments: Value(
          ScenarioAdjustment.encodeList([
            RecurringChangeAdjustment(
              ruleId: rent,
              from: DateTime(2026, 11),
              mode: ChangeMode.percent,
              value: -1000,
            ),
          ]),
        ),
      ),
    );
  });

  tearDown(() => db.close());

  List<Override> overridesWith(ForecastRunner runner) => [
    forecastRunnerProvider.overrideWithValue(runner),
    forecastTodayProvider.overrideWithValue(today),
  ];
  final overrides = overridesWith(const ForecastRunner.inline());

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(400, 900),
    ForecastRunner runner = const ForecastRunner.inline(),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(screen, db: db, overrides: overridesWith(runner)),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  // The page, not the horizontally scrolling horizon selector.
  final verticalScrollable = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  );

  testWidgets('forecast board (phone) shows lowest point and scenario', (
    tester,
  ) async {
    await pumpScreen(tester, const ForecastScreen());
    expect(find.text('Forecast'), findsWidgets);
    expect(find.text('Lowest point'), findsOneWidget);
    expect(find.text('All accounts'), findsOneWidget);
    // Choose the account: its 500.00 threshold is crossed after the laptop.
    await tester.tap(find.text('All accounts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Everyday checking').last);
    await tester.pumpAndSettle();
    expect(find.text('Everyday checking'), findsWidgets);
    expect(find.textContaining('below your'), findsWidgets);
    expect(find.text('Pay rent less'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Can I afford it?'),
      300,
      scrollable: verticalScrollable,
    );
    expect(find.text('Can I afford it?'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('forecast board (desktop) uses a side panel', (tester) async {
    await pumpScreen(
      tester,
      const ForecastScreen(),
      size: const Size(1280, 900),
    );
    expect(find.text('Lowest point'), findsOneWidget);
    expect(find.text('Scenarios'), findsWidgets);
    expect(find.text('Upcoming big events'), findsOneWidget);
    expect(find.text('New laptop'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('board cards fold like the dashboard', (tester) async {
    await pumpScreen(
      tester,
      const ForecastScreen(),
      size: const Size(1280, 1400),
    );
    for (final title in [
      'Balances',
      'Scenarios',
      'Can I afford it?',
      'Warnings',
      'Upcoming big events',
    ]) {
      expect(find.byTooltip('Collapse $title'), findsOneWidget, reason: title);
    }
    // The warning count sits in the header, so it stays when folded.
    expect(
      find.textContaining('Warnings · ', findRichText: true),
      findsOneWidget,
    );

    // Open: the link is the card's footer, below the scenarios.
    final edit = find.text('Edit scenarios');
    expect(edit, findsOneWidget);
    final row = find.descendant(
      of: find.ancestor(of: edit, matching: find.byType(Card)),
      matching: find.text('Pay rent less'),
    );
    expect(tester.getTopLeft(edit).dy, greaterThan(tester.getTopLeft(row).dy));

    await tester.tap(find.byTooltip('Collapse Scenarios'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Expand Scenarios'), findsOneWidget);
    expect(find.text('Edit scenarios'), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ForecastScreen)),
    );
    expect(
      container.read(settingsProvider).get(ForecastSettings.cardExpansion),
      '{"scenarios":false}',
    );
    // Folded, the link moves into ⋮.
    await tester.tap(find.byTooltip('Widget options'));
    await tester.pumpAndSettle();
    expect(find.text('Edit scenarios'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Expand Scenarios'));
    await tester.pumpAndSettle();
    expect(find.text('Edit scenarios'), findsOneWidget);
    expect(
      container.read(settingsProvider).get(ForecastSettings.cardExpansion),
      '',
    );
    await unmount(tester);
  });

  testWidgets('desktop side panel collapses from the app bar', (tester) async {
    await pumpScreen(
      tester,
      const ForecastScreen(),
      size: const Size(1280, 900),
    );
    expect(find.text('Can I afford it?'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide side panel'));
    await tester.pumpAndSettle();
    expect(find.text('Can I afford it?'), findsNothing);
    expect(find.text('Upcoming big events'), findsNothing);
    expect(find.text('Lowest point'), findsOneWidget);
    await tester.tap(find.byTooltip('Show side panel'));
    await tester.pumpAndSettle();
    expect(find.text('Can I afford it?'), findsOneWidget);
    await unmount(tester);

    // Phones stack everything in one column and have no toggle.
    await pumpScreen(tester, const ForecastScreen());
    expect(find.byTooltip('Hide side panel'), findsNothing);
    await unmount(tester);
  });

  testWidgets('balances table scrolls sideways instead of squeezing', (
    tester,
  ) async {
    final writer = SyncWriter(db, testClock(), 'dev-1');
    for (final name in ['Second scenario', 'Third scenario']) {
      await writer.insert(
        db.scenarios,
        ScenariosCompanion(
          name: Value(name),
          enabled: const Value(true),
          adjustments: Value(
            ScenarioAdjustment.encodeList([
              OneOffAdjustment(
                date: DateTime(2026, 12, 15),
                amountMinor: 80000,
                accountId: checking,
                label: name,
              ),
            ]),
          ),
        ),
      );
    }
    final table = find.byType(Table);
    double extent() => tester
        .state<ScrollableState>(
          find.ancestor(of: table, matching: find.byType(Scrollable)).first,
        )
        .position
        .maxScrollExtent;

    // A phone shows every compared scenario and scrolls.
    await pumpScreen(tester, const ForecastScreen());
    await tester.scrollUntilVisible(table, 300, scrollable: verticalScrollable);
    expect(find.text('With Pay rent less'), findsOneWidget);
    expect(find.text('With Third scenario'), findsOneWidget);
    expect(extent(), greaterThan(0));
    await unmount(tester);

    // Without scenarios the table fits a wide screen.
    await db.delete(db.scenarios).go();
    await pumpScreen(
      tester,
      const ForecastScreen(),
      size: const Size(1280, 900),
    );
    expect(extent(), 0);
    expect(tester.getSize(table).width, greaterThan(500));
    await unmount(tester);
  });

  testWidgets('board keeps its result while a new horizon computes', (
    tester,
  ) async {
    final runner = _GatedRunner();
    await pumpScreen(tester, const ForecastScreen(), runner: runner);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    runner.gate = Completer<void>();
    await tester.tap(find.byTooltip('6 months'));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Lowest point'), findsOneWidget);

    runner.gate!.complete();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await unmount(tester);
  });

  testWidgets('custom horizon via dialog, up to 120 months', (tester) async {
    await pumpScreen(tester, const ForecastScreen());
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    // On a phone the custom segment is scrolled into view first.
    expect(find.text('Custom'), findsOneWidget);
    await tester.ensureVisible(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.text('Custom horizon'), findsOneWidget);

    // Out of range: error and Done disabled.
    await tester.enterText(find.byType(TextField), '200');
    await tester.pump();
    expect(find.text('Enter 1–120 months'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Done'))
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField), '18');
    await tester.pump();
    expect(find.text('Enter 1–120 months'), findsNothing);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 18);
    await tester.tap(find.text('Done'));
    await settle();
    expect(find.text('18 mo'), findsOneWidget);
    expect(find.text('Custom'), findsNothing);

    // Tapping the selected custom segment reopens the dialog.
    await tester.tap(find.text('18 mo'));
    await tester.pumpAndSettle();
    expect(find.text('Custom horizon'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '120');
    await tester.pump();
    await tester.tap(find.text('Done'));
    await settle();
    expect(find.text('120 mo'), findsOneWidget);
    expect(find.text('Lowest point'), findsOneWidget);

    // A preset switches back and the custom segment resets.
    await tester.ensureVisible(find.text('6 mo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6 mo'));
    await settle();
    expect(find.text('Custom'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('horizon selector scrolls when it does not fit', (tester) async {
    double extent() => tester
        .state<ScrollableState>(
          find
              .ancestor(
                of: find.byType(SegmentedButton<int>),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .maxScrollExtent;

    await pumpScreen(
      tester,
      const ForecastScreen(),
      size: const Size(320, 900),
    );
    expect(extent(), greaterThan(0));
    await unmount(tester);

    await pumpScreen(
      tester,
      const ForecastScreen(),
      size: const Size(1280, 900),
    );
    expect(extent(), 0);
    await unmount(tester);
  });

  testWidgets('combined scenarios line needs two compared scenarios', (
    tester,
  ) async {
    Finder combinedSwitch() => find.descendant(
      of: find.widgetWithText(ListTile, 'All combined'),
      matching: find.byType(Switch),
    );
    await pumpScreen(
      tester,
      const ForecastScreen(),
      size: const Size(1280, 900),
    );
    expect(find.text('All combined'), findsNothing);
    await unmount(tester);

    await SyncWriter(db, testClock(), 'dev-1').insert(
      db.scenarios,
      ScenariosCompanion(
        name: const Value('Bonus'),
        enabled: const Value(true),
        adjustments: Value(
          ScenarioAdjustment.encodeList([
            OneOffAdjustment(
              date: DateTime(2026, 12, 15),
              amountMinor: 80000,
              accountId: checking,
              label: 'Bonus',
            ),
          ]),
        ),
      ),
    );
    await pumpScreen(
      tester,
      const ForecastScreen(),
      size: const Size(1280, 900),
    );
    expect(combinedSwitch(), findsOneWidget);
    expect(tester.widget<Switch>(combinedSwitch()).value, isFalse);
    expect(find.text('With All combined'), findsNothing);

    await tester.tap(combinedSwitch());
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(tester.widget<Switch>(combinedSwitch()).value, isTrue);
    // Legend entry, toggle row and balances column.
    expect(find.text('All combined'), findsNWidgets(2));
    expect(find.text('With All combined'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('chart has an accessible summary', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpScreen(tester, const ForecastScreen());
    expect(
      find.bySemanticsLabel(RegExp('Projected daily balance of All accounts')),
      findsOneWidget,
    );
    handle.dispose();
    await unmount(tester);
  });

  testWidgets('projection screen renders milestones and assumptions', (
    tester,
  ) async {
    await pumpScreen(tester, const ProjectionScreen());
    expect(find.text('Long-term projection'), findsOneWidget);
    expect(find.text('Milestones'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Assumptions'), 300);
    expect(find.text('Assumptions'), findsOneWidget);
    // Phones stack everything in one column and have no toggle.
    expect(find.byTooltip('Hide side panel'), findsNothing);
    await unmount(tester);
  });

  testWidgets('projection shows progress while it computes', (tester) async {
    final runner = _GatedRunner()..gate = Completer<void>();
    await pumpScreen(tester, const ProjectionScreen(), runner: runner);
    expect(find.text('Calculating projection…'), findsOneWidget);
    expect(find.text('Milestones'), findsNothing);

    runner.gate!.complete();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Milestones'), findsOneWidget);
    expect(find.text('Recalculating…'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    // A changed assumption keeps the old result, marked as recomputing.
    runner.gate = Completer<void>();
    await tester.scrollUntilVisible(find.text('Plan'), 300);
    await tester.tap(find.text('Plan'));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Recalculating…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Milestones'), findsOneWidget);

    runner.gate!.complete();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Recalculating…'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await unmount(tester);
  });

  testWidgets('real values switch without a new projection', (tester) async {
    final runner = _GatedRunner();
    await pumpScreen(tester, const ProjectionScreen(), runner: runner);
    expect(find.text('Nominal'), findsOneWidget);
    final runs = runner.runs;

    await tester.scrollUntilVisible(find.text('Show real values'), 300);
    await tester.tap(find.text('Show real values'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 300));
    expect(runner.runs, runs);
    expect(find.text('Recalculating…'), findsNothing);
    await tester.scrollUntilVisible(find.text('Real'), -300);
    expect(find.text('Real'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('desktop projection collapses its side panel', (tester) async {
    await pumpScreen(
      tester,
      const ProjectionScreen(),
      size: const Size(1280, 900),
    );
    expect(find.text('Assumptions'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide side panel'));
    await tester.pumpAndSettle();
    expect(find.text('Assumptions'), findsNothing);
    expect(find.text('Milestones'), findsOneWidget);
    await tester.tap(find.byTooltip('Show side panel'));
    await tester.pumpAndSettle();
    expect(find.text('Assumptions'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('scenario list and editor', (tester) async {
    await pumpScreen(tester, const ScenariosScreen());
    expect(find.text('Pay rent less'), findsOneWidget);
    await unmount(tester);

    await pumpScreen(tester, ScenarioEditorScreen(scenarioId: scenarioId));
    expect(find.text('Edit scenario'), findsOneWidget);
    expect(find.text('Rent'), findsWidgets);
    await unmount(tester);

    await pumpScreen(tester, const ScenarioEditorScreen(scenarioId: 'new'));
    expect(find.text('New scenario'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('German strings', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        const ForecastScreen(),
        db: db,
        overrides: overrides,
        locale: const Locale('de'),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Prognose'), findsWidgets);
    expect(find.text('Tiefster Stand'), findsOneWidget);
    await unmount(tester);
  });
}

/// Holds forecasts back until [gate] completes.
class _GatedRunner extends ForecastRunner {
  _GatedRunner() : super.inline();

  Completer<void>? gate;
  int runs = 0;

  @override
  Future<CashflowBatch> cashflow(CashflowRequest r) async {
    await gate?.future;
    return await super.cashflow(r);
  }

  @override
  Future<ProjectionBatch> projection(ProjectionRequest r) async {
    runs++;
    await gate?.future;
    return await super.projection(r);
  }
}
