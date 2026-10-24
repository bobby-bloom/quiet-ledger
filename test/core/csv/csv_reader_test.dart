import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/csv/csv_reader.dart';

void main() {
  test('plain rows with CRLF, LF and CR', () {
    expect(parseCsv('a,b\r\nc,d\ne,f\rg,h'), [
      ['a', 'b'],
      ['c', 'd'],
      ['e', 'f'],
      ['g', 'h'],
    ]);
  });

  test('quoted fields with delimiters, quotes and line breaks', () {
    expect(parseCsv('"a,b","say ""hi""","x\r\ny"\r\n'), [
      ['a,b', 'say "hi"', 'x\r\ny'],
    ]);
  });

  test('distinguishes null from empty string', () {
    expect(parseCsv(',"",x', unquotedEmptyAsNull: true), [
      [null, '', 'x'],
    ]);
    expect(parseCsv(',"",x'), [
      ['', '', 'x'],
    ]);
  });

  test('trailing empty field and blank lines', () {
    expect(parseCsv('a,\n\nb,c\n'), [
      ['a', ''],
      ['b', 'c'],
    ]);
  });

  test('BOM and other delimiters', () {
    expect(parseCsv('﻿a;b', delimiter: ';'), [
      ['a', 'b'],
    ]);
    expect(parseCsv('a\tb', delimiter: '\t'), [
      ['a', 'b'],
    ]);
  });

  test('malformed input throws', () {
    expect(() => parseCsv('"open'), throwsFormatException);
    expect(() => parseCsv('"a"b,c'), throwsFormatException);
  });
}
