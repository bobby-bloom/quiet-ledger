import 'package:meta/meta.dart';

/// One row for the running-balance check.
@immutable
class BalancePoint {
  const BalancePoint({
    required this.ref,
    required this.amountMinor,
    this.balanceMinor,
    this.date,
  });

  /// Row reference shown in reports.
  final String ref;
  final int amountMinor;

  /// The sheet's balance after this row, when the cell has one.
  final int? balanceMinor;
  final DateTime? date;
}

/// A row whose sheet balance differs from the computed one.
@immutable
class BalanceMismatch {
  const BalanceMismatch(this.ref, this.expectedMinor, this.actualMinor);

  final String ref;

  /// Previous balance + this row's amount.
  final int expectedMinor;

  /// What the sheet says.
  final int actualMinor;

  int get differenceMinor => actualMinor - expectedMinor;
}

/// Result of verifying a running-balance column (PLAN.md §2.5 step 6).
@immutable
class BalanceReport {
  const BalanceReport({
    required this.groupKey,
    required this.rowCount,
    required this.checked,
    required this.mismatches,
    required this.descending,
    required this.sumMinor,
    this.openingMinor,
    this.closingMinor,
  });

  /// Account key (or sheet key when one sheet holds several accounts).
  final String groupKey;
  final int rowCount;

  /// Rows that had a balance and were compared.
  final int checked;
  final List<BalanceMismatch> mismatches;

  /// The sheet lists the newest row first.
  final bool descending;

  /// Sum of all amounts.
  final int sumMinor;

  /// Balance before the oldest row, derived from the first balance.
  final int? openingMinor;

  /// The sheet's balance after the newest row.
  final int? closingMinor;

  bool get hasBalance => openingMinor != null;
  int get matched => checked - mismatches.length;
  bool get ok => mismatches.isEmpty;

  /// Opening + all amounts; equals [closingMinor] when everything matches.
  int? get computedClosingMinor =>
      openingMinor == null ? null : openingMinor! + sumMinor;
}

/// Verifies [points] (in sheet order) against their balance column.
///
/// Both directions are tried: oldest-first sheets (balance = previous +
/// amount) and newest-first bank exports; the one with fewer mismatches
/// wins. The opening balance is derived from the first row that has a
/// balance (`balance − amounts so far`). After a mismatch the check
/// re-synchronises on the sheet's value, so one wrong row is reported once
/// instead of shifting every following row.
BalanceReport checkBalances(String groupKey, List<BalancePoint> points) {
  final asc = _check(groupKey, points, descending: false);
  if (points.length < 2) return asc;
  final desc = _check(groupKey, points.reversed.toList(), descending: true);
  if (desc.mismatches.length < asc.mismatches.length) return desc;
  if (desc.mismatches.length == asc.mismatches.length &&
      desc.mismatches.isNotEmpty &&
      _datesDescending(points)) {
    return desc;
  }
  return asc;
}

bool _datesDescending(List<BalancePoint> points) {
  final dated = [
    for (final p in points)
      if (p.date != null) p.date!,
  ];
  if (dated.length < 2) return false;
  return dated.first.isAfter(dated.last);
}

BalanceReport _check(
  String groupKey,
  List<BalancePoint> chronological, {
  required bool descending,
}) {
  int? opening;
  var prefix = 0;
  var checked = 0;
  var offset = 0;
  final mismatches = <BalanceMismatch>[];
  int? closing;
  for (final p in chronological) {
    prefix += p.amountMinor;
    final b = p.balanceMinor;
    if (b == null) continue;
    closing = b;
    if (opening == null) {
      opening = b - prefix;
      checked++;
      continue;
    }
    checked++;
    final expected = opening + offset + prefix;
    if (expected != b) {
      mismatches.add(BalanceMismatch(p.ref, expected, b));
      offset += b - expected;
    }
  }
  return BalanceReport(
    groupKey: groupKey,
    rowCount: chronological.length,
    checked: checked,
    mismatches: mismatches,
    descending: descending,
    sumMinor: prefix,
    openingMinor: opening,
    closingMinor: closing,
  );
}
