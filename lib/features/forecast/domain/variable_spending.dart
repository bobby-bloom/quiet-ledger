import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/calendar/holidays.dart';
import 'package:personal_finance/core/settings/setting_enums.dart';
import 'package:personal_finance/features/forecast/domain/forecast_dates.dart';
import 'package:personal_finance/features/forecast/domain/forecast_models.dart';
import 'package:personal_finance/features/forecast/domain/recurring_expansion.dart';

// Expected variable spending (PLAN.md §2.4).
//
// Heuristics:
// * Mean/median methods look at the trailing N *complete* calendar months
//   before the current month. Months before the first ledger entry are not
//   counted (a new user with 2 months of history gets a 2-month statistic);
//   months inside the window without spending in a category count as 0.
//   The history excludes transfers and entries created by recurring rules.
// * Categories that an active recurring rule books to are skipped for the
//   mean/median methods: their spending is already in the rules (this also
//   avoids double counting imported history that is not linked to a rule).
// * The budget method uses the budget of each period (the latest budget row
//   at or before the period, so budgets carry forward into periods that
//   are not filled yet) minus what recurring rules book to that category in
//   the period, floored at 0. Rollover amounts are not counted as spending.
// * In the current month/period only the remainder (estimate − already
//   spent, ≥ 0) is spread over the days from tomorrow to its end.
// * Each estimate is booked on the account where the category is usually
//   paid (most entries in the history), falling back to the primary
//   account. Categories usually paid from an account outside the forecast
//   are not forecast.
// * Money is spread evenly over the days of the month/period; the
//   remainder cents go to the first days, so totals never drift.

/// Trailing months of a mean/median method (0 for the budget method).
int trailingMonthsOf(VariableSpendingMethod m) => switch (m) {
  VariableSpendingMethod.budget => 0,
  VariableSpendingMethod.mean3 || VariableSpendingMethod.median3 => 3,
  VariableSpendingMethod.mean6 || VariableSpendingMethod.median6 => 6,
  VariableSpendingMethod.mean12 || VariableSpendingMethod.median12 => 12,
};

bool isMedianMethod(VariableSpendingMethod m) =>
    m == VariableSpendingMethod.median3 ||
    m == VariableSpendingMethod.median6 ||
    m == VariableSpendingMethod.median12;

/// Mean of [values], rounded half away from zero.
int meanOf(List<int> values) => values.isEmpty
    ? 0
    : divRound(values.fold(0, (a, b) => a + b), values.length);

/// Median of [values]; for an even count the mean of the two middle values
/// (rounded half away from zero).
int medianOf(List<int> values) {
  if (values.isEmpty) return 0;
  final s = [...values]..sort();
  final mid = s.length ~/ 2;
  return s.length.isOdd ? s[mid] : divRound(s[mid - 1] + s[mid], 2);
}

/// The complete calendar months used by a trailing window of [months]
/// before [today]'s month, oldest first, skipping months before
/// [firstTxnDate].
List<DateTime> trailingWindow(
  DateTime today,
  int months,
  DateTime? firstTxnDate,
) {
  if (firstTxnDate == null || months <= 0) return const [];
  final first = monthStart(firstTxnDate);
  final current = monthStart(today);
  return [
    for (var k = months; k >= 1; k--) DateTime(current.year, current.month - k),
  ].where((m) => !m.isBefore(first)).toList();
}

/// Expected monthly spending (positive) per expense category for a
/// mean/median [method]. Categories in [exclude] are skipped.
Map<String, int> estimateMonthlySpending({
  required SpendingHistory history,
  required VariableSpendingMethod method,
  required DateTime today,
  Set<String> exclude = const {},
}) {
  final window = trailingWindow(
    today,
    trailingMonthsOf(method),
    history.firstTxnDate,
  );
  if (window.isEmpty) return const {};
  final index = {
    for (var i = 0; i < window.length; i++)
      window[i].year * 12 + window[i].month: i,
  };
  final values = <String, List<int>>{};
  for (final t in history.months) {
    if (exclude.contains(t.categoryId)) continue;
    if (history.expenseCategoryIds.isNotEmpty &&
        !history.expenseCategoryIds.contains(t.categoryId)) {
      continue;
    }
    final i = index[t.year * 12 + t.month];
    if (i == null) continue;
    (values[t.categoryId] ??= List<int>.filled(window.length, 0))[i] +=
        t.spentMinor;
  }
  final median = isMedianMethod(method);
  final out = <String, int>{};
  for (final e in values.entries) {
    final v = median ? medianOf(e.value) : meanOf(e.value);
    if (v > 0) out[e.key] = v;
  }
  return out;
}

