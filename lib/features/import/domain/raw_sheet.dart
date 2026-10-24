import 'package:meta/meta.dart';

// Format-independent representation of what a reader found in a file.
// Everything here is plain data so it can cross isolate boundaries.

enum RawKind { empty, text, number, date, boolean, error }

/// One cell as read from a file.
///
/// Numbers keep their exact decimal text (`number`, e.g. `-45.67`) so amounts
/// never pass through `double` arithmetic. Dates are local midnight.
@immutable
class RawCell {
  const RawCell._(this.kind, {this.text, this.number, this.date});

  /// A text cell; blank text becomes [empty].
  factory RawCell.text(String text) =>
      text.trim().isEmpty ? empty : RawCell._(RawKind.text, text: text);

  /// A numeric cell with its canonical decimal text (`1234.5`, `-3`, `1e-7`).
  const RawCell.number(String number) : this._(RawKind.number, number: number);

  const RawCell.date(DateTime date) : this._(RawKind.date, date: date);

  const RawCell.boolean(bool value)
    : this._(RawKind.boolean, text: value ? 'TRUE' : 'FALSE');

  const RawCell.error(String code) : this._(RawKind.error, text: code);

  static const empty = RawCell._(RawKind.empty);

  final RawKind kind;
  final String? text;
  final String? number;
  final DateTime? date;

  bool get isEmpty => kind == RawKind.empty;
  bool get isNotEmpty => kind != RawKind.empty;
  bool get isText => kind == RawKind.text;

  /// The value as shown in the preview grid.
  String get display => switch (kind) {
    RawKind.empty => '',
    RawKind.text || RawKind.boolean || RawKind.error => text!,
    RawKind.number => number!,
    RawKind.date =>
      '${_two(date!.day)}.${_two(date!.month)}.${date!.year.toString().padLeft(4, '0')}',
  };

  /// Trimmed text for text cells, display value otherwise.
  String get trimmed => display.trim();

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  bool operator ==(Object other) =>
      other is RawCell &&
      other.kind == kind &&
      other.text == text &&
      other.number == number &&
      other.date == date;

  @override
  int get hashCode => Object.hash(kind, text, number, date);

  @override
  String toString() => 'RawCell(${kind.name}: $display)';
}

/// A merged cell range, 0-based and inclusive.
@immutable
class MergedRange {
  const MergedRange(this.firstRow, this.firstCol, this.lastRow, this.lastCol);

  final int firstRow;
  final int firstCol;
  final int lastRow;
  final int lastCol;

  bool contains(int row, int col) =>
      row >= firstRow && row <= lastRow && col >= firstCol && col <= lastCol;

  bool get isHorizontal => lastCol > firstCol;

  @override
  bool operator ==(Object other) =>
      other is MergedRange &&
      other.firstRow == firstRow &&
      other.firstCol == firstCol &&
      other.lastRow == lastRow &&
      other.lastCol == lastCol;

  @override
  int get hashCode => Object.hash(firstRow, firstCol, lastRow, lastCol);
}

/// One sheet (or the single table of a CSV file).
@immutable
class RawSheet {
  const RawSheet({
    required this.name,
    required this.rows,
    this.merges = const [],
    this.hidden = false,
  });

  final String name;

  /// Rows as stored; rows may have different lengths (trailing blanks
  /// trimmed).
  final List<List<RawCell>> rows;
  final List<MergedRange> merges;
  final bool hidden;

  int get rowCount => rows.length;

  int get columnCount {
    var max = 0;
    for (final r in rows) {
      if (r.length > max) max = r.length;
    }
    return max;
  }

  RawCell cell(int row, int col) {
    if (row < 0 || row >= rows.length) return RawCell.empty;
    final r = rows[row];
    return col < 0 || col >= r.length ? RawCell.empty : r[col];
  }

  /// Like [cell], but a cell covered by a merged range returns the value of
  /// the range's top-left cell.
  RawCell mergedCell(int row, int col) {
    final c = cell(row, col);
    if (c.isNotEmpty || merges.isEmpty) return c;
    for (final m in merges) {
      if (m.contains(row, col)) return cell(m.firstRow, m.firstCol);
    }
    return c;
  }

