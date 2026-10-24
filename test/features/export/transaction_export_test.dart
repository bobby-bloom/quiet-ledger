import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/csv/csv_reader.dart';
import 'package:personal_finance/core/csv/csv_writer.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/export/data/transaction_export.dart';
import 'package:personal_finance/features/export/domain/export_period.dart';
import 'package:personal_finance/features/export/domain/txn_export.dart';

import '../../helpers/test_app.dart';
import 'export_fixtures.dart';

const _utf8Comma = CsvOptions(
  delimiter: CsvDelimiter.comma,
  encoding: CsvEncoding.utf8,
  decimalSeparator: DecimalSeparator.point,
);

void main() {
  late AppDatabase db;
  late Fixture f;

  setUp(() async {
    db = newTestDb();
    f = await seed(db);
  });

  tearDown(() => db.close());

  Future<List<Map<String, String?>>> exportFlat({
    TxnExportQuery query = const TxnExportQuery(),
    CsvOptions options = _utf8Comma,
  }) async {
    final file = await exportTransactions(
      db,
      query: query,
      options: options,
      labels: TxnExportLabels.raw(),
      now: DateTime(2026, 4),
    );
    expect(file.fileName, 'transactions-2026-04-01.csv');
    final rows = parseCsv(utf8.decode(file.bytes));
    final header = rows.first;
    return [
      for (final r in rows.skip(1))
        {for (var i = 0; i < header.length; i++) header[i]!: r[i]},
    ];
  }

  test('columns for a normal expense', () async {
    final rows = await exportFlat();
    final e = rows.firstWhere((r) => r['id'] == f.expense);
    expect(e['date'], '2026-03-05');
    expect(e['valueDate'], '2026-03-06');
    expect(e['account'], 'Girokonto');
    expect(e['type'], 'expense');
    expect(e['amount'], '-25.50');
    expect(e['currency'], 'EUR');
    expect(e['payee'], 'Bäckerei "Korn"; Filiale');
    expect(e['note'], 'Zeile 1\nZeile 2');
    expect(e['category'], 'Essen > Lebensmittel');
    expect(e['split'], '');
    expect(e['tags'], 'Arbeit, Urlaub');
    expect(e['status'], 'cleared');
    expect(e['transferAccount'], '');
    expect(e['Beleg'], 'R-1');
    expect(e['Garantie bis'], '2028-03-05');
  });

  test('header order: fixed columns, custom fields, id', () async {
    final file = await exportTransactions(
      db,
      query: const TxnExportQuery(),
      options: _utf8Comma,
      labels: TxnExportLabels.raw(),
    );
    final header = parseCsv(utf8.decode(file.bytes)).first;
    expect(header, [...TxnColumnKeys.fixed, 'Beleg', 'Garantie bis', 'id']);
  });

  test('transfers export both legs with the counter-account', () async {
    final rows = await exportFlat();
    final legs = rows.where((r) => r['type'] == 'transfer').toList();
    expect(legs, hasLength(2));
    final out = legs.firstWhere((r) => r['account'] == 'Girokonto');
    final inc = legs.firstWhere((r) => r['account'] == 'Tagesgeld');
    expect(out['amount'], '-500.00');
    expect(out['transferAccount'], 'Tagesgeld');
    expect(inc['amount'], '500.00');
    expect(inc['transferAccount'], 'Girokonto');
    expect(out['category'], '');
  });

  test('splits become one row per line with a marker', () async {
    final rows = await exportFlat();
    final lines = rows.where((r) => r['id'] == f.split).toList();
    expect(lines.map((r) => r['split']), ['1/2', '2/2']);
    expect(lines.map((r) => r['amount']), ['-70.00', '-30.00']);
    expect(lines.map((r) => r['category']), [
      'Essen > Lebensmittel',
      'Haushalt',
    ]);
    // Split note wins, otherwise the transaction note.
    expect(lines.map((r) => r['note']), ['Großeinkauf', 'Putz']);
    expect(lines.every((r) => r['payee'] == 'Kaufhaus'), isTrue);
  });

  test('deleted transactions are excluded; sums are consistent', () async {
    final rows = await exportFlat();
    expect(rows.any((r) => r['payee'] == 'Gelöscht'), isFalse);
    // expense, income, 2 transfer legs, 2 split lines.
    expect(rows, hasLength(6));
    final cents = rows
        .map((r) => (double.parse(r['amount']!) * 100).round())
        .fold(0, (a, b) => a + b);
    expect(cents, -2550 + 300000 - 10000);
  });

  test('rows are ordered by date', () async {
    final rows = await exportFlat();
    final dates = rows.map((r) => r['date']!).toList();
    expect(dates, [...dates]..sort());
  });

  test('filters by period and account', () async {
    final range = exportPeriodRange(
      ExportPeriod.custom,
      DateTime(2026, 4),
      customStart: DateTime(2026, 3, 5),
      customEnd: DateTime(2026, 3, 10),
    );
    final rows = await exportFlat(
      query: TxnExportQuery(
        start: range.start,
        end: range.end,
        accountIds: {f.checking},
      ),
    );
    expect(rows.map((r) => r['id']), [f.expense, f.transfer]);
  });

  test('German options and column selection', () async {
    final file = await exportTransactions(
      db,
      query: const TxnExportQuery(),
      options: const CsvOptions(
        encoding: CsvEncoding.windows1252,
        dateFormat: 'dd.MM.yyyy',
        decimalSeparator: DecimalSeparator.comma,
        columns: ['amount', 'date', 'payee'],
      ),
      labels: TxnExportLabels.raw(),
    );
    final text = latin1.decode(file.bytes);
    final lines = text.split('\r\n');
    expect(lines.first, 'amount;date;payee');
    expect(lines, contains('-25,50;05.03.2026;"Bäckerei ""Korn""; Filiale"'));
  });

  test('one file per account as zip', () async {
    final file = await exportTransactions(
      db,
      query: const TxnExportQuery(),
      options: _utf8Comma,
      labels: TxnExportLabels.raw(),
      layout: TxnExportLayout.perAccount,
      now: DateTime(2026, 4),
    );
    expect(file.fileName, 'transactions-by-account-2026-04-01.zip');
    expect(file.mimeType, 'application/zip');
    final zip = ZipDecoder().decodeBytes(file.bytes);
    expect(zip.files.map((e) => e.name), ['Girokonto.csv', 'Tagesgeld.csv']);
    final saving = parseCsv(utf8.decode(zip.files[1].content));
    expect(saving, hasLength(2)); // header + transfer leg
    expect(file.rowCount, 6);
  });

  test('preview limit', () async {
    final rows = await loadTxnExportRows(db, const TxnExportQuery(limit: 1));
    expect(rows.single.id, f.income);
  });

  test('helpers', () {
    expect(safeFileName('a/b:c*'), 'a_b_c_');
    expect(safeFileName('...'), 'file');
    expect(
      categoryPath('c', {
        'p': (name: 'P', parentId: null),
        'c': (name: 'C', parentId: 'p'),
      }),
      'P > C',
    );
    expect(exportPeriodRange(ExportPeriod.lastMonth, DateTime(2026, 1, 15)), (
      start: DateTime(2025, 12),
      end: DateTime(2026),
    ));
    expect(
      exportPeriodRange(ExportPeriod.last12Months, DateTime(2026, 10, 3)),
      (start: DateTime(2025, 11), end: DateTime(2026, 11)),
    );
  });
}
