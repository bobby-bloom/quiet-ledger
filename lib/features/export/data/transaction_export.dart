import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/csv/csv_writer.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/features/export/domain/txn_export.dart';

/// Which transactions to export. Dates are ledger dates; [end] is
/// exclusive. Null bounds/accounts mean "no limit".
@immutable
class TxnExportQuery {
  const TxnExportQuery({this.start, this.end, this.accountIds, this.limit});

  final DateTime? start;
  final DateTime? end;
  final Set<String>? accountIds;

  /// Maximum number of *transactions* (for previews).
  final int? limit;

  TxnExportQuery withLimit(int? limit) => TxnExportQuery(
    start: start,
    end: end,
    accountIds: accountIds,
    limit: limit,
  );

  @override
  bool operator ==(Object other) =>
      other is TxnExportQuery &&
      other.start == start &&
      other.end == end &&
      const SetEquality<String>().equals(other.accountIds, accountIds) &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(
    start,
    end,
    accountIds == null ? null : Object.hashAllUnordered(accountIds!),
    limit,
  );
}

/// How the transaction export is split into files.
enum TxnExportLayout {
  /// One CSV with all accounts.
  flat,

  /// A zip with one CSV per account.
  perAccount,
}

/// A finished export file.
@immutable
class ExportFile {
  const ExportFile({
    required this.fileName,
    required this.bytes,
    required this.mimeType,
    required this.rowCount,
  });
  final String fileName;
  final Uint8List bytes;
  final String mimeType;

  /// Data rows written (excluding headers).
  final int rowCount;
}

/// Custom field definitions that apply to transactions (live, by sort
/// order), for [txnExportColumns].
Future<List<TxnExportField>> txnExportFields(AppDatabase db) async {
  final defs =
      await (db.select(db.customFieldDefs)
            ..where(
              (d) => d.deletedAt.isNull() & d.appliesTo.equals('transaction'),
            )
            ..orderBy([(d) => OrderingTerm(expression: d.sortOrder)]))
          .get();
  return [for (final d in defs) TxnExportField(d.id, d.name, d.type)];
}

