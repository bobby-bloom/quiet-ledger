// Regression tests for the independent review of the budget features.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/sync/hlc.dart';
import 'package:personal_finance/core/sync/sync_backend.dart';
import 'package:personal_finance/core/sync/sync_engine.dart';
import 'package:personal_finance/features/budgets/data/budgets_repository.dart';
import 'package:personal_finance/features/budgets/domain/budget_math.dart';
import 'package:personal_finance/features/budgets/domain/budget_rules.dart';

import '../../helpers/test_app.dart';
import '../plan/plan_fixtures.dart';

void main() {
  final board = BudgetPeriods(const BudgetPeriodConfig());
  DateRange month(int y, int m) => board.periodOf(DateTime(y, m, 15));
  final oct = month(2026, 10);
  DateRange week(BudgetPeriods p, DateTime d) =>
      windowPeriods(p, BudgetCadence.week).periodOf(d);

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
            ..where((b) => b.deletedAt.isNull() & b.categoryId.equals(food))
            ..orderBy([(b) => OrderingTerm(expression: b.periodStart)]))
          .get();

  Future<String> repeatMonthly(DateRange from, int amount, {int every = 1}) =>
      repo.repeatFrom(
        periods: board,
        categoryId: food,
        from: from,
        amountMinor: amount,
        repeat: BudgetRepeat.everyPeriod(every: every),
      );

  test(
    'a new length keeps earlier budgets and later ones set by hand',
    () async {
      await repeatMonthly(month(2026, 1), 40000);
      await repo.ensureFromRules(board, DateTime(2026, 11, 30));
      await repo.setAmount(food, DateTime(2026, 3), 55000);
      await repo.setAmount(food, DateTime(2026, 12), 1000);
      final year = DateRange(DateTime(2026), DateTime(2027));
      await repo.repeatFrom(
        periods: board,
        categoryId: food,
        from: year,
        amountMinor: 500000,
        repeat: const BudgetRepeat.everyPeriod(cadence: BudgetCadence.year),
        replace: oct,
      );
      final rows = await live();
      final monthly = {
        for (final b in rows)
          if (b.periodEnd == null) b.periodStart.month: b.amountMinor,
      };
      // Jan–Sep stay (March as set by hand), October is replaced, the
      // generated November goes, the hand-set December stays.
      expect(monthly, {
        1: 40000, 2: 40000, 3: 55000, 4: 40000, 5: 40000, 6: 40000, //
        7: 40000, 8: 40000, 9: 40000, 12: 1000,
      });
      expect(
        rows.where((b) => b.periodEnd != null).single.periodStart,
        DateTime(2026),
      );
    },
  );

  test('a new weekly length keeps the previous month', () async {
    await repo.setAmount(food, DateTime(2026, 9), 30000);
    await repeatMonthly(oct, 40000);
    await repo.repeatFrom(
      periods: board,
      categoryId: food,
      from: week(board, oct.start),
      amountMinor: 9000,
      repeat: const BudgetRepeat.everyPeriod(cadence: BudgetCadence.week),
      replace: oct,
    );
    expect((await repo.period(DateTime(2026, 9))).single.amountMinor, 30000);
    expect(await repo.period(oct.start), isEmpty);
  });

  test('every 2 periods → every period fills the skipped periods', () async {
    await repeatMonthly(oct, 20000, every: 2);
    await repo.ensureFromRules(board, DateTime(2027, 2, 28));
    await repeatMonthly(oct, 20000);
    await repo.ensureFromRules(board, DateTime(2027, 2, 28));
    expect(
      [for (final b in await live()) b.periodStart.month],
      [
        10, 11, 12, 1, 2, //
      ],
    );
  });

  test('changing the first day of week does not overlap windows', () async {
    await repo.repeatFrom(
      periods: board,
      categoryId: food,
      from: week(board, DateTime(2026, 10, 5)),
      amountMinor: 6000,
      repeat: const BudgetRepeat.everyPeriod(cadence: BudgetCadence.week),
    );
    await repo.ensureFromRules(board, DateTime(2026, 10, 20));
    final sunday = BudgetPeriods(
      const BudgetPeriodConfig(firstDayOfWeek: DateTime.sunday),
    );
    await repo.ensureFromRules(sunday, DateTime(2026, 11, 30));
    final rows = await live();
    for (var i = 1; i < rows.length; i++) {
      expect(
        rows[i].periodStart.isBefore(rows[i - 1].periodEnd!),
        isFalse,
        reason: '${rows[i - 1].periodStart} overlaps ${rows[i].periodStart}',
      );
    }
    expect(rows.length, greaterThan(5));
  });

  test('a period type change keeps the rule length (no monthly amount per '
      'week)', () async {
    await repeatMonthly(oct, 40000);
    await repo.ensureFromRules(board, DateTime(2026, 11, 30));
    final weekly = BudgetPeriods(
      const BudgetPeriodConfig(type: BudgetPeriodType.weekly),
    );
    await repo.ensureFromRules(weekly, DateTime(2026, 12, 31));
    final rows = await live();
    expect(
      [for (final b in rows) (b.periodStart.month, b.periodEnd?.month)],
      [(10, 11), (11, 12), (12, 1)],
    );
    expect(rows.every((b) => b.amountMinor == 40000), isTrue);
    // Back to monthly: the rows are budgets of the period again.
    await repo.ensureFromRules(board, DateTime(2026, 12, 31));
    expect((await live()).every((b) => b.periodEnd == null), isTrue);
  });

  test('explicit fills mark a generated row as set by hand', () async {
    await repeatMonthly(oct, 40000);
    await repo.setAmounts(oct.start, {food: 40000});
    expect((await repo.period(oct.start)).single.ruleId, isNull);
  });

  test('Fill › Repeat skips budgets that already repeat', () async {
    final rent = await f.category('Rent');
    await repo.repeatFrom(
      periods: board,
      categoryId: food,
      from: oct,
      amountMinor: 40000,
      repeat: const BudgetRepeat.forPeriods(3),
    );
    await repo.setAmount(rent, oct.start, 90000);
    expect(await repo.repeatPeriod(board, oct), 1);
    final rules = await repo.rules();
    expect(rules.firstWhere((r) => r.categoryId == food).count, 3);
  });

  group('envelope', () {
    test('the board share and the carry agree for child windows', () async {
      final groceries = await f.category('Groceries', parentId: food);
      await repo.setAmount(food, oct.start, 50000);
      await repo.setWindowAmount(groceries, week(board, oct.start), 10000);
      final categories = {
        for (final c in await db.select(db.categories).get()) c.id: c,
      };
      final a = assignedInPeriod(
        periods: board,
        period: oct,
        periodRows: await repo.period(oct.start),
        windowRows: await repo.windows(oct),
        categories: categories,
      );
      expect((a.periodMinor, a.windowMinor), (50000, 0));
    });

    test('a period with only window budgets keeps the carry', () async {
      final checking = await f.account('Checking');
      final salary = await f.category('Salary', kind: CategoryKind.income);
      final sep = month(2026, 9);
      await f.income(checking, salary, 100000, DateTime(2026, 9, 2));
      for (final d in [7, 14, 21, 28]) {
        await repo.setWindowAmount(
          food,
          week(board, DateTime(2026, 9, d)),
          7500,
        );
      }
      final categories = {
        for (final c in await db.select(db.categories).get()) c.id: c,
      };
      final chain = await repo.syncChain(
        periods: board,
        target: oct,
        categories: categories,
        defaultMode: RolloverMode.none,
      );
      // Weeks starting in September: 7, 14, 21, 28 → 4 × 75.
      expect(
        assignedInPeriod(
          periods: board,
          period: sep,
          periodRows: const [],
          windowRows: await repo.windows(sep),
          categories: categories,
        ).windowMinor,
        30000,
      );
      expect(chain.carryMinor, 70000);
    });
  });

  test('sync: a hand edit on one device beats a later generated row from '
      'another', () async {
    final backend = InMemorySyncBackend();
    var now = 1790000000000;
    ({AppDatabase db, BudgetsRepository repo, SyncEngine engine}) device(
      String name,
    ) {
      final d = newTestDb();
      final clock = HlcClock(name, now: () => now++);
      final writer = SyncWriter(
        d,
        clock,
        name,
        now: () => DateTime.fromMillisecondsSinceEpoch(now),
      );
      return (
        db: d,
        repo: BudgetsRepository(d, writer),
        engine: SyncEngine(
          db: d,
          clock: clock,
          deviceId: name,
          backend: backend,
        ),
      );
    }

    final a = device('a');
    final b = device('b');
    addTearDown(a.db.close);
    addTearDown(b.db.close);
    await a.repo.repeatFrom(
      periods: board,
      categoryId: 'food',
      from: oct,
      amountMinor: 40000,
      repeat: const BudgetRepeat.everyPeriod(),
    );
    await a.engine.sync();
    await b.engine.sync();
    final nov = board.next(oct);
    await a.repo.ensureFromRules(board, nov.start);
    await a.repo.setAmount('food', nov.start, 1000);
    // B generates November later, before it has A's edit.
    await b.repo.ensureFromRules(board, nov.start);
    await a.engine.sync();
    await b.engine.sync();
    await a.engine.sync();
    for (final d in [a, b]) {
      final row = (await d.repo.period(nov.start)).single;
      expect((row.amountMinor, row.ruleId), (1000, null), reason: '$d');
    }

    // A removal wins the same way.
    final dec = board.next(nov);
    await a.repo.removeFromPeriod(board, 'food', dec);
    await b.repo.ensureFromRules(board, dec.start);
    await a.engine.sync();
    await b.engine.sync();
    await a.engine.sync();
    for (final d in [a, b]) {
      expect(await d.repo.period(dec.start), isEmpty);
    }
  });
}
