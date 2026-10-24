import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/features/import/domain/balance_checker.dart';
import 'package:personal_finance/features/import/domain/header_synonyms.dart';
import 'package:personal_finance/features/import/domain/import_analysis.dart';
import 'package:personal_finance/features/import/domain/import_config.dart';
import 'package:personal_finance/features/import/domain/import_drafts.dart';
import 'package:personal_finance/features/import/domain/mapping_suggester.dart';
import 'package:personal_finance/features/import/domain/raw_sheet.dart';
import 'package:personal_finance/features/import/domain/row_parser.dart';
import 'package:personal_finance/features/import/domain/source_reader.dart';
import 'package:personal_finance/features/import/domain/structure_detector.dart';
import 'package:personal_finance/features/import/domain/transfer_matcher.dart';

/// A sheet from rows of strings ('' = empty).
RawSheet sheet(
  List<List<Object?>> rows, {
  String name = 'S',
  List<MergedRange> merges = const [],
}) => RawSheet(
  name: name,
  merges: merges,
  rows: [
    for (final r in rows)
      [
        for (final v in r)
          switch (v) {
            null => RawCell.empty,
            final DateTime d => RawCell.date(d),
            final num n => RawCell.number('$n'),
            _ => RawCell.text('$v'),
          },
      ],
  ],
);

RawWorkbook wb(
  RawSheet s, {
  SourceFormat format = SourceFormat.xlsx,
  String file = 'f.xlsx',
}) => RawWorkbook(fileName: file, format: format, sheets: [s], fileHash: 'h');

ParsedSheet parse(
  RawSheet s,
  SheetConfig cfg, {
  RowFilterConfig filters = const RowFilterConfig(),
}) => parseSheet(wb(s), s, cfg, filters);

