import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/features/import/domain/balance_checker.dart';
import 'package:personal_finance/features/import/domain/dedupe.dart';
import 'package:personal_finance/features/import/domain/import_config.dart';
import 'package:personal_finance/features/import/domain/mapping_suggester.dart';
import 'package:personal_finance/features/import/domain/raw_sheet.dart';
import 'package:personal_finance/features/import/domain/row_parser.dart';
import 'package:personal_finance/features/import/domain/text_normalize.dart';
import 'package:personal_finance/features/import/domain/transfer_matcher.dart';

// ---------------------------------------------------------------- context --

@immutable
class ExistingAccount {
  const ExistingAccount({
    required this.id,
    required this.name,
    this.type = AccountType.checking,
    this.balanceMinor = 0,
    this.openingMinor = 0,
    this.archived = false,
  });

  final String id;
  final String name;
  final AccountType type;

  /// Current balance (opening + live transactions).
  final int balanceMinor;
  final int openingMinor;
  final bool archived;
}

@immutable
class ExistingCategory {
  const ExistingCategory({
    required this.id,
    required this.name,
    this.parentId,
    this.kind = CategoryKind.expense,
    this.archived = false,
  });

  final String id;
  final String name;
  final String? parentId;
  final CategoryKind kind;
  final bool archived;
}

@immutable
class ExistingTag {
  const ExistingTag({required this.id, required this.name});

  final String id;
  final String name;
}

@immutable
class ExistingField {
  const ExistingField({
    required this.id,
    required this.name,
    this.type = CustomFieldType.text,
    this.options = const [],
  });

  final String id;
  final String name;
  final CustomFieldType type;
  final List<String> options;
}

/// Existing data an import is compared with. Plain data, so the analysis
/// can run in a background isolate.
@immutable
class ImportContext {
  const ImportContext({
    this.accounts = const [],
    this.categories = const [],
    this.tags = const [],
    this.customFields = const [],
    this.existingHashes = const {},
    this.previousHashes = const {},
  });

  final List<ExistingAccount> accounts;
  final List<ExistingCategory> categories;
  final List<ExistingTag> tags;
  final List<ExistingField> customFields;

  /// Dedupe hash → number of live transactions with it.
  final Map<String, int> existingHashes;

  /// Hash → count of rows imported by earlier batches of the same profile
  /// or file (also rows deleted since), for incremental re-import.
  final Map<String, int> previousHashes;

  ExistingAccount? account(String id) =>
      accounts.firstWhereOrNull((a) => a.id == id);

  ExistingCategory? category(String id) =>
      categories.firstWhereOrNull((c) => c.id == id);

  /// "Parent › Child" label of an existing category.
  String categoryLabel(String id) {
    final c = category(id);
    if (c == null) return '';
    final p = c.parentId == null ? null : category(c.parentId!);
    return p == null ? c.name : '${p.name} › ${c.name}';
  }

  ImportContext copyWith({Map<String, int>? previousHashes}) => ImportContext(
    accounts: accounts,
    categories: categories,
    tags: tags,
    customFields: customFields,
    existingHashes: existingHashes,
    previousHashes: previousHashes ?? this.previousHashes,
  );
}

// --------------------------------------------------------------- analysis --

/// A distinct account or category value found in the sheets.
@immutable
class ValueStat {
  const ValueStat({
    required this.key,
    required this.label,
    required this.path,
    required this.count,
    required this.sumMinor,
    required this.positive,
    required this.negative,
  });

  final String key;

  /// Display text as found (first occurrence).
  final String label;

  /// For categories: the one- or two-level path.
  final List<String> path;
  final int count;
  final int sumMinor;
  final int positive;
  final int negative;

  /// Majority sign suggests the category kind.
  CategoryKind get kind =>
      positive > negative ? CategoryKind.income : CategoryKind.expense;
}

enum DupStatus {
  unique,

  /// Matches an existing transaction.
  existing,

  /// Same as a row from another file/sheet of this batch.
  batch,

