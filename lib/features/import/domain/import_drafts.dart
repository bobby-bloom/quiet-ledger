import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/import/domain/date_parser.dart';
import 'package:personal_finance/features/import/domain/dedupe.dart';
import 'package:personal_finance/features/import/domain/import_analysis.dart';
import 'package:personal_finance/features/import/domain/import_config.dart';
import 'package:personal_finance/features/import/domain/number_parser.dart';
import 'package:personal_finance/features/import/domain/row_parser.dart';
import 'package:personal_finance/features/import/domain/transfer_matcher.dart';

/// Placeholder ids for entities the import will create. They are replaced
/// by real ids at commit time.
abstract final class PendingIds {
  static const prefix = 'pending:';

  static String account(String ref) => '${prefix}acc:$ref';
  static String category(String key) => '${prefix}cat:$key';
  static String tag(String key) => '${prefix}tag:$key';

  static bool isPending(String? id) => id != null && id.startsWith(prefix);
}

@immutable
class NewAccountSpec {
  const NewAccountSpec({
    required this.pendingId,
    required this.name,
    required this.type,
    this.openingMinor = 0,
    this.openingDate,
  });

  final String pendingId;
  final String name;
  final AccountType type;
  final int openingMinor;
  final DateTime? openingDate;

  NewAccountSpec copyWith({int? openingMinor, DateTime? openingDate}) =>
      NewAccountSpec(
        pendingId: pendingId,
        name: name,
        type: type,
        openingMinor: openingMinor ?? this.openingMinor,
        openingDate: openingDate ?? this.openingDate,
      );
}

/// A category to create. [parentId] is an existing id, the pending id of
/// another spec (listed before this one) or null.
@immutable
class NewCategorySpec {
  const NewCategorySpec({
    required this.pendingId,
    required this.name,
    required this.kind,
    this.parentId,
  });

  final String pendingId;
  final String name;
  final CategoryKind kind;
  final String? parentId;
}

@immutable
class NewTagSpec {
  const NewTagSpec({required this.pendingId, required this.name});

  final String pendingId;
  final String name;
}

/// One transaction the import would write.
@immutable
class PlannedTxn {
  const PlannedTxn({
    required this.draft,
    required this.rows,
    required this.dup,
    required this.included,
    required this.ref,
  });

  /// Uses pending ids for entities that do not exist yet.
  final TxnDraft draft;

  /// Indices into [ImportAnalysis.rows] (two for a merged transfer).
  final List<int> rows;
  final DupStatus dup;
  final bool included;

  /// Decision key (row ref of the first row).
  final String ref;

  PlannedTxn copyWith({TxnDraft? draft, bool? included}) => PlannedTxn(
    draft: draft ?? this.draft,
    rows: rows,
    dup: dup,
    included: included ?? this.included,
    ref: ref,
  );
}

/// Per-row and per-pair choices of the wizard (not part of a profile).
@immutable
class ImportDecisions {
  const ImportDecisions({this.transfers = const {}, this.include = const {}});

  /// [TransferMatch.key] → merge into a transfer?
  final Map<String, bool> transfers;

  /// [PlannedTxn.ref] → import this row?
  final Map<String, bool> include;

  ImportDecisions copyWith({
    Map<String, bool>? transfers,
    Map<String, bool>? include,
  }) => ImportDecisions(
    transfers: transfers ?? this.transfers,
    include: include ?? this.include,
  );
}

/// Whether a detected pair is merged when the user has not decided.
bool defaultTransferAccepted(TransferMatch t, ImportAnalysis a) {
  if (t.score > 0 || t.dayDiff == 0) return true;
  final out = a.rows[t.outIndex].row;
  final inc = a.rows[t.inIndex].row;
  return out.categoryPath.isEmpty || inc.categoryPath.isEmpty;
}

/// Whether a row with [dup] is imported when the user has not decided.
bool defaultIncluded(DupStatus dup, DuplicatePolicy policy) => switch (dup) {
  DupStatus.unique => true,
  DupStatus.alreadyImported => false,
  DupStatus.existing || DupStatus.batch => policy == DuplicatePolicy.import,
};

