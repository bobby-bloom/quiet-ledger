import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:personal_finance/core/csv/csv_writer.dart';

// A report's tabular data. The same table is rendered beneath every chart
// (also the accessible alternative to the chart) and exported to CSV.

enum CellKind { text, money, count, percent, date }

/// One typed table cell. Money is in minor units, percentages in basis
/// points.
@immutable
class ReportCell {
  const ReportCell.text(String this.text)
    : kind = CellKind.text,
      number = null,
      date = null,
      signed = false;

  /// [signed] shows an explicit `+` for positive values (deltas).
  const ReportCell.money(int this.number, {this.signed = false})
    : kind = CellKind.money,
      text = null,
      date = null;

  const ReportCell.count(int this.number)
    : kind = CellKind.count,
      text = null,
      date = null,
      signed = false;

  /// [bp] null renders as an empty cell (e.g. no previous value).
  const ReportCell.percent(int? bp, {this.signed = false})
    : kind = CellKind.percent,
      number = bp,
      text = null,
      date = null;

  const ReportCell.date(DateTime this.date)
    : kind = CellKind.date,
      text = null,
      number = null,
      signed = false;

  final CellKind kind;
  final String? text;
  final int? number;
  final DateTime? date;
  final bool signed;

  bool get isNumeric => kind != CellKind.text && kind != CellKind.date;

  @override
  bool operator ==(Object other) =>
      other is ReportCell &&
      other.kind == kind &&
      other.text == text &&
      other.number == number &&
      other.date == date;

  @override
  int get hashCode => Object.hash(kind, text, number, date);
}

@immutable
class ReportColumn {
  const ReportColumn(this.label, {this.numeric = false});

  final String label;

  /// Right-aligned, tabular figures.
  final bool numeric;
}

@immutable
class ReportRow {
  const ReportRow(this.cells, {this.link, this.drill, this.emphasis = false});

  final List<ReportCell> cells;

  /// Location opened when the row is tapped (e.g. the transactions list).
  final String? link;

  /// Id passed to the table's drill-down callback (e.g. a parent category).
  final String? drill;

  /// Total rows are set in bold.
  final bool emphasis;
}

@immutable
class ReportTable {
  const ReportTable({required this.columns, required this.rows});

  final List<ReportColumn> columns;
  final List<ReportRow> rows;
}

/// The CSV cell value of [c] for `CsvWriter` (money as fixed-point amount,
/// percentages as percent with two decimals).
Object? csvValue(ReportCell c) => switch (c.kind) {
  CellKind.text => c.text,
  CellKind.money => CsvAmount(c.number!),
  CellKind.count => c.number,
  CellKind.percent => c.number == null ? null : CsvAmount(c.number!),
  CellKind.date => c.date,
};

/// Encodes [table] as CSV bytes with the delimiter, encoding, decimal
/// separator and date format of [options].
Uint8List reportTableCsvBytes(ReportTable table, CsvOptions options) =>
    CsvWriter(options).encodeTable(
      [for (final c in table.columns) c.label],
      [
        for (final r in table.rows) [for (final c in r.cells) csvValue(c)],
      ],
    );
