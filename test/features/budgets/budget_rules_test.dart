import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/sync/tombstone_purge.dart';
import 'package:personal_finance/features/budgets/data/budgets_repository.dart';
import 'package:personal_finance/features/budgets/domain/budget_rules.dart';
import 'package:personal_finance/features/categories/data/categories_repository.dart';

import '../../helpers/test_app.dart';
import '../plan/plan_fixtures.dart';

void main() {
  final periods = BudgetPeriods(const BudgetPeriodConfig());
  DateRange month(int y, int m) => periods.periodOf(DateTime(y, m, 15));
  final jan = month(2026, 1);

  group('BudgetRulePlan', () {
    BudgetRulePlan rule({int every = 1, int? count, DateTime? end}) =>
        BudgetRulePlan(
          id: 'r',
          categoryId: 'food',
          amountMinor: 100,
          start: jan.start,
          every: every,
          count: count,
          end: end,
        );
    List<int> months(BudgetRulePlan r, DateTime upTo) => [
      for (final p in r.periodsUpTo(periods, upTo)) p.start.month,
    ];

    test('covers every n-th period, a count or until a date', () {
      final upTo = DateTime(2026, 12);
      expect(months(rule(), DateTime(2026, 4)), [1, 2, 3, 4]);
      expect(months(rule(every: 2), DateTime(2026, 6)), [1, 3, 5]);
      expect(months(rule(count: 3), upTo), [1, 2, 3]);
      expect(months(rule(every: 3, count: 2), upTo), [1, 4]);
      expect(months(rule(end: DateTime(2026, 3, 31)), upTo), [1, 2, 3]);
      expect(months(rule(count: 1), upTo), [1]);
      expect(rule(every: 2).covers(periods, DateTime(2026, 3)), isTrue);
      expect(rule(every: 2).covers(periods, DateTime(2026, 4)), isFalse);
      expect(rule().covers(periods, DateTime(2025, 12)), isFalse);
    });

    test('due periods follow the watermark', () {
      final r = BudgetRulePlan(
        id: 'r',
        categoryId: 'food',
        amountMinor: 100,
        start: jan.start,
        generatedUntil: DateTime(2026, 2),
      );
      expect(
        [for (final p in r.due(periods, DateTime(2026, 4))) p.start],
        [DateTime(2026, 3), DateTime(2026, 4)],
      );
    });

    test('a period that moved before the watermark is due again', () {
      final salary = BudgetPeriods(
        BudgetPeriodConfig(
          salaryDates: [
            DateTime(2026, 1, 28),
            DateTime(2026, 2, 26), // landed early; expected 27 Feb
            DateTime(2026, 3, 27),
          ],
        ),
      );
      final r = BudgetRulePlan(
        id: 'r',
        categoryId: 'food',
        amountMinor: 100,
        start: DateTime(2026, 1, 28),
        generatedUntil: DateTime(2026, 2, 27),
      );
      expect(
        [for (final p in r.due(salary, DateTime(2026, 2, 27))) p.start],
        [DateTime(2026, 2, 26)],
      );
    });

    test('remaining count and repeat setting', () {
      expect(rule(count: 6).remainingCountFrom(periods, DateTime(2026, 3)), 4);
      expect(rule().remainingCountFrom(periods, DateTime(2026, 3)), isNull);
      expect(
        rule(count: 2).repeatOn(periods),
        const BudgetRepeat.forPeriods(2),
      );
      expect(
        rule(every: 2).repeatOn(periods),
        const BudgetRepeat.everyPeriod(every: 2),
      );
    });

    test('generated ids are deterministic per rule and period', () {
      final a = generatedBudgetId('r1', DateTime(2026, 3));
      expect(generatedBudgetId('r1', DateTime(2026, 3, 1, 12)), a);
      expect(generatedBudgetId('r1', DateTime(2026, 4)), isNot(a));
      expect(generatedBudgetId('r2', DateTime(2026, 3)), isNot(a));
    });

    test('the newest rule wins', () {
      final old = BudgetRulePlan(
        id: 'old',
        categoryId: 'food',
        amountMinor: 1,
        start: DateTime(2026),
        updatedAt: '1',
      );
      final newer = BudgetRulePlan(
        id: 'new',
        categoryId: 'food',
        amountMinor: 2,
        start: DateTime(2026),
        updatedAt: '2',
      );
      expect(
        ruleFor([old, newer], periods, 'food', DateTime(2026, 2))?.id,
        'new',
      );
      expect(ruleFor([old, newer], periods, 'rent', DateTime(2026, 2)), isNull);
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
      repo = BudgetsRepository(db, SyncWriter(db, testClock(), 'test'));
      food = await f.category('Food');
    });

    tearDown(() => db.close());

    Future<Map<int, (int, bool)>> rows() async => {
      for (final b in await (db.select(
        db.budgets,
      )..where((b) => b.deletedAt.isNull() & b.categoryId.equals(food))).get())
        b.periodStart.month + (b.periodStart.year - 2026) * 12: (
          b.amountMinor,
          b.ruleId != null,
        ),
    };

    Future<String> repeat(
      DateRange from,
      int amount, [
      BudgetRepeat r = const BudgetRepeat.everyPeriod(),
    ]) => repo.repeatFrom(
      periods: periods,
      categoryId: food,
      from: from,
      amountMinor: amount,
      repeat: r,
    );

    test('a new rule sets the period and generates later ones once', () async {
      await repeat(jan, 40000);
      expect(await rows(), {1: (40000, true)});
      expect(await repo.ensureFromRules(periods, DateTime(2026, 3)), 2);
      expect(await rows(), {
        1: (40000, true),
        2: (40000, true),
        3: (40000, true),
      });
      expect(await repo.ensureFromRules(periods, DateTime(2026, 3)), 0);
      final b = (await repo.period(DateTime(2026, 2))).single;
      expect(b.id, generatedBudgetId(b.ruleId!, DateTime(2026, 2)));
    });

    test('budgets set by hand win and are never overwritten', () async {
      await repo.setAmount(food, DateTime(2026, 2), 5000);
      await repeat(jan, 40000);
      await repo.ensureFromRules(periods, DateTime(2026, 3));
      expect(await rows(), {
        1: (40000, true),
        2: (5000, false),
        3: (40000, true),
      });
      // Editing a generated row makes it a manual override.
      await repo.setAmount(food, DateTime(2026, 3), 30000);
      expect((await rows())[3], (30000, false));
    });

    test('a removed period is not generated again, even after the '
        'tombstone purge', () async {
      await repeat(jan, 40000);
      await repo.ensureFromRules(periods, DateTime(2026, 2));
      final removed = await repo.removeFromPeriod(
        periods,
        food,
        month(2026, 3),
      );
      expect(removed, hasLength(1)); // generated first, then removed
      await purgeTombstones(
        db,
        Duration.zero,
        now: DateTime.now().add(const Duration(days: 1)),
      );
      await repo.ensureFromRules(periods, DateTime(2026, 4));
      expect((await rows()).keys, [1, 2, 4]);
    });

    test('this and following: later generated rows move to the new amount, '
        'manual ones stay', () async {
      final first = await repeat(jan, 40000);
      await repo.ensureFromRules(periods, DateTime(2026, 4));
      await repo.setAmount(food, DateTime(2026, 4), 1000);
      final second = await repeat(month(2026, 3), 45000);
      expect(await rows(), {
        1: (40000, true),
        2: (40000, true),
        3: (45000, true),
        4: (1000, false),
      });
      final rules = {for (final r in await repo.rules()) r.id: r};
      expect(rules[first]!.end, DateTime(2026, 2, 28));
      expect(rules[second]!.start, DateTime(2026, 3));
      // The new rule inherited the watermark: April stays manual, May is new.
      await repo.ensureFromRules(periods, DateTime(2026, 5));
      expect((await rows())[5], (45000, true));
      expect((await repo.period(DateTime(2026, 2))).single.ruleId, first);
    });

    test('a changed repeat removes rows the new rule does not cover', () async {
      await repeat(jan, 40000);
      await repo.ensureFromRules(periods, DateTime(2026, 4));
      await repeat(jan, 40000, const BudgetRepeat.everyPeriod(every: 2));
      expect((await rows()).keys, [1, 3]);
      expect(await repo.rules(), hasLength(1)); // the old one started here
    });

    test(
      'stop repeating removes generated rows from then on; undo restores',
      () async {
        await repeat(jan, 40000);
        await repo.ensureFromRules(periods, DateTime(2026, 4));
        await repo.setAmount(food, DateTime(2026, 4), 1000);
        final removed = await repo.stopRepeating(food, DateTime(2026, 2));
        expect(await rows(), {1: (40000, true), 4: (1000, false)});
        await repo.ensureFromRules(periods, DateTime(2026, 6));
        expect((await rows()).keys, [1, 4]);
        await repo.restoreBudgets(removed);
        expect((await rows()).keys, [1, 2, 3, 4]);
      },
    );

    test('for x periods and until a date', () async {
      await repeat(jan, 100, const BudgetRepeat.forPeriods(2));
      await repo.ensureFromRules(periods, DateTime(2026, 6));
      expect((await rows()).keys, [1, 2]);
      await repeat(month(2026, 3), 200, BudgetRepeat.until(DateTime(2026, 4)));
      await repo.ensureFromRules(periods, DateTime(2026, 6));
      expect((await rows()).keys, [1, 2, 3, 4]);
    });

    test('Fill menu: repeat these budgets every period', () async {
      final rent = await f.category('Rent');
      await repo.setAmounts(jan.start, {food: 40000, rent: 90000});
      expect(await repo.repeatPeriod(periods, jan), 2);
      await repo.ensureFromRules(periods, DateTime(2026, 2));
      final feb = await repo.period(DateTime(2026, 2));
      expect(
        {for (final b in feb) b.categoryId: b.amountMinor},
        {food: 40000, rent: 90000},
      );
    });

    test('two devices generate the same row ids', () async {
      final other = newTestDb();
      addTearDown(other.close);
      final ruleId = await repeat(jan, 40000);
      final rule = await (db.select(
        db.budgetRules,
      )..where((r) => r.id.equals(ruleId))).getSingle();
      await other.into(other.budgetRules).insert(rule);
      final otherRepo = BudgetsRepository(
        other,
        SyncWriter(other, testClock(node: 'b'), 'b'),
      );
      await repo.ensureFromRules(periods, DateTime(2026, 3));
      await otherRepo.ensureFromRules(periods, DateTime(2026, 3));
      Future<Set<String>> ids(AppDatabase d) async => {
        for (final b in await (d.select(
          d.budgets,
        )..where((b) => b.periodStart.isBiggerThanValue(jan.start))).get())
          b.id,
      };
      expect(await ids(other), await ids(db));
      expect(await ids(db), hasLength(2));
    });

    test('category merge: rules move to a target without one, end when the '
        'target has its own', () async {
      final writer = SyncWriter(db, testClock(node: 'm'), 'm');
      final cats = CategoriesRepository(
        db,
        writer,
        LedgerRepository(db, writer),
      );
      final snacks = await f.category('Snacks');
      final drinks = await f.category('Drinks');
      await repo.repeatFrom(
        periods: periods,
        categoryId: snacks,
        from: jan,
        amountMinor: 3000,
        repeat: const BudgetRepeat.everyPeriod(),
      );
      await cats.merge(snacks, food, periods: periods);
      Future<List<BudgetRulePlan>> open() async => [
        for (final r in await repo.rules())
          if (r.end == null) r,
      ];
      expect((await open()).single.categoryId, food);
      expect((await open()).single.amountMinor, 3000);
      expect((await repo.period(jan.start)).single.categoryId, food);

      await repo.repeatFrom(
        periods: periods,
        categoryId: drinks,
        from: jan,
        amountMinor: 2000,
        repeat: const BudgetRepeat.everyPeriod(),
      );
      await cats.merge(drinks, food, periods: periods);
      // Food's own repeating budget stays; Drinks' ends after the horizon.
      expect((await open()).single.amountMinor, 3000);
      expect((await repo.period(jan.start)).single.amountMinor, 5000);
      expect((await repo.period(jan.start)).single.ruleId, isNull);
      // No rule was changed in place: every rule's amount is as created.
      expect({for (final r in await repo.rules()) r.amountMinor}, {3000, 2000});
    });
  });
}