/// Everything the import would write.
@immutable
class ImportDraftSet {
  const ImportDraftSet({
    required this.txns,
    required this.accounts,
    required this.categories,
    required this.tags,
  });

  final List<PlannedTxn> txns;
  final List<NewAccountSpec> accounts;
  final List<NewCategorySpec> categories;
  final List<NewTagSpec> tags;

  List<PlannedTxn> get included => [
    for (final t in txns)
      if (t.included) t,
  ];

  ImportDraftSet withTxns(List<PlannedTxn> txns) => ImportDraftSet(
    txns: txns,
    accounts: accounts,
    categories: categories,
    tags: tags,
  );
}

/// Converts a raw custom field text to the JSON value stored for [field].
Object? customFieldValue(String raw, ExistingField? field) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  switch (field?.type ?? CustomFieldType.text) {
    case CustomFieldType.text:
      return t;
    case CustomFieldType.number:
      final minor =
          parseAmountText(t, NumberFormatKind.de) ??
          parseAmountText(t, NumberFormatKind.en);
      if (minor == null) return t;
      return minor % 100 == 0 ? minor ~/ 100 : minor / 100;
    case CustomFieldType.date:
      for (final k in const [
        DateFormatKind.dmy,
        DateFormatKind.ymd,
        DateFormatKind.monthName,
        DateFormatKind.excelSerial,
      ]) {
        final d = parseDateText(t, k);
        if (d != null) {
          return '${d.year.toString().padLeft(4, '0')}-'
              '${d.month.toString().padLeft(2, '0')}-'
              '${d.day.toString().padLeft(2, '0')}';
        }
      }
      return t;
    case CustomFieldType.boolean:
      return const {
        '1',
        'x',
        'ja',
        'yes',
        'true',
        'wahr',
        'y',
        'j',
        '✓',
      }.contains(t.toLowerCase());
    case CustomFieldType.select:
      return field!.options.firstWhereOrNull(
            (o) => o.toLowerCase() == t.toLowerCase(),
          ) ??
          t;
    case CustomFieldType.multiselect:
      return [
        for (final p in t.split(RegExp('[,;|]')))
          if (p.trim().isNotEmpty)
            field!.options.firstWhereOrNull(
                  (o) => o.toLowerCase() == p.trim().toLowerCase(),
                ) ??
                p.trim(),
      ];
  }
}