  bool isRowEmpty(int row) =>
      row >= rows.length || rows[row].every((c) => c.isEmpty);
}

enum SourceFormat { xlsx, xls, csv, clipboard }

/// Text encodings the CSV reader understands. [latin1] is ISO-8859-1,
/// [latin9] is ISO-8859-15 (Latin-9, with the euro sign at 0xA4).
enum TextEncoding { auto, utf8, utf16le, utf16be, windows1252, latin1, latin9 }

enum LineEnding { crlf, lf, cr }

/// How a delimited text file was (or should be) read.
@immutable
class CsvDialect {
  const CsvDialect({
    this.delimiter = ',',
    this.quote = '"',
    this.encoding = TextEncoding.utf8,
    this.lineEnding = LineEnding.lf,
    this.hadBom = false,
  });

  factory CsvDialect.fromJson(Map<String, Object?> j) => CsvDialect(
    delimiter: j['delimiter'] as String? ?? ',',
    quote: j['quote'] as String? ?? '"',
    encoding: TextEncoding.values.firstWhere(
      (e) => e.name == j['encoding'],
      orElse: () => TextEncoding.auto,
    ),
  );

  final String delimiter;
  final String quote;
  final TextEncoding encoding;
  final LineEnding lineEnding;
  final bool hadBom;

  Map<String, Object?> toJson() => {
    'delimiter': delimiter,
    'quote': quote,
    'encoding': encoding.name,
  };

  @override
  bool operator ==(Object other) =>
      other is CsvDialect &&
      other.delimiter == delimiter &&
      other.quote == quote &&
      other.encoding == encoding &&
      other.lineEnding == lineEnding &&
      other.hadBom == hadBom;

  @override
  int get hashCode =>
      Object.hash(delimiter, quote, encoding, lineEnding, hadBom);
}

/// Everything read from one file (or one clipboard paste).
@immutable
class RawWorkbook {
  const RawWorkbook({
    required this.fileName,
    required this.format,
    required this.sheets,
    required this.fileHash,
    this.dialect,
    this.date1904 = false,
    this.formulasWithoutValue = 0,
  });

  final String fileName;
  final SourceFormat format;
  final List<RawSheet> sheets;

  /// sha256 of the file bytes (hex).
  final String fileHash;

  /// For delimited text: how it was read.
  final CsvDialect? dialect;

  /// Workbook uses the 1904 date system.
  final bool date1904;

  /// Formula cells without a cached result (the file was never recalculated
  /// and saved by a spreadsheet app); they read as empty.
  final int formulasWithoutValue;
}

/// Raised when a file cannot be read at all.
enum ImportReadError {
  /// OpenDocument spreadsheet: ask the user to re-save as .xlsx.
  ods,

  /// Apple Numbers file.
  numbers,

  /// Password-protected / encrypted workbook.
  encrypted,

  /// PDF or another document type that holds no table.
  notASpreadsheet,

  /// Damaged or unreadable file.
  corrupt,

  /// Readable, but contains no data.
  empty,
}

class ImportReadException implements Exception {
  const ImportReadException(this.error, {this.detail});

  final ImportReadError error;
  final String? detail;

  @override
  String toString() =>
      'ImportReadException(${error.name}${detail == null ? '' : ': $detail'})';
}

/// "A", "B", ... "Z", "AA", ... for a 0-based column index.
String columnLetter(int index) {
  var n = index + 1;
  final sb = StringBuffer();
  while (n > 0) {
    final rem = (n - 1) % 26;
    sb.write(String.fromCharCode(65 + rem));
    n = (n - 1) ~/ 26;
  }
  return sb.toString().split('').reversed.join();
}

/// Parses "A1" / "AB12" into a 0-based (row, col).
(int, int)? parseCellRef(String ref) {
  final m = RegExp(r'^\$?([A-Za-z]+)\$?(\d+)$').firstMatch(ref.trim());
  if (m == null) return null;
  var col = 0;
  for (final ch in m.group(1)!.toUpperCase().codeUnits) {
    col = col * 26 + (ch - 64);
  }
  return (int.parse(m.group(2)!) - 1, col - 1);
}
