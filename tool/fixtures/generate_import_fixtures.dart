// Generates the import fixture library in test/fixtures/import/.
//
//   dart run tool/fixtures/generate_import_fixtures.dart
//
// The files are checked in; re-run only when the fixtures change (tests
// assert exact values from them). Everything is deterministic.
//
// Fixtures (a fictional German household, Max Mustermann):
// * haushaltsbuch.xlsx      Girokonto log, sheets "2023" and "2024": title
//                           rows, merged title, header in row 4, signed
//                           amounts, real date cells, "A > B" categories,
//                           running balance as formulas with cached values,
//                           "Summe <Monat>" subtotal rows, "Übertrag" row,
//                           a "TOTAL Tankstelle" payee.
// * sparkonto_sh.xlsx       Sparkonto bank export: preamble rows, header in
//                           row 5, text dates, amount + S/H column, Saldo;
//                           plus an "Info" sheet without data. Transfers
//                           with the Girokonto (±200 monthly, −500 once).
// * budget_soll_haben.xlsx  Two-row merged header ("Betrag" over
//                           "Ausgabe | Einnahme"), Excel serial numbers as
//                           dates, account column, category + subcategory,
//                           tags, receipt column, a text amount, two broken
//                           cells, a "Gesamt" row.
// * umsaetze_win1252.csv    Windows-1252, ';', CRLF, bank preamble, umlauts,
//                           quoted ';', 1.234,56, newest first with Saldo.
// * statement_en.csv        UTF-8 with BOM, ',', MM/dd/yyyy, "1,234.56",
//                           negatives in parentheses, "Food:Groceries",
//                           running Balance.
// * kasse_latin9.tsv        ISO-8859-15 (with €), tab separated, dd.MM.yy,
//                           amount + Einnahme/Ausgabe column.
// * kalender.ods            Minimal OpenDocument file (must be rejected
//                           with a "re-save as xlsx" message).
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:enough_convert/latin.dart';
import 'package:enough_convert/windows.dart';
import 'package:excel_plus/excel_plus.dart';

const outDir = 'test/fixtures/import';

const monthsDe = [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
];

class Entry {
  Entry(this.date, this.payee, this.note, this.category, this.cents);

  final DateTime date;
  final String payee;
  final String note;
  final String category;
  final int cents;
}

/// Girokonto entries of one month (m = 1..12).
List<Entry> giroMonth(int year, int m) {
  final k = (year - 2023) * 12 + m; // 1.. running month number
  final name = monthsDe[m - 1];
  final e = <Entry>[
    Entry(
      DateTime(year, m),
      'Arbeitgeber GmbH',
      'Gehalt $name',
      'Einkommen > Gehalt',
      325000,
    ),
    Entry(
      DateTime(year, m),
      'Hausverwaltung Schmidt',
      'Miete $name',
      'Wohnen > Miete',
      -98000,
    ),
    Entry(
      DateTime(year, m, 3),
      'Stadtwerke',
      'Abschlag Strom',
      'Wohnen > Nebenkosten',
      -6500,
    ),
    Entry(
      DateTime(year, m, 5),
      'REWE Markt',
      'Einkauf',
      'Lebensmittel > Supermarkt',
      -(4567 + k * 111),
    ),
    Entry(
      DateTime(year, m, 8),
      'Eigenes Sparkonto',
      'Umbuchung Sparkonto',
      'Umbuchung',
      -20000,
    ),
    Entry(
      DateTime(year, m, 12),
      'Aral Tankstelle',
      'Tanken',
      'Mobilität > Kraftstoff',
      -(5840 + k * 73),
    ),
    Entry(
      DateTime(year, m, 15),
      'Trattoria Da Mario',
      'Abendessen',
      'Freizeit > Restaurant',
      -(3250 + (k % 3) * 425),
    ),
    Entry(
      DateTime(year, m, 20),
      'Bäckerei Müller',
      'Brötchen',
      'Lebensmittel > Bäckerei',
      -890,
    ),
    Entry(
      DateTime(year, m, 25),
      'Telekom',
      'Mobilfunk',
      'Kommunikation > Handy',
      -1999,
    ),
  ];
  if (year == 2023 && m == 8) {
    e.add(
      Entry(
        DateTime(2023, 8, 17),
        'Reisebüro Sonnenschein',
        'Urlaub Italien',
        'Freizeit > Urlaub',
        -124900,
      ),
    );
  }
  if (year == 2023 && m == 11) {
    e.add(
      Entry(
        DateTime(2023, 11, 28),
        'Arbeitgeber GmbH',
        'Weihnachtsgeld',
        'Einkommen > Gehalt',
        150000,
      ),
    );
  }
  if (year == 2024 && m == 3) {
    e.add(
      Entry(
        DateTime(2024, 3, 8),
        'Eigenes Sparkonto',
        'Umbuchung vom Sparkonto',
        'Umbuchung',
        50000,
      ),
    );
  }
  if (year == 2024 && m == 6) {
    e.add(
      Entry(
        DateTime(2024, 6, 22),
        'TOTAL Tankstelle',
        'Tanken',
        'Mobilität > Kraftstoff',
        -6120,
      ),
    );
  }
  e.sort((a, b) => a.date.compareTo(b.date));
  return e;
}

