import 'package:meta/meta.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:uuid/uuid.dart';

/// How a budget repeats, as chosen in the amount dialog.
@immutable
class BudgetRepeat {
  const BudgetRepeat._(this.kind, {this.every = 1, this.count, this.until});

  /// Every [every]-th period until changed.
  const BudgetRepeat.everyPeriod({int every = 1})
    : this._(BudgetRepeatKind.every, every: every);

  /// [count] periods, this one included.
  const BudgetRepeat.forPeriods(int count, {int every = 1})
    : this._(BudgetRepeatKind.count, every: every, count: count);

  /// Every period starting on or before [until].
  const BudgetRepeat.until(DateTime until, {int every = 1})
    : this._(BudgetRepeatKind.until, every: every, until: until);

  /// This period only (no rule).
  static const once = BudgetRepeat._(BudgetRepeatKind.once);

  final BudgetRepeatKind kind;
  final int every;
  final int? count;
  final DateTime? until;

  bool get repeats => kind != BudgetRepeatKind.once;

  @override
  bool operator ==(Object other) =>
      other is BudgetRepeat &&
      other.kind == kind &&
      other.every == every &&
      other.count == count &&
      other.until == until;

  @override
  int get hashCode => Object.hash(kind, every, count, until);
}

enum BudgetRepeatKind { once, every, count, until }

/// A live `budget_rules` row: a budget that repeats over budget periods.
///
/// A rule covers every [every]-th period starting with the one that starts
/// on [start], at most [count] of them and none starting after [end].
/// Periods up to [generatedUntil] already had their row generated (and may
/// have been edited or removed since).
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
  );

  final String id;
  final String categoryId;
  final int amountMinor;
  final DateTime start;
  final int every;
  final DateTime? end;
  final int? count;
  final DateTime? generatedUntil;

  /// HLC of the last change; the newest rule wins when two cover the same
  /// category and period.
  final String updatedAt;

  /// Safety limit for the walk over periods (100 years of weeks).
  static const _maxSteps = 5300;

  /// Covered periods that start on or before [upTo], oldest first.
  List<DateRange> periodsUpTo(BudgetPeriods periods, DateTime upTo) {
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

  /// The repeat setting this rule stands for.
  BudgetRepeat get repeat => count != null
      ? BudgetRepeat.forPeriods(count!, every: every)
      : end != null
      ? BudgetRepeat.until(end!, every: every)
      : BudgetRepeat.everyPeriod(every: every);

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
      other.updatedAt == updatedAt;

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
  );
}

/// The rule covering [categoryId] in the period starting [periodStart]: the
/// newest by [BudgetRulePlan.updatedAt] when several do (after sync or a
/// category merge).
BudgetRulePlan? ruleFor(
  Iterable<BudgetRulePlan> rules,
  BudgetPeriods periods,
  String categoryId,
  DateTime periodStart,
) {
  BudgetRulePlan? best;
  for (final r in rules) {
    if (r.categoryId != categoryId) continue;
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

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
