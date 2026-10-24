import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/budgets/data/budget_period_provider.dart';
import 'package:personal_finance/features/budgets/data/budgets_repository.dart';
import 'package:personal_finance/features/budgets/domain/budget_math.dart';
import 'package:personal_finance/features/budgets/domain/outstanding.dart';
import 'package:personal_finance/features/plan/plan_providers.dart';
import 'package:personal_finance/features/recurring/data/recurring_providers.dart';

/// Budget rows of the period starting at the given date.
final periodBudgetsProvider = StreamProvider.autoDispose
    .family<List<Budget>, DateTime>(
      (ref, start) => ref.watch(budgetsRepositoryProvider).watchPeriod(start),
    );

/// Actual spending and income of a period.
final periodActualsProvider = StreamProvider.autoDispose
    .family<PeriodActuals, DateRange>(
      (ref, range) => ref.watch(budgetsRepositoryProvider).watchActuals(range),
    );

/// Planned ledger entries of a period (budget accounts, no transfers).
final _plannedItemsProvider = StreamProvider.autoDispose
    .family<List<OutstandingItem>, DateRange>(
      (ref, range) => ref
          .watch(budgetsRepositoryProvider)
          .watchPlannedItems(range, ref.watch(planTodayProvider)),
    );

/// Ledger rows created for recurring rules in a period, for dedupe.
final _ruleBookingsProvider = StreamProvider.autoDispose
    .family<Set<(String, DateTime)>, DateRange>(
      (ref, range) =>
          ref.watch(budgetsRepositoryProvider).watchRuleBookings(range),
    );

/// Outstanding amounts of a period: planned ledger entries plus unposted
/// recurring occurrences (deduped against rows already booked for a rule).
/// Empty while Settings › Budgets › show outstanding is off.
final periodPlannedProvider = FutureProvider.autoDispose
    .family<PeriodPlanned, DateRange>((ref, range) async {
      final show = ref.watch(
        settingsProvider.select((s) => s.get(BudgetSettings.showOutstanding)),
      );
      if (!show) return PeriodPlanned.empty;
      final today = ref.watch(planTodayProvider);
      final calendar = ref.watch(holidayCalendarProvider);
      final plannedF = ref.watch(_plannedItemsProvider(range).future);
      final bookingsF = ref.watch(_ruleBookingsProvider(range).future);
      final plansF = ref.watch(recurringPlansProvider.future);
      final accountsF = ref.watch(accountsProvider.future);
      final categoriesF = ref.watch(categoriesProvider.future);
      final planned = await plannedF;
      final bookings = await bookingsF;
      final plans = await plansF;
      final accounts = await accountsF;
      final categories = await categoriesF;
      final recurring = recurringOutstanding(
        plans: plans,
        range: range,
        today: today,
        calendar: calendar,
        budgetAccountIds: {
          for (final a in accounts)
            if (a.includeInBudgets) a.id,
        },
        posted: bookings,
      );
      return PeriodPlanned.fromItems(
        [...planned, ...recurring],
        {for (final c in categories) c.id: c.kind},
      );
    });

/// Budget templates, sorted by name.
final budgetTemplatesProvider = StreamProvider<List<BudgetTemplate>>(
  (ref) => ref.watch(budgetsRepositoryProvider).watchTemplates(),
);

/// Effective warning threshold (percent) for a category: the category's
/// `warnThresholdOverride`, else a category-scoped setting, else global.
int warnThresholdFor(Category? c, SettingsSnapshot s) {
  final override = c?.warnThresholdOverride;
  if (override != null && override > 0) return override;
  if (c == null) return s.get(BudgetSettings.warnThreshold);
  return s.get(BudgetSettings.warnThreshold, scope: 'category:${c.id}');
}

/// Effective rollover mode for a category.
RolloverMode rolloverModeFor(Category? c, SettingsSnapshot s) =>
    parseRolloverMode(c?.rolloverOverride) ??
    s.get(BudgetSettings.defaultRollover);

/// Rollovers along the chain ending at the period (synced to the DB) and
/// the envelope carry. Re-runs when the previous period's spending or
/// budgets change.
final budgetChainProvider = FutureProvider.autoDispose
    .family<BudgetChain, DateRange>((ref, period) async {
      final periods = ref.watch(budgetPeriodsProvider);
      final prev = periods.previous(period);
      final settings = ref.watch(settingsProvider);
      final categoriesF = ref.watch(categoriesProvider.future);
      final prevActualsF = ref.watch(periodActualsProvider(prev).future);
      final prevBudgetsF = ref.watch(periodBudgetsProvider(prev.start).future);
      final budgetsF = ref.watch(periodBudgetsProvider(period.start).future);
      final categories = await categoriesF;
      await prevActualsF;
      await prevBudgetsF;
      await budgetsF;
      return await ref
          .read(budgetsRepositoryProvider)
          .syncChain(
            periods: periods,
            target: period,
            categories: {for (final c in categories) c.id: c},
            defaultMode: settings.get(BudgetSettings.defaultRollover),
          );
    });

