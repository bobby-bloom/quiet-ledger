import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/forecast/domain/cashflow_engine.dart';
import 'package:personal_finance/features/forecast/domain/forecast_models.dart';
import 'package:personal_finance/features/forecast/domain/variable_spending.dart';

import 'forecast_fixtures.dart';

CategoryMonthTotal m(String cat, int y, int month, int spent) =>
    CategoryMonthTotal(
      categoryId: cat,
      year: y,
      month: month,
      spentMinor: spent,
    );

/// Groceries: Jul 100.00, Aug 500.00, Sep 600.00; fuel: Sep 90.00.
SpendingHistory history({DateTime? first, Map<String, int>? spentThisMonth}) =>
    SpendingHistory(
      months: [
        m('groceries', 2026, 7, 10000),
        m('groceries', 2026, 8, 50000),
        m('groceries', 2026, 9, 60000),
        m('fuel', 2026, 9, 9000),
        // Current (incomplete) month is never part of the window.
        m('groceries', 2026, 10, 99999),
      ],
      firstTxnDate: first ?? d(2026, 7, 3),
      categoryAccount: const {'groceries': 'checking', 'fuel': 'card'},
      spentThisMonth: spentThisMonth ?? const {},
      expenseCategoryIds: const {'groceries', 'fuel', 'cat-rent'},
    );

Map<String, int> estimate(VariableSpendingMethod method, {DateTime? first}) =>
    estimateMonthlySpending(
      history: history(first: first),
      method: method,
      today: today,
    );

