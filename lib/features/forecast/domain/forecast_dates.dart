// Calendar helpers for the forecast engine. All values are local midnight
// dates; day arithmetic goes through UTC so DST changes never shift a day.

/// Local midnight of [d].
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// [d] plus [n] calendar days (local midnight).
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Whole calendar days from [a] to [b] (negative when [b] is before [a]).
int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// [d] plus [months] months; the day is clamped to the target month's
/// length (31 Jan + 1 month = 28/29 Feb).
DateTime addMonthsClamped(DateTime d, int months) {
  final total = d.year * 12 + (d.month - 1) + months;
  final y = total ~/ 12;
  final m = total % 12 + 1;
  final day = d.day.clamp(1, daysInMonth(y, m));
  return DateTime(y, m, day);
}

DateTime monthStart(DateTime d) => DateTime(d.year, d.month);

DateTime nextMonthStart(DateTime d) => DateTime(d.year, d.month + 1);

/// Inclusive last day of the forecast horizon: [today] + [months] months.
DateTime horizonEnd(DateTime today, int months) =>
    addMonthsClamped(dayOf(today), months.clamp(1, 480));

/// Splits [total] into [parts] integers that sum exactly to [total]. The
/// remainder cents are spread evenly (share k = ⌊(k+1)·t/n⌋ − ⌊k·t/n⌋ on the
/// magnitude), so the spread never drifts and a window clipped by the
/// horizon books its fair part.
List<int> allocateEvenly(int total, int parts) {
  if (parts <= 0) return const [];
  final sign = total < 0 ? -1 : 1;
  final t = total.abs();
  var previous = 0;
  return List<int>.generate(parts, (k) {
    final cumulative = (t * (k + 1)) ~/ parts;
    final share = cumulative - previous;
    previous = cumulative;
    return sign * share;
  }, growable: false);
}