/// Spending (positive) that recurring [items] book to each category within
/// [range].
Map<String, int> recurringSpendingIn(
  List<RecurringItem> items,
  DateRange range,
  HolidayCalendar? calendar,
) {
  final out = <String, int>{};
  for (final item in items) {
    if (item.isTransfer) continue;
    final cats = {
      for (final c in item.categories)
        if (c.categoryId != null) c.categoryId!,
    };
    if (cats.isEmpty) continue;
    for (final o in expandItem(
      item,
      range.start,
      range.last,
      calendar: calendar,
    )) {
      for (final c in cats) {
        final portion = categoryPortion(item, c, o.amountMinor);
        out[c] = (out[c] ?? 0) - portion;
      }
    }
  }
  return out;
}

/// Builds the spread items of expected variable spending for
/// `(today, end]`.
List<SpreadItem> planVariableSpending(
  ForecastInput input,
  DateTime end, {
  required Set<String> accountIds,
  List<RecurringItem>? recurring,
}) {
  final today = dayOf(input.today);
  final tomorrow = addDays(today, 1);
  if (end.isBefore(tomorrow)) return const [];
  final rules = recurring ?? input.recurring;
  final h = input.history;

  String? accountFor(String categoryId) {
    final usual = h.categoryAccount[categoryId];
    if (usual != null) return accountIds.contains(usual) ? usual : null;
    final p = input.primaryAccountId;
    return p != null && accountIds.contains(p) ? p : null;
  }

  final out = <SpreadItem>[];
  if (input.method == VariableSpendingMethod.budget) {
    final periods = BudgetPeriods(input.periodConfig)
        .periodsBetween(today, end);
    final byCategory = <String, List<BudgetRow>>{};
    for (final b in input.budgets) {
      if (h.expenseCategoryIds.isNotEmpty &&
          !h.expenseCategoryIds.contains(b.categoryId)) {
        continue;
      }
      (byCategory[b.categoryId] ??= []).add(b);
    }
    for (final list in byCategory.values) {
      list.sort((a, b) => a.periodStart.compareTo(b.periodStart));
    }
    for (final p in periods) {
      final recurringIn = recurringSpendingIn(rules, p, input.calendar);
      final isCurrent = p.contains(today);
      for (final e in byCategory.entries) {
        BudgetRow? row;
        for (final b in e.value) {
          if (b.periodStart.isBefore(p.end)) row = b;
        }
        if (row == null) continue;
        var amount = row.amountMinor - (recurringIn[e.key] ?? 0);
        if (isCurrent) amount -= h.spentThisPeriod[e.key] ?? 0;
        if (amount <= 0) continue;
        final account = accountFor(e.key);
        if (account == null) continue;
        final start = isCurrent ? tomorrow : p.start;
        if (!start.isBefore(p.end)) continue;
        out.add(
          SpreadItem(
            accountId: account,
            categoryId: e.key,
            start: start,
            end: p.end,
            totalMinor: -amount,
          ),
        );
      }
    }
    return out;
  }

  final covered = <String>{
    for (final r in rules)
      if (!r.isTransfer)
        for (final c in r.categories)
          if (c.categoryId != null) c.categoryId!,
  };
  final estimates = estimateMonthlySpending(
    history: h,
    method: input.method,
    today: today,
    exclude: covered,
  );
  for (final e in estimates.entries) {
    final account = accountFor(e.key);
    if (account == null) continue;
    final remaining = e.value - (h.spentThisMonth[e.key] ?? 0);
    final firstNext = nextMonthStart(today);
    if (remaining > 0 && tomorrow.isBefore(firstNext)) {
      out.add(
        SpreadItem(
          accountId: account,
          categoryId: e.key,
          start: tomorrow,
          end: firstNext,
          totalMinor: -remaining,
        ),
      );
    }
    for (var m = firstNext; !m.isAfter(end); m = nextMonthStart(m)) {
      out.add(
        SpreadItem(
          accountId: account,
          categoryId: e.key,
          start: m,
          end: nextMonthStart(m),
          totalMinor: -e.value,
        ),
      );
    }
  }
  return out;
}
