import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
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

  final overrides = [
    forecastRunnerProvider.overrideWithValue(const ForecastRunner.inline()),
    forecastTodayProvider.overrideWithValue(today),
  ];

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(screen, db: db, overrides: overrides));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

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
    await tester.scrollUntilVisible(find.text('Can I afford it?'), 300);
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