const giroOpening = 123456;
const sparOpening = 500000;

double eur(int cents) => cents / 100;

String fmtDe(int cents) {
  final neg = cents < 0;
  final abs = cents.abs();
  final intPart = (abs ~/ 100).toString();
  final sb = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) sb.write('.');
    sb.write(intPart[i]);
  }
  return '${neg ? '-' : ''}$sb,${(abs % 100).toString().padLeft(2, '0')}';
}

String fmtEn(int cents, {bool parens = false}) {
  final neg = cents < 0;
  final abs = cents.abs();
  final intPart = (abs ~/ 100).toString();
  final sb = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) sb.write(',');
    sb.write(intPart[i]);
  }
  final s = '$sb.${(abs % 100).toString().padLeft(2, '0')}';
  if (!neg) return s;
  return parens ? '($s)' : '-$s';
}

String two(int v) => v.toString().padLeft(2, '0');
String dmy(DateTime d) => '${two(d.day)}.${two(d.month)}.${d.year}';

CellIndex at(int col, int row) =>
    CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row);

void main() {
  Directory(outDir).createSync(recursive: true);
  final giroClosing = writeHaushaltsbuch();
  final sparClosing = writeSparkonto();
  writeBudget();
  final csvClosing = writeWin1252Csv();
  final enClosing = writeEnglishCsv();
  writeLatin9Tsv();
  writeOds();
  print('Girokonto closing: ${fmtDe(giroClosing)}');
  print('Sparkonto closing: ${fmtDe(sparClosing)}');
  print('win1252 CSV closing: ${fmtDe(csvClosing)}');
  print('English CSV closing: ${fmtEn(enClosing)}');
}

/// Returns the closing balance in cents.
int writeHaushaltsbuch() {
  final excel = Excel.createExcel();
  var balance = giroOpening;
  for (final (year, months) in [(2023, 12), (2024, 6)]) {
    final s = excel['$year'];
    s.merge(
      at(0, 0),
      at(6, 0),
      customValue: TextCellValue('Haushaltsbuch $year'),
    );
    s.updateCell(
      at(0, 1),
      TextCellValue('Girokonto Sparkasse – alle Beträge in EUR'),
    );
    const headers = [
      'Datum',
      'Empfänger',
      'Verwendungszweck',
      'Kategorie',
      'Betrag',
      'Kontostand',
      'Beleg-Nr.',
    ];
    for (var c = 0; c < headers.length; c++) {
      s.updateCell(at(c, 3), TextCellValue(headers[c]));
    }
    var r = 4;
    int? prevBalanceRow;
    if (year == 2024) {
      s.updateCell(at(1, r), TextCellValue('Übertrag aus 2023'));
      s.updateCell(at(5, r), DoubleCellValue(eur(balance)));
      prevBalanceRow = r;
      r++;
    }
    var receipt = year == 2023 ? 1 : 500;
    for (var m = 1; m <= months; m++) {
      final first = r;
      for (final e in giroMonth(year, m)) {
        balance += e.cents;
        s.updateCell(
          at(0, r),
          DateCellValue(
            year: e.date.year,
            month: e.date.month,
            day: e.date.day,
          ),
        );
        s.updateCell(at(1, r), TextCellValue(e.payee));
        s.updateCell(at(2, r), TextCellValue(e.note));
        s.updateCell(at(3, r), TextCellValue(e.category));
        s.updateCell(at(4, r), DoubleCellValue(eur(e.cents)));
        if (prevBalanceRow == null) {
          s.updateCell(at(5, r), DoubleCellValue(eur(balance)));
        } else {
          s.updateCell(
            at(5, r),
            FormulaCellValue(
              'F${prevBalanceRow + 1}+E${r + 1}',
              cachedValue: eur(balance).toString(),
            ),
          );
        }
        if (e.payee.contains('REWE') || e.payee.contains('Aral')) {
          s.updateCell(
            at(6, r),
            TextCellValue('R-${receipt.toString().padLeft(4, '0')}'),
          );
          receipt++;
        }
        prevBalanceRow = r;
        r++;
      }
      final sum = giroMonth(year, m).fold<int>(0, (a, e) => a + e.cents);
      s.updateCell(at(0, r), TextCellValue('Summe ${monthsDe[m - 1]}'));
      s.updateCell(
        at(4, r),
        FormulaCellValue(
          'SUM(E${first + 1}:E$r)',
          cachedValue: eur(sum).toString(),
        ),
      );
      r += 2; // blank row after each month
    }
  }
  excel.delete('Sheet1');
  File('$outDir/haushaltsbuch.xlsx').writeAsBytesSync(excel.save()!);
  return balance;
}

