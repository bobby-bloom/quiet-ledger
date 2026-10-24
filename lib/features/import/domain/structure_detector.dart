import 'package:meta/meta.dart';
import 'package:personal_finance/features/import/domain/date_parser.dart';
import 'package:personal_finance/features/import/domain/header_synonyms.dart';
import 'package:personal_finance/features/import/domain/raw_sheet.dart';

/// Where the header and the data of a sheet are.
@immutable
class SheetStructure {
  const SheetStructure({
    required this.headerRow,
    required this.headerRows,
    required this.firstDataRow,
  });

  /// 0-based; -1 = the sheet has no header row.
  final int headerRow;
  final int headerRows;
  final int firstDataRow;

  @override
  bool operator ==(Object other) =>
      other is SheetStructure &&
      other.headerRow == headerRow &&
      other.headerRows == headerRows &&
      other.firstDataRow == firstDataRow;

  @override
  int get hashCode => Object.hash(headerRow, headerRows, firstDataRow);

  @override
  String toString() =>
      'SheetStructure(header: $headerRow×$headerRows, data: $firstDataRow)';
}

final _numberLike = RegExp(
  r'^[-+−(]?\s*[€$£]?\s*[\d.,\s  ]+\)?\s*[€$£]?\s*[-−]?$',
);
final _dateLike = RegExp(
  r'^\d{1,4}[./\-]\d{1,2}[./\-]?\d{0,4}$|^\d{1,2}\.?\s+[A-Za-zÄÖÜäöü]{3,}\.?\s+\d{2,4}$',
);

/// Whether a cell looks like data (a number, date or amount text) rather
/// than a header label.
bool isDataLike(RawCell c) {
  switch (c.kind) {
    case RawKind.number:
    case RawKind.date:
    case RawKind.boolean:
      return true;
    case RawKind.text:
      final t = c.text!.trim();
      return _numberLike.hasMatch(t) || _dateLike.hasMatch(t);
    case RawKind.empty:
    case RawKind.error:
      return false;
  }
}

bool _isDateish(RawCell c) {
  if (c.kind == RawKind.date) return true;
  if (c.kind == RawKind.number) {
    final n = num.tryParse(c.number!);
    return n != null && n >= 18264 && n <= 73050;
  }
  if (c.kind == RawKind.text) {
    final t = c.text!.trim();
    return _dateLike.hasMatch(t) ||
        parseDateText(t, DateFormatKind.monthName, yearHint: 2000) != null;
  }
  return false;
}

/// Statistics of one row used to recognise headers.
({int nonEmpty, int labels, int data, int known, bool dateish}) _rowStats(
  RawSheet sheet,
  int r,
) {
  var nonEmpty = 0;
  var labels = 0;
  var data = 0;
  var known = 0;
  var dateish = false;
  final row = r < sheet.rows.length ? sheet.rows[r] : const <RawCell>[];
  for (final c in row) {
    if (c.isEmpty) continue;
    nonEmpty++;
    if (isDataLike(c)) {
      data++;
      if (_isDateish(c)) dateish = true;
    } else if (c.isText) {
      labels++;
      if (isKnownHeader(c.text!)) known++;
    }
  }
  return (
    nonEmpty: nonEmpty,
    labels: labels,
    data: data,
    known: known,
    dateish: dateish,
  );
}

/// Finds the header row(s) and the first data row of [sheet].
///
/// The header is the row (within the first 40) with the best mix of known
/// header words, text labels and data rows below it; title rows above it
/// are skipped. A second header row is added when the header is split over
/// two rows (merged group labels above, or sub-labels below).
SheetStructure detectStructure(RawSheet sheet) {
  final limit = sheet.rowCount < 40 ? sheet.rowCount : 40;
  var best = -1;
  var bestScore = 0.0;
  for (var r = 0; r < limit; r++) {
    final s = _rowStats(sheet, r);
    if (s.labels < 2 || s.labels < s.nonEmpty * 0.6) continue;
    // Data below: dates / numbers in the next non-empty rows.
    var below = 0;
    var seen = 0;
    for (var k = r + 1; k < sheet.rowCount && seen < 5; k++) {
      final b = _rowStats(sheet, k);
      if (b.nonEmpty == 0) continue;
      seen++;
      if (b.data > 0 && (b.dateish || b.data >= 2)) below++;
    }
    final score =
        s.known * 4.0 +
        s.labels +
        (seen == 0 ? 0 : below / seen * 4) -
        s.data * 2;
    if (score > bestScore + 0.01) {
      best = r;
      bestScore = score;
    }
  }
  if (best < 0) {
    var first = 0;
    while (first < sheet.rowCount && sheet.isRowEmpty(first)) {
      first++;
    }
    return SheetStructure(headerRow: -1, headerRows: 0, firstDataRow: first);
  }
  var start = best;
  var count = 1;
  // Group labels above (e.g. "Betrag" merged over "Ausgabe | Einnahme").
  if (best > 0) {
    final above = _rowStats(sheet, best - 1);
    final hasHorizontalMerge = sheet.merges.any(
      (m) => m.firstRow == best - 1 && m.isHorizontal,
    );
    if (above.nonEmpty > 0 &&
        above.data == 0 &&
        hasHorizontalMerge &&
        (above.known > 0 || above.labels >= 2)) {
      start = best - 1;
      count = 2;
    }
  }
  // Sub-labels below the header.
  final next = _rowStats(sheet, best + 1);
  if (next.nonEmpty > 0 && next.data == 0 && next.labels > 0) {
    final after = _rowStats(sheet, best + 2);
    final mergedHeader = sheet.merges.any(
      (m) => m.firstRow == best && (m.isHorizontal || m.lastRow > best),
    );
    if (after.data > 0 && (mergedHeader || next.known > 0)) count++;
  }
  return SheetStructure(
    headerRow: start,
    headerRows: count,
    firstDataRow: start + count,
  );
}

/// Column labels of [sheet] for a header at [headerRow] spanning
/// [headerRows] rows. Merged cells are propagated (a group label merged
/// over several columns appears in each), and the parts of multi-row
/// headers are joined with a space ("Betrag Ausgabe"). Columns without a
/// header get an empty label.
List<String> composeHeaders(
  RawSheet sheet,
  int headerRow,
  int headerRows, {
  int? columnCount,
}) {
  final cols = columnCount ?? sheet.columnCount;
  if (headerRow < 0 || headerRows <= 0) return List.filled(cols, '');
  return [
    for (var c = 0; c < cols; c++)
      () {
        final parts = <String>[];
        for (var r = headerRow; r < headerRow + headerRows; r++) {
          final v = sheet
              .mergedCell(r, c)
              .trimmed
              .replaceAll(RegExp(r'\s+'), ' ');
          if (v.isNotEmpty && (parts.isEmpty || parts.last != v)) parts.add(v);
        }
        return parts.join(' ');
      }(),
  ];
}
