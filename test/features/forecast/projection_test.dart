import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/forecast/domain/cashflow_engine.dart';
import 'package:personal_finance/features/forecast/domain/forecast_dates.dart';
import 'package:personal_finance/features/forecast/domain/forecast_models.dart';
import 'package:personal_finance/features/forecast/domain/forecast_pipeline.dart';
import 'package:personal_finance/features/forecast/domain/projection.dart';

import 'forecast_fixtures.dart';

NetWorthProjection project(ForecastInput input, ProjectionAssumptions a) =>
    runProjectionBatch(ProjectionRequest(input: input, assumptions: a))
        .baseline;

ForecastInput only(
  List<ForecastAccount> accounts, {
  List<RecurringItem> recurring = const [],
  SpendingHistory history = const SpendingHistory(),
  List<GoalInput> goals = const [],
  String? primary,
}) => ForecastInput(
  today: today,
  accounts: accounts,
  recurring: recurring,
  history: history,
  goals: goals,
  primaryAccountId: primary,
);

void main() {
  const noInflation = ProjectionAssumptions(years: 1, inflationBp: 0);

  test('expected return compounds monthly with cent rounding', () {
    final p = project(
      only([
        account(
          'etf',
          balance: 1000000,
          type: AccountType.investment,
          returnBp: 600,
        ),
      ]),
      noInflation,
    );
    expect(p.points.length, 13);
    expect(p.points.first.nominalMinor, 1000000);
    // 10,000.00 × (1 + 0.06 / 12)^12, rounded to the cent each month.
    expect(p.last.nominalMinor, 1061679);
    expect(p.last.date, addMonthsClamped(today, 12));
  });

  test('default return applies to non-cash assets only', () {
    final p = project(
      only([
        account('chk', balance: 1000000),
        account('sav', balance: 1000000, type: AccountType.savings),
      ]),
      noInflation.copyWith(defaultReturnBp: 600),
    );
    expect(p.last.nominalMinor, 1000000 + 1061679);
  });

  test('loan interest and recurring repayments, debt-free milestone', () {
    final p = project(
      only(
        [
          account('chk', balance: 2000000),
          account(
            'loan',
            balance: -1000000,
            type: AccountType.loan,
            interestBp: 1200,
          ),
        ],
        recurring: [
          rule(
            'repay',
            rrule: 'FREQ=MONTHLY;BYMONTHDAY=1',
            amount: -100000,
            accountId: 'chk',
            transferTo: 'loan',
          ),
        ],
      ),
      noInflation.copyWith(years: 2),
    );
    // 1 % per month on the debt; the last payment only covers what is left.
    final debtFree = p.milestones.singleWhere(
      (m) => m.kind == MilestoneKind.debtFree,
    );
    expect(debtFree.date, addMonthsClamped(today, 11));
    expect(p.points[11].liabilitiesMinor, 0);
    expect(p.points[10].liabilitiesMinor, lessThan(0));
    // Total paid 10,589.85: net worth 20,000 − 10,000 − 589.85 interest.
    expect(p.points[11].nominalMinor, 941015);
    // The payment stops once the loan is paid off.
    expect(p.last.nominalMinor, 941015);
  });

  test('inflation: real vs nominal', () {
    final a = noInflation.copyWith(inflationBp: 200);
    final p = project(only([account('chk', balance: 1000000)]), a);
    expect(p.last.nominalMinor, 1000000);
    expect(p.last.realMinor, 980215);
    expect(p.real, isFalse);
    final real = p.withReal(true);
    expect(real.real, isTrue);
    expect(real.values.last, 980215);
  });

  test('net-worth milestones are found for real and nominal values', () {
    // Returns keep pace with inflation: only the nominal value grows.
    final p = project(
      only([
        account(
          'etf',
          balance: 950000,
          type: AccountType.investment,
          returnBp: 600,
        ),
      ]),
      noInflation.copyWith(inflationBp: 600),
    );
    expect(p.milestones, same(p.nominalMilestones));
    expect(
      [for (final m in p.nominalMilestones) (m.amountMinor, m.date)],
      [(1000000, addMonthsClamped(today, 11))],
    );
    expect(p.realMilestones, isEmpty);
    final real = p.withReal(true);
    expect(real.milestones, isEmpty);
    expect(real.values, [for (final pt in p.points) pt.realMinor]);
    expect(real.withReal(false).milestones, p.nominalMilestones);
  });

  test('savings from history: trailing mean, indexed to inflation', () {
    final history = SpendingHistory(monthlyNet: List.filled(12, 100000));
    final p = project(
      only([account('chk', balance: 500000)], history: history),
      noInflation.copyWith(years: 2),
    );
    expect(p.monthlySavingsMinor, 100000);
    expect(p.points[12].nominalMinor, 500000 + 12 * 100000);
    // Milestones: 10k after 5 months, 25k after 20 months.
    final levels = [
      for (final m in p.milestones)
        if (m.kind == MilestoneKind.netWorth) (m.amountMinor, m.date),
    ];
    expect(levels, [
      (1000000, addMonthsClamped(today, 5)),
      (2500000, addMonthsClamped(today, 20)),
    ]);

    final indexed = project(
      only([account('chk')], history: history),
      const ProjectionAssumptions(years: 1, inflationBp: 1200),
    );
    // 1 % per month: 1,010.00, 1,020.10, ...
    expect(indexed.points[1].nominalMinor, 101000);
    expect(indexed.points[2].nominalMinor, 101000 + 102010);
  });

  test('savings from the plan follow the recurring rules', () {
    final input = only(
      [account('chk')],
      recurring: [
        rule(
          'salary',
          rrule: 'FREQ=MONTHLY;BYMONTHDAY=28',
          amount: 300000,
          accountId: 'chk',
        ),
        rule(
          'rent',
          rrule: 'FREQ=MONTHLY;BYMONTHDAY=1',
          amount: -120000,
          accountId: 'chk',
          end: d(2027, 4, 30),
        ),
      ],
      history: SpendingHistory(monthlyNet: List.filled(12, 1)),
    );
    final p = project(input, noInflation.copyWith(source: SavingsSource.plan));
    expect(p.source, SavingsSource.plan);
    // Steps end on the 23rd: Oct 28 + Nov 1 fall into step 1.
    expect(p.points[1].nominalMinor, 180000);
    // Rent ends in April: from step 7 on only the salary remains.
    expect(p.points[6].nominalMinor, 6 * 180000);
    expect(p.points[7].nominalMinor - p.points[6].nominalMinor, 300000);
  });

  test('plan savings use budgets for variable spending', () {
    final input = ForecastInput(
      today: today,
      accounts: [account('chk')],
      recurring: [
        rule(
          'salary',
          rrule: 'FREQ=MONTHLY;BYMONTHDAY=28',
          amount: 300000,
          accountId: 'chk',
        ),
      ],
      history: SpendingHistory(
        months: [
          for (final m in [7, 8, 9])
            CategoryMonthTotal(
              categoryId: 'groceries',
              year: 2026,
              month: m,
              spentMinor: 99999,
            ),
        ],
        firstTxnDate: d(2026, 1, 1),
        categoryAccount: const {'groceries': 'chk'},
        expenseCategoryIds: const {'groceries'},
      ),
      budgets: [
        BudgetRow(
          categoryId: 'groceries',
          periodStart: d(2026, 10, 1),
          amountMinor: 50000,
        ),
      ],
      method: VariableSpendingMethod.mean3,
      primaryAccountId: 'chk',
    );
    final p = project(input, noInflation.copyWith(source: SavingsSource.plan));
    // Step 1 (24 Oct – 23 Nov): salary − October's budget − 23/30 of
    // November's budget (⌊23 · 500/30⌋).
    expect(p.points[1].nominalMinor, 300000 - 50000 - 38333);
  });

  test('goal reached milestone for linked and unlinked goals', () {
    final input = only(
      [
        account('chk', balance: 1000000),
        account('sav', type: AccountType.savings),
      ],
      goals: const [
        GoalInput(
          id: 'g1',
          name: 'Car',
          targetMinor: 300000,
          accountId: 'sav',
          contributionMinor: 100000,
        ),
        GoalInput(
          id: 'g2',
          name: 'Bike',
          targetMinor: 50000,
          savedMinor: 10000,
          contributionMinor: 20000,
        ),
      ],
      primary: 'chk',
    );
    final p = project(input, noInflation);
    final reached = {
      for (final m in p.milestones)
        if (m.kind == MilestoneKind.goalReached) m.refId: m.date,
    };
    expect(reached['g1'], addMonthsClamped(today, 3));
    expect(reached['g2'], addMonthsClamped(today, 2));
    // Contributions are transfers: net worth does not change.
    expect(p.last.nominalMinor, 1010000);
  });

  test('milestones already passed are not repeated', () {
    final p = project(only([account('chk', balance: 3000000)]), noInflation);
    expect(p.milestones, isEmpty);
  });

  test('yearly points and monthly flows aggregation', () {
    final model = prepareCashflowModel(
      only([account('chk')]),
      scope: AccountScope.netWorth,
      endOverride: addMonthsClamped(today, 24),
    );
    final flows = aggregateMonthly(model, 24);
    expect(flows.steps, 24);
    expect(flows.stepEnds.first, d(2026, 11, 23));
    final p = projectNetWorth(
      model,
      const ProjectionAssumptions(years: 2),
      flows: flows,
    );
    expect(p.yearly.length, 3);
  });
}