/// Builds the transactions (with pending ids) and the entities to create.
ImportDraftSet buildImportDrafts(
  ImportAnalysis analysis,
  ImportConfig config,
  ImportContext context, {
  ImportDecisions decisions = const ImportDecisions(),
}) {
  // Accounts.
  final newAccounts = <String, NewAccountSpec>{};
  final accountIds = <String, String>{};
  for (final e in analysis.accountTargets.entries) {
    final t = e.value;
    if (t.existingId != null) {
      accountIds[e.key] = t.existingId!;
      continue;
    }
    final ref = resolvedAccountRef(e.key, t);
    final pending = PendingIds.account(ref);
    accountIds[e.key] = pending;
    newAccounts.putIfAbsent(
      pending,
      () => NewAccountSpec(
        pendingId: pending,
        name: (t.name.isEmpty ? e.key : t.name).trim(),
        type: t.type,
      ),
    );
  }
  String accountFor(String key) =>
      accountIds[key] ?? PendingIds.account('new:$key');
  String? transferTarget(String? key) {
    if (key == null || key.isEmpty) return null;
    if (key.startsWith('id:')) return key.substring(3);
    return accountIds[key];
  }

  // Categories.
  final newCategories = <String, NewCategorySpec>{};
  final categoryIds = <String, String?>{};
  final transferTo = <String, String>{};
  for (final e in analysis.categoryTargets.entries) {
    final t = e.value;
    switch (t.mode) {
      case CategoryTargetMode.existing:
        categoryIds[e.key] = t.existingId;
      case CategoryTargetMode.none:
        categoryIds[e.key] = null;
      case CategoryTargetMode.transfer:
        categoryIds[e.key] = null;
        final target = transferTarget(t.transferAccount);
        if (target != null) transferTo[e.key] = target;
      case CategoryTargetMode.create:
        final path = t.path.isEmpty ? const ['?'] : t.path;
        String? parentId;
        if (path.length > 1) {
          final parentKey = valueKey(path.first);
          final existingParent =
              context.categories.firstWhereOrNull(
                (c) =>
                    c.parentId == null &&
                    !c.archived &&
                    valueKey(c.name) == parentKey &&
                    c.kind == t.kind,
              ) ??
              context.categories.firstWhereOrNull(
                (c) => c.parentId == null && valueKey(c.name) == parentKey,
              );
          if (existingParent != null) {
            parentId = existingParent.id;
          } else {
            final pendingParent = PendingIds.category(parentKey);
            parentId = pendingParent;
            newCategories.putIfAbsent(
              pendingParent,
              () => NewCategorySpec(
                pendingId: pendingParent,
                name: path.first,
                kind: t.kind,
              ),
            );
          }
        }
        final key = categoryKey(path);
        final pending = PendingIds.category(key);
        categoryIds[e.key] = pending;
        newCategories.putIfAbsent(
          pending,
          () => NewCategorySpec(
            pendingId: pending,
            name: path.last,
            kind: t.kind,
            parentId: parentId,
          ),
        );
    }
  }

  // Tags.
  final newTags = <String, NewTagSpec>{};
  final tagIds = <String, String>{};
  String tagFor(String name) {
    final k = valueKey(name);
    return tagIds.putIfAbsent(k, () {
      final existing = context.tags.firstWhereOrNull(
        (t) => valueKey(t.name) == k,
      );
      if (existing != null) return existing.id;
      final pending = PendingIds.tag(k);
      newTags[pending] = NewTagSpec(pendingId: pending, name: name.trim());
      return pending;
    });
  }

  final fields = {for (final f in context.customFields) f.id: f};
  Map<String, Object?> customFor(Map<String, String> raw) => {
    for (final e in raw.entries)
      e.key: ?customFieldValue(e.value, fields[e.key]),
  };

  // Transfer pairs.
  final pairOfOut = <int, TransferMatch>{};
  final pairedIn = <int>{};
  for (final t in analysis.transfers) {
    final accepted =
        decisions.transfers[t.key] ?? defaultTransferAccepted(t, analysis);
    if (!accepted) continue;
    pairOfOut[t.outIndex] = t;
    pairedIn.add(t.inIndex);
  }

  final txns = <PlannedTxn>[];
  for (final a in analysis.rows) {
    if (pairedIn.contains(a.index)) continue;
    final r = a.row;
    final pair = pairOfOut[a.index];
    TxnDraft draft;
    var rows = [a.index];
    var dup = a.dup;
    if (pair != null) {
      final inc = analysis.rows[pair.inIndex];
      final ir = inc.row;
      rows = [a.index, inc.index];
      if (inc.dup == DupStatus.batch) dup = DupStatus.batch;
      final notes = <String>{?r.note, ?ir.note};
      draft = TxnDraft(
        accountId: accountFor(r.accountKey),
        transferAccountId: accountFor(ir.accountKey),
        amountMinor: r.amountMinor!,
        date: r.date!,
        type: TxnType.transfer,
        valueDate: r.valueDate,
        payee: r.payee ?? ir.payee,
        note: notes.isEmpty ? null : notes.join(' / '),
        status: r.status ?? ir.status ?? TxnStatus.cleared,
        tagIds: {
          for (final t in [...r.tags, ...ir.tags]) tagFor(t),
        }.toList(),
        customFields: {
          ...customFor(ir.customFields),
          ...customFor(r.customFields),
        },
        dedupeHash: transferHash(a.hash, inc.hash),
        importRowRef: '${r.rowRef} & ${ir.rowRef}',
      );
    } else {
      final own = accountFor(r.accountKey);
      final key = r.categoryKeyValue;
      final target = transferTo[key];
      final base = TxnDraft(
        accountId: own,
        amountMinor: r.amountMinor!,
        date: r.date!,
        type: r.amountMinor! < 0 ? TxnType.expense : TxnType.income,
        valueDate: r.valueDate,
        payee: r.payee,
        note: r.note,
        categoryId: r.categoryPath.isEmpty ? null : categoryIds[key],
        status: r.status ?? TxnStatus.cleared,
        tagIds: {for (final t in r.tags) tagFor(t)}.toList(),
        customFields: customFor(r.customFields),
        dedupeHash: a.hash,
        importRowRef: r.rowRef,
      );
      if (target != null && target != own) {
        // One-sided transfer: the other leg is not in the sheets.
        draft = r.amountMinor! < 0
            ? base.copyWith(
                type: TxnType.transfer,
                transferAccountId: target,
                categoryId: null,
                dedupeHash: transferHash(a.hash, ''),
              )
            : base.copyWith(
                type: TxnType.transfer,
                accountId: target,
                transferAccountId: own,
                amountMinor: -r.amountMinor!,
                categoryId: null,
                dedupeHash: transferHash('', a.hash),
              );
      } else {
        draft = base;
      }
    }
    final ref = r.rowRef;
    txns.add(
      PlannedTxn(
        draft: draft,
        rows: rows,
        dup: dup,
        included:
            decisions.include[ref] ?? defaultIncluded(dup, config.duplicates),
        ref: ref,
      ),
    );
  }

  // Opening balances of new accounts: from the running balance when
  // available, dated on the earliest imported row.
  final earliest = <String, DateTime>{};
  void seen(String id, DateTime d) {
    final cur = earliest[id];
    if (cur == null || d.isBefore(cur)) earliest[id] = d;
  }

  for (final t in txns) {
    if (!t.included) continue;
    seen(t.draft.accountId, t.draft.date);
    if (t.draft.transferAccountId != null) {
      seen(t.draft.transferAccountId!, t.draft.date);
    }
  }
  final accounts = <NewAccountSpec>[
    for (final spec in newAccounts.values)
      () {
        final ref = spec.pendingId.substring(PendingIds.account('').length);
        final report = analysis.balanceFor(ref);
        return spec.copyWith(
          openingMinor: config.setOpeningBalances ? report?.openingMinor : null,
          openingDate: earliest[spec.pendingId],
        );
      }(),
  ];

  // Parents before children.
  final categories = newCategories.values.toList()
    ..sort((a, b) {
      final ap = PendingIds.isPending(a.parentId) ? 1 : 0;
      final bp = PendingIds.isPending(b.parentId) ? 1 : 0;
      return ap.compareTo(bp);
    });

  return ImportDraftSet(
    txns: txns,
    accounts: accounts,
    categories: categories,
    tags: newTags.values.toList(),
  );
}

