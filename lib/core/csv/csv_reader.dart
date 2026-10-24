/// Minimal RFC 4180 CSV parser that keeps the difference between an unquoted
/// empty field (`null` when [unquotedEmptyAsNull]) and a quoted empty field
/// (`''`). Used to read the backup bundle written with
/// `CsvOptions.bundle`. Handles quoted delimiters, doubled quotes and line
/// breaks inside quotes, and `\n`, `\r\n` or `\r` line endings. A UTF-8 BOM
/// at the start is skipped. Blank lines are skipped.
///
/// Throws [FormatException] on an unterminated quoted field or on text after
/// a closing quote.
List<List<String?>> parseCsv(
  String input, {
  String delimiter = ',',
  bool unquotedEmptyAsNull = false,
}) {
  assert(delimiter.length == 1, 'delimiter must be one character');
  final d = delimiter.codeUnitAt(0);
  const quote = 0x22;
  const cr = 0x0D;
  const lf = 0x0A;
  final rows = <List<String?>>[];
  var row = <String?>[];
  final field = StringBuffer();
  var quoted = false;
  var i = input.startsWith('﻿') ? 1 : 0;
  final n = input.length;
  var lineHasContent = false;

  void endField() {
    final text = field.toString();
    row.add(!quoted && text.isEmpty && unquotedEmptyAsNull ? null : text);
    field.clear();
    quoted = false;
  }

  void endRow() {
    endField();
    if (lineHasContent || row.length > 1) rows.add(row);
    row = <String?>[];
    lineHasContent = false;
  }

  while (i < n) {
    final c = input.codeUnitAt(i);
    if (c == quote && field.isEmpty && !quoted) {
      // Quoted field.
      quoted = true;
      lineHasContent = true;
      i++;
      var closed = false;
      while (i < n) {
        final q = input.codeUnitAt(i);
        if (q == quote) {
          if (i + 1 < n && input.codeUnitAt(i + 1) == quote) {
            field.writeCharCode(quote);
            i += 2;
            continue;
          }
          closed = true;
          i++;
          break;
        }
        field.writeCharCode(q);
        i++;
      }
      if (!closed) {
        throw FormatException('Unterminated quoted field', input, i);
      }
      if (i < n) {
        final next = input.codeUnitAt(i);
        if (next != d && next != cr && next != lf) {
          throw FormatException('Unexpected character after quote', input, i);
        }
      }
      continue;
    }
    if (c == d) {
      lineHasContent = true;
      endField();
      i++;
      continue;
    }
    if (c == cr || c == lf) {
      endRow();
      i++;
      if (c == cr && i < n && input.codeUnitAt(i) == lf) i++;
      continue;
    }
    lineHasContent = true;
    field.writeCharCode(c);
    i++;
  }
  if (lineHasContent || field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}