void main() {
  group('header synonyms', () {
    test('DE and EN header names', () {
      final cases = {
        'Datum': ColumnTarget.date,
        'Buchungstag': ColumnTarget.date,
        'Valuta': ColumnTarget.valueDate,
        'Wertstellung': ColumnTarget.valueDate,
        'Betrag (EUR)': ColumnTarget.amount,
        'Umsatz in €': ColumnTarget.amount,
        'Soll': ColumnTarget.debit,
        'Haben': ColumnTarget.credit,
        'Ausgabe': ColumnTarget.debit,
        'Einnahme': ColumnTarget.credit,
        'S/H': ColumnTarget.amountType,
        '+/-': ColumnTarget.amountType,
        'Empfänger': ColumnTarget.payee,
        'Auftraggeber/Empfänger': ColumnTarget.payee,
        'Verwendungszweck': ColumnTarget.note,
        'Verwendungszweck 2': ColumnTarget.note,
        'Kategorie': ColumnTarget.category,
        'Unterkategorie': ColumnTarget.subcategory,
        'Konto': ColumnTarget.account,
        'Saldo': ColumnTarget.balance,
        'Kontostand': ColumnTarget.balance,
        'Tags': ColumnTarget.tags,
        'Status': ColumnTarget.status,
        'Date': ColumnTarget.date,
        'Amount': ColumnTarget.amount,
        'Debit': ColumnTarget.debit,
        'Credit': ColumnTarget.credit,
        'Payee': ColumnTarget.payee,
        'Description': ColumnTarget.note,
        'Balance': ColumnTarget.balance,
        'Währung': ColumnTarget.ignore,
        'Betrag Ausgabe': ColumnTarget.debit,
      };
      for (final e in cases.entries) {
        expect(targetForHeader(e.key)?.$1, e.value, reason: e.key);
      }
      expect(targetForHeader('Lieblingsfarbe'), isNull);
    });
  });

  group('structure detection', () {
    test('header not in row 1, title rows skipped', () {
      final s = sheet([
        ['Haushaltsbuch 2023'],
        ['alle Beträge in EUR'],
        [],
        ['Datum', 'Empfänger', 'Betrag', 'Kontostand'],
        [DateTime(2023), 'REWE', -12.5, 100],
        [DateTime(2023, 1, 2), 'Aral', -40, 60],
      ]);
      expect(
        detectStructure(s),
        const SheetStructure(headerRow: 3, headerRows: 1, firstDataRow: 4),
      );
    });

    test('two-row merged header', () {
      final s = sheet(
        [
          ['Datum', 'Text', 'Betrag', null],
          [null, null, 'Ausgabe', 'Einnahme'],
          [45293, 'Kaffee', 3.2, null],
          [45294, 'Lohn', null, 100],
        ],
        merges: const [
          MergedRange(0, 0, 1, 0),
          MergedRange(0, 1, 1, 1),
          MergedRange(0, 2, 0, 3),
        ],
      );
      final st = detectStructure(s);
      expect(
        st,
        const SheetStructure(headerRow: 0, headerRows: 2, firstDataRow: 2),
      );
      expect(composeHeaders(s, 0, 2), [
        'Datum',
        'Text',
        'Betrag Ausgabe',
        'Betrag Einnahme',
      ]);
    });

    test('group label row above the header', () {
      final s = sheet(
        [
          [null, null, 'Betrag', null],
          ['Datum', 'Text', 'Soll', 'Haben'],
          ['01.01.2024', 'x', '1,00', null],
          ['02.01.2024', 'y', null, '2,00'],
        ],
        merges: const [MergedRange(0, 2, 0, 3)],
      );
      expect(detectStructure(s).headerRow, 0);
      expect(detectStructure(s).headerRows, 2);
    });

    test('no header at all', () {
      final s = sheet([
        [],
        ['05.01.2023', 'REWE', '-12,50'],
        ['06.01.2023', 'Aral', '-40,00'],
      ]);
      expect(
        detectStructure(s),
        const SheetStructure(headerRow: -1, headerRows: 0, firstDataRow: 1),
      );
      final cfg = suggestSheetConfig(wb(s, format: SourceFormat.csv), s);
      expect(cfg.targetOf(0), ColumnTarget.date);
      expect(cfg.targetOf(1), ColumnTarget.payee);
      expect(cfg.targetOf(2), ColumnTarget.amount);
    });

    test('data-like cells', () {
      expect(isDataLike(RawCell.text('1.234,56')), isTrue);
      expect(isDataLike(RawCell.text('05.01.2023')), isTrue);
      expect(isDataLike(RawCell.text('Datum')), isFalse);
    });
  });

  group('mapping suggestion', () {
    test('S/H sheet with sheet-name account and value date', () {
      final s = sheet([
        ['Buchungstag', 'Valuta', 'Text', 'Umsatz', 'S/H', 'Saldo'],
        ['01.01.2024', '02.01.2024', 'Zins', '1,00', 'H', '101,00'],
        ['03.01.2024', '03.01.2024', 'Gebühr', '2,00', 'S', '99,00'],
      ], name: 'Sparkonto');
      final cfg = suggestSheetConfig(wb(s), s);
      expect(cfg.amountMode, AmountMode.amountWithType);
      expect(cfg.accountSource, AccountSource.sheetName);
      expect(cfg.fixedAccount, 'Sparkonto');
      expect(
        [for (final c in cfg.columns) c.target],
        [
          ColumnTarget.date,
          ColumnTarget.valueDate,
          ColumnTarget.note,
          ColumnTarget.amount,
          ColumnTarget.amountType,
          ColumnTarget.balance,
        ],
      );
    });

    test('custom field by header name, category separator, tags', () {
      final s = sheet([
        ['Datum', 'Betrag', 'Kategorie', 'Beleg-Nr', 'Tags'],
        ['01.01.2024', '-1,00', 'Food: Groceries', 'R1', 'a; b'],
        ['02.01.2024', '-2,00', 'Food: Bakery', 'R2', 'c'],
      ]);
      final cfg = suggestSheetConfig(
        wb(s),
        s,
        customFields: const [('cf1', 'Beleg-Nr.')],
      );
      expect(cfg.column(3)!.customFieldId, 'cf1');
      expect(cfg.categorySeparator, ':');
      expect(cfg.tagSeparator, ';');
      expect(cfg.year, isNull);
    });

    test('year from sheet name; generic names are not accounts', () {
      expect(isAccountLikeSheetName('Girokonto'), isTrue);
      expect(isAccountLikeSheetName('2023'), isFalse);
      expect(isAccountLikeSheetName('Tabelle1'), isFalse);
      expect(isAccountLikeSheetName('Sheet 2'), isFalse);
      expect(isAccountLikeSheetName('Oktober'), isFalse);
      final s = sheet([
        ['Datum', 'Betrag'],
        ['01.01.', '-1,00'],
      ], name: '2023');
      final cfg = suggestSheetConfig(wb(s, file: 'haushalt_buch.xlsx'), s);
      expect(cfg.year, 2023);
      expect(cfg.accountSource, AccountSource.fixed);
      expect(cfg.fixedAccount, 'Haushalt buch');
    });
  });

  group('row parsing', () {
    const base = SheetConfig(fileName: 'f.xlsx', sheetName: 'S');

    test('signed amounts, subtotal and placeholder rows, year hint', () {
      final s = sheet([
        ['Datum', 'Empfänger', 'Betrag', 'Kategorie'],
        ['05.01.', 'REWE', '-12,50', 'Food > Groceries'],
        ['06.01.', 'TOTAL Tankstelle', '-40,00', 'Car'],
        ['Summe Januar', null, '-52,50'],
        [null, 'Zwischensumme', '-52,50'],
        ['07.01.', 'Nichts', '-'],
        ['08.01.', 'Gutschrift', '(3,00)'],
        [],
        ['31.02.', 'Falsch', '1,00'],
      ]);
      final cfg = base.copyWith(
        firstDataRow: 1,
        year: 2023,
        categorySeparator: '>',
        fixedAccount: 'Giro',
        columns: const [
          ColumnConfig(index: 0, target: ColumnTarget.date),
          ColumnConfig(index: 1, target: ColumnTarget.payee),
          ColumnConfig(index: 2, target: ColumnTarget.amount),
          ColumnConfig(index: 3, target: ColumnTarget.category),
        ],
      );
      final p = parse(s, cfg);
      expect(p.classes, [
        RowClass.header,
        RowClass.data,
        RowClass.data,
        RowClass.subtotal,
        RowClass.subtotal,
        RowClass.noAmount,
        RowClass.data,
        RowClass.empty,
        RowClass.invalid,
      ]);
      final rows = p.validRows;
      expect(rows[0].date, DateTime(2023, 1, 5));
      expect(rows[0].amountMinor, -1250);
      expect(rows[0].categoryPath, ['Food', 'Groceries']);
      expect(rows[0].accountKey, 'giro');
      expect(rows[1].payee, 'TOTAL Tankstelle');
      expect(rows[2].amountMinor, -300);
      expect(p.issues.single.kind, IssueKind.badDate);
      expect(p.issues.single.row, 8);
    });

    test('debit / credit columns', () {
      final s = sheet([
        ['Datum', 'Soll', 'Haben'],
        ['01.01.2024', '12,00', null],
        ['02.01.2024', null, '100,00'],
        ['03.01.2024', '-5,00', null],
        ['04.01.2024', 'abc', null],
      ]);
      final p = parse(
        s,
        base.copyWith(
          firstDataRow: 1,
          fixedAccount: 'a',
          amountMode: AmountMode.debitCredit,
          columns: const [
            ColumnConfig(index: 0, target: ColumnTarget.date),
            ColumnConfig(index: 1, target: ColumnTarget.debit),
            ColumnConfig(index: 2, target: ColumnTarget.credit),
          ],
        ),
      );
      expect(
        [for (final r in p.validRows) r.amountMinor],
        [-1200, 10000, -500],
      );
      expect(p.issues.single.kind, IssueKind.badAmount);
    });

    test('amount + type column variants', () {
      final s = sheet([
        ['Datum', 'Betrag', 'Typ'],
        ['01.01.2024', '12,00', 'S'],
        ['02.01.2024', '10,00', 'Haben'],
        ['03.01.2024', '5,00', 'Ausgabe'],
        ['04.01.2024', '7,00', '+'],
        ['05.01.2024', '9,00', '-'],
        ['06.01.2024', '1,00', 'debit'],
        ['07.01.2024', '1,00', '???'],
      ]);
      final p = parse(
        s,
        base.copyWith(
          firstDataRow: 1,
          fixedAccount: 'a',
          amountMode: AmountMode.amountWithType,
          columns: const [
            ColumnConfig(index: 0, target: ColumnTarget.date),
            ColumnConfig(index: 1, target: ColumnTarget.amount),
            ColumnConfig(index: 2, target: ColumnTarget.amountType),
          ],
        ),
      );
      expect(
        [for (final r in p.validRows) r.amountMinor],
        [-1200, 1000, -500, 700, -900, -100],
      );
      expect(p.issues.single.kind, IssueKind.badType);
    });

    test('invert sign, account column, subcategory, tags, status, custom field, balance', () {
      final s = sheet([
        [
          'Datum',
          'Betrag',
          'Konto',
          'Kat',
          'Unter',
          'Tags',
          'Status',
          'Beleg',
          'Saldo',
        ],
        [
          '01.01.2024',
          '12,00',
          'Bargeld',
          'Freizeit',
          'Kino',
          '#film #familie',
          'offen',
          'B1',
          '88,00',
        ],
        ['02.01.2024', '3,00', '', 'Essen', '', '', 'gebucht', '', 'kaputt'],
      ]);
      final p = parse(
        s,
        base.copyWith(
          firstDataRow: 1,
          fixedAccount: 'Giro',
          invertSign: true,
          accountSource: AccountSource.column,
          tagSeparator: ' ',
          columns: const [
            ColumnConfig(index: 0, target: ColumnTarget.date),
            ColumnConfig(index: 1, target: ColumnTarget.amount),
            ColumnConfig(index: 2, target: ColumnTarget.account),
            ColumnConfig(index: 3, target: ColumnTarget.category),
            ColumnConfig(index: 4, target: ColumnTarget.subcategory),
            ColumnConfig(index: 5, target: ColumnTarget.tags),
            ColumnConfig(index: 6, target: ColumnTarget.status),
            ColumnConfig(
              index: 7,
              target: ColumnTarget.customField,
              customFieldId: 'cf',
            ),
            ColumnConfig(index: 8, target: ColumnTarget.balance),
          ],
        ),
      );
      final r = p.validRows;
      expect(r[0].amountMinor, -1200);
      expect(r[0].accountLabel, 'Bargeld');
      expect(r[1].accountLabel, 'Giro');
      expect(r[0].categoryPath, ['Freizeit', 'Kino']);
      expect(r[1].categoryPath, ['Essen']);
      expect(r[0].tags, ['film', 'familie']);
      expect(r[0].status, TxnStatus.pending);
      expect(r[1].status, TxnStatus.cleared);
      expect(r[0].customFields, {'cf': 'B1'});
      expect(r[0].balanceMinor, 8800);
      expect(r[1].balanceMinor, isNull);
      expect(p.issues.single.kind, IssueKind.badBalance);
    });

    test('rows without date are reported when the filter is off', () {
      final s = sheet([
        ['Datum', 'Betrag'],
        [null, '1,00'],
      ]);
      final cfg = base.copyWith(
        firstDataRow: 1,
        fixedAccount: 'a',
        columns: const [
          ColumnConfig(index: 0, target: ColumnTarget.date),
          ColumnConfig(index: 1, target: ColumnTarget.amount),
        ],
      );
      expect(parse(s, cfg).classes[1], RowClass.noDate);
      final p = parse(
        s,
        cfg,
        filters: const RowFilterConfig(skipWithoutDate: false),
      );
      expect(p.classes[1], RowClass.invalid);
      expect(p.issues.single.kind, IssueKind.missingDate);
    });

    test('custom skip pattern (regex) and repeated headers', () {
      final s = sheet([
        ['Datum', 'Betrag'],
        ['01.01.2024', '1,00'],
        ['Datum', 'Betrag'],
        ['Monatsende', '1,00'],
        ['02.01.2024', '2,00'],
      ]);
      final cfg = base.copyWith(
        firstDataRow: 1,
        fixedAccount: 'a',
        columns: const [
          ColumnConfig(index: 0, target: ColumnTarget.date),
          ColumnConfig(index: 1, target: ColumnTarget.amount),
        ],
      );
      final p = parse(
        s,
        cfg,
        filters: const RowFilterConfig(skipPatterns: ['/^monats/']),
      );
      expect(p.classes, [
        RowClass.header,
        RowClass.data,
        RowClass.header,
        RowClass.subtotal,
        RowClass.data,
      ]);
    });

    test('helpers', () {
      expect(splitCategory('A > B > C', '>'), ['A', 'B / C']);
      expect(splitCategory('Food', ''), ['Food']);
      expect(splitTags('a, b, A', ','), ['a', 'b']);
      expect(parseStatus('Vorgemerkt'), TxnStatus.pending);
      expect(parseStatus('geplant'), TxnStatus.planned);
      expect(parseStatus('✓'), TxnStatus.cleared);
      expect(parseStatus('hm'), isNull);
    });
  });

  group('running balance', () {
    BalancePoint p(String r, int a, int? b) =>
        BalancePoint(ref: r, amountMinor: a, balanceMinor: b);

    test('oldest first: opening derived, all match', () {
      final r = checkBalances('g', [
        p('1', 100, 1100),
        p('2', -50, 1050),
        p('3', -25, null),
        p('4', 10, 1035),
      ]);
      expect(r.openingMinor, 1000);
      expect(r.closingMinor, 1035);
      expect(r.computedClosingMinor, 1035);
      expect(r.checked, 3);
      expect(r.ok, isTrue);
      expect(r.descending, isFalse);
    });

    test('newest first (bank export)', () {
      final r = checkBalances('g', [
        p('3', 10, 1060),
        p('2', -50, 1050),
        p('1', 100, 1100),
      ]);
      expect(r.descending, isTrue);
      expect(r.openingMinor, 1000);
      expect(r.closingMinor, 1060);
      expect(r.ok, isTrue);
    });

    test('one wrong row is reported once', () {
      final r = checkBalances('g', [
        p('1', 100, 1100),
        p('2', -50, 1049),
        p('3', -50, 999),
        p('4', 1, 1000),
      ]);
      expect(r.mismatches, hasLength(1));
      expect(r.mismatches.single.ref, '2');
      expect(r.mismatches.single.expectedMinor, 1050);
      expect(r.mismatches.single.differenceMinor, -1);
      expect(r.matched, 3);
    });

    test('balance starts later', () {
      final r = checkBalances('g', [p('1', 100, null), p('2', 50, 1150)]);
      expect(r.openingMinor, 1000);
    });
  });

  group('transfer matching', () {
    TransferCandidate c(
      int i,
      String acc,
      int day,
      int amount, [
      String text = '',
    ]) => TransferCandidate(
      index: i,
      accountKey: acc,
      date: DateTime(2024, 1, day),
      amountMinor: amount,
      text: text,
    );

    test('pairs within the window, closest first, each row once', () {
      final m = matchTransfers([
        c(0, 'giro', 8, -20000, 'Umbuchung'),
        c(1, 'spar', 9, 20000),
        c(2, 'spar', 12, 20000),
        c(3, 'giro', 20, -5000),
        c(4, 'giro', 20, 5000),
        c(5, 'cash', 30, 5000),
      ]);
      expect(m.map((x) => (x.outIndex, x.inIndex)), [(0, 1)]);
      expect(m.single.dayDiff, 1);
      expect(m.single.score, greaterThan(0));
      expect(
        matchTransfers([c(0, 'a', 1, -100), c(1, 'b', 9, 100)], windowDays: 7),
        isEmpty,
      );
      expect(
        matchTransfers([c(0, 'a', 1, -100), c(1, 'b', 8, 100)], windowDays: 7),
        hasLength(1),
      );
    });

    test('text hints win ties', () {
      final m = matchTransfers([
        c(0, 'giro', 5, -100),
        c(1, 'cash', 5, 100, 'Geldautomat'),
        c(2, 'spar', 5, 100, 'Umbuchung'),
      ]);
      expect(m.single.inIndex, 2);
    });
  });

  group('drafts', () {
    test('transfer category to an existing account, custom field values', () {
      final s = sheet([
        ['Datum', 'Betrag', 'Kategorie', 'Beleg'],
        ['01.01.2024', '-100,00', 'Sparen', '12'],
        ['02.01.2024', '50,00', 'Sparen', ''],
        ['03.01.2024', '-5,00', 'Food', 'x'],
      ]);
      final w = wb(s);
      const cfgSheet = SheetConfig(
        fileName: 'f.xlsx',
        sheetName: 'S',
        fixedAccount: 'Giro',
        columns: [
          ColumnConfig(index: 0, target: ColumnTarget.date),
          ColumnConfig(index: 1, target: ColumnTarget.amount),
          ColumnConfig(index: 2, target: ColumnTarget.category),
          ColumnConfig(
            index: 3,
            target: ColumnTarget.customField,
            customFieldId: 'n',
          ),
        ],
      );
      const ctx = ImportContext(
        accounts: [
          ExistingAccount(id: 'g', name: 'Giro'),
          ExistingAccount(id: 's', name: 'Sparbuch'),
        ],
        categories: [ExistingCategory(id: 'food', name: 'Food')],
        customFields: [
          ExistingField(id: 'n', name: 'Beleg', type: CustomFieldType.number),
        ],
      );
      const cfg = ImportConfig(
        sheets: [cfgSheet],
        categories: {'sparen': CategoryTarget.transfer('id:s')},
      );
      final a = analyseImport([w], cfg, ctx);
      expect(a.accountTargets['giro']!.existingId, 'g');
      expect(a.categoryTargets['food']!.existingId, 'food');
      final set = buildImportDrafts(a, cfg, ctx);
      final d = [for (final t in set.txns) t.draft];
      expect(d[0].type, TxnType.transfer);
      expect(
        (d[0].accountId, d[0].transferAccountId, d[0].amountMinor),
        ('g', 's', -10000),
      );
      expect(
        (d[1].accountId, d[1].transferAccountId, d[1].amountMinor),
        ('s', 'g', -5000),
      );
      expect(d[0].customFields, {'n': 12});
      expect(d[2].categoryId, 'food');
      expect(d[2].customFields, {'n': 'x'});
      expect(set.accounts, isEmpty);
      final sum = summariseImport(set, a, ctx);
      expect(sum.transfers, 2);
      expect(sum.accounts.firstWhere((x) => x.accountId == 's').netMinor, 5000);
    });

    test('new categories with hierarchy reuse an existing parent', () {
      final s = sheet([
        ['Datum', 'Betrag', 'Kategorie'],
        ['01.01.2024', '-1,00', 'Food > Snacks'],
        ['02.01.2024', '-1,00', 'Hobby > Bikes'],
      ]);
      const ctx = ImportContext(
        categories: [ExistingCategory(id: 'food', name: 'Food')],
      );
      const cfg = ImportConfig(
        sheets: [
          SheetConfig(
            fileName: 'f.xlsx',
            sheetName: 'S',
            fixedAccount: 'Giro',
            categorySeparator: '>',
            columns: [
              ColumnConfig(index: 0, target: ColumnTarget.date),
              ColumnConfig(index: 1, target: ColumnTarget.amount),
              ColumnConfig(index: 2, target: ColumnTarget.category),
            ],
          ),
        ],
      );
      final a = analyseImport([wb(s)], cfg, ctx);
      final set = buildImportDrafts(a, cfg, ctx);
      expect(
        {for (final c in set.categories) (c.name, c.parentId)},
        {
          ('Snacks', 'food'),
          ('Hobby', null),
          ('Bikes', PendingIds.category('hobby')),
        },
      );
      final names = [for (final c in set.categories) c.name];
      expect(names.indexOf('Hobby'), lessThan(names.indexOf('Bikes')));
      expect(set.accounts.single.name, 'Giro');
    });

    test('custom field conversion', () {
      const date = ExistingField(
        id: 'd',
        name: 'd',
        type: CustomFieldType.date,
      );
      const flag = ExistingField(
        id: 'b',
        name: 'b',
        type: CustomFieldType.boolean,
      );
      const sel = ExistingField(
        id: 's',
        name: 's',
        type: CustomFieldType.select,
        options: ['Rot', 'Grün'],
      );
      const multi = ExistingField(
        id: 'm',
        name: 'm',
        type: CustomFieldType.multiselect,
        options: ['A', 'B'],
      );
      expect(customFieldValue('05.01.2024', date), '2024-01-05');
      expect(customFieldValue('ja', flag), isTrue);
      expect(customFieldValue('nein', flag), isFalse);
      expect(customFieldValue('rot', sel), 'Rot');
      expect(customFieldValue('a; b', multi), ['A', 'B']);
      expect(
        customFieldValue(
          '12,5',
          const ExistingField(id: 'n', name: 'n', type: CustomFieldType.number),
        ),
        12.5,
      );
      expect(customFieldValue('  ', null), isNull);
      expect(customFieldValue('text', null), 'text');
    });
  });

  group('config', () {
    test('JSON round trip keeps every choice', () {
      const cfg = ImportConfig(
        sheets: [
          SheetConfig(
            fileName: 'a.csv',
            sheetName: 'a',
            headerRow: 3,
            headerRows: 2,
            firstDataRow: 5,
            lastDataRow: 99,
            amountMode: AmountMode.amountWithType,
            invertSign: true,
            typeTokens: TypeTokens(negative: ['minus'], positive: ['plus']),
            accountSource: AccountSource.column,
            fixedAccount: 'Giro',
            year: 2023,
            categorySeparator: ':',
            tagSeparator: ';',
            headerSignature: ['datum', 'betrag'],
            columns: [
              ColumnConfig(index: 0, target: ColumnTarget.date),
              ColumnConfig(
                index: 1,
                target: ColumnTarget.customField,
                customFieldId: 'cf',
              ),
            ],
          ),
        ],
        filters: RowFilterConfig(
          skipPatterns: ['X'],
          skipWithoutDate: false,
          skipZeroAmount: false,
        ),
        accounts: {
          'giro': AccountTarget.existing('id1'),
          'spar': AccountTarget.create('Spar', type: AccountType.savings),
        },
        categories: {
          'a': CategoryTarget.existing('c1'),
          'b': CategoryTarget.create(['B', 'C'], kind: CategoryKind.income),
          'c': CategoryTarget.none(),
          'd': CategoryTarget.transfer('spar'),
        },
        transfers: TransferConfig(detect: false, windowDays: 7),
        duplicates: DuplicatePolicy.import,
        incremental: false,
        applyRules: false,
        setOpeningBalances: false,
        csvOptions: {'a.csv': CsvReadOptions(delimiter: ';')},
      );
      final back = ImportConfig.decode(cfg.encode());
      expect(back.encode(), cfg.encode());
      expect(back.sheets.single.column(1)!.customFieldId, 'cf');
      expect(back.accounts['spar']!.type, AccountType.savings);
      expect(
        back.categories['b'],
        const CategoryTarget.create(['B', 'C'], kind: CategoryKind.income),
      );
    });

    test(
      'withTarget keeps unique targets unique and switches the amount mode',
      () {
        const s = SheetConfig(
          fileName: 'f',
          sheetName: 's',
          columns: [ColumnConfig(index: 0, target: ColumnTarget.date)],
        );
        final t = s.withTarget(1, ColumnTarget.date);
        expect(t.targetOf(0), ColumnTarget.ignore);
        expect(t.targetOf(1), ColumnTarget.date);
        expect(
          t.withTarget(2, ColumnTarget.debit).amountMode,
          AmountMode.debitCredit,
        );
        expect(
          t.withTarget(2, ColumnTarget.amountType).amountMode,
          AmountMode.amountWithType,
        );
        final notes = t
            .withTarget(2, ColumnTarget.note)
            .withTarget(3, ColumnTarget.note);
        expect(notes.columnsFor(ColumnTarget.note), hasLength(2));
      },
    );

    test('a profile is reused for a new year sheet with the same columns', () {
      final s2024 = sheet([
        ['Datum', 'Betrag'],
        ['01.01.', '1,00'],
      ], name: '2024');
      final s2025 = sheet([
        ['Datum', 'Betrag'],
        ['01.01.', '1,00'],
      ], name: '2025');
      final first = initialConfig([wb(s2024)]);
      final profile = first.withSheet(
        first.sheets.single.copyWith(fixedAccount: 'Giro', invertSign: true),
      );
      final next = initialConfig([wb(s2025)], profile: profile);
      expect(next.sheets.single.sheetName, '2025');
      expect(next.sheets.single.year, 2025);
      expect(next.sheets.single.fixedAccount, 'Giro');
      expect(next.sheets.single.invertSign, isTrue);
    });
  });
}
