import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/features/import/domain/date_parser.dart';
import 'package:personal_finance/features/import/domain/import_config.dart';
import 'package:personal_finance/features/import/domain/number_parser.dart';
import 'package:personal_finance/features/import/domain/raw_sheet.dart';
import 'package:personal_finance/features/import/domain/structure_detector.dart';
import 'package:personal_finance/features/import/domain/text_normalize.dart';

/// What a sheet row is.
enum RowClass {
  data,

  /// Above the header (titles, bank preamble) or before the first data row.
  title,
  header,
  empty,

  /// Subtotal / sum row matched by a skip pattern.
  subtotal,

  /// No date (skipped by the row filter).
  noDate,

  /// No or zero amount (skipped by the row filter).
  noAmount,

  /// After the configured last data row.
  afterEnd,

  /// A data row with unreadable values; not imported.
  invalid,
}

enum IssueKind {
  badDate,
  missingDate,
  badValueDate,
  badAmount,
  missingAmount,
  badType,
  badBalance,
  badStatus,
  badCustomField,
  missingAccount,

  /// Date outside the year of the sheet (warning only).
  yearMismatch,
}

/// A cell that could not be read (or looks suspicious).
@immutable
class CellIssue {
  const CellIssue(this.row, this.col, this.kind, this.value);

  /// 0-based sheet row / column.
  final int row;
  final int col;
  final IssueKind kind;
  final String value;

  /// Errors make the row invalid; warnings only inform.
  bool get isError => switch (kind) {
    IssueKind.badDate ||
    IssueKind.missingDate ||
    IssueKind.badAmount ||
    IssueKind.missingAmount ||
    IssueKind.badType ||
    IssueKind.missingAccount => true,
    IssueKind.badValueDate ||
    IssueKind.badBalance ||
    IssueKind.badStatus ||
    IssueKind.badCustomField ||
    IssueKind.yearMismatch => false,
  };

  @override
  String toString() => '${columnLetter(col)}${row + 1}: ${kind.name} "$value"';
}

/// One data row read according to the config.
@immutable
class ParsedRow {
  const ParsedRow({
    required this.fileName,
    required this.sheetName,
    required this.row,
    required this.date,
    required this.amountMinor,
    required this.accountKey,
    required this.accountLabel,
    this.valueDate,
    this.payee,
    this.note,
    this.categoryPath = const [],
    this.tags = const [],
    this.status,
    this.customFields = const {},
    this.balanceMinor,
    this.issues = const [],
    String? categoryKeyValue,
  }) : _categoryKey = categoryKeyValue;

  final String fileName;
  final String sheetName;

  /// 0-based sheet row.
  final int row;

  /// Null only for invalid rows.
  final DateTime? date;
  final int? amountMinor;
  final DateTime? valueDate;
  final String? payee;
  final String? note;

  /// One or two levels.
  final List<String> categoryPath;

  /// [valueKey] of the account and its display label.
  final String accountKey;
  final String accountLabel;
  final List<String> tags;
  final TxnStatus? status;

  /// Custom field id → raw text.
  final Map<String, String> customFields;
  final int? balanceMinor;
  final List<CellIssue> issues;

  bool get isValid =>
      date != null && amountMinor != null && !issues.any((i) => i.isError);

  /// Stable reference of the source row: `file|sheet|row` (1-based row).
  String get rowRef => '$fileName|$sheetName|${row + 1}';

  final String? _categoryKey;

  /// [categoryKey] of [categoryPath] (cached).
  String get categoryKeyValue => _categoryKey ?? categoryKey(categoryPath);
}

/// Detected or overridden formats per column.
@immutable
class ResolvedFormats {
  const ResolvedFormats(this.dates, this.numbers);

  final Map<int, DateFormatKind> dates;
  final Map<int, NumberFormatKind> numbers;
}

/// Result of reading one sheet.
@immutable
class ParsedSheet {
  const ParsedSheet({
    required this.config,
    required this.classes,
    required this.rows,
    required this.issues,
    required this.formats,
    required this.headers,
  });

  final SheetConfig config;

  /// Class of every sheet row (index = 0-based row).
  final List<RowClass> classes;

  /// Data rows (valid and invalid) in sheet order.
  final List<ParsedRow> rows;

  /// All issues of the sheet.
  final List<CellIssue> issues;
  final ResolvedFormats formats;

  /// Composed header label per column.
  final List<String> headers;

  int count(RowClass c) => classes.where((x) => x == c).length;

