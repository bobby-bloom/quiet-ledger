import 'package:personal_finance/features/import/domain/date_parser.dart';
import 'package:personal_finance/features/import/domain/header_synonyms.dart';
import 'package:personal_finance/features/import/domain/import_config.dart';
import 'package:personal_finance/features/import/domain/number_parser.dart';
import 'package:personal_finance/features/import/domain/raw_sheet.dart';
import 'package:personal_finance/features/import/domain/source_reader.dart';
import 'package:personal_finance/features/import/domain/structure_detector.dart';
import 'package:personal_finance/features/import/domain/text_normalize.dart';

/// Sheet names that say nothing about the account.
const _genericSheetNames = {
  'tabelle',
  'sheet',
  'blatt',
  'table',
  'daten',
  'data',
  'export',
  'umsaetze',
  'umsatz',
  'kontoumsaetze',
  'transactions',
  'buchungen',
  'clipboard',
  'haushaltsbuch',
  'ausgaben',
  'einnahmen',
  'finanzen',
};

/// Whether a sheet name looks like an account name (not a year, not
/// "Tabelle1", not a month).
bool isAccountLikeSheetName(String name) {
  final letters = normaliseText(name).replaceAll(RegExp('[0-9 ]'), '');
  if (letters.isEmpty) return false;
  if (_genericSheetNames.contains(letters)) return false;
  if (monthFromName(letters) != null) return false;
  return true;
}

/// Data rows used for content analysis.
List<int> _sampleRows(RawSheet sheet, SheetStructure st, {int max = 80}) {
  final out = <int>[];
  for (var r = st.firstDataRow; r < sheet.rowCount && out.length < max; r++) {
    if (!sheet.isRowEmpty(r)) out.add(r);
  }
  return out;
}

class _ColumnStats {
  int nonEmpty = 0;
  int dates = 0;
  int numbers = 0;
  int negatives = 0;
  int typeTokens = 0;
  final Set<String> distinct = {};
  final List<String> texts = [];
}

