import 'package:meta/meta.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/settings/setting_enums.dart';
import 'package:uuid/uuid.dart';

/// How a budget repeats and how long one budget lasts, as chosen in the
/// amount dialog. "Period" below means one window of [cadence]: the budget
/// period, or a week, month, quarter or year for a budget with its own
/// length.
@immutable
class BudgetRepeat {
  const BudgetRepeat._(
    this.kind, {
    this.every = 1,
    this.count,
    this.until,
    this.cadence = BudgetCadence.period,
  });

  /// This period only (no rule).
  const BudgetRepeat.single({BudgetCadence cadence = BudgetCadence.period})
    : this._(BudgetRepeatKind.once, cadence: cadence);

  /// Every [every]-th period until changed.
  const BudgetRepeat.everyPeriod({
    int every = 1,
    BudgetCadence cadence = BudgetCadence.period,
  }) : this._(BudgetRepeatKind.every, every: every, cadence: cadence);

  /// [count] periods, this one included.
  const BudgetRepeat.forPeriods(
    int count, {
    int every = 1,
    BudgetCadence cadence = BudgetCadence.period,
  }) : this._(
         BudgetRepeatKind.count,
         every: every,
         count: count,
         cadence: cadence,
       );

  /// Every period starting on or before [until].
  const BudgetRepeat.until(
    DateTime until, {
    int every = 1,
    BudgetCadence cadence = BudgetCadence.period,
  }) : this._(
         BudgetRepeatKind.until,
         every: every,
         until: until,
         cadence: cadence,
       );

  /// This budget period only (no rule).
  static const once = BudgetRepeat.single();

  final BudgetRepeatKind kind;
  final int every;
  final int? count;
  final DateTime? until;
  final BudgetCadence cadence;

  bool get repeats => kind != BudgetRepeatKind.once;

  /// The budget has its own length instead of the budget period.
  bool get windowed => cadence != BudgetCadence.period;

  @override
  bool operator ==(Object other) =>
      other is BudgetRepeat &&
      other.kind == kind &&
      other.every == every &&
      other.count == count &&
      other.until == until &&
      other.cadence == cadence;

  @override
  int get hashCode => Object.hash(kind, every, count, until, cadence);
}

enum BudgetRepeatKind { once, every, count, until }

/// A live `budget_rules` row: a budget that repeats over budget periods, or
/// over windows of its own length ([cadence]).
///
/// A rule covers every [every]-th period (window) starting with the one
/// that starts on [start], at most [count] of them and none starting after
/// [end]. Periods up to [generatedUntil] already had their row generated
/// (and may have been edited or removed since). Methods take the budget
/// periods and switch to the rule's windows themselves.
@immutable
class BudgetRulePlan {
  const BudgetRulePlan({
    required this.id,
    required this.categoryId,
    required this.amountMinor,
    required this.start,
    this.every = 1,
    this.end,
    this.count,
    this.generatedUntil,
    this.updatedAt = '',
    this.cadence = BudgetCadence.period,
    this.periodType,
    this.createdAtMillis = 0,
  });

  factory BudgetRulePlan.fromRow(BudgetRule r) => BudgetRulePlan(
    id: r.id,
    categoryId: r.categoryId,
    amountMinor: r.amountMinor,
    start: _day(r.startDate),
    every: r.every < 1 ? 1 : r.every,
    end: r.endDate == null ? null : _day(r.endDate!),
    count: r.count,
    generatedUntil: r.generatedUntil == null ? null : _day(r.generatedUntil!),
    updatedAt: r.updatedAt,
    cadence: r.cadence,
    periodType: r.periodType == null
        ? null
        : BudgetPeriodType.values.asNameMap()[r.periodType],
    createdAtMillis: r.createdAt,
  );

  final String id;
  final String categoryId;
  final int amountMinor;
  final DateTime start;
  final int every;
  final DateTime? end;
  final int? count;
  final DateTime? generatedUntil;
  final BudgetCadence cadence;

  /// For a `period` rule, the period type it was made for (null: rules
  /// from before this was recorded, which follow the current type).
  final BudgetPeriodType? periodType;

