import 'package:meta/meta.dart';
import 'package:personal_finance/core/calendar/holidays.dart';
import 'package:personal_finance/core/settings/setting_enums.dart';
import 'package:rrule/rrule.dart';

/// One expanded occurrence of a recurring rule.
@immutable
class Occurrence {
  const Occurrence(this.scheduled, this.date);

  /// Date produced by the RRULE.
  final DateTime scheduled;

  /// Date after business-day shifting (the day money actually moves).
  final DateTime date;

  @override
  bool operator ==(Object other) =>
      other is Occurrence && other.scheduled == scheduled && other.date == date;

  @override
  int get hashCode => Object.hash(scheduled, date);

  @override
  String toString() => 'Occurrence($scheduled -> $date)';
}

/// Expands RFC 5545 recurrence rules into local dates.
///
/// [rrule] may be given with or without the `RRULE:` prefix, e.g.
/// `FREQ=MONTHLY;BYMONTHDAY=-1` (last day of month) or
/// `FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1` (last weekday).
/// Holidays are handled by [shift] with [calendar].
///
/// Note on month-end: `FREQ=MONTHLY;BYMONTHDAY=31` skips months without a
/// 31st (RFC behaviour). Use [RRules.clampMonthDay] to build rules that fall back
/// to the last day instead (e.g. 31 → 30 Apr, 28/29 Feb).
List<Occurrence> expandRecurrence({
  required String rrule,
  required DateTime start,
  required DateTime from,
  required DateTime to,
  DateTime? end,
  int? count,
  WeekendShift shift = WeekendShift.none,
  HolidayCalendar? calendar,
  int maxOccurrences = 5000,
}) {
  final cal = calendar ?? HolidayCalendar.none();
  final normalized = rrule.trim().toUpperCase().startsWith('RRULE:')
      ? rrule.trim()
      : 'RRULE:${rrule.trim()}';
  var rule = RecurrenceRule.fromString(normalized);
  if (count != null && rule.count == null && rule.until == null) {
    rule = rule.copyWith(count: count);
  }
  final startUtc = DateTime.utc(start.year, start.month, start.day);
  final result = <Occurrence>[];
  // Shifting can move a date across [from] / [to]; widen the window a bit.
  final windowFrom = DateTime(from.year, from.month, from.day - 7);
  final windowTo = DateTime(to.year, to.month, to.day + 7);
  var n = 0;
  for (final occ in rule.getInstances(start: startUtc)) {
    if (++n > maxOccurrences) break;
    final scheduled = DateTime(occ.year, occ.month, occ.day);
    if (end != null && scheduled.isAfter(end)) break;
    if (scheduled.isAfter(windowTo)) break;
    if (scheduled.isBefore(windowFrom)) continue;
    final date = switch (shift) {
      WeekendShift.none => scheduled,
      WeekendShift.previous => cal.previousBusinessDay(scheduled),
      WeekendShift.next => cal.nextBusinessDay(scheduled),
    };
    if (date.isBefore(from) || date.isAfter(to)) continue;
    result.add(Occurrence(scheduled, date));
  }
  return result;
}

/// Helper to build common rules.
abstract final class RRules {
  static String monthlyOnDay(int day, {int interval = 1}) =>
      'FREQ=MONTHLY;INTERVAL=$interval;BYMONTHDAY=$day';

  /// Monthly on [day], falling back to the month's last day when it has
  /// fewer days (e.g. the 31st becomes 30 April and 28/29 February).
  static String clampMonthDay(int day, {int interval = 1}) {
    if (day <= 28) return monthlyOnDay(day, interval: interval);
    // BYMONTHDAY=29,30,31 + BYSETPOS=1 would pick the first; we need the
    // largest existing day <= [day]: list candidates and take the last.
    final days = [for (var d = 28; d <= day; d++) d].join(',');
    return 'FREQ=MONTHLY;INTERVAL=$interval;BYMONTHDAY=$days;BYSETPOS=-1';
  }

  static String lastDayOfMonth({int interval = 1}) =>
      'FREQ=MONTHLY;INTERVAL=$interval;BYMONTHDAY=-1';

  static String lastBusinessDayOfMonth({int interval = 1}) =>
      'FREQ=MONTHLY;INTERVAL=$interval;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1';

  static String weekly({int interval = 1}) => 'FREQ=WEEKLY;INTERVAL=$interval';

  static String yearly({int interval = 1}) => 'FREQ=YEARLY;INTERVAL=$interval';
}

/// Amount in effect on [date] given dated amount changes (e.g. a rent
/// increase). [changes] maps fromDate -> amountMinor.
int amountOn(DateTime date, int baseAmount, Map<DateTime, int> changes) {
  var amount = baseAmount;
  DateTime? best;
  for (final e in changes.entries) {
    if (!e.key.isAfter(date) && (best == null || e.key.isAfter(best))) {
      best = e.key;
      amount = e.value;
    }
  }
  return amount;
}
