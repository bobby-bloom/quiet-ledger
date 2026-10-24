import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/calendar/holidays.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/budgets/data/budget_period_provider.dart';
import 'package:personal_finance/features/budgets/data/budget_providers.dart';
import 'package:personal_finance/features/budgets/data/budgets_repository.dart';
import 'package:personal_finance/features/plan/plan_providers.dart';
import 'package:personal_finance/features/recurring/data/recurring_repository.dart';
import 'package:personal_finance/features/recurring/domain/recurring_logic.dart';

import '../../helpers/test_app.dart';
import '../plan/plan_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProviderContainer c;
  late PlanFixture f;

  setUp(() {
    db = newTestDb();
    f = PlanFixture(db);
    c = testContainer(
      db,
      overrides: [planTodayProvider.overrideWithValue(DateTime(2026, 10, 24))],
    );
  });

  tearDown(() async {
    c.dispose();
    await db.close();
  });

  test('salaryDates merges posted and expected dates', () {
    final plan = RecurringPlan(
      id: 'r',
      name: 'Salary',
      rrule: 'FREQ=MONTHLY;BYMONTHDAY=25',
      start: DateTime(2026),
      template: TxnDraft(accountId: 'a', amountMinor: 1, date: DateTime(2026)),
      lastPostedDate: DateTime(2026, 10, 25),
    );
    final dates = salaryDates(
      posted: [DateTime(2026, 9, 25), DateTime(2026, 10, 23)],
      rule: plan,
      calendar: HolidayCalendar.none(),
      today: DateTime(2026, 10, 24),
      horizonDays: 70,
    );
    expect(dates, [
      DateTime(2026, 9, 25),
      DateTime(2026, 10, 23),
      DateTime(2026, 11, 25),
      DateTime(2026, 12, 25),
    ]);
  });

  test('salary-based periods start when the salary actually lands', () async {
    final checking = await f.account('Checking');
    final salaryCat = await f.category('Salary', kind: CategoryKind.income);
    final repo = c.read(recurringRepositoryProvider);
    final ruleId = await repo.create(
      RecurringRuleDraft(
        name: 'Salary',
        rrule: 'FREQ=MONTHLY;BYMONTHDAY=25',
        startDate: DateTime(2026, 8, 25),
        weekendShift: WeekendShift.previous,
        template: TxnDraft(
          accountId: checking,
          amountMinor: 300000,
          date: DateTime(2026),
          type: TxnType.income,
          categoryId: salaryCat,
        ),
      ),
    );
    // Salary arrived on 25 Sep and early on 23 Oct (confirmed for 23 Oct's
    // occurrence of the 25th).
    for (final d in [DateTime(2026, 9, 25), DateTime(2026, 10, 23)]) {
      await f.ledger.create(
        TxnDraft(
          accountId: checking,
          amountMinor: 300000,
          date: d,
          type: TxnType.income,
          categoryId: salaryCat,
          recurringRuleId: ruleId,
        ),
      );
    }
    await f.writer.update(
      db.recurringRules,
      ruleId,
      RecurringRulesCompanion(lastPostedDate: Value(DateTime(2026, 10, 23))),
    );
    final settings = c.read(settingsProvider.notifier);
    await settings.set(BudgetSettings.salaryBased, true);
    await settings.set(BudgetSettings.salaryRuleId, ruleId);
    await settings.set(BudgetSettings.holidayCountry, 'DE');

    final sub = c.listen(budgetPeriodsProvider, (_, _) {});
    final dates = await c.read(salaryDatesProvider.future);
    // Expected: Nov 25 (Wed) and Dec 25 (holiday) → 23 Dec (24 Dec is a
    // bank closing day in the German calendar).
    expect(dates.take(4), [
      DateTime(2026, 9, 25),
      DateTime(2026, 10, 23),
      DateTime(2026, 11, 25),
      DateTime(2026, 12, 23),
    ]);
    final periods = sub.read();
    expect(
      periods.periodOf(DateTime(2026, 10, 24)),
      DateRange(DateTime(2026, 10, 23), DateTime(2026, 11, 25)),
    );
    expect(
      periods.periodOf(DateTime(2026, 10)),
      DateRange(DateTime(2026, 9, 25), DateTime(2026, 10, 23)),
    );
    expect(
      c.read(currentBudgetPeriodProvider),
      DateRange(DateTime(2026, 10, 23), DateTime(2026, 11, 25)),
    );
    sub.close();
  });

  test('settings drive the period configuration', () async {
    final settings = c.read(settingsProvider.notifier);
    await settings.set(BudgetSettings.startDay, 25);
    await settings.set(BudgetSettings.weekendShift, WeekendShift.previous);
    await settings.set(BudgetSettings.holidayCountry, 'DE');
    final p = c.read(budgetPeriodsProvider).periodOf(DateTime(2026, 10, 24));
    // 25 Oct 2026 is a Sunday → Fri 23 Oct; 25 Nov 2026 is a Wednesday.
    expect(p, DateRange(DateTime(2026, 10, 23), DateTime(2026, 11, 25)));
    await settings.set(BudgetSettings.periodType, BudgetPeriodType.weekly);
    await settings.set(GeneralSettings.firstDayOfWeek, FirstDayOfWeek.monday);
    final w = c.read(budgetPeriodsProvider).periodOf(DateTime(2026, 10, 24));
    expect(w, DateRange(DateTime(2026, 10, 19), DateTime(2026, 10, 26)));
  });

  test('budget summary: totals, envelope and state per category', () async {
    final checking = await f.account('Checking');
    final groceries = await f.category('Groceries');
    final shopping = await f.category('Shopping');
    final eating = await f.category('Eating out', warnThresholdOverride: 90);
    final salary = await f.category('Salary', kind: CategoryKind.income);
    final period = c.read(currentBudgetPeriodProvider);
    final budgets = c.read(budgetsRepositoryProvider);
    await budgets.setAmounts(period.start, {
      groceries: 40000,
      shopping: 16000,
      eating: 15000,
    });
    await f.expense(checking, groceries, 31240, DateTime(2026, 10, 5));
    await f.expense(checking, shopping, 18490, DateTime(2026, 10, 6));
    await f.expense(checking, eating, 13860, DateTime(2026, 10, 7));
    await f.income(checking, salary, 300000, DateTime(2026, 10));
    await c
        .read(settingsProvider.notifier)
        .set(BudgetSettings.mode, BudgetMode.envelope);

    final sub = c.listen(budgetSummaryProvider, (_, _) {});
    final s = await c.read(budgetSummaryProvider.future);
    expect(s.totalBudgetedMinor, 71000);
    expect(s.totalSpentMinor, 63590);
    expect(s.lineFor(shopping)!.overMinor, 2490);
    expect(s.lines.first.categoryId, shopping); // over first
    expect(s.lineFor(eating)!.state.name, 'warning'); // 92 % ≥ 90 %
    expect(s.lineFor(eating)!.percentUsed, 92);
    expect(s.lineFor(groceries)!.state.name, 'onTrack');
    expect(s.toBeBudgetedMinor, 300000 - 71000);
    // Default shift "previous": 1 Nov 2026 (Sunday) → the period ends on
    // Thu 29 Oct.
    expect(s.period.last, DateTime(2026, 10, 29));
    expect(s.dayOfPeriod, 24);
    expect(s.daysLeft, 6);
    sub.close();
  });
}
