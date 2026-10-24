import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/budgets/data/budgets_repository.dart';
import 'package:personal_finance/features/budgets/domain/budget_math.dart';

import '../../helpers/test_app.dart';
import '../plan/plan_fixtures.dart';

void main() {
  late AppDatabase db;
  late PlanFixture f;
  late BudgetsRepository repo;
  final periods = BudgetPeriods(const BudgetPeriodConfig());
  final jan = periods.periodOf(DateTime(2026, 1, 15));
  final feb = periods.next(jan);
  final mar = periods.next(feb);

  setUp(() {
    db = newTestDb();
    f = PlanFixture(db);
    repo = BudgetsRepository(db, SyncWriter(db, testClock(), 'test'));
  });

  tearDown(() => db.close());

  group('spent SQL', () {
    test(
      'counts splits, rolls children into parents, skips transfers, excluded '
      'accounts, planned and deleted rows',
      () async {
        final checking = await f.account('Checking');
        final savings = await f.account('Savings');
        final excluded = await f.account('Business', includeInBudgets: false);
        final food = await f.category('Food');
        final groceries = await f.category('Groceries', parentId: food);
        final rent = await f.category('Rent');
        final salary = await f.category('Salary', kind: CategoryKind.income);
        final d = DateTime(2026, 1, 10);

        await f.expense(checking, groceries, 5000, d);
        await f.expense(checking, food, 1000, d);
        // Split: 30 groceries + 70 rent.
        await f.ledger.create(
          TxnDraft(
            accountId: checking,
            amountMinor: -10000,
            date: d,
            splits: [
              SplitDraft(amountMinor: -3000, categoryId: groceries),
              SplitDraft(amountMinor: -7000, categoryId: rent),
            ],
          ),
        );
        // Transfer: excluded.
        await f.ledger.create(
          TxnDraft(
            accountId: checking,
            amountMinor: -20000,
            date: d,
            type: TxnType.transfer,
            transferAccountId: savings,
          ),
        );
        // Excluded account, planned and deleted entries.
        await f.expense(excluded, groceries, 99900, d);
        await f.expense(checking, groceries, 500, d, status: TxnStatus.planned);
        final deleted = await f.expense(checking, groceries, 700, d);
        await f.ledger.delete(deleted);
        // Refund reduces spending.
        await f.ledger.create(
          TxnDraft(
            accountId: checking,
            amountMinor: 500,
            date: d,
            type: TxnType.income,
            categoryId: groceries,
          ),
        );
        // Income and an uncategorised expense.
        await f.income(checking, salary, 300000, d);
        await f.expense(checking, null, 1200, d);
        // Outside the period.
        await f.expense(checking, groceries, 4000, DateTime(2026, 2));
        await f.expense(checking, groceries, 4000, DateTime(2025, 12, 31));

        final a = await repo.actuals(jan);
        expect(a.netByCategory[groceries], -5000 - 3000 + 500);
        expect(a.netByCategory[food], -1000);
        expect(a.spentOf(groceries), 7500);
        expect(a.spentOf(food, [groceries]), 8500);
        expect(a.spentOf(rent), 7000);
        expect(a.incomeMinor, 300000);
        expect(a.uncategorizedSpentMinor, 1200);

        final lines = await repo.watchCategoryLines({
          food,
          groceries,
        }, jan).first;
        expect(lines.map((l) => l.amountMinor).toList()..sort(), [
          -5000,
          -3000,
          -1000,
          500,
        ]);
        expect(lines.where((l) => l.isSplit).single.amountMinor, -3000);
      },
    );
  });

  group('rollover chains across 3 periods', () {
    late String food;

    Future<void> seed() async {
      final checking = await f.account('Checking');
      food = await f.category('Food');
      for (final p in [jan, feb, mar]) {
        await repo.setAmount(food, p.start, 10000);
      }
      await f.expense(checking, food, 8000, DateTime(2026, 1, 10));
      await f.expense(checking, food, 15000, DateTime(2026, 2, 10));
    }

    Future<Map<DateTime, int>> stored() async {
      final out = <DateTime, int>{};
      for (final p in [jan, feb, mar]) {
        out[p.start] = (await repo.period(p.start)).single.rolloverMinor;
      }
      return out;
    }

    final expected = <RolloverMode, (int, int)>{
      // Jan: 100 − 80 = +20 left. Feb: 100 + r − 150.
      RolloverMode.none: (0, 0),
      RolloverMode.leftover: (2000, 0), // Feb 120 − 150 = −30 → 0
      RolloverMode.overspent: (0, -5000), // Feb 100 − 150 = −50
      RolloverMode.both: (2000, -3000), // Feb 120 − 150 = −30
    };

    for (final e in expected.entries) {
      test('mode ${e.key.name}', () async {
        await seed();
        final cats = {
          for (final c in await db.select(db.categories).get()) c.id: c,
        };
        final chain = await repo.syncChain(
          periods: periods,
          target: mar,
          categories: cats,
          defaultMode: e.key,
        );
        expect(chain.rolloverByCategory[food] ?? 0, e.value.$2);
        final s = await stored();
        expect(s[jan.start], 0);
        expect(s[feb.start], e.value.$1);
        expect(s[mar.start], e.value.$2);

        // Idempotent: a second run changes nothing.
        final before = await db.select(db.changeLog).get();
        await repo.syncChain(
          periods: periods,
          target: mar,
          categories: cats,
          defaultMode: e.key,
        );
        expect((await db.select(db.changeLog).get()).length, before.length);
      });
    }

    test('category override beats the default mode', () async {
      await seed();
      await f.writer.update(
        db.categories,
        food,
        const CategoriesCompanion(rolloverOverride: Value('both')),
      );
      final cats = {
        for (final c in await db.select(db.categories).get()) c.id: c,
      };
      await repo.syncChain(
        periods: periods,
        target: mar,
        categories: cats,
        defaultMode: RolloverMode.none,
      );
      final s = await stored();
      expect(s[feb.start], 2000);
      expect(s[mar.start], -3000);
    });
  });

  test('envelope: to be budgeted carries unassigned money', () async {
    final checking = await f.account('Checking');
    final food = await f.category('Food');
    final salary = await f.category('Salary', kind: CategoryKind.income);
    await f.income(checking, salary, 100000, DateTime(2026));
    await f.income(checking, salary, 100000, DateTime(2026, 2));
    await repo.setAmount(food, jan.start, 80000);
    await repo.setAmount(food, feb.start, 90000);
    final cats = {
      for (final c in await db.select(db.categories).get()) c.id: c,
    };
    final chain = await repo.syncChain(
      periods: periods,
      target: feb,
      categories: cats,
      defaultMode: RolloverMode.none,
    );
    // Jan: 1000 + 0 − 800 = 200 carried into Feb.
    expect(chain.carryMinor, 20000);
    final febIncome = (await repo.actuals(feb)).incomeMinor;
    // Feb: 1000 + 200 − 900 = 300 left to assign.
    expect(
      toBeBudgeted(
        incomeMinor: febIncome,
        carryMinor: chain.carryMinor,
        assignedMinor: 90000,
      ),
      30000,
    );
  });

  test('fill from the N-period average of actual spending', () async {
    final checking = await f.account('Checking');
    final food = await f.category('Food');
    final rent = await f.category('Rent');
    final apr = periods.next(mar);
    await f.expense(checking, food, 10000, DateTime(2026, 1, 5));
    await f.expense(checking, food, 20050, DateTime(2026, 2, 5));
    // March: nothing → counts as 0 in the 3-period average.
    await f.expense(checking, rent, 90000, DateTime(2026, 3));
    final n = await repo.fillFromAverage(periods, apr, 3);
    expect(n, 2);
    final rows = {
      for (final b in await repo.period(apr.start)) b.categoryId: b.amountMinor,
    };
    // (100 + 200.50 + 0) / 3 = 100.17 → rounded up to 101.
    expect(rows[food], 10100);
    expect(rows[rent], 30000);
    expect(averageAmount([10000, 20050], 3, roundUpTo: 1), 10017);
  });

  test('copy previous period, templates and bulk edit', () async {
    final food = await f.category('Food');
    final fun = await f.category('Fun');
    await repo.setAmounts(jan.start, {food: 40000, fun: 8000});
    expect(await repo.copyPeriod(jan, feb), 2);
    final id = await repo.saveTemplate('Normal month', feb.start);
    await repo.setAmounts(feb.start, {fun: null, food: 45000});
    final feb2 = {
      for (final b in await repo.period(feb.start)) b.categoryId: b.amountMinor,
    };
    expect(feb2, {food: 45000});
    expect(await repo.applyTemplate(id, mar.start), 2);
    final m = {
      for (final b in await repo.period(mar.start)) b.categoryId: b.amountMinor,
    };
    expect(m, {food: 40000, fun: 8000});
  });

  group('budget state', () {
    test('thresholds and over', () {
      expect(
        budgetState(
          availableMinor: 10000,
          spentMinor: 7900,
          thresholdPercent: 80,
        ),
        BudgetState.onTrack,
      );
      expect(
        budgetState(
          availableMinor: 10000,
          spentMinor: 8000,
          thresholdPercent: 80,
        ),
        BudgetState.warning,
      );
      expect(
        budgetState(
          availableMinor: 10000,
          spentMinor: 10000,
          thresholdPercent: 80,
        ),
        BudgetState.warning,
      );
      expect(
        budgetState(
          availableMinor: 10000,
          spentMinor: 10001,
          thresholdPercent: 80,
        ),
        BudgetState.over,
      );
      expect(
        budgetState(availableMinor: 0, spentMinor: 0, thresholdPercent: 80),
        BudgetState.onTrack,
      );
      expect(
        budgetState(availableMinor: -500, spentMinor: 0, thresholdPercent: 80),
        BudgetState.over,
      );
    });

    test('rollover modes', () {
      expect(rolloverFor(RolloverMode.leftover, -10), 0);
      expect(rolloverFor(RolloverMode.leftover, 10), 10);
      expect(rolloverFor(RolloverMode.overspent, 10), 0);
      expect(rolloverFor(RolloverMode.overspent, -10), -10);
      expect(rolloverFor(RolloverMode.both, -10), -10);
      expect(rolloverFor(RolloverMode.none, 10), 0);
    });
  });
}
