import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/budgets/data/budget_period_provider.dart';
import 'package:personal_finance/features/budgets/data/budgets_repository.dart';
import 'package:personal_finance/features/budgets/domain/budget_math.dart';
import 'package:personal_finance/features/budgets/domain/budget_rules.dart';
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

/// Live repeating budgets.
final budgetRulesProvider = StreamProvider<List<BudgetRulePlan>>(
  (ref) => ref.watch(budgetsRepositoryProvider).watchRules(),
);

/// Generates the rows of repeating budgets up to the period (and at least up
/// to the next period) before a board reads it; resolves to the live rules.
final budgetRulesSyncProvider = FutureProvider.autoDispose
    .family<List<BudgetRulePlan>, DateRange>((ref, period) async {
      // Salary-based periods are only right once the salary dates loaded.
      await ref.watch(salaryDatesProvider.future);
      final periods = ref.watch(budgetPeriodsProvider);
      final next = periods.next(ref.watch(currentBudgetPeriodProvider));
      final rules = await ref.watch(budgetRulesProvider.future);
      if (rules.isEmpty) return rules;
      final upTo = period.start.isAfter(next.start) ? period.start : next.start;
      await ref.read(budgetsRepositoryProvider).ensureFromRules(periods, upTo);
      return rules;
    });

/// Budgets with their own length overlapping a range.
final periodWindowRowsProvider = StreamProvider.autoDispose
    .family<List<Budget>, DateRange>(
      (ref, range) => ref.watch(budgetsRepositoryProvider).watchWindows(range),
    );

/// A budget with its own length as shown on a board, with its figures.
typedef BoardWindow = ({
  Budget row,
  DateRange range,
  PeriodActuals actuals,
  PeriodPlanned planned,
  int rolloverMinor,
});

/// The window of each category with a budget of its own length shown on
/// the board of the period: the one containing the period's reference day
/// (today in the current period), else the last one starting before it,
/// else the first.
Map<String, Budget> pickBoardWindows(
  List<Budget> rows,
  DateRange period,
  DateTime today,
) {
  final day = referenceDay(period, today);
  final pick = <String, Budget>{};
  int rank(Budget b) {
    final r = DateRange(b.periodStart, b.periodEnd!);
    if (r.contains(day)) return 2;
    return b.periodStart.isAfter(day) ? 0 : 1;
  }

  for (final b in rows) {
    final cur = pick[b.categoryId];
    if (cur == null) {
      pick[b.categoryId] = b;
      continue;
    }
    final rb = rank(b);
    final rc = rank(cur);
    if (rb > rc ||
        (rb == rc && rb == 1 && b.periodStart.isAfter(cur.periodStart))) {
      pick[b.categoryId] = b;
    }
  }
  return pick;
}

/// The windows of budgets with their own length shown on the board of the
/// period, with spending, outstanding amounts and rollover over each
/// window.
final boardWindowsProvider = FutureProvider.autoDispose
    .family<List<BoardWindow>, DateRange>((ref, period) async {
      final today = ref.watch(planTodayProvider);
      final settings = ref.watch(settingsProvider);
      final repo = ref.watch(budgetsRepositoryProvider);
      final rowsF = ref.watch(periodWindowRowsProvider(period).future);
      final categoriesF = ref.watch(categoriesProvider.future);
      final rows = await rowsF;
      final categories = await categoriesF;
      final out = <BoardWindow>[];
      for (final b in pickBoardWindows(rows, period, today).values) {
        final range = DateRange(b.periodStart, b.periodEnd!);
        final actualsF = ref.watch(periodActualsProvider(range).future);
        final plannedF = ref.watch(periodPlannedProvider(range).future);
        final cat = categories.where((c) => c.id == b.categoryId).firstOrNull;
        final children = [
          for (final c in categories)
            if (c.parentId == b.categoryId) c.id,
        ];
        out.add((
          row: b,
          range: range,
          actuals: await actualsF,
          planned: await plannedF,
          rolloverMinor: await repo.windowRollover(
            b,
            rolloverModeFor(cat, settings),
            children: children,
          ),
        ));
      }
      return out;
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
      // Window budgets add to what each period assigned (envelope carry).
      final prevWindowsF = ref.watch(periodWindowRowsProvider(prev).future);
      final budgetsF = ref.watch(periodBudgetsProvider(period.start).future);
      final categories = await categoriesF;
      await prevActualsF;
      await prevBudgetsF;
      await prevWindowsF;
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
  List<BudgetRulePlan> rules = const [],
  BudgetPeriods? periods,
  List<BoardWindow> windows = const [],
  List<Budget> windowRows = const [],
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
  // A budget of the period wins over one with its own length.
  final shownWindows = [
    for (final w in windows)
      if (categories.containsKey(w.row.categoryId) &&
          !budgeted.contains(w.row.categoryId))
        w,
  ];
  final withBudget = {
    ...budgeted,
    for (final w in shownWindows) w.row.categoryId,
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
        isRoot: c.parentId == null || !withBudget.contains(c.parentId),
        rule: periods == null || rules.isEmpty
            ? null
            : ruleFor(rules, periods, c.id, period.start),
        generated: b.ruleId != null,
      ),
    );
  }
  for (final w in shownWindows) {
    final c = categories[w.row.categoryId]!;
    final kids = children[c.id] ?? const <String>[];
    lines.add(
      BudgetLine(
        categoryId: c.id,
        parentId: c.parentId,
        name: c.name,
        icon: c.icon,
        color: c.color,
        budgetId: w.row.id,
        budgetedMinor: w.row.amountMinor,
        rolloverMinor: w.rolloverMinor,
        spentMinor: w.actuals.spentOf(c.id, kids),
        plannedMinor: w.planned.spentOf(c.id, kids),
        thresholdPercent: warnThresholdFor(c, settings),
        rolloverMode: rolloverModeFor(c, settings),
        isRoot: c.parentId == null || !withBudget.contains(c.parentId),
        rule: periods == null || rules.isEmpty
            ? null
            : ruleFor(rules, periods, c.id, w.row.periodStart, windowed: true),
        generated: w.row.ruleId != null,
        window: w.range,
        cadence: periods == null ? null : cadenceOfWindow(periods, w.range),
      ),
    );
  }
  var windowAssigned = 0;
  if (periods != null) {
    for (final b in windowRows) {
      final c = categories[b.categoryId];
      if (c == null || budgeted.contains(c.id)) continue;
      if (c.parentId != null && withBudget.contains(c.parentId)) continue;
      windowAssigned += windowShare(
        periods,
        DateRange(b.periodStart, b.periodEnd!),
        b.amountMinor,
        period,
      );
    }
  }
  var unbudgeted = actuals.uncategorizedSpentMinor;
  for (final e in actuals.netByCategory.entries) {
    final c = categories[e.key];
    if (c == null || c.kind != CategoryKind.expense) continue;
    if (withBudget.contains(c.id)) continue;
    if (c.parentId != null && withBudget.contains(c.parentId)) continue;
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
    windowAssignedMinor: windowAssigned,
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
      final rulesF = ref.watch(budgetRulesSyncProvider(period).future);
      final windowsF = ref.watch(boardWindowsProvider(period).future);
      final windowRowsF = ref.watch(periodWindowRowsProvider(period).future);
      final periods = ref.watch(budgetPeriodsProvider);
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
        rules: await rulesF,
        periods: periods,
        windows: await windowsF,
        windowRows: await windowRowsF,
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
