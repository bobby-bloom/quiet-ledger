/// Period choices of the transaction export.
enum ExportPeriod {
  thisMonth,
  lastMonth,
  thisYear,
  lastYear,
  last12Months,
  all,
  custom,
}

/// Half-open ledger-date range `[start, end)` for [period] relative to
/// [today]. For [ExportPeriod.custom], [customStart]/[customEnd] are
/// inclusive days. Null bounds mean "unbounded".
({DateTime? start, DateTime? end}) exportPeriodRange(
  ExportPeriod period,
  DateTime today, {
  DateTime? customStart,
  DateTime? customEnd,
}) {
  final y = today.year;
  final m = today.month;
  return switch (period) {
    ExportPeriod.thisMonth => (start: DateTime(y, m), end: DateTime(y, m + 1)),
    ExportPeriod.lastMonth => (start: DateTime(y, m - 1), end: DateTime(y, m)),
    ExportPeriod.thisYear => (start: DateTime(y), end: DateTime(y + 1)),
    ExportPeriod.lastYear => (start: DateTime(y - 1), end: DateTime(y)),
    ExportPeriod.last12Months => (
      start: DateTime(y, m - 11),
      end: DateTime(y, m + 1),
    ),
    ExportPeriod.all => (start: null, end: null),
    ExportPeriod.custom => (
      start: customStart == null
          ? null
          : DateTime(customStart.year, customStart.month, customStart.day),
      end: customEnd == null
          ? null
          : DateTime(customEnd.year, customEnd.month, customEnd.day + 1),
    ),
  };
}
