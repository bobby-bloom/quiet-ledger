import 'package:meta/meta.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/settings/app_settings.dart';

/// Budget row state, mapped to bar colours on track → primary,
/// ≥ threshold → warningFill, over → error.
enum BudgetState { onTrack, warning, over }

/// Parses `categories.rollover_override`; null/unknown = use the default.
RolloverMode? parseRolloverMode(String? s) =>
    s == null ? null : RolloverMode.values.asNameMap()[s];

/// Amount carried into the next period for a category whose period ended
/// with [availableMinor] = budget + rollover − spent left (negative when
/// overspent).
int rolloverFor(RolloverMode mode, int availableMinor) => switch (mode) {
  RolloverMode.none => 0,
  RolloverMode.leftover => availableMinor > 0 ? availableMinor : 0,
  RolloverMode.overspent => availableMinor < 0 ? availableMinor : 0,
  RolloverMode.both => availableMinor,
};

/// Classifies spending against an available amount with a warning
/// threshold in percent.
BudgetState budgetState({
  required int availableMinor,
  required int spentMinor,
  required int thresholdPercent,
}) {
  if (spentMinor > availableMinor) {
    return spentMinor > 0 || availableMinor < 0
        ? BudgetState.over
        : BudgetState.onTrack;
  }
  if (availableMinor <= 0) return BudgetState.onTrack;
  // spent / available >= threshold / 100, in integers.
  if (spentMinor * 100 >= availableMinor * thresholdPercent) {
    return BudgetState.warning;
  }
  return BudgetState.onTrack;
}

/// Zero-based budgeting: money still to assign in a period.
int toBeBudgeted({
  required int incomeMinor,
  required int carryMinor,
  required int assignedMinor,
}) => incomeMinor + carryMinor - assignedMinor;

/// Average of [values] over [periods] (missing periods count as 0), rounded
/// half up to cents and then up to a multiple of [roundUpTo] minor units
/// (100 = whole euros; 1 = no extra rounding).
int averageAmount(List<int> values, int periods, {int roundUpTo = 100}) {
  if (periods <= 0) return 0;
  final sum = values.fold(0, (a, b) => a + b);
  if (sum <= 0) return 0;
  final avg = (sum * 2 + periods) ~/ (periods * 2);
  if (roundUpTo <= 1) return avg;
  return ((avg + roundUpTo - 1) ~/ roundUpTo) * roundUpTo;
}

/// One budgeted category in a period.
@immutable
class BudgetLine {
  const BudgetLine({
    required this.categoryId,
    required this.name,
    required this.budgetedMinor,
    required this.rolloverMinor,
    required this.spentMinor,
    required this.thresholdPercent,
    required this.rolloverMode,
    this.parentId,
    this.icon,
    this.color,
    this.budgetId,
    this.isRoot = true,
  });

  final String categoryId;
  final String? parentId;
  final String name;
  final String? icon;
  final int? color;

  /// Id of the `budgets` row (null for a category without a budget).
  final String? budgetId;

  /// Amount set for this period.
  final int budgetedMinor;

  /// Carried in from the previous period (negative = overspent carried).
  final int rolloverMinor;

  /// Net spending in the period (parent categories include children;
  /// refunds reduce it).
  final int spentMinor;
  final int thresholdPercent;
  final RolloverMode rolloverMode;

  /// False when the parent category has its own budget (then this line is a
  /// sub-allocation and not counted in totals).
  final bool isRoot;

  int get availableMinor => budgetedMinor + rolloverMinor;
  int get remainingMinor => availableMinor - spentMinor;
  int get overMinor => remainingMinor < 0 ? -remainingMinor : 0;

  /// Spent / available (0..∞); 1 when nothing is available but something
  /// was spent.
  double get ratio {
    if (availableMinor <= 0) return spentMinor > 0 ? 1 : 0;
    return spentMinor / availableMinor;
  }

  /// Rounded percent used.
  int get percentUsed =>
      availableMinor <= 0 ? (spentMinor > 0 ? 100 : 0) : (ratio * 100).round();

