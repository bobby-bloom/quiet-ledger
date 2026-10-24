import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/csv/csv_reader.dart';
import 'package:personal_finance/core/csv/csv_writer.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';

String text(List<int> bytes) => utf8.decode(bytes);

void main() {
  group('encodings', () {
    const options = CsvOptions(header: false);

    test('UTF-8 with BOM (default) and without', () {
      final bom = CsvWriter(options).encodeTable(const [], [
        ['Müller'],
      ]);
      expect(bom.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      expect(utf8.decode(bom.sublist(3)), 'Müller\r\n');

      final plain = CsvWriter(options.copyWith(encoding: CsvEncoding.utf8))
          .encodeTable(const [], [
            ['Müller'],
          ]);
      expect(plain.first, 'M'.codeUnitAt(0));
      expect(utf8.decode(plain), 'Müller\r\n');
    });

    test('Windows-1252 encodes umlauts, ß and € as single bytes', () {
      final bytes =
          CsvWriter(options.copyWith(encoding: CsvEncoding.windows1252))
              .encodeTable(const [], [
                ['Größe Ä€'],
              ]);
      expect(bytes, [
        0x47, 0x72, 0xF6, 0xDF, 0x65, 0x20, 0xC4, 0x80, 0x0D, 0x0A, //
      ]);
    });

    test('ISO-8859-15 puts € at 0xA4', () {
      final bytes =
          CsvWriter(options.copyWith(encoding: CsvEncoding.iso8859_15))
              .encodeTable(const [], [
                ['ü€'],
              ]);
      expect(bytes, [0xFC, 0xA4, 0x0D, 0x0A]);
    });

    test('unrepresentable characters become ? instead of failing', () {
      final bytes =
          CsvWriter(options.copyWith(encoding: CsvEncoding.windows1252))
              .encodeTable(const [], [
                ['a😀b'],
              ]);
      expect(latin1.decode(bytes.sublist(0, 1)), 'a');
      expect(bytes.contains(0x3F), isTrue);
    });
  });

  group('quoting', () {
    final w = CsvWriter(const CsvOptions(encoding: CsvEncoding.utf8));

    test('quotes fields with the delimiter, quotes or line breaks', () {
      expect(w.field('plain'), 'plain');
      expect(w.field('a;b'), '"a;b"');
      expect(w.field('a,b'), 'a,b');
      expect(w.field('say "hi"'), '"say ""hi"""');
      expect(w.field('line1\nline2'), '"line1\nline2"');
      expect(w.field('cr\rhere'), '"cr\rhere"');
      expect(w.field(' padded'), '" padded"');
      expect(w.field(null), '');
      expect(w.field(''), '');
    });

    test('comma delimiter quotes commas', () {
      final c = CsvWriter(const CsvOptions(delimiter: CsvDelimiter.comma));
      expect(c.field('a,b'), '"a,b"');
      expect(c.field('a;b'), 'a;b');
    });

    test('tab and pipe', () {
      final t = CsvWriter(const CsvOptions(delimiter: CsvDelimiter.tab));
      expect(t.line(['a', 'b\tc']), 'a\t"b\tc"');
      expect(t.options.fileExtension, 'tsv');
      final p = CsvWriter(const CsvOptions(delimiter: CsvDelimiter.pipe));
      expect(p.line(['a|b', 'c']), '"a|b"|c');
    });

    test('quoteAll and distinguishNull', () {
      final all = CsvWriter(const CsvOptions(quoteAll: true));
      expect(all.line(['a', 1]), '"a";"1"');
      final dn = CsvWriter(CsvOptions.bundle);
      expect(dn.line([null, '', 'x']), ',"",x');
    });

    test('output parses back to the same cells', () {
      final rows = [
        ['h1', 'h2', 'h3'],
        ['a;b', 'quote "q"', 'multi\r\nline'],
        ['', ' lead', 'trail '],
      ];
      final out = w.encodeRowsToString(rows);
      expect(parseCsv(out, delimiter: ';'), rows);
    });
  });

  group('values', () {
    test('decimal separators', () {
      String fmt(DecimalSeparator d, {String locale = 'en_US'}) =>
          CsvWriter(CsvOptions(decimalSeparator: d, locale: locale))
              .formatValue(const CsvAmount(-123456));
      expect(fmt(DecimalSeparator.point), '-1234.56');
      expect(fmt(DecimalSeparator.comma), '-1234,56');
      expect(fmt(DecimalSeparator.locale, locale: 'de_DE'), '-1234,56');
      expect(fmt(DecimalSeparator.locale), '-1234.56');

      final de = CsvWriter(
        const CsvOptions(decimalSeparator: DecimalSeparator.comma),
      );
      expect(de.formatValue(1.5), '1,5');
      expect(de.formatValue(Decimal.parse('0.25')), '0,25');
      expect(de.formatValue(42), '42');
    });

    test('amounts', () {
      expect(const CsvAmount(5).format('.'), '0.05');
      expect(const CsvAmount(-5).format(','), '-0,05');
      expect(const CsvAmount(0).format('.'), '0.00');
      expect(const CsvAmount(100000).format('.'), '1000.00');
      expect(const CsvAmount(1234, scale: 0).format('.'), '1234');
    });

    test('dates, lists, bools', () {
      final w = CsvWriter(const CsvOptions(dateFormat: 'dd.MM.yyyy'));
      expect(w.formatValue(DateTime(2026, 3, 7)), '07.03.2026');
      expect(
        w.formatValue(CsvDateTime(DateTime(2026, 3, 7, 9, 5, 2))),
        '07.03.2026 09:05:02',
      );
      expect(w.formatValue(['a', 'b']), 'a, b');
      expect(w.formatValue(true), 'true');
    });

    test('a delimiter equal to the decimal separator gets quoted', () {
      final w = CsvWriter(
        const CsvOptions(
          delimiter: CsvDelimiter.comma,
          decimalSeparator: DecimalSeparator.comma,
        ),
      );
      expect(w.field(const CsvAmount(150)), '"1,50"');
    });
  });

  group('columns', () {
    const cols = [
      CsvColumn<Map<String, Object?>>('a', 'A', _a),
      CsvColumn<Map<String, Object?>>('b', 'B', _b),
      CsvColumn<Map<String, Object?>>('c', 'C', _c),
    ];
    final rows = [
      {'a': 1, 'b': 'x', 'c': null},
    ];

    test('all columns with header by default', () {
      final w = CsvWriter(const CsvOptions(encoding: CsvEncoding.utf8));
      expect(text(w.encode(cols, rows)), 'A;B;C\r\n1;x;\r\n');
    });

    test('selection and order, no header', () {
      final w = CsvWriter(
        const CsvOptions(
          encoding: CsvEncoding.utf8,
          header: false,
          columns: ['c', 'a', 'unknown'],
        ),
      );
      expect(text(w.encode(cols, rows)), ';1\r\n');
    });
  });

  group('options', () {
    test('from settings', () {
      final s = SettingsSnapshot({
        'global|${ImportExportSettings.csvDelimiter.key}': 'tab',
        'global|${ImportExportSettings.csvEncoding.key}': 'windows1252',
        'global|${ImportExportSettings.csvDateFormat.key}': 'dd.MM.yyyy',
        'global|${ImportExportSettings.csvDecimalSeparator.key}': 'locale',
      });
      final o = CsvOptions.fromSettings(s, locale: 'de_DE');
      expect(o.delimiter, CsvDelimiter.tab);
      expect(o.encoding, CsvEncoding.windows1252);
      expect(o.dateFormat, 'dd.MM.yyyy');
      expect(o.decimalChar, ',');

      final d = CsvOptions.fromSettings(const SettingsSnapshot.empty());
      expect(d.delimiter, CsvDelimiter.semicolon);
      expect(d.encoding, CsvEncoding.utf8Bom);
      expect(d.decimalChar, '.');
    });

    test('JSON round trip', () {
      const o = CsvOptions(
        delimiter: CsvDelimiter.pipe,
        encoding: CsvEncoding.iso8859_15,
        dateFormat: 'MM/dd/yyyy',
        decimalSeparator: DecimalSeparator.comma,
        header: false,
        columns: ['b', 'a'],
      );
      expect(CsvOptions.fromJson(o.toJson()), o);
      expect(
        CsvOptions.fromJson(const {'delimiter': 'bogus'}).delimiter,
        CsvDelimiter.semicolon,
      );
    });
  });
}

Object? _a(Map<String, Object?> r) => r['a'];
Object? _b(Map<String, Object?> r) => r['b'];
Object? _c(Map<String, Object?> r) => r['c'];
