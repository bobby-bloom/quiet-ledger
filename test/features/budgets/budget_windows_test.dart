import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/budgets/data/budget_period_provider.dart';
import 'package:personal_finance/features/budgets/data/budget_providers.dart';
import 'package:personal_finance/features/budgets/data/budgets_repository.dart';
import 'package:personal_finance/features/budgets/domain/budget_math.dart';
import 'package:personal_finance/features/budgets/domain/budget_rules.dart';
import 'package:personal_finance/features/plan/plan_providers.dart';

import '../../helpers/test_app.dart';
import '../plan/plan_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final board = BudgetPeriods(const BudgetPeriodConfig());
  final oct = board.periodOf(DateTime(2026, 10, 15));
  DateRange week(DateTime d) =>
      windowPeriods(board, BudgetCadence.week).periodOf(d);

  group('domain', () {
    test('windows follow the calendar settings', () {
      expect(
        week(DateTime(2026, 10, 14)),
        DateRange(DateTime(2026, 10, 12), DateTime(2026, 10, 19)),
      );
      final sunday = BudgetPeriods(
        const BudgetPeriodConfig(firstDayOfWeek: DateTime.sunday),
      );
      expect(
        windowPeriods(
          sunday,
          BudgetCadence.week,
        ).periodOf(DateTime(2026, 10, 14)).start,
        DateTime(2026, 10, 11),
      );
      final fiscal = BudgetPeriods(
        const BudgetPeriodConfig(fiscalYearStartMonth: 4),
      );
      expect(
        windowPeriods(fiscal, BudgetCadence.year).periodOf(DateTime(2026, 2)),
        DateRange(DateTime(2025, 4), DateTime(2026, 4)),
      );
      // Salary-based starts do not move windows.
      final salary = BudgetPeriods(
        BudgetPeriodConfig(
          salaryDates: [DateTime(2026, 9, 28), DateTime(2026, 10, 28)],
        ),
      );
      expect(
        windowPeriods(
          salary,
          BudgetCadence.month,
        ).periodOf(DateTime(2026, 10, 5)).start,
        DateTime(2026, 10),
      );
      expect(windowPeriods(board, BudgetCadence.period), same(board));
    });

    test('lengths: matching the period type, and of a window', () {
      expect(
        cadenceOfPeriodType(BudgetPeriodType.monthly),
        BudgetCadence.month,
      );
      expect(cadenceOfPeriodType(BudgetPeriodType.biWeekly), isNull);
      expect(
        cadenceOfWindow(board, week(DateTime(2026, 10, 14))),
        BudgetCadence.week,
      );
      expect(
        cadenceOfWindow(board, DateRange(DateTime(2026), DateTime(2027))),
        BudgetCadence.year,
      );
      expect(
        cadenceOfWindow(
          board,
          DateRange(DateTime(2026, 10, 2), DateTime(2026, 10, 5)),
        ),
        isNull,
      );
    });

    test('reference day: today, else the last or first day', () {
      expect(referenceDay(oct, DateTime(2026, 10, 14)), DateTime(2026, 10, 14));
      expect(referenceDay(oct, DateTime(2026, 12, 3)), DateTime(2026, 10, 31));
      expect(referenceDay(oct, DateTime(2026, 8, 3)), DateTime(2026, 10));
    });

    test('shares: spread over covered periods, short windows in one', () {
      final year = DateRange(DateTime(2026), DateTime(2027));
      expect(windowTargets(board, year), hasLength(12));
      expect(windowShare(board, year, 120000, oct), 10000);
      // 100,005 cents over 12 periods: the first five get one cent more.
      expect(
        windowShare(board, year, 100005, board.periodOf(DateTime(2026))),
        8334,
      );
      expect(windowShare(board, year, 100005, oct), 8333);
      var sum = 0;
      for (final p in windowTargets(board, year)) {
        sum += windowShare(board, year, 100005, p);
      }
      expect(sum, 100005);
      // A week belongs to the period it starts in.
      final w = week(DateTime(2026, 9, 30)); // 28 Sep – 4 Oct
      expect(
        windowShare(board, w, 5000, board.periodOf(DateTime(2026, 9, 15))),
        5000,
      );
      expect(windowShare(board, w, 5000, oct), 0);
      expect(windowShare(board, year, 1, board.periodOf(DateTime(2025, 6))), 0);
    });

    test('a weekly rule covers every n-th week', () {
      final r = BudgetRulePlan(
        id: 'r',
        categoryId: 'food',
        amountMinor: 100,
        start: DateTime(2026, 10, 5),
        every: 2,
        cadence: BudgetCadence.week,
      );
      expect(
        [for (final w in r.periodsUpTo(board, DateTime(2026, 11))) w.start.day],
        [5, 19],
      );
      expect(r.isWindowed, isTrue);
      expect(
        r.repeat,
        const BudgetRepeat.everyPeriod(every: 2, cadence: BudgetCadence.week),
      );
    });
  });

  group('repository', () {
    late AppDatabase db;
    late PlanFixture f;
    late BudgetsRepository repo;
    late String food;

    setUp(() async {
      db = newTestDb();
      f = PlanFixture(db);
      repo = BudgetsRepository(db, f.writer);
      food = await f.category('Food');
    });

    tearDown(() => db.close());

    Future<List<Budget>> live() =>
        (db.select(db.budgets)
              ..where((b) => b.deletedAt.isNull())
              ..orderBy([(b) => OrderingTerm(expression: b.periodStart)]))
            .get();

    test(
      'weekly rows carry their end and stay out of period queries',
      () async {
        await repo.repeatFrom(
          periods: board,
          categoryId: food,
          from: week(DateTime(2026, 10)),
          amountMinor: 6000,
          repeat: const BudgetRepeat.everyPeriod(cadence: BudgetCadence.week),
        );
        await repo.ensureFromRules(board, DateTime(2026, 11));
        final rows = await live();
        expect([for (final b in rows) b.periodStart.day], [28, 5, 12, 19, 26]);
        expect(
          rows.every((b) => b.periodEnd!.difference(b.periodStart).inDays == 7),
          isTrue,
        );
        expect(await repo.period(DateTime(2026, 10)), isEmpty);
        expect(await repo.windows(oct), hasLength(5));
        expect(await repo.ensureFromRules(board, DateTime(2026, 11)), 0);
      },
    );

    test('switching a monthly budget to weekly replaces the month, keeps '
        'later budgets set by hand', () async {
      await repo.repeatFrom(
        periods: board,
        categoryId: food,
        from: oct,
        amountMinor: 40000,
        repeat: const BudgetRepeat.everyPeriod(),
      );
      await repo.ensureFromRules(board, DateTime(2026, 12));
      await repo.setAmount(food, DateTime(2026, 12), 1000);
      await repo.repeatFrom(
        periods: board,
        categoryId: food,
        from: week(oct.start),
        amountMinor: 9000,
        repeat: const BudgetRepeat.everyPeriod(cadence: BudgetCadence.week),
      );
      expect(await repo.period(oct.start), isEmpty);
      expect(await repo.period(DateTime(2026, 11)), isEmpty);
      expect((await repo.period(DateTime(2026, 12))).single.amountMinor, 1000);
      final rules = await repo.rules();
      expect(
        rules.where((r) => r.end == null).single.cadence,
        BudgetCadence.week,
      );
      await repo.ensureFromRules(board, DateTime(2026, 10, 31));
      expect(await repo.windows(oct), hasLength(5));
    });

    test('a window set by hand wins; a removed window stays removed', () async {
      await repo.repeatFrom(
        periods: board,
        categoryId: food,
        from: week(DateTime(2026, 10, 5)),
        amountMinor: 6000,
        repeat: const BudgetRepeat.everyPeriod(cadence: BudgetCadence.week),
      );
      await repo.ensureFromRules(board, DateTime(2026, 10, 19));
      await repo.setWindowAmount(food, week(DateTime(2026, 10, 12)), 8000);
      final removed = await repo.removeWindow(
        board,
        food,
        week(DateTime(2026, 10, 19)),
      );
      expect(removed, hasLength(1));
      await repo.ensureFromRules(board, DateTime(2026, 11));
      final rows = await repo.windows(oct);
      expect(
        {
          for (final b in rows)
            b.periodStart.day: (b.amountMinor, b.ruleId != null),
        },
        {5: (6000, true), 12: (8000, false), 26: (6000, true)},
      );
      expect(
        await repo.windowBudget(food, week(DateTime(2026, 10, 12))),
        isNotNull,
      );
    });

    test('window rollover follows the chain of weeks', () async {
      final checking = await f.account('Checking');
      await repo.repeatFrom(
        periods: board,
        categoryId: food,
        from: week(DateTime(2026, 10, 5)),
        amountMinor: 6000,
        repeat: const BudgetRepeat.everyPeriod(cadence: BudgetCadence.week),
      );
      await repo.ensureFromRules(board, DateTime(2026, 10, 19));
      await f.expense(checking, food, 4000, DateTime(2026, 10, 6)); // 20 left
      await f.expense(
        checking,
        food,
        7000,
        DateTime(2026, 10, 13),
      ); // 80 avail.
      final w19 = (await repo.windowBudget(
        food,
        week(DateTime(2026, 10, 19)),
      ))!;
      expect(await repo.windowRollover(w19, RolloverMode.leftover), 1000);
      expect(await repo.windowRollover(w19, RolloverMode.none), 0);
    });

    test('envelope: window shares count as assigned', () async {
      await repo.setWindowAmount(
        food,
        DateRange(DateTime(2026), DateTime(2027)),
        120000,
      );
      expect(await repo.windowAssigned(board, oct), 10000);
      expect(await repo.windowAssigned(board, oct, skip: {food}), 0);
    });
  });

  group('board', () {
    late AppDatabase db;
    late ProviderContainer c;
    late PlanFixture f;

    setUp(() async {
      db = newTestDb();
      f = PlanFixture(db);
      c = testContainer(
        db,
        overrides: [
          planTodayProvider.overrideWithValue(DateTime(2026, 10, 14)),
        ],
      );
      await c
          .read(settingsProvider.notifier)
          .set(BudgetSettings.weekendShift, WeekendShift.none);
    });

    tearDown(() async {
      c.dispose();
      await db.close();
    });

    DateRange cweek(DateTime d) => windowPeriods(
      c.read(budgetPeriodsProvider),
      BudgetCadence.week,
    ).periodOf(d);

    Future<BudgetSummary> boardOf(DateRange period) async {
      final sub = c.listen(budgetBoardProvider(period), (_, _) {});
      addTearDown(sub.close);
      return await c.read(budgetBoardProvider(period).future);
    }

    test('shows the current week, outside the totals', () async {
      final checking = await f.account('Checking');
      final food = await f.category('Food');
      final rent = await f.category('Rent');
      final repo = c.read(budgetsRepositoryProvider);
      final period = c.read(currentBudgetPeriodProvider);
      expect(period, oct);
      await repo.setAmount(rent, oct.start, 90000);
      await repo.repeatFrom(
        periods: c.read(budgetPeriodsProvider),
        categoryId: food,
        from: cweek(oct.start),
        amountMinor: 6000,
        repeat: const BudgetRepeat.everyPeriod(cadence: BudgetCadence.week),
      );
      await f.expense(checking, food, 3000, DateTime(2026, 10, 6)); // last week
      await f.expense(checking, food, 2500, DateTime(2026, 10, 13));
      final s = await boardOf(oct);
      final line = s.lineFor(food)!;
      expect(line.window, cweek(DateTime(2026, 10, 14)));
      expect(line.cadence, BudgetCadence.week);
      expect(line.spentMinor, 2500);
      expect(line.budgetedMinor, 6000);
      expect(line.rule, isNotNull);
      expect(s.tickFor(line), line.window!.progressAt(DateTime(2026, 10, 14)));
      expect(s.totalBudgetedMinor, 90000); // rent only
      expect(s.unbudgetedSpentMinor, 0); // food has a budget
      expect(s.hasWindowed, isTrue);
      // Envelope: weeks starting in October are assigned in October.
      expect(s.windowAssignedMinor, 4 * 6000);
      expect(s.assignedMinor, 90000 + 4 * 6000);

      // November shows its first week.
      final nov = board.next(oct);
      final n = await boardOf(nov);
      expect(n.lineFor(food)!.window, cweek(DateTime(2026, 11)));
      // September shows the week that runs into October.
      final sep = board.previous(oct);
      expect((await boardOf(sep)).lineFor(food)!.window, cweek(oct.start));
    });

    test('a budget of the period wins over a window', () async {
      final food = await f.category('Food');
      final repo = c.read(budgetsRepositoryProvider);
      await repo.setWindowAmount(food, cweek(DateTime(2026, 10, 14)), 6000);
      await repo.setAmount(food, oct.start, 40000);
      final line = (await boardOf(oct)).lineFor(food)!;
      expect(line.window, isNull);
      expect(line.budgetedMinor, 40000);
    });
  });
}
