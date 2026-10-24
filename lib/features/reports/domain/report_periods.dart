import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/reports/domain/report_models.dart';

// Period arithmetic for reports. All ranges are half-open `[start, end)` of
// local dates.

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _month(int year, int month) => DateTime(year, month);

/// Adds [months] to [d], clamping the day to the target month's length.
DateTime addMonths(DateTime d, int months) {
  final total = d.year * 12 + (d.month - 1) + months;
  final y = total ~/ 12;
  final m = total % 12 + 1;
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.day > last ? last : d.day);
}

/// The calendar month containing [d].
DateRange monthOf(DateTime d) =>
    DateRange(_month(d.year, d.month), _month(d.year, d.month + 1));

/// The [count] calendar months ending with the month containing [last].
DateRange lastMonths(DateTime last, int count) => DateRange(
  _month(last.year, last.month - count + 1),
  _month(last.year, last.month + 1),
);

/// Resolves a [ReportPeriod] preset relative to [today].
DateRange reportPeriodRange(ReportPeriod p, DateTime today) {
  final t = _day(today);
  return switch (p) {
    ReportPeriod.thisMonth => monthOf(t),
    ReportPeriod.lastMonth => monthOf(_month(t.year, t.month - 1)),
    ReportPeriod.last3Months => lastMonths(t, 3),
    ReportPeriod.last12Months => lastMonths(t, 12),
    ReportPeriod.yearToDate => DateRange(
      DateTime(t.year),
      DateTime(t.year, t.month, t.day + 1),
    ),
    ReportPeriod.thisYear => DateRange(DateTime(t.year), DateTime(t.year + 1)),
    ReportPeriod.lastYear => DateRange(DateTime(t.year - 1), DateTime(t.year)),
  };
}

bool _isMonthStart(DateTime d) => d.day == 1;

/// Number of whole months in [r] when it starts and ends on a month
/// boundary, otherwise null.
int? wholeMonths(DateRange r) {
  if (!_isMonthStart(r.start) || !_isMonthStart(r.end)) return null;
  return (r.end.year * 12 + r.end.month) - (r.start.year * 12 + r.start.month);
}

/// Shifts [r] by [steps] of its own length: month-aligned ranges move by
/// whole months, year-to-date style ranges (starting 1 January) by years,
/// anything else by its number of days.
DateRange shiftRange(DateRange r, int steps) {
  final months = wholeMonths(r);
  if (months != null && months > 0) {
    return DateRange(
      addMonths(r.start, months * steps),
      addMonths(r.end, months * steps),
    );
  }
  if (r.start.month == 1 && r.start.day == 1) {
    return sameRangeYearsAgo(r, -steps);
  }
  final days = r.days;
  return DateRange(
    DateTime(r.start.year, r.start.month, r.start.day + days * steps),
    DateTime(r.end.year, r.end.month, r.end.day + days * steps),
  );
}

/// The same calendar span [years] earlier (e.g. October 2025 for October
/// 2026). Month-aligned ranges stay month-aligned.
DateRange sameRangeYearsAgo(DateRange r, int years) =>
    DateRange(addMonths(r.start, -12 * years), addMonths(r.end, -12 * years));

/// The ranges of the period comparison: (current, previous, same period one
/// year earlier).
(DateRange, DateRange, DateRange) comparisonRanges(DateRange current) =>
    (current, shiftRange(current, -1), sameRangeYearsAgo(current, 1));

/// Splits [range] into buckets of [interval], clipped to [range]. For
/// [ReportInterval.budgetPeriod] pass [budget]; quarters and years follow
/// [fiscalYearStartMonth].
List<DateRange> bucketsFor(
  DateRange range,
  ReportInterval interval, {
  BudgetPeriods? budget,
  int fiscalYearStartMonth = 1,
}) {
  if (!range.start.isBefore(range.end)) return const [];
  final out = <DateRange>[];
  DateRange clip(DateRange b) => DateRange(
    b.start.isBefore(range.start) ? range.start : b.start,
    b.end.isAfter(range.end) ? range.end : b.end,
  );
  if (interval == ReportInterval.budgetPeriod) {
    final periods = (budget ?? BudgetPeriods(const BudgetPeriodConfig()))
        .periodsBetween(range.start, range.last);
    for (final p in periods) {
      final c = clip(p);
      if (c.start.isBefore(c.end)) out.add(c);
    }
    return out;
  }
  final months = switch (interval) {
    ReportInterval.month => 1,
    ReportInterval.quarter => 3,
    ReportInterval.year => 12,
    ReportInterval.budgetPeriod => 1,
  };
  final offset = months == 1
      ? 0
      : (range.start.month - fiscalYearStartMonth) % months;
  var start = _month(range.start.year, range.start.month - offset);
  while (start.isBefore(range.end)) {
    final end = _month(start.year, start.month + months);
    out.add(clip(DateRange(start, end)));
    start = end;
  }
  return out;
}

/// Months whose end lies within [range] (for net worth series): one bucket
/// per calendar month overlapping [range].
List<DateRange> monthBuckets(DateRange range) =>
    bucketsFor(range, ReportInterval.month);

/// Whether [r] is exactly one calendar month.
bool isSingleMonth(DateRange r) => wholeMonths(r) == 1;

/// Whether [r] is exactly one calendar year.
bool isSingleYear(DateRange r) =>
    wholeMonths(r) == 12 && r.start.month == 1 && r.start.day == 1;