  BudgetState get state => budgetState(
    availableMinor: availableMinor,
    spentMinor: spentMinor,
    thresholdPercent: thresholdPercent,
  );

  /// Rollover into the next period if the period ended now.
  int get nextRolloverMinor => rolloverFor(rolloverMode, remainingMinor);

  @override
  bool operator ==(Object other) =>
      other is BudgetLine &&
      other.categoryId == categoryId &&
      other.budgetId == budgetId &&
      other.budgetedMinor == budgetedMinor &&
      other.rolloverMinor == rolloverMinor &&
      other.spentMinor == spentMinor &&
      other.thresholdPercent == thresholdPercent &&
      other.rolloverMode == rolloverMode &&
      other.isRoot == isRoot &&
      other.name == name;

  @override
  int get hashCode => Object.hash(
    categoryId,
    budgetId,
    budgetedMinor,
    rolloverMinor,
    spentMinor,
    thresholdPercent,
    rolloverMode,
    isRoot,
    name,
  );
}

/// Budgets of one period: totals and per-category lines. Exposed for the
/// dashboard as `budgetSummaryProvider`.
@immutable
class BudgetSummary {
  const BudgetSummary({
    required this.period,
    required this.today,
    required this.mode,
    required this.lines,
    this.incomeMinor = 0,
    this.carryMinor = 0,
    this.unbudgetedSpentMinor = 0,
  });

  final DateRange period;
  final DateTime today;
  final BudgetMode mode;

  /// Sorted: over first, then warning, then on track; by name within.
  final List<BudgetLine> lines;

  /// Income of the period (envelope mode).
  final int incomeMinor;

  /// Unassigned money carried from the previous period (envelope mode).
  final int carryMinor;

  /// Expense spending in categories without a budget.
  final int unbudgetedSpentMinor;

  Iterable<BudgetLine> get _roots => lines.where((l) => l.isRoot);

  /// Budget + rollover over root lines.
  int get totalBudgetedMinor => _roots.fold(0, (a, l) => a + l.availableMinor);

  /// Amounts assigned this period (without rollovers) over root lines.
  int get assignedMinor => _roots.fold(0, (a, l) => a + l.budgetedMinor);
  int get totalSpentMinor => _roots.fold(0, (a, l) => a + l.spentMinor);
  int get totalRemainingMinor => totalBudgetedMinor - totalSpentMinor;

  /// Envelope mode: income + carry − assigned ("€X left to assign").
  int get toBeBudgetedMinor => toBeBudgeted(
    incomeMinor: incomeMinor,
    carryMinor: carryMinor,
    assignedMinor: assignedMinor,
  );

  bool get isEmpty => lines.isEmpty;
  bool get isCurrent => period.contains(today);

  /// Today's position in the period (0..1) for the bar tick; null outside.
  double? get todayTick => isCurrent ? period.progressAt(today) : null;

  /// 1-based day of the period for "Today, day 23 of 31".
  int get dayOfPeriod =>
      DateTime.utc(today.year, today.month, today.day)
          .difference(
            DateTime.utc(
              period.start.year,
              period.start.month,
              period.start.day,
            ),
          )
          .inDays +
      1;

  int get daysLeft => isCurrent ? period.days - dayOfPeriod + 1 : 0;

  int count(BudgetState s) => lines.where((l) => l.state == s).length;

  BudgetLine? lineFor(String categoryId) {
    for (final l in lines) {
      if (l.categoryId == categoryId) return l;
    }
    return null;
  }
}

/// Sorts lines by severity, then name.
List<BudgetLine> sortLines(Iterable<BudgetLine> lines) {
  int sev(BudgetState s) => switch (s) {
    BudgetState.over => 0,
    BudgetState.warning => 1,
    BudgetState.onTrack => 2,
  };
  return lines.toList()..sort((a, b) {
    final c = sev(a.state).compareTo(sev(b.state));
    return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
}