int writeSparkonto() {
  final excel = Excel.createExcel();
  final s = excel['Sparkonto'];
  s.updateCell(at(0, 0), TextCellValue('Kontoauszug Sparkonto'));
  s.updateCell(at(0, 1), TextCellValue('IBAN: DE98 7654 3210 0000 1111 22'));
  s.updateCell(at(0, 2), TextCellValue('Zeitraum: 01.01.2023 – 30.06.2024'));
  const headers = [
    'Buchungstag',
    'Valuta',
    'Buchungstext',
    'Auftraggeber/Empfänger',
    'Umsatz',
    'S/H',
    'Saldo',
  ];
  for (var c = 0; c < headers.length; c++) {
    s.updateCell(at(c, 4), TextCellValue(headers[c]));
  }
  final rows = <(DateTime, String, String, int)>[];
  for (final (year, months) in [(2023, 12), (2024, 6)]) {
    for (var m = 1; m <= months; m++) {
      rows.add((
        DateTime(year, m, 9),
        'Umbuchung',
        'Girokonto Max Mustermann',
        20000,
      ));
      if (year == 2024 && m == 3) {
        rows.add((
          DateTime(2024, 3, 8),
          'Umbuchung',
          'Girokonto Max Mustermann',
          -50000,
        ));
      }
    }
    if (year == 2023) {
      rows.add((DateTime(2023, 12, 31), 'Zinsen', 'Sparkasse', 3745));
    }
  }
  rows.sort((a, b) => a.$1.compareTo(b.$1));
  var balance = sparOpening;
  var r = 5;
  for (final (date, text, payee, cents) in rows) {
    balance += cents;
    s.updateCell(at(0, r), TextCellValue(dmy(date)));
    s.updateCell(at(1, r), TextCellValue(dmy(date)));
    s.updateCell(at(2, r), TextCellValue(text));
    s.updateCell(at(3, r), TextCellValue(payee));
    s.updateCell(at(4, r), DoubleCellValue(eur(cents.abs())));
    s.updateCell(at(5, r), TextCellValue(cents < 0 ? 'S' : 'H'));
    s.updateCell(at(6, r), DoubleCellValue(eur(balance)));
    r++;
  }
  final info = excel['Info'];
  info.updateCell(at(0, 0), TextCellValue('Exportiert am 01.07.2024'));
  info.updateCell(at(0, 1), TextCellValue('Alle Angaben ohne Gewähr'));
  excel.delete('Sheet1');
  File('$outDir/sparkonto_sh.xlsx').writeAsBytesSync(excel.save()!);
  return balance;
}

