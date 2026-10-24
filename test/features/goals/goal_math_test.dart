import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/features/goals/data/goals_providers.dart';
import 'package:personal_finance/features/goals/data/goals_repository.dart';
import 'package:personal_finance/features/goals/domain/goal_math.dart';
import 'package:personal_finance/features/plan/plan_providers.dart';

import '../../helpers/test_app.dart';
import '../plan/plan_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final periods = BudgetPeriods(const BudgetPeriodConfig());
  final today = DateTime(2026, 10, 23);

  group('projectGoal', () {
    test('required contribution per period until the target date', () {
      final p = projectGoal(
        savedMinor: 20000,
        targetMinor: 120000,
        today: today,
        periods: periods,
        targetDate: DateTime(2027, 4),
      );
      // Period starts in (23 Oct, 1 Apr]: Nov, Dec, Jan, Feb, Mar, Apr = 6.
      expect(p.periodsLeft, 6);
      expect(p.requiredPerPeriodMinor, 16667); // ceil(1000 / 6)
      expect(p.remainingMinor, 100000);
      expect(p.projectedDate, isNull);
      expect(p.onTrack, isFalse);
    });

    test('ETA from a planned contribution per period', () {
      final p = projectGoal(
        savedMinor: 20000,
        targetMinor: 120000,
        today: today,
        periods: periods,
        targetDate: DateTime(2027, 4),
        pace: const GoalPace.perPeriod(25000),
      );
      // 4 contributions: Nov, Dec, Jan, Feb → reached 1 Feb 2027.
      expect(p.projectedDate, DateTime(2027, 2));
      expect(p.onTrack, isTrue);
    });

    test('ETA from the account pace', () {
      final p = projectGoal(
        savedMinor: 20000,
        targetMinor: 120000,
        today: today,
        periods: periods,
        targetDate: DateTime(2027, 4),
        pace: const GoalPace.perDays(30000, 90),
      );
      // 1000 at 300 per 90 days → 300 days.
      expect(p.projectedDate, DateTime(2027, 8, 19));
      expect(p.onTrack, isFalse);
    });

    test('no contribution opportunity left: everything is due now', () {
      final p = projectGoal(
        savedMinor: 0,
        targetMinor: 5000,
        today: today,
        periods: periods,
        targetDate: DateTime(2026, 10, 30),
      );
      expect(p.periodsLeft, 0);
      expect(p.requiredPerPeriodMinor, 5000);
    });

    test('reached and negative pace', () {
      final reached = projectGoal(
        savedMinor: 130000,
        targetMinor: 120000,
        today: today,
        periods: periods,
      );
      expect(reached.reached, isTrue);
      expect(reached.fraction, 1);
      expect(reached.projectedDate, today);
      final losing = projectGoal(
        savedMinor: 0,
        targetMinor: 1000,
        today: today,
        periods: periods,
        pace: const GoalPace.perDays(-500, 120),
      );
      expect(losing.projectedDate, isNull);
    });
  });

  group('goals data', () {
    late AppDatabase db;
    late ProviderContainer c;
    late PlanFixture f;

    setUp(() {
      db = newTestDb();
      f = PlanFixture(db);
      c = testContainer(
        db,
        overrides: [planTodayProvider.overrideWithValue(today)],
      );
    });

    tearDown(() async {
      c.dispose();
      await db.close();
    });

    test('account pace from the last months of net change', () async {
      final savings = await f.account(
        'Savings',
        opening: 100000,
        openingDate: DateTime(2026),
      );
      await f.income(savings, null, 10000, DateTime(2026, 5));
      await f.income(savings, null, 20000, DateTime(2026, 8));
      await f.expense(savings, null, 5000, DateTime(2026, 9));
      final pace = await c
          .read(goalsRepositoryProvider)
          .accountPace(savings, today);
      // Window 23 Apr – 23 Oct (183 days), net +250.
      expect(pace!.amountMinor, 25000);
      expect(pace.days, 183);

      final young = await f.account('New', openingDate: DateTime(2026, 9));
      expect(
        await c.read(goalsRepositoryProvider).accountPace(young, today),
        isNull,
      );
    });

    test('CRUD, contributions, priority order and progress', () async {
      final repo = c.read(goalsRepositoryProvider);
      final savings = await f.account(
        'Savings',
        opening: 50000,
        openingDate: DateTime(2025),
      );
      await f.income(savings, null, 30000, DateTime(2026, 6));
      final a = await repo.create(
        const GoalDraft(name: 'Holiday', targetMinor: 200000),
      );
      final b = await repo.create(
        GoalDraft(
          name: 'Emergency fund',
          targetMinor: 500000,
          accountId: savings,
          targetDate: DateTime(2027, 10),
        ),
      );
      final d = await repo.create(
        const GoalDraft(
          name: 'Bike',
          targetMinor: 100000,
          contributionMinor: 10000,
        ),
      );
      await repo.addContribution(a, 25000);
      await repo.addContribution(a, -5000);
      await repo.addContribution(d, -99999);
      await repo.reorder([b, d, a]);
      await repo.setArchived(a, true);

      final sub = c.listen(goalsProgressProvider, (_, _) {});
      final list = await c.read(goalsProgressProvider.future);
      expect(list.map((g) => g.name), ['Emergency fund', 'Bike']);
      final ef = list.first;
      expect(ef.savedMinor, 80000);
      expect(ef.paceSource, GoalPaceSource.account);
      expect(ef.projection.requiredPerPeriodMinor, isNotNull);
      final bike = list.last;
      expect(bike.savedMinor, 0);
      expect(bike.paceSource, GoalPaceSource.contribution);
      // 10 contributions of 100 → start of the 10th next period: 1 Aug 2027
      // is a Sunday, so (default shift "previous") the period starts Fri 30
      // Jul.
      expect(bike.projection.projectedDate, DateTime(2027, 7, 30));
      final all = await c.read(allGoalsProgressProvider.future);
      expect(all.firstWhere((g) => g.id == a).savedMinor, 20000);
      sub.close();

      expect(
        () => repo.create(const GoalDraft(name: '', targetMinor: 0)),
        throwsArgumentError,
      );
      await repo.update(
        d,
        const GoalDraft(name: 'E-bike', targetMinor: 150000),
      );
      expect((await repo.goalById(d))!.name, 'E-bike');
      await repo.delete(d);
      expect(await repo.goalById(d), isNull);
    });
  });
}
