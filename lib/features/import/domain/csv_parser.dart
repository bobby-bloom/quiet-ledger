import 'package:personal_finance/features/import/domain/raw_sheet.dart';

/// Candidate field delimiters, in order of preference on ties.
const csvDelimiters = [';', ',', '\t', '|'];

/// Splits delimited [text] into rows of fields (RFC 4180 with lenient
/// handling of stray quotes). Accepts `\r\n`, `\n` and `\r` line endings
/// and line breaks inside quoted fields. A doubled quote inside a quoted
/// field is a literal quote. Empty lines are kept as empty rows so row
/// numbers match the file's lines.
List<List<String>> parseDelimited(
  String text, {
  required String delimiter,
  String quote = '"',
  int? maxRows,
}) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var fieldStarted = false;
  final d = delimiter.codeUnitAt(0);
  final q = quote.isEmpty ? -1 : quote.codeUnitAt(0);
  const cr = 13;
  const lf = 10;
  final n = text.length;

  void endField() {
    row.add(field.toString());
    field.clear();
    fieldStarted = false;
  }

  void endRow() {
    endField();
    rows.add(row.length == 1 && row.single.isEmpty ? <String>[] : row);
    row = <String>[];
  }

  var i = 0;
  while (i < n) {
    final c = text.codeUnitAt(i);
    if (inQuotes) {
      if (c == q) {
        if (i + 1 < n && text.codeUnitAt(i + 1) == q) {
          field.writeCharCode(q);
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      field.writeCharCode(c);
      i++;
      continue;
    }
    if (c == q && !fieldStarted) {
      inQuotes = true;
      fieldStarted = true;
      i++;
      continue;
    }
    if (c == d) {
      endField();
      i++;
      continue;
    }
    if (c == cr || c == lf) {
      endRow();
      if (maxRows != null && rows.length >= maxRows) return rows;
      if (c == cr && i + 1 < n && text.codeUnitAt(i + 1) == lf) i++;
      i++;
      continue;
    }
    field.writeCharCode(c);
    if (c != 32 && c != 9) fieldStarted = true;
    i++;
  }
  if (field.isNotEmpty || row.isNotEmpty || fieldStarted) endRow();
  return rows;
}

/// Detects the line ending used by [text].
LineEnding detectLineEnding(String text) {
  var crlf = 0;
  var lf = 0;
  var cr = 0;
  final n = text.length < 65536 ? text.length : 65536;
  for (var i = 0; i < n; i++) {
    final c = text.codeUnitAt(i);
    if (c == 13) {
      if (i + 1 < text.length && text.codeUnitAt(i + 1) == 10) {
        crlf++;
        i++;
      } else {
        cr++;
      }
    } else if (c == 10) {
      lf++;
    }
  }
  if (crlf >= lf && crlf >= cr && crlf > 0) return LineEnding.crlf;
  if (cr > lf) return LineEnding.cr;
  return LineEnding.lf;
}

/// Detects the quote character: `"` unless single quotes clearly wrap
/// fields.
String detectQuote(String sample) {
  final dq = RegExp(
    r'(^|[;,\t|])"|"($|[;,\t|\r\n])',
    multiLine: true,
  ).allMatches(sample).length;
  final sq = RegExp(
    r"(^|[;,\t|])'|'($|[;,\t|\r\n])",
    multiLine: true,
  ).allMatches(sample).length;
  return sq > dq * 2 && sq >= 4 ? "'" : '"';
}

/// Detects the field delimiter. Every candidate splits the first lines; the
/// winner yields the most lines sharing the same field count (> 1). This
/// tolerates bank preambles of a few lines with a different shape.
String detectDelimiter(String text, {String quote = '"'}) {
  final sample = text.length > 65536 ? text.substring(0, 65536) : text;
  var best = ',';
  var bestScore = -1.0;
  for (final d in csvDelimiters) {
    final rows = parseDelimited(
      sample,
      delimiter: d,
      quote: quote,
      maxRows: 60,
    );
    if (rows.isEmpty) continue;
    final counts = <int, int>{};
    for (final r in rows) {
      counts[r.length] = (counts[r.length] ?? 0) + 1;
    }
    var modeFields = 1;
    var modeLines = 0;
    counts.forEach((fields, lines) {
      if (fields > 1 &&
          (lines > modeLines || (lines == modeLines && fields > modeFields))) {
        modeFields = fields;
        modeLines = lines;
      }
    });
    if (modeLines == 0) continue;
    // Consistency first, then more columns.
    final score = modeLines * 1000.0 + modeFields;
    if (score > bestScore) {
      bestScore = score;
      best = d;
    }
  }
  return best;
}

/// Reads delimited text into a single [RawSheet] named [sheetName]. When
/// [delimiter] or [quote] is null it is detected. Handles Excel's `sep=;`
/// first line.
({RawSheet sheet, String delimiter, String quote, LineEnding lineEnding})
readDelimitedText(
  String text, {
  required String sheetName,
  String? delimiter,
  String? quote,
}) {
  var body = text;
  var delim = delimiter;
  final sepLine = RegExp(r'^\s*"?sep=(.)"?\s*(\r\n|\n|\r)').firstMatch(body);
  if (sepLine != null) {
    delim ??= sepLine.group(1);
    body = body.substring(sepLine.end);
  }
  final q =
      quote ??
      detectQuote(body.length > 65536 ? body.substring(0, 65536) : body);
  delim ??= detectDelimiter(body, quote: q);
  final rows = parseDelimited(body, delimiter: delim, quote: q);
  // Trim trailing empty fields per row.
  final cells = <List<RawCell>>[
    for (final r in rows)
      () {
        var end = r.length;
        while (end > 0 && r[end - 1].trim().isEmpty) {
          end--;
        }
        return [for (var i = 0; i < end; i++) RawCell.text(r[i])];
      }(),
  ];
  return (
    sheet: RawSheet(name: sheetName, rows: cells),
    delimiter: delim,
    quote: q,
    lineEnding: detectLineEnding(text),
  );
}