  /// Imported by an earlier batch of the same profile/file.
  alreadyImported,
}

/// A valid row with its duplicate status.
@immutable
class AnalysedRow {
  const AnalysedRow(this.index, this.row, this.hash, this.dup);

  /// Position in [ImportAnalysis.rows].
  final int index;
  final ParsedRow row;
  final String hash;
  final DupStatus dup;

  int get amountMinor => row.amountMinor!;
  DateTime get date => row.date!;
}

/// Identity of the account a key resolves to: an existing id or `new:<key>`.
String resolvedAccountRef(String key, AccountTarget target) =>
    target.existingId ??
    'new:${valueKey(target.name.isEmpty ? key : target.name)}';

@immutable
class ImportAnalysis {
  const ImportAnalysis({
    required this.sheets,
    required this.rows,
    required this.accountValues,
    required this.categoryValues,
    required this.accountTargets,
    required this.accountSuggestions,
    required this.categoryTargets,
    required this.categorySuggestions,
    required this.transfers,
    required this.balances,
    required this.formulasWithoutValue,
  });

  final List<ParsedSheet> sheets;

  /// Valid rows of all included sheets, in sheet order.
  final List<AnalysedRow> rows;
  final List<ValueStat> accountValues;
  final List<ValueStat> categoryValues;

  /// Effective target per account key (config choice or suggestion).
  final Map<String, AccountTarget> accountTargets;
  final Map<String, List<FuzzyMatch<String>>> accountSuggestions;

  /// Effective target per category key (config choice or suggestion).
  final Map<String, CategoryTarget> categoryTargets;
  final Map<String, List<FuzzyMatch<String>>> categorySuggestions;

  /// Debit/credit pairs (indices into [rows]).
  final List<TransferMatch> transfers;

  /// Running-balance checks per resolved account (or per sheet when the
  /// account comes from a column).
  final List<BalanceReport> balances;
  final int formulasWithoutValue;

  List<CellIssue> get issues => [for (final s in sheets) ...s.issues];

  int get invalidRowCount =>
      sheets.fold(0, (n, s) => n + s.count(RowClass.invalid));

  int count(RowClass c) => sheets.fold(0, (n, s) => n + s.count(c));

  BalanceReport? balanceFor(String groupKey) =>
      balances.firstWhereOrNull((b) => b.groupKey == groupKey);
}

/// Guesses an account type from its name.
AccountType guessAccountType(String name) {
  final n = normaliseText(name);
  bool any(List<String> words) => words.any(n.contains);
  if (any(['kreditkarte', 'credit card', 'visa', 'mastercard', 'amex'])) {
    return AccountType.creditCard;
  }
  if (any(['spar', 'tagesgeld', 'festgeld', 'savings', 'saving'])) {
    return AccountType.savings;
  }
  if (any([
    'bar',
    'cash',
    'geldboerse',
    'portemonnaie',
    'brieftasche',
    'wallet',
    'kasse',
  ])) {
    return AccountType.cash;
  }
  if (any(['depot', 'broker', 'invest', 'etf', 'aktien', 'wertpapier'])) {
    return AccountType.investment;
  }
  if (any([
    'darlehen',
    'kredit',
    'loan',
    'mortgage',
    'baufinanzierung',
    'hypothek',
  ])) {
    return AccountType.loan;
  }
  return AccountType.checking;
}