void writeBudget() {
  final excel = Excel.createExcel();
  final s = excel['Budget'];
  // Two-row header: "Betrag" merged over "Ausgabe | Einnahme"; the other
  // labels are merged vertically over both rows.
  const top = [
    'Datum',
    'Beschreibung',
    'Kategorie',
    'Unterkategorie',
    'Betrag',
    '',
    'Konto',
    'Tags',
    'Beleg',
  ];
  for (var c = 0; c < top.length; c++) {
    if (top[c].isEmpty) continue;
    if (c == 4) {
      s.merge(at(4, 0), at(5, 0), customValue: TextCellValue('Betrag'));
    } else {
      s.merge(at(c, 0), at(c, 1), customValue: TextCellValue(top[c]));
    }
  }
  s.updateCell(at(4, 1), TextCellValue('Ausgabe'));
  s.updateCell(at(5, 1), TextCellValue('Einnahme'));
  // (serial, description, category, sub, out, in, account, tags, receipt)
  final rows = <List<Object?>>[
    [
      45293,
      'Wocheneinkauf',
      'Lebensmittel',
      'Supermarkt',
      54.37,
      null,
      'Girokonto',
      'familie',
      'B-001',
    ],
    [
      45294,
      'Kaffee to go',
      'Freizeit',
      'Café',
      3.2,
      null,
      'Bargeld',
      null,
      null,
    ],
    [
      45296,
      'Erstattung Krankenkasse',
      'Gesundheit',
      'Arzt',
      null,
      85.0,
      'Girokonto',
      null,
      'B-002',
    ],
    [
      45300,
      'Kino',
      'Freizeit',
      'Kultur',
      '24,00',
      null,
      'Kreditkarte',
      'familie, wochenende',
      null,
    ],
    [
      45303,
      'Hotel Gardasee',
      'Urlaub',
      'Unterkunft',
      412.8,
      null,
      'Kreditkarte',
      'urlaub, familie',
      'B-003',
    ],
    [45304, 'Geldautomat', 'Bargeld', '', null, 100.0, 'Bargeld', null, null],
    [
      45307,
      'Drogerie',
      'Haushalt',
      'Drogerie',
      '41,2O',
      null,
      'Girokonto',
      null,
      null,
    ],
    [
      '31.09.2024',
      'Buchhandlung',
      'Freizeit',
      'Bücher',
      18.9,
      null,
      'Girokonto',
      null,
      null,
    ],
    [
      45310,
      'Gehalt',
      'Einkommen',
      'Gehalt',
      null,
      3250.0,
      'Girokonto',
      null,
      null,
    ],
    [
      45312,
      'Wochenmarkt',
      'Lebensmittel',
      'Markt',
      23.5,
      null,
      'Bargeld',
      'familie',
      null,
    ],
  ];
  var r = 2;
  for (final row in rows) {
    for (var c = 0; c < row.length; c++) {
      final v = row[c];
      if (v == null || v == '') continue;
      final cell = switch (v) {
        final int i => IntCellValue(i),
        final double d => DoubleCellValue(d),
        _ => TextCellValue('$v'),
      };
      s.updateCell(at(c, r), cell);
    }
    r++;
  }
  s.updateCell(at(0, r), TextCellValue('Gesamt'));
  s.updateCell(
    at(4, r),
    FormulaCellValue('SUM(E3:E$r)', cachedValue: '557.57'),
  );
  s.updateCell(at(5, r), FormulaCellValue('SUM(F3:F$r)', cachedValue: '3435'));
  excel.delete('Sheet1');
  File('$outDir/budget_soll_haben.xlsx').writeAsBytesSync(excel.save()!);
}