/// Suggests a complete [SheetConfig] for [sheet]: header/data rows,
/// column targets (from DE/EN header names, then from the content), the
/// amount mode, the account source, the year from the sheet name and the
/// category/tag separators.
///
/// [customFields] are (id, name) pairs; a column whose header matches a
/// custom field name is mapped to it.
SheetConfig suggestSheetConfig(
  RawWorkbook workbook,
  RawSheet sheet, {
  List<(String, String)> customFields = const [],
}) {
  final st = detectStructure(sheet);
  final cols = sheet.columnCount;
  final headers = composeHeaders(
    sheet,
    st.headerRow,
    st.headerRows,
    columnCount: cols,
  );
  final samples = _sampleRows(sheet, st);
  const tokens = TypeTokens();

  final stats = List.generate(cols, (_) => _ColumnStats());
  for (final r in samples) {
    for (var c = 0; c < cols; c++) {
      final cell = sheet.cell(r, c);
      if (cell.isEmpty) continue;
      final s = stats[c];
      s.nonEmpty++;
      if (s.distinct.length < 50) s.distinct.add(cell.trimmed.toLowerCase());
      if (cell.kind == RawKind.date) {
        s.dates++;
      } else if (cell.kind == RawKind.number) {
        final n = num.tryParse(cell.number!);
        if (n != null && n >= 18264 && n <= 73050 && n == n.floor()) {
          // Could be a serial date; decided below together with the header.
          s.dates++;
        }
        s.numbers++;
        if (n != null && n < 0) s.negatives++;
      } else if (cell.isText) {
        final t = cell.text!.trim();
        s.texts.add(t);
        if (tokens.signOf(t) != null && t.length <= 10) s.typeTokens++;
        if (parseAmountText(t, NumberFormatKind.de) != null ||
            parseAmountText(t, NumberFormatKind.en) != null) {
          s.numbers++;
          if (RegExp(r'^\s*[-−(]|[-−]\s*$').hasMatch(t)) s.negatives++;
        } else if (_looksLikeDate(t)) {
          s.dates++;
        }
      }
    }
  }

  // 1. Header names.
  final targets = List<ColumnTarget>.filled(cols, ColumnTarget.ignore);
  final confidence = List<int>.filled(cols, 0);
  final fieldIds = List<String?>.filled(cols, null);
  for (var c = 0; c < cols; c++) {
    final h = headers[c];
    if (h.isEmpty) continue;
    final hit = targetForHeader(h);
    if (hit != null) {
      targets[c] = hit.$1;
      confidence[c] = hit.$2;
    }
    if (customFields.isNotEmpty && (hit == null || hit.$2 < 3)) {
      final m = fuzzyMatches(
        h,
        customFields.map((f) => (f.$1, f.$2)),
        threshold: 0.8,
        limit: 1,
      );
      if (m.isNotEmpty) {
        targets[c] = ColumnTarget.customField;
        fieldIds[c] = m.first.value;
        confidence[c] = 3;
      }
    }
  }

  // Content sanity: a "date" column without dates, an amount column
  // without numbers, are dropped.
  for (var c = 0; c < cols; c++) {
    final s = stats[c];
    if (s.nonEmpty == 0) continue;
    final t = targets[c];
    if ((t == ColumnTarget.date || t == ColumnTarget.valueDate) &&
        s.dates < s.nonEmpty * 0.5) {
      targets[c] = ColumnTarget.ignore;
    }
    if ((t == ColumnTarget.amount ||
            t == ColumnTarget.debit ||
            t == ColumnTarget.credit ||
            t == ColumnTarget.balance) &&
        s.numbers < s.nonEmpty * 0.5) {
      targets[c] = ColumnTarget.ignore;
    }
    if (t == ColumnTarget.amountType && s.typeTokens < s.nonEmpty * 0.6) {
      targets[c] = ColumnTarget.ignore;
    }
  }

  // 2. Resolve duplicates of unique targets: keep the most confident (then
  // leftmost) column; a second date becomes the value date.
  final seen = <ColumnTarget, int>{};
  for (var c = 0; c < cols; c++) {
    final t = targets[c];
    if (!t.isUnique) continue;
    final prev = seen[t];
    if (prev == null) {
      seen[t] = c;
      continue;
    }
    final keep = confidence[c] > confidence[prev] ? c : prev;
    final drop = keep == c ? prev : c;
    seen[t] = keep;
    if (t == ColumnTarget.date && !seen.containsKey(ColumnTarget.valueDate)) {
      targets[drop] = ColumnTarget.valueDate;
      seen[ColumnTarget.valueDate] = drop;
    } else {
      targets[drop] = ColumnTarget.ignore;
    }
  }

  bool has(ColumnTarget t) => targets.contains(t);
  int? firstWhere(bool Function(int c) test) {
    for (var c = 0; c < cols; c++) {
      if (targets[c] == ColumnTarget.ignore && fieldIds[c] == null && test(c)) {
        return c;
      }
    }
    return null;
  }

  // 3. Content-based fallbacks.
  if (!has(ColumnTarget.date)) {
    final c = firstWhere(
      (c) => stats[c].nonEmpty > 0 && stats[c].dates >= stats[c].nonEmpty * 0.8,
    );
    if (c != null) targets[c] = ColumnTarget.date;
  }
  final hasAmount =
      has(ColumnTarget.amount) ||
      has(ColumnTarget.debit) ||
      has(ColumnTarget.credit);
  if (!hasAmount) {
    final numeric = <int>[
      for (var c = 0; c < cols; c++)
        if (targets[c] == ColumnTarget.ignore &&
            stats[c].nonEmpty > 0 &&
            stats[c].numbers >= stats[c].nonEmpty * 0.8 &&
            stats[c].dates < stats[c].nonEmpty * 0.5)
          c,
    ];
    if (numeric.isNotEmpty) targets[numeric.first] = ColumnTarget.amount;
  }
  if (!has(ColumnTarget.amountType) && has(ColumnTarget.amount)) {
    final amountCol = targets.indexOf(ColumnTarget.amount);
    final c = firstWhere(
      (c) =>
          stats[c].nonEmpty > 0 &&
          stats[c].typeTokens >= stats[c].nonEmpty * 0.9 &&
          stats[c].distinct.length <= 4,
    );
    if (c != null && stats[amountCol].negatives == 0) {
      targets[c] = ColumnTarget.amountType;
    }
  }
  if (!has(ColumnTarget.payee) && !has(ColumnTarget.note)) {
    final c = firstWhere(
      (c) =>
          stats[c].nonEmpty > 0 &&
          stats[c].texts.length >= stats[c].nonEmpty * 0.8 &&
          stats[c].numbers < stats[c].nonEmpty * 0.5 &&
          stats[c].dates < stats[c].nonEmpty * 0.5 &&
          stats[c].distinct.length >=
              (stats[c].nonEmpty < 3 ? stats[c].nonEmpty : 3),
    );
    if (c != null) targets[c] = ColumnTarget.payee;
  }

  final columns = <ColumnConfig>[
    for (var c = 0; c < cols; c++)
      if (targets[c] != ColumnTarget.ignore)
        ColumnConfig(index: c, target: targets[c], customFieldId: fieldIds[c]),
  ];

  final mode = has(ColumnTarget.debit) || has(ColumnTarget.credit)
      ? AmountMode.debitCredit
      : has(ColumnTarget.amountType)
      ? AmountMode.amountWithType
      : AmountMode.signed;

  // Category separator.
  var catSep = '';
  final catCol = targets.indexOf(ColumnTarget.category);
  if (catCol >= 0 && !has(ColumnTarget.subcategory)) {
    catSep = detectCategorySeparator(stats[catCol].texts);
  }
  var tagSep = ',';
  final tagCol = targets.indexOf(ColumnTarget.tags);
  if (tagCol >= 0) tagSep = detectTagSeparator(stats[tagCol].texts);

  final accountFromSheet =
      workbook.format != SourceFormat.csv &&
      workbook.format != SourceFormat.clipboard &&
      isAccountLikeSheetName(sheet.name);
  final source = has(ColumnTarget.account)
      ? AccountSource.column
      : accountFromSheet
      ? AccountSource.sheetName
      : AccountSource.fixed;

  return SheetConfig(
    fileName: workbook.fileName,
    sheetName: sheet.name,
    include:
        !sheet.hidden &&
        samples.isNotEmpty &&
        has(ColumnTarget.date) &&
        (has(ColumnTarget.amount) ||
            has(ColumnTarget.debit) ||
            has(ColumnTarget.credit)),
    headerRow: st.headerRow,
    headerRows: st.headerRows,
    firstDataRow: st.firstDataRow,
    columns: columns,
    amountMode: mode,
    accountSource: source,
    fixedAccount: accountFromSheet
        ? sheet.name.trim()
        : defaultAccountName(workbook, sheet),
    year: yearFromName(sheet.name),
    categorySeparator: catSep,
    tagSeparator: tagSep,
    headerSignature: [for (final h in headers) headerKey(h)],
  );
}