  List<ParsedRow> get validRows => [
    for (final r in rows)
      if (r.isValid) r,
  ];
}

final _whitespace = RegExp(r'\s+');

/// Rows used to detect formats (enough to see every notation in practice).
const _formatSamples = 3000;

const _placeholders = {'-', '–', '—', '/', 'n/a', 'na', '--', '---'};

bool _isPlaceholder(RawCell c) =>
    c.isText && _placeholders.contains(c.text!.trim().toLowerCase());

RawCell _value(RawSheet sheet, int r, int c) {
  final cell = sheet.cell(r, c);
  return _isPlaceholder(cell) ? RawCell.empty : cell;
}

/// Compiles the subtotal patterns: plain words match at the start of a cell
/// (followed by a non-letter or the end), case- and umlaut-insensitive;
/// `/…/` is a regular expression. Plain words are combined into one
/// expression for speed.
List<RegExp> compileSkipPatterns(List<String> patterns) {
  final words = <String>{};
  final custom = <RegExp>[];
  for (final p in patterns) {
    final t = p.trim();
    if (t.isEmpty) continue;
    if (t.length > 2 && t.startsWith('/') && t.endsWith('/')) {
      try {
        custom.add(RegExp(t.substring(1, t.length - 1), caseSensitive: false));
      } on FormatException {
        words.add(RegExp.escape(t));
      }
      continue;
    }
    words
      ..add(RegExp.escape(t))
      ..add(RegExp.escape(foldText(t)));
  }
  return [
    if (words.isNotEmpty)
      RegExp(
        '^\\s*(?:${words.join('|')})(?![a-zA-ZäöüÄÖÜß])',
        caseSensitive: false,
      ),
    ...custom,
  ];
}

/// Status words → status.
TxnStatus? parseStatus(String raw) {
  if (raw.trim() == '✓' || raw.trim() == '✔') return TxnStatus.cleared;
  final k = valueKey(raw);
  if (k.isEmpty) return null;
  const cleared = {
    'cleared',
    'gebucht',
    'erledigt',
    'bezahlt',
    'abgerechnet',
    'ok',
    'x',
    'ja',
    'yes',
    'true',
    'reconciled',
    'r',
    'c',
    'booked',
    'paid',
  };
  const pending = {
    'pending',
    'vorgemerkt',
    'offen',
    'ausstehend',
    'nein',
    'no',
    'false',
    'p',
    'open',
    'unbestaetigt',
    'uncleared',
  };
  const planned = {'planned', 'geplant', 'plan', 'scheduled', 'zukuenftig'};
  if (cleared.contains(k)) return TxnStatus.cleared;
  if (pending.contains(k)) return TxnStatus.pending;
  if (planned.contains(k)) return TxnStatus.planned;
  return null;
}

/// Splits a category cell into a one- or two-level path.
List<String> splitCategory(String raw, String separator) {
  final t = raw.trim();
  if (t.isEmpty) return const [];
  if (separator.isEmpty) return [t];
  final parts = [
    for (final p in t.split(separator))
      if (p.trim().isNotEmpty) p.trim(),
  ];
  if (parts.length <= 1) return parts;
  return [parts.first, parts.sublist(1).join(' / ')];
}

/// Splits a tags cell.
List<String> splitTags(String raw, String separator) {
  final sep = separator.isEmpty ? ',' : separator;
  final parts = sep == ' ' ? raw.split(RegExp(r'\s+')) : raw.split(sep);
  final seen = <String>{};
  return [
    for (final p in parts)
      if (p.trim().replaceFirst(RegExp('^#'), '') case final t
          when t.isNotEmpty && seen.add(t.toLowerCase()))
        t,
  ];
}

