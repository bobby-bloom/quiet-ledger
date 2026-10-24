import 'dart:convert';
import 'dart:typed_data';

import 'package:enough_convert/latin.dart';
import 'package:enough_convert/windows.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/import/domain/csv_parser.dart';
import 'package:personal_finance/features/import/domain/date_parser.dart';
import 'package:personal_finance/features/import/domain/dedupe.dart';
import 'package:personal_finance/features/import/domain/number_parser.dart';
import 'package:personal_finance/features/import/domain/raw_sheet.dart';
import 'package:personal_finance/features/import/domain/source_reader.dart';
import 'package:personal_finance/features/import/domain/text_decoding.dart';
import 'package:personal_finance/features/import/domain/text_normalize.dart';

void main() {
  group('Excel serial dates', () {
    test('1900 system incl. the 1900 leap-year bug', () {
      expect(excelSerialToDate(1), DateTime(1900));
      expect(excelSerialToDate(59), DateTime(1900, 2, 28));
      // Excel's fictitious 29.02.1900.
      expect(excelSerialToDate(60), DateTime(1900, 2, 28));
      expect(excelSerialToDate(61), DateTime(1900, 3));
      expect(excelSerialToDate(45000), DateTime(2023, 3, 15));
      expect(excelSerialToDate(45292), DateTime(2024));
      expect(excelSerialToDate(45292.75), DateTime(2024));
      expect(excelSerialToDate(0), isNull);
      expect(excelSerialToDate(-3), isNull);
    });

    test('1904 system', () {
      expect(excelSerialToDate(0, date1904: true), DateTime(1904));
      expect(excelSerialToDate(43830, date1904: true), DateTime(2024));
    });

    test('round trip', () {
      expect(dateToExcelSerial(DateTime(2024)), 45292);
      expect(
        excelSerialToDate(dateToExcelSerial(DateTime(2031, 7, 9))),
        DateTime(2031, 7, 9),
      );
    });
  });

  group('date text', () {
    DateTime? p(String s, DateFormatKind k, {int? year}) =>
        parseDateText(s, k, yearHint: year);

    test('day first', () {
      expect(p('05.01.2023', DateFormatKind.dmy), DateTime(2023, 1, 5));
      expect(p('5.1.23', DateFormatKind.dmy), DateTime(2023, 1, 5));
      expect(p('31/12/2024', DateFormatKind.dmy), DateTime(2024, 12, 31));
      expect(p('31-12-2024', DateFormatKind.dmy), DateTime(2024, 12, 31));
      expect(p('05.01.', DateFormatKind.dmy, year: 2023), DateTime(2023, 1, 5));
      expect(p('05.01.', DateFormatKind.dmy), isNull);
      expect(p('Mo, 05.01.2026', DateFormatKind.dmy), DateTime(2026, 1, 5));
      expect(p('05.01.2023 14:30', DateFormatKind.dmy), DateTime(2023, 1, 5));
      expect(p('31.09.2024', DateFormatKind.dmy), isNull);
      expect(p('29.02.2023', DateFormatKind.dmy), isNull);
      expect(p('29.02.2024', DateFormatKind.dmy), DateTime(2024, 2, 29));
      expect(p('99.99.99', DateFormatKind.dmy), isNull);
    });

    test('two-digit years', () {
      expect(expandYear(23), 2023);
      expect(expandYear(69), 2069);
      expect(expandYear(70), 1970);
      expect(expandYear(1999), 1999);
    });

    test('month first, ISO, compact', () {
      expect(p('12/31/2024', DateFormatKind.mdy), DateTime(2024, 12, 31));
      expect(p('3/4/24', DateFormatKind.mdy), DateTime(2024, 3, 4));
      expect(p('13/01/2024', DateFormatKind.mdy), isNull);
      expect(p('2024-12-31', DateFormatKind.ymd), DateTime(2024, 12, 31));
      expect(
        p('2024-12-31T10:00:00Z', DateFormatKind.ymd),
        DateTime(2024, 12, 31),
      );
      expect(p('2024/1/5', DateFormatKind.ymd), DateTime(2024, 1, 5));
      expect(p('20241231', DateFormatKind.compact), DateTime(2024, 12, 31));
      expect(p('05.01.2023', DateFormatKind.ymd), isNull);
    });

    test('month names DE/EN', () {
      expect(
        p('5. Januar 2023', DateFormatKind.monthName),
        DateTime(2023, 1, 5),
      );
      expect(
        p('05. März 2024', DateFormatKind.monthName),
        DateTime(2024, 3, 5),
      );
      expect(p('1. Okt. 2024', DateFormatKind.monthName), DateTime(2024, 10));
      expect(p('Jan 5, 2023', DateFormatKind.monthName), DateTime(2023, 1, 5));
      expect(
        p('December 24 2023', DateFormatKind.monthName),
        DateTime(2023, 12, 24),
      );
      expect(p('05-Jan-23', DateFormatKind.monthName), DateTime(2023, 1, 5));
      expect(
        p('24 Dez', DateFormatKind.monthName, year: 2022),
        DateTime(2022, 12, 24),
      );
      expect(p('Hello 2023', DateFormatKind.monthName), isNull);
      expect(monthFromName('Mrz'), 3);
      expect(monthFromName('Dezember'), 12);
    });

    test('excel serial as text', () {
      expect(p('45000', DateFormatKind.excelSerial), DateTime(2023, 3, 15));
    });

    test('cells', () {
      expect(
        parseDateCell(RawCell.date(DateTime(2024, 2, 3)), DateFormatKind.dmy),
        DateTime(2024, 2, 3),
      );
      expect(
        parseDateCell(const RawCell.number('45000'), DateFormatKind.auto),
        DateTime(2023, 3, 15),
      );
      expect(
        parseDateCell(
          const RawCell.number('43830'),
          DateFormatKind.excelSerial,
          date1904: true,
        ),
        DateTime(2024),
      );
      expect(
        parseDateCell(RawCell.text('03/04/2024'), DateFormatKind.mdy),
        DateTime(2024, 3, 4),
      );
    });
  });

  group('date format detection', () {
    List<RawCell> t(List<String> v) => [for (final s in v) RawCell.text(s)];

    test('picks the notation that reads most values', () {
      expect(
        detectDateFormat(t(['05.01.2023', '17.01.2023'])),
        DateFormatKind.dmy,
      );
      expect(
        detectDateFormat(t(['01/17/2024', '02/03/2024'])),
        DateFormatKind.mdy,
      );
      expect(
        detectDateFormat(t(['17/01/2024', '02/03/2024'])),
        DateFormatKind.dmy,
      );
      expect(
        detectDateFormat(t(['2024-01-17', '2024-02-03'])),
        DateFormatKind.ymd,
      );
      expect(
        detectDateFormat(t(['5. Januar 2023', '6. Mai 2023'])),
        DateFormatKind.monthName,
      );
      expect(
        detectDateFormat(t(['20240117', '20240203'])),
        DateFormatKind.compact,
      );
      expect(
        detectDateFormat(const [
          RawCell.number('45000'),
          RawCell.number('45001'),
        ]),
        DateFormatKind.excelSerial,
      );
    });

    test('ambiguous slash dates follow the hint', () {
      final v = t(['03/04/2024', '05/06/2024']);
      expect(detectDateFormat(v), DateFormatKind.dmy);
      expect(detectDateFormat(v, preferMonthFirst: true), DateFormatKind.mdy);
      // Dots are always day first.
      expect(
        detectDateFormat(t(['03.04.2024']), preferMonthFirst: true),
        DateFormatKind.dmy,
      );
    });

    test('year from sheet name', () {
      expect(yearFromName('2023'), 2023);
      expect(yearFromName('Konto 2024'), 2024);
      expect(yearFromName('Girokonto'), isNull);
      expect(yearFromName('12345'), isNull);
    });
  });

  group('amounts', () {
    int? de(String s) => parseAmountText(s, NumberFormatKind.de);
    int? en(String s) => parseAmountText(s, NumberFormatKind.en);
    int? sp(String s) => parseAmountText(s, NumberFormatKind.space);

    test('German notation', () {
      expect(de('1.234,56'), 123456);
      expect(de('-1.234,56'), -123456);
      expect(de('1234,5'), 123450);
      expect(de('12'), 1200);
      expect(de('1.234.567,89 €'), 123456789);
      expect(de('€ -45,90'), -4590);
      expect(de('45,90-'), -4590);
      expect(de('−12,50'), -1250);
      expect(de('(12,50)'), -1250);
      expect(de('+3.250,00 EUR'), 325000);
      expect(de('45,90 S'), -4590);
      expect(de('45,90 H'), 4590);
      expect(de(',50'), 50);
      expect(de('1,005'), 101);
      expect(de('41,2O'), isNull);
      expect(de('1,234.56'), isNull);
      expect(de('abc'), isNull);
      expect(de(''), isNull);
    });

    test('English notation', () {
      expect(en('1,234.56'), 123456);
      expect(en('(45.00)'), -4500);
      expect(en(r'$1,000'), 100000);
      expect(en('-0.99'), -99);
      expect(en('12.345'), 1235);
      expect(en('45.00 DR'), -4500);
      expect(en('45.00 CR'), 4500);
      expect(en('1.234,56'), isNull);
    });

    test('space grouping', () {
      expect(sp('1 234,56'), 123456);
      expect(sp('1\u00a0234,56'), 123456);
      expect(sp('1 234.56'), 123456);
      expect(sp("1'234.56"), 123456);
    });

    test('cells', () {
      expect(
        parseAmountCell(const RawCell.number('-45.67'), NumberFormatKind.de),
        -4567,
      );
      expect(
        parseAmountCell(
          const RawCell.number('41.199999999999996'),
          NumberFormatKind.de,
        ),
        4120,
      );
      expect(
        parseAmountCell(const RawCell.number('1e-7'), NumberFormatKind.de),
        0,
      );
      expect(parseAmountCell(RawCell.text('12,50'), NumberFormatKind.de), 1250);
      expect(parseAmountCell(RawCell.empty, NumberFormatKind.de), isNull);
      expect(decimalToMinor('-0.005'), -1);
    });

    test('format detection', () {
      expect(detectNumberFormat(['1.234,56', '-45,90']), NumberFormatKind.de);
      expect(detectNumberFormat(['1,234.56', '(45.00)']), NumberFormatKind.en);
      expect(detectNumberFormat(['1 234,56', '12,00']), NumberFormatKind.space);
      expect(detectNumberFormat(['1.234']), NumberFormatKind.de);
      expect(detectNumberFormat(['1,234']), NumberFormatKind.en);
      expect(detectNumberFormat(['12', '13']), NumberFormatKind.de);
      expect(
        detectNumberFormat(['12', '13'], fallback: NumberFormatKind.en),
        NumberFormatKind.en,
      );
    });
  });

  group('text decoding', () {
    Uint8List b(List<int> v) => Uint8List.fromList(v);

    test('BOMs', () {
      final r = decodeText(b([0xEF, 0xBB, 0xBF, ...utf8.encode('Müller')]));
      expect(r.text, 'Müller');
      expect(r.encoding, TextEncoding.utf8);
      expect(r.hadBom, isTrue);
      final le = decodeText(b([0xFF, 0xFE, 0x4D, 0x00, 0xFC, 0x00]));
      expect(le.text, 'Mü');
      expect(le.encoding, TextEncoding.utf16le);
      final be = decodeText(b([0xFE, 0xFF, 0x00, 0x4D, 0x00, 0xFC]));
      expect(be.text, 'Mü');
    });

    test('UTF-8 without BOM', () {
      final r = decodeText(b(utf8.encode('Größe;€')));
      expect(r.encoding, TextEncoding.utf8);
      expect(r.text, 'Größe;€');
    });

    test('Windows-1252 (euro at 0x80)', () {
      final bytes = const Windows1252Codec().encode('Bäckerei;12,50 €');
      final r = decodeText(Uint8List.fromList(bytes));
      expect(r.encoding, TextEncoding.windows1252);
      expect(r.text, 'Bäckerei;12,50 €');
    });

    test('ISO-8859-15 (euro at 0xA4)', () {
      final bytes = const Latin15Codec().encode('Bäcker;3,95 €');
      final r = decodeText(Uint8List.fromList(bytes));
      expect(r.encoding, TextEncoding.latin9);
      expect(r.text, 'Bäcker;3,95 €');
    });

    test('ISO-8859-1 umlauts default to Windows-1252', () {
      final r = decodeText(b(latin1.encode('Müller')));
      expect(r.encoding, TextEncoding.windows1252);
      expect(r.text, 'Müller');
      expect(
        decodeText(
          b(latin1.encode('Müller')),
          encoding: TextEncoding.latin1,
        ).text,
        'Müller',
      );
    });

    test('UTF-16 without BOM', () {
      final units = <int>[];
      for (final c in 'Datum\tBetrag\n'.codeUnits) {
        units
          ..add(c & 0xFF)
          ..add(c >> 8);
      }
      final r = decodeText(b(units));
      expect(r.encoding, TextEncoding.utf16le);
      expect(r.text, 'Datum\tBetrag\n');
    });
  });

  group('CSV', () {
    test('quotes, doubled quotes, embedded delimiters and line breaks', () {
      final rows = parseDelimited(
        'a;"b;c";"say ""hi"""\r\n1;"multi\nline";3\n',
        delimiter: ';',
      );
      expect(rows, [
        ['a', 'b;c', 'say "hi"'],
        ['1', 'multi\nline', '3'],
      ]);
    });

    test('CR-only line endings and empty lines keep row numbers', () {
      expect(parseDelimited('a,b\r\rc,d', delimiter: ','), [
        ['a', 'b'],
        <String>[],
        ['c', 'd'],
      ]);
      expect(detectLineEnding('a\r\nb\r\n'), LineEnding.crlf);
      expect(detectLineEnding('a\nb\n'), LineEnding.lf);
      expect(detectLineEnding('a\rb\r'), LineEnding.cr);
    });

    test('delimiter detection, also with a bank preamble', () {
      expect(detectDelimiter('a,b,c\n1,2,3\n4,5,6'), ',');
      expect(detectDelimiter('a;b;c\n1,5;2;3\n4;5,25;6'), ';');
      expect(detectDelimiter('a\tb\n1\t2'), '\t');
      expect(detectDelimiter('a|b|c\n1|2|3'), '|');
      expect(
        detectDelimiter(
          '"Konto";"DE12"\n"Zeitraum: 1.1.-31.1."\n\n'
          '"Datum";"Text";"Betrag";"Saldo"\n'
          '"01.01.";"x, y";"1,00";"2,00"\n"02.01.";"z";"3,00";"5,00"\n',
        ),
        ';',
      );
    });

    test('quote detection', () {
      expect(detectQuote('"a","b"\n"c","d"'), '"');
      expect(detectQuote("'a','b'\n'c','d'\n'e','f'"), "'");
    });

    test('sep= directive and trailing empty fields', () {
      final r = readDelimitedText('sep=|\na|b||\n1|2', sheetName: 'x');
      expect(r.delimiter, '|');
      expect(r.sheet.rows.first, [RawCell.text('a'), RawCell.text('b')]);
    });

    test('clipboard paste from Excel', () {
      final wb = readClipboardText('Datum\tBetrag\n05.01.2023\t-12,50\n');
      expect(wb.format, SourceFormat.clipboard);
      expect(wb.sheets.single.cell(1, 1), RawCell.text('-12,50'));
    });

    test('readCsvBytes reports the dialect', () {
      final bytes = Uint8List.fromList(
        const Windows1252Codec().encode(
          'Datum;Empfänger;Betrag\r\n01.02.2024;Café Süß;-3,50\r\n',
        ),
      );
      final wb = readCsvBytes(bytes, fileName: 'k.csv');
      expect(wb.dialect!.delimiter, ';');
      expect(wb.dialect!.encoding, TextEncoding.windows1252);
      expect(wb.dialect!.lineEnding, LineEnding.crlf);
      expect(wb.sheets.single.cell(1, 1).text, 'Café Süß');
      expect(wb.sheets.single.name, 'k');
    });

    test('forced options', () {
      final bytes = Uint8List.fromList(utf8.encode("a,b\n'x,y',z"));
      final wb = readCsvBytes(
        bytes,
        fileName: 'f.csv',
        options: const CsvReadOptions(delimiter: ',', quote: "'"),
      );
      expect(wb.sheets.single.cell(1, 0).text, 'x,y');
    });
  });

  group('file sniffing', () {
    test('rejects unsupported formats with a reason', () {
      expect(
        () => readImportFile(
          Uint8List.fromList(utf8.encode('%PDF-1.4 ...')),
          fileName: 'a.pdf',
        ),
        throwsA(
          isA<ImportReadException>().having(
            (e) => e.error,
            'error',
            ImportReadError.notASpreadsheet,
          ),
        ),
      );
      expect(
        () => readImportFile(Uint8List(0), fileName: 'a.csv'),
        throwsA(
          isA<ImportReadException>().having(
            (e) => e.error,
            'error',
            ImportReadError.empty,
          ),
        ),
      );
      expect(
        () => readImportFile(
          Uint8List.fromList([1, 2, 3]),
          fileName: 'a.numbers',
        ),
        throwsA(
          isA<ImportReadException>().having(
            (e) => e.error,
            'error',
            ImportReadError.numbers,
          ),
        ),
      );
      expect(
        () => readImportFile(
          Uint8List.fromList(utf8.encode('not really')),
          fileName: 'broken.xlsx',
        ),
        throwsA(
          isA<ImportReadException>().having(
            (e) => e.error,
            'error',
            ImportReadError.corrupt,
          ),
        ),
      );
    });

    test('helpers', () {
      expect(baseName(r'C:\Users\max\Umsätze_2024.csv'), 'Umsätze_2024');
      expect(columnLetter(0), 'A');
      expect(columnLetter(25), 'Z');
      expect(columnLetter(26), 'AA');
      expect(parseCellRef(r'$AB$12'), (11, 27));
      expect(sha256Hex([1, 2, 3]).length, 64);
    });
  });

  group('normalisation and fuzzy matching', () {
    test('folding', () {
      expect(foldText('Müller Straße'), 'mueller strasse');
      expect(headerKey('Betrag (€)'), 'betrag');
      expect(normaliseText('  REWE  Markt GmbH. '), 'rewe markt gmbh');
      expect(normaliseText(null), '');
    });

    test('similarity', () {
      expect(similarity('Lebensmittel', 'lebensmittel'), 1);
      expect(similarity('Lebensmitel', 'Lebensmittel'), greaterThan(0.85));
      expect(similarity('Giro', 'Girokonto'), greaterThanOrEqualTo(0.8));
      expect(similarity('Miete', 'Tanken'), lessThan(0.5));
      expect(levenshtein('kitten', 'sitting'), 3);
      final m = fuzzyMatches('Supermarkt', [
        ('a', 'Lebensmittel › Supermarkt'),
        ('b', 'Freizeit'),
        ('c', 'Supermarket'),
      ]);
      expect(m.map((x) => x.value), containsAll(['a', 'c']));
      expect(m.map((x) => x.value), isNot(contains('b')));
    });
  });

  group('dedupe hash', () {
    test('normalises payee and note, includes date and signed amount', () {
      final a = dedupeHash(
        date: DateTime(2024, 1, 2),
        amountMinor: -480,
        payee: 'Bäckerei  Müller',
        note: 'Brötchen',
      );
      final b = dedupeHash(
        date: DateTime(2024, 1, 2, 13),
        amountMinor: -480,
        payee: 'BÄCKEREI MÜLLER.',
        note: 'brötchen',
      );
      expect(a, b);
      expect(a, hasLength(32));
      expect(
        dedupeHash(
          date: DateTime(2024, 1, 2),
          amountMinor: 480,
          payee: 'Bäckerei Müller',
          note: 'Brötchen',
        ),
        isNot(a),
      );
      expect(
        dedupeHash(
          date: DateTime(2024, 1, 3),
          amountMinor: -480,
          payee: 'Bäckerei Müller',
          note: 'Brötchen',
        ),
        isNot(a),
      );
    });

    test('transfer legs and multiset counting', () {
      final stored = transferHash('out', 'in');
      expect(legHash(stored, -100), 'out');
      expect(legHash(stored, 100), 'in');
      expect(legHash('plain', 5), 'plain');
      final c = HashCounter({'x': 2});
      expect(c.take('x'), isTrue);
      expect(c.take('x'), isTrue);
      expect(c.take('x'), isFalse);
      c.add('y');
      expect(c.contains('y'), isTrue);
    });
  });
}
