import 'package:personal_finance/core/settings/app_settings.dart';

/// Start (inclusive) of the group that [date] belongs to. [firstDayOfWeek]
/// uses `DateTime.weekday` numbering (1 = Monday ... 7 = Sunday).
DateTime groupStart(DateTime date, TxnGrouping grouping, int firstDayOfWeek) {
  final d = DateTime(date.year, date.month, date.day);
  switch (grouping) {
    case TxnGrouping.day:
    case TxnGrouping.none:
      return d;
    case TxnGrouping.week:
      final back = (d.weekday - firstDayOfWeek + 7) % 7;
      return DateTime(d.year, d.month, d.day - back);
    case TxnGrouping.month:
      return DateTime(d.year, d.month);
  }
}

/// End (exclusive) of the group starting at [start].
DateTime groupEnd(DateTime start, TxnGrouping grouping) => switch (grouping) {
  TxnGrouping.day ||
  TxnGrouping.none => DateTime(start.year, start.month, start.day + 1),
  TxnGrouping.week => DateTime(start.year, start.month, start.day + 7),
  TxnGrouping.month => DateTime(start.year, start.month + 1),
};

/// Whether the list can be grouped by date for [sort]. Grouping is only
/// meaningful when the list is ordered by date.
bool groupingApplies(TxnGrouping grouping, TxnSort sort) =>
    grouping != TxnGrouping.none &&
    (sort == TxnSort.dateDesc || sort == TxnSort.dateAsc);

/// Sums per-day amounts into groups: returns group start -> sum.
Map<DateTime, int> sumByGroup(
  Map<DateTime, int> daySums,
  TxnGrouping grouping,
  int firstDayOfWeek,
) {
  final out = <DateTime, int>{};
  for (final e in daySums.entries) {
    final g = groupStart(e.key, grouping, firstDayOfWeek);
    out[g] = (out[g] ?? 0) + e.value;
  }
  return out;
}