/// Account name proposed for a sheet with a fixed account: an
/// account-like sheet name, else the file name ("Umsaetze_Giro.csv" →
/// "Umsaetze Giro").
String defaultAccountName(RawWorkbook workbook, RawSheet sheet) {
  if (workbook.format == SourceFormat.xlsx ||
      workbook.format == SourceFormat.xls) {
    if (isAccountLikeSheetName(sheet.name)) return sheet.name.trim();
  }
  final base = baseName(workbook.fileName)
      .replaceAll(RegExp(r'[_\s]+'), ' ')
      .trim();
  if (base.isEmpty) return 'Import';
  return base[0].toUpperCase() + base.substring(1);
}

bool _looksLikeDate(String t) {
  for (final k in const [
    DateFormatKind.dmy,
    DateFormatKind.ymd,
    DateFormatKind.mdy,
    DateFormatKind.monthName,
  ]) {
    if (parseDateText(t, k) != null) return true;
  }
  return false;
}

/// Separator used in "Parent > Child" category values, or '' when the
/// values have no hierarchy.
String detectCategorySeparator(List<String> values) {
  if (values.isEmpty) return '';
  const candidates = [
    ' > ',
    '>',
    ' › ',
    '›',
    ' / ',
    ':',
    ' - ',
    '/',
    '|',
    r'\',
  ];
  for (final sep in candidates) {
    final n = values.where((v) {
      final i = v.indexOf(sep);
      return i > 0 && i < v.length - sep.length;
    }).length;
    // " - " stays padded so "Coca-Cola" is not split.
    if (n >= values.length * 0.3) return sep == ' - ' ? sep : sep.trim();
  }
  return '';
}

/// Separator between tags in a tags column.
String detectTagSeparator(List<String> values) {
  var comma = 0;
  var semi = 0;
  var pipe = 0;
  var hash = 0;
  for (final v in values) {
    if (v.contains(',')) comma++;
    if (v.contains(';')) semi++;
    if (v.contains('|')) pipe++;
    if (RegExp(r'#\w+\s+#\w+').hasMatch(v)) hash++;
  }
  if (hash > comma && hash > semi) return ' ';
  if (semi > comma && semi >= pipe) return ';';
  if (pipe > comma) return '|';
  return ',';
}