/// Loads export rows for [query], ordered by date, then creation. Split
/// transactions expand to one row per split line.
Future<List<TxnExportRow>> loadTxnExportRows(
  AppDatabase db,
  TxnExportQuery query,
) async {
  final select = db.select(db.transactions)
    ..where((t) {
      var e = t.deletedAt.isNull();
      if (query.start != null) {
        e = e & t.date.isBiggerOrEqualValue(query.start!);
      }
      if (query.end != null) e = e & t.date.isSmallerThanValue(query.end!);
      if (query.accountIds != null) e = e & t.accountId.isIn(query.accountIds!);
      return e;
    })
    ..orderBy([
      (t) => OrderingTerm(expression: t.date),
      (t) => OrderingTerm(expression: t.createdAt),
      (t) => OrderingTerm(expression: t.id),
    ]);
  if (query.limit != null) select.limit(query.limit!);
  final txns = await select.get();
  if (txns.isEmpty) return const [];

  // Reference data, including deleted rows so names always resolve.
  final accounts = {
    for (final a in await db.select(db.accounts).get()) a.id: a.name,
  };
  final categories = {
    for (final c in await db.select(db.categories).get())
      c.id: (name: c.name, parentId: c.parentId),
  };
  final tagNames = {
    for (final t in await db.select(db.tags).get()) t.id: t.name,
  };

  final ids = [for (final t in txns) t.id];
  final splits = <String, List<TxnSplit>>{};
  final tags = <String, List<String>>{};
  final values = <String, Map<String, Object?>>{};
  final peerAccount = <String, String>{};
  final peerIds = [
    for (final t in txns)
      if (t.transferPeerId != null) t.transferPeerId!,
  ];

  for (final chunk in ids.slices(500)) {
    for (final s
        in await (db.select(db.transactionSplits)
              ..where((s) => s.transactionId.isIn(chunk) & s.deletedAt.isNull())
              ..orderBy([(s) => OrderingTerm(expression: s.sortOrder)]))
            .get()) {
      (splits[s.transactionId] ??= []).add(s);
    }
    for (final tt
        in await (db.select(
              db.transactionTags,
            )..where((x) => x.transactionId.isIn(chunk) & x.deletedAt.isNull()))
            .get()) {
      final name = tagNames[tt.tagId];
      if (name != null) (tags[tt.transactionId] ??= []).add(name);
    }
    for (final v in await (db.select(
      db.customFieldValues,
    )..where((x) => x.entityId.isIn(chunk) & x.deletedAt.isNull())).get()) {
      Object? decoded;
      try {
        decoded = jsonDecode(v.value);
      } on FormatException {
        decoded = v.value;
      }
      (values[v.entityId] ??= {})[v.fieldId] = decoded;
    }
  }
  for (final chunk in peerIds.slices(500)) {
    for (final p in await (db.select(
      db.transactions,
    )..where((x) => x.id.isIn(chunk))).get()) {
      peerAccount[p.id] = p.accountId;
    }
  }

  final rows = <TxnExportRow>[];
  for (final t in txns) {
    final peerAcc = t.transferPeerId == null
        ? null
        : peerAccount[t.transferPeerId!];
    final tagList = [...?tags[t.id]]..sort();
    TxnExportRow row({
      required int amount,
      String? categoryId,
      String? note,
      String? split,
    }) => TxnExportRow(
      id: t.id,
      date: t.date,
      valueDate: t.valueDate,
      accountId: t.accountId,
      accountName: accounts[t.accountId] ?? '',
      type: t.type,
      amountMinor: amount,
      currency: t.currency,
      status: t.status,
      payee: t.payee,
      note: note,
      categoryPath: categoryId == null
          ? null
          : categoryPath(categoryId, categories),
      split: split,
      tags: tagList,
      transferAccountName: peerAcc == null ? null : accounts[peerAcc],
      customFields: values[t.id] ?? const {},
    );

    final lines = splits[t.id];
    if (lines == null || lines.isEmpty) {
      rows.add(
        row(amount: t.amountMinor, categoryId: t.categoryId, note: t.note),
      );
    } else {
      for (var i = 0; i < lines.length; i++) {
        final s = lines[i];
        rows.add(
          row(
            amount: s.amountMinor,
            categoryId: s.categoryId,
            note: s.note ?? t.note,
            split: '${i + 1}/${lines.length}',
          ),
        );
      }
    }
  }
  return rows;
}

/// Builds the transaction export file(s).
///
/// [layout] `flat` → `transactions-<date>.csv`; `perAccount` → a zip with
/// `<account name>.csv` per account that has rows.
Future<ExportFile> exportTransactions(
  AppDatabase db, {
  required TxnExportQuery query,
  required CsvOptions options,
  required TxnExportLabels labels,
  TxnExportLayout layout = TxnExportLayout.flat,
  DateTime? now,
}) async {
  final rows = await loadTxnExportRows(db, query);
  final columns = txnExportColumns(
    labels,
    customFields: await txnExportFields(db),
  );
  final writer = CsvWriter(options);
  final stamp = DateFormat('yyyy-MM-dd').format(now ?? DateTime.now());
  final ext = options.fileExtension;
  if (layout == TxnExportLayout.flat) {
    return ExportFile(
      fileName: 'transactions-$stamp.$ext',
      bytes: writer.encode(columns, rows),
      mimeType: options.mimeType,
      rowCount: rows.length,
    );
  }
  final byAccount = groupBy<TxnExportRow, String>(rows, (r) => r.accountId);
  final archive = Archive();
  final used = <String>{};
  final names = byAccount.map(
    (id, list) => MapEntry(id, list.first.accountName),
  );
  final sortedIds = byAccount.keys.toList()
    ..sort(
      (a, b) => names[a]!.toLowerCase().compareTo(names[b]!.toLowerCase()),
    );
  for (final id in sortedIds) {
    final base = safeFileName(names[id]!, fallback: 'account');
    var name = '$base.$ext';
    for (var i = 2; !used.add(name.toLowerCase()); i++) {
      name = '$base ($i).$ext';
    }
    archive.add(
      ArchiveFile.bytes(name, writer.encode(columns, byAccount[id]!)),
    );
  }
  return ExportFile(
    fileName: 'transactions-by-account-$stamp.zip',
    bytes: ZipEncoder().encodeBytes(archive),
    mimeType: 'application/zip',
    rowCount: rows.length,
  );
}