void main() {
  group('statistics', () {
    test('mean and median', () {
      expect(meanOf([10000, 50000, 60000]), 40000);
      expect(medianOf([60000, 10000, 50000]), 50000);
      expect(medianOf([0, 0, 0, 10000, 50000, 60000]), 5000);
      expect(medianOf([1, 2]), 2); // 1.5 rounds half away from zero
      expect(meanOf(const []), 0);
      expect(medianOf(const []), 0);
    });

    test('trailing window uses complete months after the first entry', () {
      expect(trailingWindow(today, 3, d(2020, 1, 1)), [
        d(2026, 7, 1),
        d(2026, 8, 1),
        d(2026, 9, 1),
      ]);
      expect(trailingWindow(today, 6, d(2026, 8, 20)), [
        d(2026, 8, 1),
        d(2026, 9, 1),
      ]);
      expect(trailingWindow(today, 12, null), isEmpty);
      expect(trailingWindow(today, 3, d(2026, 10, 2)), isEmpty);
    });
  });

  group('estimateMonthlySpending', () {
    test('mean vs median over 3 months', () {
      expect(estimate(VariableSpendingMethod.mean3), {
        'groceries': 40000,
        'fuel': 3000,
      });
      expect(estimate(VariableSpendingMethod.median3), {'groceries': 50000});
    });

    test('6/12 month windows count empty months as zero', () {
      final first = d(2026, 1, 15);
      // Apr–Sep: 0, 0, 0, 100, 500, 600.
      expect(estimate(VariableSpendingMethod.mean6, first: first), {
        'groceries': 20000,
        'fuel': 1500,
      });
      expect(estimate(VariableSpendingMethod.median6, first: first), {
        'groceries': 5000,
      });
      // Jan–Sep available (9 months) for the 12-month window.
      expect(estimate(VariableSpendingMethod.mean12, first: first), {
        'groceries': 13333,
        'fuel': 1000,
      });
      expect(estimate(VariableSpendingMethod.median12, first: first), isEmpty);
    });

    test('short history limits the window instead of adding zeros', () {
      // Only Jul–Sep exist: the 12-month mean equals the 3-month mean.
      expect(
        estimate(VariableSpendingMethod.mean12),
        estimate(VariableSpendingMethod.mean3),
      );
    });

    test('excluded (recurring-covered) and non-expense categories', () {
      final h = SpendingHistory(
        months: [m('groceries', 2026, 9, 1000), m('salary', 2026, 9, 5000)],
        firstTxnDate: d(2026, 1, 1),
        expenseCategoryIds: const {'groceries'},
      );
      expect(
        estimateMonthlySpending(
          history: h,
          method: VariableSpendingMethod.mean3,
          today: today,
          exclude: {'groceries'},
        ),
        isEmpty,
      );
    });

    test('net refunds never produce negative spending', () {
      final h = SpendingHistory(
        months: [m('groceries', 2026, 9, -5000)],
        firstTxnDate: d(2026, 1, 1),
      );
      expect(
        estimateMonthlySpending(
          history: h,
          method: VariableSpendingMethod.mean3,
          today: today,
        ),
        isEmpty,
      );
    });
  });

  group('planVariableSpending (history)', () {
    final input = baseInput(
      recurring: const [],
      history: history(spentThisMonth: {'groceries': 30000}),
    );

    test('current month gets the remainder, later months the estimate', () {
      final items = planVariableSpending(
        input,
        d(2027, 1, 23),
        accountIds: {'checking', 'savings'},
      );
      // Fuel is usually paid by card, which is not in the forecast.
      expect(items.every((i) => i.categoryId == 'groceries'), isTrue);
      expect(items.first.start, d(2026, 10, 24));
      expect(items.first.end, d(2026, 11, 1));
      expect(items.first.totalMinor, -10000);
      expect(items.skip(1).map((i) => (i.start, i.totalMinor)), [
        (d(2026, 11, 1), -40000),
        (d(2026, 12, 1), -40000),
        (d(2027, 1, 1), -40000),
      ]);
    });

    test('daily spread is exact and clipped by the horizon', () {
      final r = simulateCashflow(prepareCashflowModel(input));
      int day(DateTime x) => r.balanceOn('checking', x);
      // 100.00 over 24–31 Oct = 12.50 per day.
      expect(day(d(2026, 10, 24)), 100000 - 1250);
      expect(day(d(2026, 10, 31)), 100000 - 10000);
      // 400.00 over 30 November days: no drift.
      expect(day(d(2026, 11, 30)), 100000 - 10000 - 40000);
      expect(day(d(2026, 11, 1)) - day(d(2026, 11, 2)), 1333);
      expect(day(d(2026, 11, 29)) - day(d(2026, 11, 30)), 1334);
      // January is clipped at 23 Jan: 23 of 31 daily shares, ⌊23 · 400/31⌋.
      final jan = day(d(2026, 12, 31)) - day(d(2027, 1, 23));
      expect(jan, 29677);
    });

    test('categories covered by a recurring rule are not estimated', () {
      final items = planVariableSpending(
        baseInput(
          recurring: [
            rule(
              'delivery',
              rrule: 'FREQ=WEEKLY',
              amount: -2000,
              categoryId: 'groceries',
            ),
          ],
          history: history(),
        ),
        d(2027, 1, 23),
        accountIds: {'checking'},
      );
      expect(items, isEmpty);
    });

    test('falls back to the primary account without history account', () {
      final items = planVariableSpending(
        baseInput(
          recurring: const [],
          history: SpendingHistory(
            months: [m('gifts', 2026, 9, 3000)],
            firstTxnDate: d(2026, 1, 1),
          ),
        ),
        d(2026, 12, 31),
        accountIds: {'checking'},
      );
      expect(items.map((i) => i.accountId).toSet(), {'checking'});
    });
  });

  group('planVariableSpending (budget)', () {
    final input = baseInput(
      method: VariableSpendingMethod.budget,
      history: history().copyWithSpent({'groceries': 30000}),
      budgets: [
        BudgetRow(
          categoryId: 'groceries',
          periodStart: d(2026, 10, 1),
          amountMinor: 45000,
        ),
        BudgetRow(
          categoryId: 'groceries',
          periodStart: d(2026, 12, 1),
          amountMinor: 60000,
        ),
        // Covered by the rent rule (1,200 → 1,300 from January).
        BudgetRow(
          categoryId: 'cat-rent',
          periodStart: d(2026, 10, 1),
          amountMinor: 125000,
        ),
      ],
    );

    test('budget per period minus recurring and spent so far', () {
      final items = planVariableSpending(
        input,
        d(2027, 1, 23),
        accountIds: {'checking'},
      );
      final groceries = [
        for (final i in items)
          if (i.categoryId == 'groceries') (i.start, i.end, i.totalMinor),
      ];
      expect(groceries, [
        (d(2026, 10, 24), d(2026, 11, 1), -15000),
        // November carries the October budget forward.
        (d(2026, 11, 1), d(2026, 12, 1), -45000),
        (d(2026, 12, 1), d(2027, 1, 1), -60000),
        (d(2027, 1, 1), d(2027, 2, 1), -60000),
      ]);
      final rent = [
        for (final i in items)
          if (i.categoryId == 'cat-rent') (i.start, i.totalMinor),
      ];
      // 1,250 budget − 1,200 rule = 50 until December; none from January.
      expect(rent, [
        (d(2026, 10, 24), -5000),
        (d(2026, 11, 1), -5000),
        (d(2026, 12, 1), -5000),
      ]);
    });

    test('follows the configured budget periods', () {
      final weekly = ForecastInput(
        today: today,
        accounts: input.accounts,
        method: VariableSpendingMethod.budget,
        budgets: [
          BudgetRow(
            categoryId: 'groceries',
            periodStart: d(2026, 10, 19),
            amountMinor: 7000,
          ),
        ],
        periodConfig: const BudgetPeriodConfig(type: BudgetPeriodType.weekly),
        primaryAccountId: 'checking',
      );
      final items = planVariableSpending(
        weekly,
        d(2026, 11, 8),
        accountIds: {'checking'},
      );
      expect(items.map((i) => (i.start, i.end, i.totalMinor)), [
        (d(2026, 10, 24), d(2026, 10, 26), -7000),
        (d(2026, 10, 26), d(2026, 11, 2), -7000),
        (d(2026, 11, 2), d(2026, 11, 9), -7000),
      ]);
    });
  });
}

extension on SpendingHistory {
  SpendingHistory copyWithSpent(Map<String, int> spent) => SpendingHistory(
    months: months,
    firstTxnDate: firstTxnDate,
    categoryAccount: categoryAccount,
    spentThisMonth: spentThisMonth,
    spentThisPeriod: spent,
    expenseCategoryIds: expenseCategoryIds,
  );
}