int writeWin1252Csv() {
  // Oldest first here, written newest first below.
  final rows = <(DateTime, String, String, int)>[
    (DateTime(2024, 1, 2), 'Bäckerei Müller', 'Brötchen; Kaffee', -480),
    (DateTime(2024, 1, 3), 'Arbeitgeber GmbH', 'Gehalt Januar', 325000),
    (DateTime(2024, 1, 4), 'Hausverwaltung Schmidt', 'Miete Januar', -98000),
    (DateTime(2024, 1, 9), 'Größenwahn Möbel', 'Regal "Ivar"', -123456),
    (DateTime(2024, 1, 15), 'Straßenbahn Köln', 'Monatskarte', -5890),
    (DateTime(2024, 1, 22), 'Café Süß', 'Frühstück', -1275),
    (DateTime(2024, 1, 29), 'Rückerstattung Amazon', 'Gutschrift', 2999),
    (DateTime(2024, 2), 'Arbeitgeber GmbH', 'Gehalt Februar', 325000),
  ];
  const opening = 200000;
  final balances = <int>[];
  var b = opening;
  for (final r in rows) {
    b += r.$4;
    balances.add(b);
  }
  final sb = StringBuffer()
    ..write('"Umsätze Girokonto";"DE12 3456 7890 1234 5678 90"\r\n')
    ..write('"Zeitraum: 01.01.2024 - 31.01.2024";\r\n')
    ..write('\r\n')
    ..write(
      '"Buchungstag";"Valuta";"Auftraggeber/Empfänger";"Verwendungszweck";"Betrag (EUR)";"Saldo (EUR)"\r\n',
    );
  for (var i = rows.length - 1; i >= 0; i--) {
    final (d, payee, note, cents) = rows[i];
    final quotedNote = note.replaceAll('"', '""');
    sb.write(
      '"${dmy(d)}";"${dmy(d)}";"$payee";"$quotedNote";"${fmtDe(cents)}";"${fmtDe(balances[i])}"\r\n',
    );
  }
  File('$outDir/umsaetze_win1252.csv')
      .writeAsBytesSync(const Windows1252Codec().encode(sb.toString()));
  return b;
}

int writeEnglishCsv() {
  final rows = <(DateTime, String, String, int)>[
    (DateTime(2024, 3), 'ACME Corp', 'Income:Salary', 412550),
    (DateTime(2024, 3, 2), 'Whole Foods', 'Food:Groceries', -8734),
    (DateTime(2024, 3, 5), 'Landlord LLC', 'Housing:Rent', -145000),
    (DateTime(2024, 3, 9), 'Shell', 'Transport:Fuel', -4500),
    (DateTime(2024, 3, 13), 'Netflix', 'Entertainment:Streaming', -1599),
    (DateTime(2024, 3, 21), 'Whole Foods', 'Food:Groceries', -12010),
    (DateTime(2024, 3, 28), 'Refund Store', 'Shopping', 2500),
  ];
  var b = 100000;
  final sb = StringBuffer('Date,Description,Category,Amount,Balance\n');
  for (final (d, payee, cat, cents) in rows) {
    b += cents;
    final date = '${two(d.month)}/${two(d.day)}/${d.year}';
    sb.write(
      '$date,"$payee",$cat,"${fmtEn(cents, parens: true)}","${fmtEn(b)}"\n',
    );
  }
  File('$outDir/statement_en.csv')
      .writeAsBytesSync([0xEF, 0xBB, 0xBF, ...utf8.encode(sb.toString())]);
  return b;
}

void writeLatin9Tsv() {
  final rows = <(DateTime, String, String, int)>[
    (DateTime(2024, 5, 2), 'Wochenmarkt', 'Ausgabe', 1250),
    (DateTime(2024, 5, 3), 'Taschengeld', 'Einnahme', 5000),
    (DateTime(2024, 5, 6), 'Eisdiele', 'Ausgabe', 640),
    (DateTime(2024, 5, 11), 'Flohmarkt Verkauf', 'Einnahme', 2300),
    (DateTime(2024, 5, 18), 'Bäcker', 'Ausgabe', 395),
  ];
  final sb = StringBuffer('Datum\tWas\tTyp\tBetrag\n');
  for (final (d, what, type, cents) in rows) {
    final date = '${two(d.day)}.${two(d.month)}.${two(d.year % 100)}';
    sb.write('$date\t$what\t$type\t${fmtDe(cents)} €\n');
  }
  File('$outDir/kasse_latin9.tsv')
      .writeAsBytesSync(const Latin15Codec().encode(sb.toString()));
}

void writeOds() {
  final archive = Archive()
    ..addFile(
      ArchiveFile.string(
        'mimetype',
        'application/vnd.oasis.opendocument.spreadsheet',
      ),
    )
    ..addFile(
      ArchiveFile.string(
        'content.xml',
        '<?xml version="1.0"?><office:document-content/>',
      ),
    );
  File('$outDir/kalender.ods').writeAsBytesSync(ZipEncoder().encode(archive));
}