/// Builds the [BudgetSummary] of [period] from its rows, actuals and chain.
BudgetSummary buildBudgetSummary({
  required DateRange period,
  required DateTime today,
  required BudgetMode mode,
  required List<Budget> budgets,
  required PeriodActuals actuals,
  required Map<String, Category> categories,
  required BudgetChain chain,
  required SettingsSnapshot settings,
  PeriodPlanned planned = PeriodPlanned.empty,
}) {
  final children = <String, List<String>>{};
  for (final c in categories.values) {
    if (c.parentId != null) {
      children.putIfAbsent(c.parentId!, () => []).add(c.id);
    }
  }
  final budgeted = {
    for (final b in budgets)
      if (categories.containsKey(b.categoryId)) b.categoryId,
  };
  final lines = <BudgetLine>[];
  for (final b in budgets) {
    final c = categories[b.categoryId];
    if (c == null) continue;
    lines.add(
      BudgetLine(
        categoryId: c.id,
        parentId: c.parentId,
        name: c.name,
        icon: c.icon,
        color: c.color,
        budgetId: b.id,
        budgetedMinor: b.amountMinor,
        rolloverMinor: chain.rolloverByCategory[c.id] ?? 0,
        spentMinor: actuals.spentOf(c.id, children[c.id] ?? const []),
        plannedMinor: planned.spentOf(c.id, children[c.id] ?? const []),
        thresholdPercent: warnThresholdFor(c, settings),
        rolloverMode: rolloverModeFor(c, settings),
        isRoot: c.parentId == null || !budgeted.contains(c.parentId),
      ),
    );
  }
  var unbudgeted = actuals.uncategorizedSpentMinor;
  for (final e in actuals.netByCategory.entries) {
    final c = categories[e.key];
    if (c == null || c.kind != CategoryKind.expense) continue;
    if (budgeted.contains(c.id)) continue;
    if (c.parentId != null && budgeted.contains(c.parentId)) continue;
    unbudgeted -= e.value;
  }
  return BudgetSummary(
    period: period,
    today: today,
    mode: mode,
    lines: sortLines(lines),
    incomeMinor: actuals.incomeMinor,
    carryMinor: chain.carryMinor,
    unbudgetedSpentMinor: unbudgeted,
    plannedIncomeMinor: planned.incomeMinor,
  );
}

/// The budget board of a period (Plan › Budgets).
final budgetBoardProvider = FutureProvider.autoDispose
    .family<BudgetSummary, DateRange>((ref, period) async {
      final settings = ref.watch(settingsProvider);
      final today = ref.watch(planTodayProvider);
      final budgetsF = ref.watch(periodBudgetsProvider(period.start).future);
      final actualsF = ref.watch(periodActualsProvider(period).future);
      final categoriesF = ref.watch(categoriesProvider.future);
      final chainF = ref.watch(budgetChainProvider(period).future);
      final plannedF = ref.watch(periodPlannedProvider(period).future);
      final categories = await categoriesF;
      return buildBudgetSummary(
        period: period,
        today: today,
        mode: settings.get(BudgetSettings.mode),
        budgets: await budgetsF,
        actuals: await actualsF,
        categories: {for (final c in categories) c.id: c},
        chain: await chainF,
        settings: settings,
        planned: await plannedF,
      );
    });

/// Budgets of the current period (dashboard "Budgets" card): totals and
/// per-category lines with their state.
final budgetSummaryProvider = FutureProvider.autoDispose<BudgetSummary>(
  (ref) => ref.watch(
    budgetBoardProvider(ref.watch(currentBudgetPeriodProvider)).future,
  ),
);

/// The period shown on the budgets board; null = the current period.
final selectedBudgetPeriodProvider =
    NotifierProvider<SelectedBudgetPeriod, DateTime?>(SelectedBudgetPeriod.new);

class SelectedBudgetPeriod extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void select(DateRange period) => state = period.start;

  void reset() => state = null;
}

/// The period shown on the budgets board.
final shownBudgetPeriodProvider = Provider<DateRange>((ref) {
  final periods = ref.watch(budgetPeriodsProvider);
  final anchor = ref.watch(selectedBudgetPeriodProvider);
  return periods.periodOf(anchor ?? ref.watch(planTodayProvider));
});