/// Reads [sheet] according to [cfg] and [filters].
ParsedSheet parseSheet(
  RawWorkbook workbook,
  RawSheet sheet,
  SheetConfig cfg,
  RowFilterConfig filters,
) {
  final rowCount = sheet.rowCount;
  final classes = List<RowClass>.filled(rowCount, RowClass.empty);
  final patterns = compileSkipPatterns(filters.skipPatterns);
  final headers = composeHeaders(
    sheet,
    cfg.headerRow,
    cfg.headerRows,
    columnCount: sheet.columnCount,
  );
  final headerLower = [for (final h in headers) h.trim().toLowerCase()];
  final dateCol = cfg.columnFor(ColumnTarget.date)?.index;
  final mappedCols = [for (final c in cfg.columns) c.index];

  // Pass 1: structure.
  final candidates = <int>[];
  for (var r = 0; r < rowCount; r++) {
    if (sheet.isRowEmpty(r)) {
      classes[r] = RowClass.empty;
      continue;
    }
    if (cfg.headerRow >= 0 &&
        r >= cfg.headerRow &&
        r < cfg.headerRow + cfg.headerRows) {
      classes[r] = RowClass.header;
      continue;
    }
    if (r < cfg.firstDataRow || (cfg.headerRow >= 0 && r < cfg.headerRow)) {
      classes[r] = RowClass.title;
      continue;
    }
    if (cfg.lastDataRow != null && r > cfg.lastDataRow!) {
      classes[r] = RowClass.afterEnd;
      continue;
    }
    // Header repeated further down (page breaks in exports).
    if (cfg.headerRow >= 0 && mappedCols.isNotEmpty) {
      var same = 0;
      for (final c in mappedCols) {
        final k = headerLower.length > c ? headerLower[c] : '';
        final cell = sheet.cell(r, c);
        if (k.isNotEmpty &&
            cell.isText &&
            cell.text!.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase() ==
                k) {
          same++;
        }
      }
      if (same >= 2 && same >= mappedCols.length * 0.6) {
        classes[r] = RowClass.header;
        continue;
      }
    }
    candidates.add(r);
  }

  // Formats per column (detected from the candidate rows unless set).
  final dateFormats = <int, DateFormatKind>{};
  final numberFormats = <int, NumberFormatKind>{};
  final numberCols = [
    for (final c in cfg.columns)
      if (c.isNumber) c,
  ];
  final allNumberTexts = <String>[];
  final numberTexts = <int, List<String>>{};
  for (final c in numberCols) {
    final texts = <String>[
      for (final r in candidates.take(_formatSamples))
        if (_value(sheet, r, c.index) case final cell when cell.isText)
          cell.text!,
    ];
    numberTexts[c.index] = texts;
    allNumberTexts.addAll(texts);
  }
  final sheetNumberFormat = detectNumberFormat(allNumberTexts);
  for (final c in numberCols) {
    numberFormats[c.index] = c.numberFormat != NumberFormatKind.auto
        ? c.numberFormat
        : detectNumberFormat(
            numberTexts[c.index]!,
            fallback: sheetNumberFormat,
          );
  }
  final monthFirst = sheetNumberFormat == NumberFormatKind.en;
  for (final c in cfg.columns.where((c) => c.isDate)) {
    dateFormats[c.index] = c.dateFormat != DateFormatKind.auto
        ? c.dateFormat
        : detectDateFormat(
            [
              for (final r in candidates.take(_formatSamples))
                _value(sheet, r, c.index),
            ],
            yearHint: cfg.year,
            preferMonthFirst: monthFirst,
          );
  }

  DateTime? readDate(RawCell cell, int col) {
    final kind = dateFormats[col] ?? DateFormatKind.auto;
    final d = parseDateCell(
      cell,
      kind == DateFormatKind.auto ? DateFormatKind.dmy : kind,
      yearHint: cfg.year,
      date1904: workbook.date1904,
    );
    if (d == null && cell.isText && kind == DateFormatKind.excelSerial) {
      // Serial columns sometimes hold a few typed dates.
      return parseDateCell(cell, DateFormatKind.dmy, yearHint: cfg.year) ??
          parseDateCell(cell, DateFormatKind.ymd);
    }
    if (d != null || cell.kind != RawKind.number) return d;
    return parseDateCell(
      cell,
      DateFormatKind.excelSerial,
      date1904: workbook.date1904,
    );
  }

  int? readNumber(RawCell cell, int col) =>
      parseAmountCell(cell, numberFormats[col] ?? sheetNumberFormat);

  // Pass 2: values.
  final keyCache = <String, String>{};
  final rows = <ParsedRow>[];
  final issues = <CellIssue>[];
  final amountCol = cfg.columnFor(ColumnTarget.amount)?.index;
  final debitCol = cfg.columnFor(ColumnTarget.debit)?.index;
  final creditCol = cfg.columnFor(ColumnTarget.credit)?.index;
  final typeCol = cfg.columnFor(ColumnTarget.amountType)?.index;
  final valueDateCol = cfg.columnFor(ColumnTarget.valueDate)?.index;
  final payeeCol = cfg.columnFor(ColumnTarget.payee)?.index;
  final noteCols = [for (final c in cfg.columnsFor(ColumnTarget.note)) c.index];
  final categoryCol = cfg.columnFor(ColumnTarget.category)?.index;
  final subcategoryCol = cfg.columnFor(ColumnTarget.subcategory)?.index;
  final accountCol = cfg.columnFor(ColumnTarget.account)?.index;
  final tagsCol = cfg.columnFor(ColumnTarget.tags)?.index;
  final statusCol = cfg.columnFor(ColumnTarget.status)?.index;
  final balanceCol = cfg.columnFor(ColumnTarget.balance)?.index;
  final fieldCols = cfg.columnsFor(ColumnTarget.customField);

  for (final r in candidates) {
    final rowIssues = <CellIssue>[];

    // Subtotal rows: a skip pattern at the start of a text cell, in a row
    // without a readable date or in the date column itself.
    int? patternCol;
    if (patterns.isNotEmpty) {
      final cells = sheet.rows[r];
      for (var c = 0; c < cells.length && patternCol == null; c++) {
        final cell = cells[c];
        if (!cell.isText) continue;
        final t = cell.text!;
        if (patterns.any((p) => p.hasMatch(t))) {
          patternCol = c;
        }
      }
    }

    final dateCell = dateCol == null
        ? RawCell.empty
        : _value(sheet, r, dateCol);
    final date = dateCol == null || dateCell.isEmpty
        ? null
        : readDate(dateCell, dateCol);
    if (patternCol != null && (date == null || patternCol == dateCol)) {
      classes[r] = RowClass.subtotal;
      continue;
    }
    if (dateCol == null || dateCell.isEmpty) {
      if (filters.skipWithoutDate) {
        classes[r] = RowClass.noDate;
        continue;
      }
      rowIssues.add(CellIssue(r, dateCol ?? 0, IssueKind.missingDate, ''));
    } else if (date == null) {
      rowIssues.add(CellIssue(r, dateCol, IssueKind.badDate, dateCell.display));
    }

    // Amount.
    int? amount;
    var amountMissing = false;
    switch (cfg.amountMode) {
      case AmountMode.signed:
        if (amountCol == null) {
          amountMissing = true;
        } else {
          final cell = _value(sheet, r, amountCol);
          if (cell.isEmpty) {
            amountMissing = true;
          } else {
            amount = readNumber(cell, amountCol);
            if (amount == null) {
              rowIssues.add(
                CellIssue(r, amountCol, IssueKind.badAmount, cell.display),
              );
            }
          }
        }
      case AmountMode.debitCredit:
        final d = debitCol == null ? RawCell.empty : _value(sheet, r, debitCol);
        final c = creditCol == null
            ? RawCell.empty
            : _value(sheet, r, creditCol);
        if (d.isEmpty && c.isEmpty) {
          amountMissing = true;
        } else {
          var sum = 0;
          var ok = true;
          if (d.isNotEmpty) {
            final v = readNumber(d, debitCol!);
            if (v == null) {
              ok = false;
              rowIssues.add(
                CellIssue(r, debitCol, IssueKind.badAmount, d.display),
              );
            } else {
              sum -= v.abs();
            }
          }
          if (c.isNotEmpty) {
            final v = readNumber(c, creditCol!);
            if (v == null) {
              ok = false;
              rowIssues.add(
                CellIssue(r, creditCol, IssueKind.badAmount, c.display),
              );
            } else {
              sum += v.abs();
            }
          }
          if (ok) amount = sum;
        }
      case AmountMode.amountWithType:
        if (amountCol == null) {
          amountMissing = true;
        } else {
          final cell = _value(sheet, r, amountCol);
          if (cell.isEmpty) {
            amountMissing = true;
          } else {
            final v = readNumber(cell, amountCol);
            if (v == null) {
              rowIssues.add(
                CellIssue(r, amountCol, IssueKind.badAmount, cell.display),
              );
            } else {
              final typeCell = typeCol == null
                  ? RawCell.empty
                  : sheet.cell(r, typeCol);
              final sign = typeCell.isEmpty
                  ? null
                  : cfg.typeTokens.signOf(typeCell.trimmed);
              if (typeCell.isNotEmpty && sign == null) {
                rowIssues.add(
                  CellIssue(r, typeCol!, IssueKind.badType, typeCell.display),
                );
              } else {
                amount = sign == null ? v : sign * v.abs();
              }
            }
          }
        }
    }
    if (amount != null && cfg.invertSign) amount = -amount;
    if ((amountMissing || amount == 0) && !rowIssues.any((i) => i.isError)) {
      if (filters.skipZeroAmount) {
        classes[r] = RowClass.noAmount;
        continue;
      }
      if (amountMissing) {
        rowIssues.add(
          CellIssue(
            r,
            amountCol ?? debitCol ?? creditCol ?? 0,
            IssueKind.missingAmount,
            '',
          ),
        );
      }
    }

    // Value date (optional).
    DateTime? valueDate;
    if (valueDateCol != null) {
      final cell = _value(sheet, r, valueDateCol);
      if (cell.isNotEmpty) {
        valueDate = readDate(cell, valueDateCol);
        if (valueDate == null) {
          rowIssues.add(
            CellIssue(r, valueDateCol, IssueKind.badValueDate, cell.display),
          );
        }
      }
    }

    String? text(int? col) {
      if (col == null) return null;
      final t = _value(sheet, r, col).trimmed;
      if (t.isEmpty) return null;
      return t.contains('  ') || t.contains('\n') || t.contains('\t')
          ? t.replaceAll(_whitespace, ' ')
          : t;
    }

    final payee = text(payeeCol);
    final noteParts = [for (final c in noteCols) ?text(c)];
    final note = noteParts.isEmpty ? null : noteParts.join(' ');

    // Category path.
    var path = const <String>[];
    final cat = text(categoryCol);
    final sub = text(subcategoryCol);
    if (cat != null) {
      path = splitCategory(cat, cfg.categorySeparator);
      if (sub != null) path = [path.first, sub];
    } else if (sub != null) {
      path = [sub];
    }

    // Account.
    String accountLabel;
    switch (cfg.accountSource) {
      case AccountSource.fixed:
        accountLabel = cfg.fixedAccount;
      case AccountSource.sheetName:
        accountLabel = sheet.name.trim();
      case AccountSource.column:
        accountLabel = text(accountCol) ?? cfg.fixedAccount;
    }
    if (valueKey(accountLabel).isEmpty) {
      rowIssues.add(
        CellIssue(r, accountCol ?? 0, IssueKind.missingAccount, accountLabel),
      );
    }

    final tagsRaw = text(tagsCol);
    final tags = tagsRaw == null
        ? const <String>[]
        : splitTags(tagsRaw, cfg.tagSeparator);

    TxnStatus? status;
    final statusRaw = text(statusCol);
    if (statusRaw != null) {
      status = parseStatus(statusRaw);
      if (status == null) {
        rowIssues.add(CellIssue(r, statusCol!, IssueKind.badStatus, statusRaw));
      }
    }

    final fields = <String, String>{};
    for (final f in fieldCols) {
      final v = text(f.index);
      if (v != null && f.customFieldId != null) {
        fields[f.customFieldId!] = fields.containsKey(f.customFieldId)
            ? '${fields[f.customFieldId]} $v'
            : v;
      }
    }

    int? balance;
    if (balanceCol != null) {
      final cell = _value(sheet, r, balanceCol);
      if (cell.isNotEmpty) {
        balance = readNumber(cell, balanceCol);
        if (balance == null) {
          rowIssues.add(
            CellIssue(r, balanceCol, IssueKind.badBalance, cell.display),
          );
        }
      }
    }

    if (date != null && cfg.year != null && date.year != cfg.year) {
      rowIssues.add(
        CellIssue(r, dateCol!, IssueKind.yearMismatch, dateCell.display),
      );
    }

    final parsed = ParsedRow(
      fileName: workbook.fileName,
      sheetName: sheet.name,
      row: r,
      date: date,
      amountMinor: amount,
      valueDate: valueDate,
      payee: payee,
      note: note,
      categoryPath: path,
      accountKey: keyCache.putIfAbsent(
        accountLabel,
        () => valueKey(accountLabel),
      ),
      categoryKeyValue: path.isEmpty
          ? ''
          : keyCache.putIfAbsent(
              '\u0000${path.join('\u0000')}',
              () => categoryKey(path),
            ),
      accountLabel: accountLabel.trim(),
      tags: tags,
      status: status,
      customFields: fields,
      balanceMinor: balance,
      issues: rowIssues,
    );
    classes[r] = parsed.isValid ? RowClass.data : RowClass.invalid;
    rows.add(parsed);
    issues.addAll(rowIssues);
  }

  return ParsedSheet(
    config: cfg,
    classes: classes,
    rows: rows,
    issues: issues,
    formats: ResolvedFormats(dateFormats, numberFormats),
    headers: headers,
  );
}
