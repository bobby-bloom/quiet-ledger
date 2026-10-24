import 'package:meta/meta.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';

/// How fast money accumulates toward a goal.
@immutable
class GoalPace {
  const GoalPace.perDays(this.amountMinor, this.days) : perPeriodMinor = null;

  const GoalPace.perPeriod(int amountMinor)
    : perPeriodMinor = amountMinor,
      amountMinor = amountMinor,
      days = 0;

  /// Net amount gained over [days] (account history), or the planned
  /// contribution per period.
  final int amountMinor;
  final int days;

  /// Set for a planned contribution per budget period.
  final int? perPeriodMinor;

  bool get isPositive =>
      amountMinor > 0 && (perPeriodMinor != null || days > 0);
}

/// Derived numbers of a savings goal.
@immutable
class GoalProjection {
  const GoalProjection({
    required this.savedMinor,
    required this.targetMinor,
    this.requiredPerPeriodMinor,
    this.periodsLeft,
    this.projectedDate,
    this.targetDate,
  });

  final int savedMinor;
  final int targetMinor;

  /// Contribution needed per period to reach the target by [targetDate]
  /// (null without a target date or when reached).
  final int? requiredPerPeriodMinor;

  /// Contribution opportunities (period starts) until [targetDate].
  final int? periodsLeft;

  /// When the goal is reached at the current pace (null when the pace is
  /// zero or negative; today when already reached).
  final DateTime? projectedDate;
  final DateTime? targetDate;

  int get remainingMinor =>
      targetMinor - savedMinor > 0 ? targetMinor - savedMinor : 0;
  bool get reached => savedMinor >= targetMinor;

  double get fraction =>
      targetMinor <= 0 ? 1 : (savedMinor / targetMinor).clamp(0, 1).toDouble();

  /// Whether the projection reaches the target by its date (true without a
  /// target date when there is a projection at all).
  bool get onTrack {
    if (reached) return true;
    if (projectedDate == null) return false;
    if (targetDate == null) return true;
    return !projectedDate!.isAfter(targetDate!);
  }

  bool get overdue => !reached && targetDate != null && projectedDate == null;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Number of period starts in `(today, targetDate]`: how many contributions
/// can still be made before the target date if one is made at the start of
/// each period.
int periodStartsUntil(BudgetPeriods periods, DateTime today, DateTime target) {
  var n = 0;
  var p = periods.periodOf(today);
  final t = _day(target);
  for (var i = 0; i < 2000; i++) {
    p = periods.next(p);
    if (p.start.isAfter(t)) break;
    n++;
  }
  return n;
}

/// `ceil(a / b)` for positive integers.
int ceilDiv(int a, int b) => (a + b - 1) ~/ b;

/// Projects a goal: required contribution per period to hit [targetDate]
/// and the date it is reached at [pace].
GoalProjection projectGoal({
  required int savedMinor,
  required int targetMinor,
  required DateTime today,
  required BudgetPeriods periods,
  DateTime? targetDate,
  GoalPace? pace,
}) {
  final t = _day(today);
  final remaining = targetMinor - savedMinor;
  if (remaining <= 0) {
    return GoalProjection(
      savedMinor: savedMinor,
      targetMinor: targetMinor,
      projectedDate: t,
      targetDate: targetDate,
    );
  }
  int? required;
  int? left;
  if (targetDate != null) {
    left = periodStartsUntil(periods, t, targetDate);
    // No contribution opportunity left: everything is due now.
    required = left == 0 ? remaining : ceilDiv(remaining, left);
  }
  DateTime? projected;
  if (pace != null && pace.isPositive) {
    if (pace.perPeriodMinor != null) {
      final n = ceilDiv(remaining, pace.perPeriodMinor!);
      var p = periods.periodOf(t);
      for (var i = 0; i < n && i < 5000; i++) {
        p = periods.next(p);
      }
      projected = p.start;
    } else {
      final days = ceilDiv(remaining * pace.days, pace.amountMinor);
      if (days <= 365 * 200) {
        projected = DateTime(t.year, t.month, t.day + days);
      }
    }
  }
  return GoalProjection(
    savedMinor: savedMinor,
    targetMinor: targetMinor,
    requiredPerPeriodMinor: required,
    periodsLeft: left,
    projectedDate: projected,
    targetDate: targetDate,
  );
}