// ---------------------------------------------------------------- summary --

@immutable
class AccountSummary {
  const AccountSummary({
    required this.accountId,
    required this.name,
    required this.isNew,
    required this.count,
    required this.inflowMinor,
    required this.outflowMinor,
    required this.startMinor,
    this.sheetClosingMinor,
    this.mismatches = 0,
  });

  /// Existing id or pending id.
  final String accountId;
  final String name;
  final bool isNew;
  final int count;
  final int inflowMinor;

  /// Negative.
  final int outflowMinor;

  /// Current balance (existing) or opening balance (new account).
  final int startMinor;

  /// The sheet's last running balance, when the sheet has one.
  final int? sheetClosingMinor;
  final int mismatches;

  int get netMinor => inflowMinor + outflowMinor;
  int get resultingMinor => startMinor + netMinor;

  /// Resulting balance equals the sheet's closing balance.
  bool? get matchesSheet =>
      sheetClosingMinor == null ? null : sheetClosingMinor == resultingMinor;

  Map<String, Object?> toJson() => {
    'accountId': accountId,
    'name': name,
    'new': isNew,
    'count': count,
    'in': inflowMinor,
    'out': outflowMinor,
    'start': startMinor,
    'result': resultingMinor,
    'sheetClosing': ?sheetClosingMinor,
    'mismatches': mismatches,
  };
}

@immutable
class CategorySummary {
  const CategorySummary({
    required this.categoryId,
    required this.label,
    required this.isNew,
    required this.count,
    required this.sumMinor,
  });

  /// Null = uncategorised.
  final String? categoryId;
  final String label;
  final bool isNew;
  final int count;
  final int sumMinor;

  Map<String, Object?> toJson() => {
    'categoryId': ?categoryId,
    'label': label,
    'count': count,
    'sum': sumMinor,
  };
}