  /// Creation time of the rule; the fixed sync timestamp of the rows it
  /// generates (see `BudgetsRepository.ensureFromRules`).
  final int createdAtMillis;

  /// The length of one budget on [board]: [cadence], or for a `period` rule
  /// made for another period type, the length of that type (so it keeps
  /// its length after the period type changed).
  BudgetCadence lengthOn(BudgetPeriods board) {
    if (cadence != BudgetCadence.period) return cadence;
    final made = periodType;
    if (made == null || made == board.config.type) return cadence;
    return cadenceOfPeriodType(made) ?? BudgetCadence.period;
  }

  /// The budgets have their own length on [board]: rows carry `periodEnd`.
  bool windowedOn(BudgetPeriods board) =>
      lengthOn(board) != BudgetCadence.period;

  /// The repeat setting this rule stands for on [board].
  BudgetRepeat repeatOn(BudgetPeriods board) {
    final c = lengthOn(board);
    return count != null
        ? BudgetRepeat.forPeriods(count!, every: every, cadence: c)
        : end != null
        ? BudgetRepeat.until(end!, every: every, cadence: c)
        : BudgetRepeat.everyPeriod(every: every, cadence: c);
  }

  /// HLC of the last change; the newest rule wins when two cover the same
  /// category and period.
  final String updatedAt;

  /// Safety limit for the walk over periods (100 years of weeks).
  static const _maxSteps = 5300;

  /// Covered periods that start on or before [upTo], oldest first.
  List<DateRange> periodsUpTo(BudgetPeriods board, DateTime upTo) {
    final periods = windowPeriods(board, lengthOn(board));
    final out = <DateRange>[];
    final limit = _day(upTo);
    var p = periods.periodOf(start);
    for (var i = 0; i < _maxSteps && !p.start.isAfter(limit); i++) {
      if (end != null && p.start.isAfter(end!)) break;
      if (i % every == 0) {
        if (count != null && out.length >= count!) break;
        out.add(p);
      }
      final next = periods.next(p);
      if (!next.start.isAfter(p.start)) break;
      p = next;
    }
    return out;
  }

  /// Whether the period starting [periodStart] is covered.
  bool covers(BudgetPeriods periods, DateTime periodStart) {
    final d = _day(periodStart);
    final list = periodsUpTo(periods, d);
    return list.isNotEmpty && list.last.start == d;
  }

  /// Covered periods after [generatedUntil] that start on or before [upTo].
  /// A period that now contains the watermark but starts earlier (a
  /// salary-based start that moved when the salary landed early) counts as
  /// not generated yet.
  List<DateRange> due(BudgetPeriods periods, DateTime upTo) {
    final g = generatedUntil;
    return [
      for (final p in periodsUpTo(periods, upTo))
        if (g == null || p.start.isAfter(g) || (p.contains(g) && p.start != g))
          p,
    ];
  }

  /// Covered periods from the one starting [periodStart] on, for a rule
  /// that is split there: the remaining count (null = unlimited).
  int? remainingCountFrom(BudgetPeriods periods, DateTime periodStart) {
    if (count == null) return null;
    final before = periodsUpTo(
      periods,
      _day(periodStart).subtract(const Duration(days: 1)),
    ).length;
    final left = count! - before;
    return left < 1 ? 1 : left;
  }

  @override
  bool operator ==(Object other) =>
      other is BudgetRulePlan &&
      other.id == id &&
      other.categoryId == categoryId &&
      other.amountMinor == amountMinor &&
      other.start == start &&
      other.every == every &&
      other.end == end &&
      other.count == count &&
      other.generatedUntil == generatedUntil &&
      other.updatedAt == updatedAt &&
      other.cadence == cadence &&
      other.periodType == periodType;

  @override
  int get hashCode => Object.hash(
    id,
    categoryId,
    amountMinor,
    start,
    every,
    end,
    count,
    generatedUntil,
    updatedAt,
    cadence,
    periodType,
  );
}