/// Reads all included sheets of [workbooks] with [config] and compares the
/// result with [context]. Pure and isolate-safe.
ImportAnalysis analyseImport(
  List<RawWorkbook> workbooks,
  ImportConfig config,
  ImportContext context,
) {
  final sheets = <ParsedSheet>[];
  var noValue = 0;
  for (final wb in workbooks) {
    noValue += wb.formulasWithoutValue;
    for (final sheet in wb.sheets) {
      final cfg = config.sheet(sheetKey(wb.fileName, sheet.name));
      if (cfg == null || !cfg.include) continue;
      sheets.add(parseSheet(wb, sheet, cfg, config.filters));
    }
  }
  final valid = [for (final s in sheets) ...s.validRows];

  // Distinct account values.
  final accountStats = <String, _Acc>{};
  final categoryStats = <String, _Acc>{};
  for (final r in valid) {
    (accountStats[r.accountKey] ??= _Acc(
      r.accountLabel,
      const [],
    )).add(r.amountMinor!);
    if (r.categoryPath.isNotEmpty) {
      (categoryStats[r.categoryKeyValue] ??= _Acc(
        r.categoryPath.join(' › '),
        r.categoryPath,
      )).add(r.amountMinor!);
    }
  }
  // Accounts named only as transfer targets still need a target.
  for (final t in config.categories.values) {
    final key = t.transferAccount;
    if (t.mode == CategoryTargetMode.transfer &&
        key != null &&
        !key.startsWith('id:')) {
      accountStats.putIfAbsent(key, () => _Acc(key, const []));
    }
  }
  final accountValues = [
    for (final e in accountStats.entries) e.value.stat(e.key),
  ]..sort((a, b) => b.count.compareTo(a.count));
  final categoryValues = [
    for (final e in categoryStats.entries) e.value.stat(e.key),
  ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

  // Account targets and suggestions.
  final liveAccounts = context.accounts.where((a) => !a.archived).toList();
  final accountTargets = <String, AccountTarget>{};
  final accountSuggestions = <String, List<FuzzyMatch<String>>>{};
  for (final v in accountValues) {
    final matches = fuzzyMatches(
      v.label,
      liveAccounts.map((a) => (a.id, a.name)),
      threshold: 0.5,
    );
    accountSuggestions[v.key] = matches;
    final chosen = config.accounts[v.key];
    if (chosen != null &&
        (chosen.existingId == null ||
            context.account(chosen.existingId!) != null)) {
      accountTargets[v.key] = chosen;
    } else if (matches.isNotEmpty && matches.first.score >= 0.85) {
      accountTargets[v.key] = AccountTarget.existing(matches.first.value);
    } else {
      accountTargets[v.key] = AccountTarget.create(
        v.label,
        type: guessAccountType(v.label),
      );
    }
  }

  // Category targets and suggestions.
  final liveCategories = context.categories.where((c) => !c.archived).toList();
  final categoryLabels = [
    for (final c in liveCategories) (c.id, context.categoryLabel(c.id)),
  ];
  final categoryTargets = <String, CategoryTarget>{};
  final categorySuggestions = <String, List<FuzzyMatch<String>>>{};
  for (final v in categoryValues) {
    final chosen = config.categories[v.key];
    final exact = _exactCategory(v.path, liveCategories, context);
    final matches = fuzzyMatches(v.path.join(' '), [
      for (final (id, label) in categoryLabels)
        (id, label.replaceAll(' › ', ' ')),
    ], threshold: 0.5);
    // Also match the leaf alone ("Groceries" ↔ "Food › Groceries").
    final leafMatches = fuzzyMatches(v.path.last, [
      for (final c in liveCategories) (c.id, c.name),
    ], threshold: 0.6);
    final merged = <String, FuzzyMatch<String>>{};
    for (final m in [...matches, ...leafMatches]) {
      final prev = merged[m.value];
      if (prev == null || prev.score < m.score) {
        merged[m.value] = FuzzyMatch(
          m.value,
          context.categoryLabel(m.value),
          m.score,
        );
      }
    }
    final suggestions = merged.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    categorySuggestions[v.key] = suggestions.take(3).toList();
    if (chosen != null &&
        (chosen.mode != CategoryTargetMode.existing ||
            context.category(chosen.existingId ?? '') != null)) {
      categoryTargets[v.key] = chosen;
    } else if (exact != null) {
      categoryTargets[v.key] = CategoryTarget.existing(exact);
    } else if (suggestions.isNotEmpty && suggestions.first.score >= 0.9) {
      categoryTargets[v.key] = CategoryTarget.existing(suggestions.first.value);
    } else {
      categoryTargets[v.key] = CategoryTarget.create(v.path, kind: v.kind);
    }
  }

  String accountRef(String key) =>
      resolvedAccountRef(key, accountTargets[key] ?? AccountTarget.create(key));

  // Duplicates.
  final existing = HashCounter(context.existingHashes);
  final previous = HashCounter(context.previousHashes);
  final seenBySource = <String, Set<String>>{};
  final rows = <AnalysedRow>[];
  for (final r in valid) {
    final h = dedupeHash(
      date: r.date!,
      amountMinor: r.amountMinor!,
      payee: r.payee,
      note: r.note,
    );
    final source = '${r.fileName}|${r.sheetName}';
    DupStatus status;
    if (config.incremental && previous.take(h)) {
      existing.take(h);
      status = DupStatus.alreadyImported;
    } else if (existing.take(h)) {
      status = DupStatus.existing;
    } else if (seenBySource.entries.any(
      (e) => e.key != source && e.value.contains(h),
    )) {
      status = DupStatus.batch;
    } else {
      status = DupStatus.unique;
    }
    (seenBySource[source] ??= {}).add(h);
    rows.add(AnalysedRow(rows.length, r, h, status));
  }

  // Transfers between accounts of this batch (duplicates excluded).
  final categoryIsTransfer = {
    for (final e in categoryTargets.entries)
      if (e.value.mode == CategoryTargetMode.transfer) e.key,
  };
  var transfers = const <TransferMatch>[];
  if (config.transfers.detect) {
    final candidates = [
      for (final r in rows)
        if (r.dup == DupStatus.unique || r.dup == DupStatus.batch)
          TransferCandidate(
            index: r.index,
            accountKey: accountRef(r.row.accountKey),
            date: r.date,
            amountMinor: r.amountMinor,
            text: [
              r.row.payee,
              r.row.note,
              r.row.categoryPath.join(' '),
            ].whereType<String>().join(' '),
            accountLabel: r.row.accountLabel,
          ),
    ];
    transfers = matchTransfers(
      candidates,
      windowDays: config.transfers.windowDays,
    );
    // Rows mapped to a transfer category count as transfer evidence.
    bool flagged(TransferMatch t) =>
        categoryIsTransfer.contains(rows[t.outIndex].row.categoryKeyValue) ||
        categoryIsTransfer.contains(rows[t.inIndex].row.categoryKeyValue);
    transfers = [
      for (final t in transfers)
        if (flagged(t))
          TransferMatch(t.outIndex, t.inIndex, t.dayDiff, t.score + 5)
        else
          t,
    ];
  }

  // Running balances.
  final balances = <BalanceReport>[];
  final groups = <String, List<(DateTime?, List<BalancePoint>)>>{};
  for (final s in sheets) {
    final cfg = s.config;
    if (cfg.columnFor(ColumnTarget.balance) == null) continue;
    final valid = s.validRows;
    if (valid.isEmpty) continue;
    if (cfg.accountSource == AccountSource.column) {
      final pts = [for (final r in valid) _point(r)];
      balances.add(checkBalances(cfg.key, pts));
      continue;
    }
    final byAccount = groupBy<ParsedRow, String>(
      valid,
      (r) => accountRef(r.accountKey),
    );
    for (final e in byAccount.entries) {
      final firstDate = e.value
          .map((r) => r.date!)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      (groups[e.key] ??= []).add((
        firstDate,
        [for (final r in e.value) _point(r)],
      ));
    }
  }
  for (final e in groups.entries) {
    // Sheets of one account (e.g. "2023", "2024") in chronological order.
    final parts = e.value..sort((a, b) => a.$1!.compareTo(b.$1!));
    balances.add(checkBalances(e.key, [for (final p in parts) ...p.$2]));
  }

  return ImportAnalysis(
    sheets: sheets,
    rows: rows,
    accountValues: accountValues,
    categoryValues: categoryValues,
    accountTargets: accountTargets,
    accountSuggestions: accountSuggestions,
    categoryTargets: categoryTargets,
    categorySuggestions: categorySuggestions,
    transfers: transfers,
    balances: balances,
    formulasWithoutValue: noValue,
  );
}

BalancePoint _point(ParsedRow r) => BalancePoint(
  ref: r.rowRef,
  amountMinor: r.amountMinor!,
  balanceMinor: r.balanceMinor,
  date: r.date,
);

String? _exactCategory(
  List<String> path,
  List<ExistingCategory> all,
  ImportContext ctx,
) {
  if (path.isEmpty) return null;
  final leaf = valueKey(path.last);
  if (path.length == 1) {
    final top = all.firstWhereOrNull(
      (c) => c.parentId == null && valueKey(c.name) == leaf,
    );
    return top?.id ?? all.firstWhereOrNull((c) => valueKey(c.name) == leaf)?.id;
  }
  final parent = valueKey(path.first);
  return all.firstWhereOrNull((c) {
    if (valueKey(c.name) != leaf || c.parentId == null) return false;
    final p = ctx.category(c.parentId!);
    return p != null && valueKey(p.name) == parent;
  })?.id;
}

class _Acc {
  _Acc(this.label, this.path);

  final String label;
  final List<String> path;
  int count = 0;
  int sum = 0;
  int pos = 0;
  int neg = 0;

  void add(int amount) {
    count++;
    sum += amount;
    if (amount > 0) pos++;
    if (amount < 0) neg++;
  }

  ValueStat stat(String key) => ValueStat(
    key: key,
    label: label,
    path: path,
    count: count,
    sumMinor: sum,
    positive: pos,
    negative: neg,
  );
}

/// Builds the initial config for [workbooks]: every sheet gets a suggested
/// [SheetConfig]; when a [profile] is given, its choices are reused for
/// sheets with the same name or the same columns (e.g. a new year's sheet).
ImportConfig initialConfig(
  List<RawWorkbook> workbooks, {
  ImportConfig? profile,
  List<(String, String)> customFields = const [],
}) {
  final base = profile ?? const ImportConfig();
  final sheets = <SheetConfig>[];
  for (final wb in workbooks) {
    for (final sheet in wb.sheets) {
      final suggested = suggestSheetConfig(
        wb,
        sheet,
        customFields: customFields,
      );
      SheetConfig? template;
      if (profile != null) {
        template =
            profile.sheets.firstWhereOrNull(
              (s) => s.fileName == wb.fileName && s.sheetName == sheet.name,
            ) ??
            profile.sheets.firstWhereOrNull((s) => s.sheetName == sheet.name) ??
            profile.sheets.firstWhereOrNull(
              (s) =>
                  s.headerSignature.isNotEmpty &&
                  const ListEquality<String>().equals(
                    s.headerSignature.where((h) => h.isNotEmpty).toList(),
                    suggested.headerSignature
                        .where((h) => h.isNotEmpty)
                        .toList(),
                  ),
            );
      }
      if (template == null) {
        sheets.add(suggested);
      } else {
        final sameSheet = template.sheetName == sheet.name;
        sheets.add(
          template.copyWith(
            fileName: wb.fileName,
            sheetName: sheet.name,
            // A sheet "2025" reusing the "2024" layout takes its own year.
            year: sameSheet ? template.year : suggested.year,
            fixedAccount: template.accountSource == AccountSource.sheetName
                ? sheet.name.trim()
                : template.fixedAccount,
            headerRow: sameSheet ? template.headerRow : suggested.headerRow,
            headerRows: sameSheet ? template.headerRows : suggested.headerRows,
            firstDataRow: sameSheet
                ? template.firstDataRow
                : suggested.firstDataRow,
            lastDataRow: sameSheet ? template.lastDataRow : null,
          ),
        );
      }
    }
  }
  return base.copyWith(sheets: sheets);
}