enum ImportWarningKind {
  invalidRows,
  balanceMismatch,
  formulasWithoutValue,
  yearMismatch,
  uncategorised,
  duplicatesIncluded,
}

@immutable
class ImportWarning {
  const ImportWarning(this.kind, {this.count = 0, this.subject = ''});

  final ImportWarningKind kind;
  final int count;

  /// Account name etc.
  final String subject;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'count': count,
    if (subject.isNotEmpty) 'subject': subject,
  };
}

@immutable
class ImportSummary {
  const ImportSummary({
    required this.sheetRows,
    required this.transactions,
    required this.transfers,
    required this.skippedDuplicates,
    required this.alreadyImported,
    required this.invalidRows,
    required this.subtotalRows,
    required this.noDateRows,
    required this.accounts,
    required this.categories,
    required this.warnings,
    required this.newAccounts,
    required this.newCategories,
    required this.newTags,
    this.categorisedByRules = 0,
  });

  /// Valid data rows read from the sheets.
  final int sheetRows;

  /// Transactions that will be written (a merged transfer counts once).
  final int transactions;
  final int transfers;
  final int skippedDuplicates;
  final int alreadyImported;
  final int invalidRows;
  final int subtotalRows;
  final int noDateRows;
  final List<AccountSummary> accounts;
  final List<CategorySummary> categories;
  final List<ImportWarning> warnings;
  final int newAccounts;
  final int newCategories;
  final int newTags;
  final int categorisedByRules;

  Map<String, Object?> toJson() => {
    'sheetRows': sheetRows,
    'transactions': transactions,
    'transfers': transfers,
    'skippedDuplicates': skippedDuplicates,
    'alreadyImported': alreadyImported,
    'invalidRows': invalidRows,
    'subtotalRows': subtotalRows,
    'noDateRows': noDateRows,
    'categorisedByRules': categorisedByRules,
    'accounts': [for (final a in accounts) a.toJson()],
    'categories': [for (final c in categories) c.toJson()],
    'warnings': [for (final w in warnings) w.toJson()],
  };
}