/// The rule covering [categoryId] in the period starting [periodStart] (the
/// window starting there when [windowed]): the newest by
/// [BudgetRulePlan.updatedAt] when several do (after sync or a category
/// merge).
BudgetRulePlan? ruleFor(
  Iterable<BudgetRulePlan> rules,
  BudgetPeriods periods,
  String categoryId,
  DateTime periodStart, {
  bool windowed = false,
}) {
  BudgetRulePlan? best;
  for (final r in rules) {
    if (r.categoryId != categoryId || r.windowedOn(periods) != windowed) {
      continue;
    }
    if (!r.covers(periods, periodStart)) continue;
    if (best == null || r.updatedAt.compareTo(best.updatedAt) > 0) best = r;
  }
  return best;
}

/// Deterministic id of the budget row [ruleId] generates for the period
/// starting [periodStart], so two devices generating the same period create
/// the same row and sync merges them.
String generatedBudgetId(String ruleId, DateTime periodStart) {
  final d = _day(periodStart);
  final day =
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  return const Uuid().v5(Namespace.url.value, 'budget-rule:$ruleId:$day');
}

/// Windows of [cadence], built from the budget periods' calendar settings
/// (start day, weekend shift, first day of week, fiscal year; no salary-based
/// start). `period` gives [board] itself.
BudgetPeriods windowPeriods(BudgetPeriods board, BudgetCadence cadence) =>
    switch (cadence) {
      BudgetCadence.period => board,
      BudgetCadence.week => BudgetPeriods(
        board.config.withType(BudgetPeriodType.weekly),
      ),
      BudgetCadence.month => BudgetPeriods(
        board.config.withType(BudgetPeriodType.monthly),
      ),
      BudgetCadence.quarter => BudgetPeriods(
        board.config.withType(BudgetPeriodType.quarterly),
      ),
      BudgetCadence.year => BudgetPeriods(
        board.config.withType(BudgetPeriodType.yearly),
      ),
      BudgetCadence.biWeek => BudgetPeriods(
        board.config.withType(BudgetPeriodType.biWeekly),
      ),
    };

/// The own length that equals the budget period type [type] (choosing it is
/// the same as the budget period).
BudgetCadence? cadenceOfPeriodType(BudgetPeriodType type) => switch (type) {
  BudgetPeriodType.weekly => BudgetCadence.week,
  BudgetPeriodType.biWeekly => BudgetCadence.biWeek,
  BudgetPeriodType.monthly => BudgetCadence.month,
  BudgetPeriodType.quarterly => BudgetCadence.quarter,
  BudgetPeriodType.yearly => BudgetCadence.year,
};

/// The length whose window [window] is (for a budget row with `periodEnd`
/// that no rule generated), or null when none matches.
BudgetCadence? cadenceOfWindow(BudgetPeriods board, DateRange window) {
  for (final c in BudgetCadence.values) {
    if (c == BudgetCadence.period) continue;
    if (windowPeriods(board, c).periodOf(window.start) == window) return c;
  }
  return null;
}

/// The day a board period is looked at: today inside it, its last day when
/// it is over, its first day when it lies ahead. A budget with its own
/// length shows the window containing this day.
DateTime referenceDay(DateRange period, DateTime today) {
  final d = _day(today);
  if (period.contains(d)) return d;
  return d.isBefore(period.start) ? period.start : period.last;
}

/// The part of a window budget's [amountMinor] assigned to the budget
/// period [period] (envelope "left to assign" and the forecast): spread
/// evenly over the budget periods starting inside the window, or all of it
/// in the budget period a shorter window starts in.
/// Cents left over go to the first periods.
int windowShare(
  BudgetPeriods board,
  DateRange window,
  int amountMinor,
  DateRange period,
) {
  final targets = windowTargets(board, window);
  final i = targets.indexOf(period);
  if (i < 0) return 0;
  final n = targets.length;
  final base = amountMinor ~/ n;
  return base + (i < amountMinor - base * n ? 1 : 0);
}

/// Budget periods a window's amount is spread over (see [windowShare]): the
/// period a window no longer than it starts in, or the periods starting
/// inside a longer window.
List<DateRange> windowTargets(BudgetPeriods board, DateRange window) {
  final home = board.periodOf(window.start);
  if (window.days <= home.days) return [home];
  final starts = [
    for (final p in board.periodsBetween(window.start, window.last))
      if (window.contains(p.start)) p,
  ];
  return starts.isEmpty ? [home] : starts;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
