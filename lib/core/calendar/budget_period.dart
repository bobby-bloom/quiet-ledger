import 'package:meta/meta.dart';
import 'package:personal_finance/core/calendar/holidays.dart';
import 'package:personal_finance/core/settings/setting_enums.dart';

/// A half-open date range `[start, end)` of local dates.
@immutable
class DateRange {
  const DateRange(this.start, this.end);

  final DateTime start;

  /// Exclusive.
  final DateTime end;

  /// Inclusive last day.
  DateTime get last => DateTime(end.year, end.month, end.day - 1);

  int get days => DateTime.utc(
    end.year,
    end.month,
    end.day,
  ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;

  bool contains(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    return !x.isBefore(start) && x.isBefore(end);
  }

  /// Fraction of the period elapsed at [d] (0..1), e.g. for the "today"
  /// tick on budget bars.
  double progressAt(DateTime d) {
    final total = end.difference(start).inMinutes;
    if (total <= 0) return 0;
    final x = DateTime(d.year, d.month, d.day, 12);
    return (x.difference(start).inMinutes / total).clamp(0, 1).toDouble();
  }

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'DateRange($start – $last)';
}

/// Configuration of budget periods (Settings › Budgets, PLAN.md §2.3).
@immutable
class BudgetPeriodConfig {
  const BudgetPeriodConfig({
    this.type = BudgetPeriodType.monthly,
    this.startDay = 1,
    this.shift = WeekendShift.none,
    this.calendar,
    this.firstDayOfWeek = DateTime.monday,
    this.fiscalYearStartMonth = 1,
    this.salaryDates = const [],
  });

  final BudgetPeriodType type;

  /// 1–28, or 0 = last day of the month.
  final int startDay;
  final WeekendShift shift;
  final HolidayCalendar? calendar;
  final int firstDayOfWeek;
  final int fiscalYearStartMonth;

  /// When non-empty (salary-based start), each period starts on one of these
  /// dates (actual or expected salary arrivals), sorted ascending.
  final List<DateTime> salaryDates;

  /// The same calendar settings with period [type] and no salary-based
  /// start: the windows of a budget with its own length.
  BudgetPeriodConfig withType(BudgetPeriodType type) => BudgetPeriodConfig(
    type: type,
    startDay: startDay,
    shift: shift,
    calendar: calendar,
    firstDayOfWeek: firstDayOfWeek,
    fiscalYearStartMonth: fiscalYearStartMonth,
  );
}

/// Computes budget periods from a [BudgetPeriodConfig].
class BudgetPeriods {
  BudgetPeriods(this.config);

  final BudgetPeriodConfig config;

  static final _biWeeklyAnchor = DateTime(2024);

  /// The period containing [date].
  DateRange periodOf(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final salary = config.salaryDates;
    if (salary.isNotEmpty &&
        !d.isBefore(_day(salary.first)) &&
        d.isBefore(_day(salary.last))) {
      for (var i = salary.length - 2; i >= 0; i--) {
        final s = _day(salary[i]);
        if (!d.isBefore(s)) return DateRange(s, _day(salary[i + 1]));
      }
    }
    switch (config.type) {
      case BudgetPeriodType.weekly:
        final start = _weekStart(d);
        return DateRange(start, _addDays(start, 7));
      case BudgetPeriodType.biWeekly:
        final anchor = _weekStart(_biWeeklyAnchor);
        final weekStart = _weekStart(d);
        final weeks = (weekStart.difference(anchor).inHours / (24 * 7)).round();
        final start = weeks.isEven ? weekStart : _addDays(weekStart, -7);
        return DateRange(start, _addDays(start, 14));
      case BudgetPeriodType.monthly:
        return _monthBased(d, 1);
      case BudgetPeriodType.quarterly:
        return _monthBased(d, 3);
      case BudgetPeriodType.yearly:
        return _monthBased(d, 12);
    }
  }

  DateRange next(DateRange p) => periodOf(p.end);

  DateRange previous(DateRange p) => periodOf(_addDays(p.start, -1));

  /// [count] consecutive periods starting with the one containing [from].
  List<DateRange> periodsFrom(DateTime from, int count) {
    final out = <DateRange>[];
    var p = periodOf(from);
    for (var i = 0; i < count; i++) {
      out.add(p);
      p = next(p);
    }
    return out;
  }

  /// Periods overlapping `[from, to]`.
  List<DateRange> periodsBetween(DateTime from, DateTime to) {
    final out = <DateRange>[];
    var p = periodOf(from);
    while (!p.start.isAfter(to)) {
      out.add(p);
      p = next(p);
    }
    return out;
  }

  DateRange _monthBased(DateTime d, int months) {
    // Period starts are monotonic; take the latest start <= d among the
    // aligned group of d and its neighbours.
    final base = _alignMonth(d.year, d.month, months);
    DateTime? start;
    var startMonth = base;
    for (var k = -2; k <= 1; k++) {
      final ym = _addMonths(base.$1, base.$2, k * months);
      final s = _startIn(ym.$1, ym.$2);
      if (!s.isAfter(d)) {
        start = s;
        startMonth = ym;
      }
    }
    final nextMonth = _addMonths(startMonth.$1, startMonth.$2, months);
    return DateRange(start!, _startIn(nextMonth.$1, nextMonth.$2));
  }

  /// First month of the period group (quarters/years follow the fiscal
  /// year start).
  (int, int) _alignMonth(int year, int month, int months) {
    if (months == 1) return (year, month);
    final offset = (month - config.fiscalYearStartMonth) % months;
    return _addMonths(year, month, -offset);
  }

  DateTime _startIn(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = config.startDay == 0
        ? lastDay
        : config.startDay.clamp(1, lastDay);
    final raw = DateTime(year, month, day);
    final cal = config.calendar ?? HolidayCalendar.none();
    return switch (config.shift) {
      WeekendShift.none => raw,
      WeekendShift.previous => cal.previousBusinessDay(raw),
      WeekendShift.next => cal.nextBusinessDay(raw),
    };
  }

  DateTime _weekStart(DateTime d) {
    final diff = (d.weekday - config.firstDayOfWeek) % 7;
    return _addDays(DateTime(d.year, d.month, d.day), -diff);
  }

  static (int, int) _addMonths(int y, int m, int delta) {
    final total = y * 12 + (m - 1) + delta;
    return (total ~/ 12, total % 12 + 1);
  }

  static DateTime _addDays(DateTime d, int n) =>
      DateTime(d.year, d.month, d.day + n);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