/// Counts, resulting balances and warnings of [set] (PLAN.md §2.5 step 11).
ImportSummary summariseImport(
  ImportDraftSet set,
  ImportAnalysis analysis,
  ImportContext context, {
  int categorisedByRules = 0,
}) {
  final included = set.included;
  final accNames = {
    for (final a in set.accounts) a.pendingId: a.name,
    for (final a in context.accounts) a.id: a.name,
  };
  final newAccById = {for (final a in set.accounts) a.pendingId: a};
  final perAccount = <String, List<int>>{};
  final counts = <String, int>{};
  void book(String id, int amount) {
    final v = perAccount.putIfAbsent(id, () => [0, 0]);
    if (amount >= 0) {
      v[0] += amount;
    } else {
      v[1] += amount;
    }
    counts[id] = (counts[id] ?? 0) + 1;
  }

  final perCategory = <String?, List<int>>{};
  var transfers = 0;
  for (final t in included) {
    final d = t.draft;
    book(d.accountId, d.amountMinor);
    if (d.isTransfer) {
      transfers++;
      book(d.transferAccountId!, -d.amountMinor);
    } else {
      final v = perCategory.putIfAbsent(d.categoryId, () => [0, 0]);
      v[0]++;
      v[1] += d.amountMinor;
    }
  }

  // Sheet closing balances per resolved account ref.
  final closing = <String, BalanceReportLike>{};
  for (final b in analysis.balances) {
    if (!b.hasBalance) continue;
    final ref = b.groupKey;
    final id = ref.startsWith('new:') ? PendingIds.account(ref) : ref;
    closing[id] = BalanceReportLike(b.closingMinor, b.mismatches.length);
  }

  final accounts = <AccountSummary>[
    for (final e in perAccount.entries)
      AccountSummary(
        accountId: e.key,
        name: accNames[e.key] ?? e.key,
        isNew: PendingIds.isPending(e.key),
        count: counts[e.key] ?? 0,
        inflowMinor: e.value[0],
        outflowMinor: e.value[1],
        startMinor: PendingIds.isPending(e.key)
            ? newAccById[e.key]?.openingMinor ?? 0
            : context.account(e.key)?.balanceMinor ?? 0,
        sheetClosingMinor: closing[e.key]?.closing,
        mismatches: closing[e.key]?.mismatches ?? 0,
      ),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  final newCats = {for (final c in set.categories) c.pendingId: c};
  String catLabel(String? id) {
    if (id == null) return '';
    final spec = newCats[id];
    if (spec == null) return context.categoryLabel(id);
    final parent = spec.parentId == null
        ? null
        : (newCats[spec.parentId]?.name ??
              context.category(spec.parentId!)?.name);
    return parent == null ? spec.name : '$parent › ${spec.name}';
  }

  final categories = <CategorySummary>[
    for (final e in perCategory.entries)
      CategorySummary(
        categoryId: e.key,
        label: catLabel(e.key),
        isNew: PendingIds.isPending(e.key),
        count: e.value[0],
        sumMinor: e.value[1],
      ),
  ]..sort((a, b) => a.sumMinor.compareTo(b.sumMinor));

  final warnings = <ImportWarning>[];
  final invalid = analysis.invalidRowCount;
  if (invalid > 0) {
    warnings.add(ImportWarning(ImportWarningKind.invalidRows, count: invalid));
  }
  for (final a in accounts) {
    if (a.mismatches > 0) {
      warnings.add(
        ImportWarning(
          ImportWarningKind.balanceMismatch,
          count: a.mismatches,
          subject: a.name,
        ),
      );
    }
  }
  if (analysis.formulasWithoutValue > 0) {
    warnings.add(
      ImportWarning(
        ImportWarningKind.formulasWithoutValue,
        count: analysis.formulasWithoutValue,
      ),
    );
  }
  final yearMismatches = analysis.issues
      .where((i) => i.kind == IssueKind.yearMismatch)
      .length;
  if (yearMismatches > 0) {
    warnings.add(
      ImportWarning(ImportWarningKind.yearMismatch, count: yearMismatches),
    );
  }
  final uncategorised = perCategory[null]?[0] ?? 0;
  if (uncategorised > 0) {
    warnings.add(
      ImportWarning(ImportWarningKind.uncategorised, count: uncategorised),
    );
  }
  final dupIncluded = included
      .where((t) => t.dup == DupStatus.existing || t.dup == DupStatus.batch)
      .length;
  if (dupIncluded > 0) {
    warnings.add(
      ImportWarning(ImportWarningKind.duplicatesIncluded, count: dupIncluded),
    );
  }

  final excluded = set.txns.where((t) => !t.included);
  final usedCategories = {for (final t in included) t.draft.categoryId};
  final usedTags = {for (final t in included) ...t.draft.tagIds};
  final usedAccounts = {
    for (final t in included) ...[
      t.draft.accountId,
      ?t.draft.transferAccountId,
    ],
  };
  return ImportSummary(
    sheetRows: analysis.rows.length,
    transactions: included.length,
    transfers: transfers,
    skippedDuplicates: excluded
        .where((t) => t.dup == DupStatus.existing || t.dup == DupStatus.batch)
        .length,
    alreadyImported: excluded
        .where((t) => t.dup == DupStatus.alreadyImported)
        .length,
    invalidRows: invalid,
    subtotalRows: analysis.count(RowClass.subtotal),
    noDateRows: analysis.count(RowClass.noDate),
    accounts: accounts,
    categories: categories,
    warnings: warnings,
    newAccounts: set.accounts
        .where((a) => usedAccounts.contains(a.pendingId))
        .length,
    newCategories: set.categories
        .where(
          (c) =>
              usedCategories.contains(c.pendingId) ||
              set.categories.any(
                (x) =>
                    x.parentId == c.pendingId &&
                    usedCategories.contains(x.pendingId),
              ),
        )
        .length,
    newTags: set.tags.where((t) => usedTags.contains(t.pendingId)).length,
    categorisedByRules: categorisedByRules,
  );
}

/// Closing balance and mismatch count of one account.
@immutable
class BalanceReportLike {
  const BalanceReportLike(this.closing, this.mismatches);

  final int? closing;
  final int mismatches;
}
