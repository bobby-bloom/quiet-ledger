import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/import/domain/dedupe.dart';
import 'package:personal_finance/features/import/domain/import_analysis.dart';
import 'package:personal_finance/features/import/domain/import_drafts.dart';
import 'package:personal_finance/features/import/domain/source_reader.dart';

final importRepositoryProvider = Provider<ImportRepository>(
  (ref) => ImportRepository(
    ref.watch(databaseProvider),
    ref.watch(syncWriterProvider),
    ref.watch(ledgerRepositoryProvider),
  ),
);

/// All import batches, newest first, with their live row counts.
final importHistoryProvider = StreamProvider<List<ImportBatchInfo>>(
  (ref) => ref.watch(importRepositoryProvider).watchHistory(),
);

/// A file that took part in a batch.
@immutable
class ImportFileInfo {
  const ImportFileInfo({
    required this.name,
    required this.hash,
    required this.rows,
  });

  factory ImportFileInfo.fromJson(Map<String, Object?> j) => ImportFileInfo(
    name: j['name'] as String? ?? '',
    hash: j['hash'] as String? ?? '',
    rows: (j['rows'] as num?)?.toInt() ?? 0,
  );

  final String name;
  final String hash;

  /// Transactions created from this file.
  final int rows;

  Map<String, Object?> toJson() => {'name': name, 'hash': hash, 'rows': rows};
}

/// One row of the import history.
@immutable
class ImportBatchInfo {
  const ImportBatchInfo({
    required this.batch,
    required this.liveCount,
    required this.summary,
  });

  final ImportBatch batch;

  /// Transactions of the batch that still exist.
  final int liveCount;
  final Map<String, Object?> summary;

  bool get isUndone => batch.undoneAt != null;

  List<ImportFileInfo> get files => [
    for (final f in (summary['files'] as List? ?? const []))
      if (f is Map) ImportFileInfo.fromJson(f.cast()),
  ];

  int intOf(String key) => (summary[key] as num?)?.toInt() ?? 0;
}

/// Result of [ImportRepository.commit].
@immutable
class ImportCommitResult {
  const ImportCommitResult({
    required this.batchId,
    required this.transactionIds,
    required this.createdIds,
  });

  final String batchId;
  final List<String> transactionIds;

  /// Pending id → real id of every created account, category and tag.
  final Map<String, String> createdIds;
}

/// Reads the data an import is compared with, writes a batch in one DB
/// transaction and undoes batches. Every write goes through [SyncWriter] /
/// [LedgerRepository].
class ImportRepository {
  ImportRepository(
    this.db,
    this.writer,
    this.ledger, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase db;
  final SyncWriter writer;
  final LedgerRepository ledger;
  final DateTime Function() _now;

  // --------------------------------------------------------------- reads --

  /// Snapshot of accounts, categories, tags, custom fields and duplicate
  /// hashes. [profileId] / [files] select the earlier batches used for
  /// incremental re-import.
  Future<ImportContext> loadContext({
    String? profileId,
    List<ImportFileInfo> files = const [],
  }) async {
    final balances = await ledger.balances();
    final accounts = await (db.select(
      db.accounts,
    )..where((a) => a.deletedAt.isNull())).get();
    final categories = await (db.select(
      db.categories,
    )..where((c) => c.deletedAt.isNull())).get();
    final tags = await (db.select(
      db.tags,
    )..where((t) => t.deletedAt.isNull())).get();
    final fields =
        await (db.select(db.customFieldDefs)..where(
              (f) => f.deletedAt.isNull() & f.appliesTo.equals('transaction'),
            ))
            .get();

    final existing = <String, int>{};
    final rows = await db
        .customSelect(
          'SELECT date, amount_minor, payee, note, dedupe_hash '
          'FROM transactions WHERE deleted_at IS NULL',
          readsFrom: {db.transactions},
        )
        .get();
    for (final r in rows) {
      final amount = r.read<int>('amount_minor');
      final stored = r.readNullable<String>('dedupe_hash');
      final h = stored == null || stored.isEmpty
          ? dedupeHash(
              date: r.read<DateTime>('date'),
              amountMinor: amount,
              payee: r.readNullable<String>('payee'),
              note: r.readNullable<String>('note'),
            )
          : legHash(stored, amount);
      if (h.isNotEmpty) existing[h] = (existing[h] ?? 0) + 1;
    }

    return ImportContext(
      accounts: [
        for (final a in accounts)
          ExistingAccount(
            id: a.id,
            name: a.name,
            type: a.type,
            balanceMinor: balances[a.id] ?? a.openingBalanceMinor,
            openingMinor: a.openingBalanceMinor,
            archived: a.archived,
          ),
      ],
      categories: [
        for (final c in categories)
          ExistingCategory(
            id: c.id,
            name: c.name,
            parentId: c.parentId,
            kind: c.kind,
            archived: c.archived,
          ),
      ],
      tags: [for (final t in tags) ExistingTag(id: t.id, name: t.name)],
      customFields: [
        for (final f in fields)
          ExistingField(
            id: f.id,
            name: f.name,
            type: f.type,
            options: _decodeOptions(f.options),
          ),
      ],
      existingHashes: existing,
      previousHashes: await previousHashes(profileId: profileId, files: files),
    );
  }

  /// Hashes of all rows (also deleted ones) of earlier, not undone batches
  /// of [profileId] or containing one of [files] (same name or same
  /// content hash).
  Future<Map<String, int>> previousHashes({
    String? profileId,
    List<ImportFileInfo> files = const [],
  }) async {
    if (profileId == null && files.isEmpty) return const {};
    final batches = await (db.select(
      db.importBatches,
    )..where((b) => b.deletedAt.isNull() & b.undoneAt.isNull())).get();
    final names = {for (final f in files) f.name.toLowerCase()};
    final hashes = {for (final f in files) f.hash};
    final ids = <String>[];
    for (final b in batches) {
      if (profileId != null && b.profileId == profileId) {
        ids.add(b.id);
        continue;
      }
      final info = ImportBatchInfo(
        batch: b,
        liveCount: 0,
        summary: _decodeSummary(b.summary),
      );
      if (info.files.any(
        (f) => names.contains(f.name.toLowerCase()) || hashes.contains(f.hash),
      )) {
        ids.add(b.id);
      }
    }
    if (ids.isEmpty) return const {};
    final out = <String, int>{};
    for (final chunk in ids.slices(500)) {
      final rows = await (db.select(
        db.transactions,
      )..where((t) => t.importBatchId.isIn(chunk))).get();
      for (final t in rows) {
        final stored = t.dedupeHash;
        if (stored == null || stored.isEmpty) continue;
        final h = legHash(stored, t.amountMinor);
        if (h.isNotEmpty) out[h] = (out[h] ?? 0) + 1;
      }
    }
    return out;
  }

  Stream<List<ImportBatchInfo>> watchHistory() {
    final batches =
        (db.select(db.importBatches)
              ..where((b) => b.deletedAt.isNull())
              ..orderBy([
                (b) => OrderingTerm(
                  expression: b.importedAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .watch();
    return batches.asyncMap((list) async {
      final counts = <String, int>{};
      final rows = await db
          .customSelect(
            'SELECT import_batch_id AS b, COUNT(*) AS n FROM transactions '
            'WHERE deleted_at IS NULL AND import_batch_id IS NOT NULL '
            'GROUP BY import_batch_id',
            readsFrom: {db.transactions},
          )
          .get();
      for (final r in rows) {
        counts[r.read<String>('b')] = r.read<int>('n');
      }
      return [
        for (final b in list)
          ImportBatchInfo(
            batch: b,
            liveCount: counts[b.id] ?? 0,
            summary: _decodeSummary(b.summary),
          ),
      ];
    });
  }

  Future<ImportBatchInfo?> batch(String id) async {
    final b = await (db.select(
      db.importBatches,
    )..where((x) => x.id.equals(id))).getSingleOrNull();
    if (b == null) return null;
    final ids = await transactionIdsOf(id);
    return ImportBatchInfo(
      batch: b,
      liveCount: ids.length,
      summary: _decodeSummary(b.summary),
    );
  }

  /// Live transactions created by batch [batchId] (both legs of transfers).
  Future<List<String>> transactionIdsOf(String batchId) async {
    final rows =
        await (db.select(db.transactions)..where(
              (t) => t.importBatchId.equals(batchId) & t.deletedAt.isNull(),
            ))
            .get();
    return [for (final r in rows) r.id];
  }

  // -------------------------------------------------------------- writes --

  /// Writes [set] in ONE DB transaction: new accounts, categories (parents
  /// first) and tags, the `import_batches` row, then all included
  /// transactions via [LedgerRepository.createAll] with `importBatchId`,
  /// `importRowRef` and `dedupeHash` set.
  Future<ImportCommitResult> commit({
    required ImportDraftSet set,
    required List<ImportFileInfo> files,
    required Map<String, Object?> summary,
    String? profileId,
  }) {
    final included = set.included;
    return writer.transaction(() async {
      final ids = <String, String>{};
      String resolve(String id) => ids[id] ?? id;

      final usedAccounts = {
        for (final t in included) ...[
          t.draft.accountId,
          ?t.draft.transferAccountId,
        ],
      };
      final usedCategories = {for (final t in included) t.draft.categoryId};
      final neededCategories = <String>{};
      for (final c in set.categories.reversed) {
        if (usedCategories.contains(c.pendingId) ||
            neededCategories.contains(c.pendingId)) {
          neededCategories.add(c.pendingId);
          if (c.parentId != null) neededCategories.add(c.parentId!);
        }
      }
      final usedTags = {for (final t in included) ...t.draft.tagIds};

      var accountOrder = await _maxSort(db.accounts, 'sort_order');
      for (final a in set.accounts) {
        if (!usedAccounts.contains(a.pendingId)) continue;
        ids[a.pendingId] = await writer.insert(
          db.accounts,
          AccountsCompanion(
            name: Value(a.name),
            type: Value(a.type),
            openingBalanceMinor: Value(a.openingMinor),
            openingDate: Value(dateOnly(a.openingDate ?? _now())),
            icon: Value(_accountIcon(a.type)),
            sortOrder: Value(++accountOrder),
          ),
        );
      }
      var categoryOrder = await _maxSort(db.categories, 'sort_order');
      for (final c in set.categories) {
        if (!neededCategories.contains(c.pendingId)) continue;
        ids[c.pendingId] = await writer.insert(
          db.categories,
          CategoriesCompanion(
            name: Value(c.name),
            kind: Value(c.kind),
            parentId: Value(c.parentId == null ? null : resolve(c.parentId!)),
            sortOrder: Value(++categoryOrder),
          ),
        );
      }
      for (final t in set.tags) {
        if (!usedTags.contains(t.pendingId)) continue;
        ids[t.pendingId] = await writer.insert(
          db.tags,
          TagsCompanion(name: Value(t.name)),
        );
      }

      final perFile = <String, int>{};
      for (final t in included) {
        final file = t.ref.split('|').first;
        perFile[file] = (perFile[file] ?? 0) + 1;
      }
      final fileInfos = [
        for (final f in files)
          ImportFileInfo(
            name: f.name,
            hash: f.hash,
            rows: perFile[f.name] ?? 0,
          ),
      ];
      final batchId = await writer.insert(
        db.importBatches,
        ImportBatchesCompanion(
          fileName: Value(files.map((f) => f.name).join(', ')),
          fileHash: Value(
            files.length == 1
                ? files.single.hash
                : sha256Hex(utf8.encode(files.map((f) => f.hash).join())),
          ),
          profileId: Value(profileId),
          importedAt: Value(_now()),
          rowCount: Value(included.length),
          summary: Value(
            jsonEncode({
              ...summary,
              'files': [for (final f in fileInfos) f.toJson()],
              'createdAccounts': [
                for (final a in set.accounts) ?ids[a.pendingId],
              ],
              'createdCategories': [
                for (final c in set.categories) ?ids[c.pendingId],
              ],
              'createdTags': [for (final t in set.tags) ?ids[t.pendingId]],
            }),
          ),
        ),
      );

      final drafts = [
        for (final t in included)
          t.draft.copyWith(
            accountId: resolve(t.draft.accountId),
            transferAccountId: t.draft.transferAccountId == null
                ? null
                : resolve(t.draft.transferAccountId!),
            categoryId: t.draft.categoryId == null
                ? null
                : resolve(t.draft.categoryId!),
            tagIds: [for (final tag in t.draft.tagIds) resolve(tag)],
            importBatchId: batchId,
          ),
      ];
      final unresolved = drafts.where(
        (d) =>
            PendingIds.isPending(d.accountId) ||
            PendingIds.isPending(d.transferAccountId) ||
            PendingIds.isPending(d.categoryId),
      );
      if (unresolved.isNotEmpty) {
        throw StateError('Unresolved import ids: ${unresolved.first}');
      }
      final txnIds = await ledger.createAll(drafts);
      return ImportCommitResult(
        batchId: batchId,
        transactionIds: txnIds,
        createdIds: ids,
      );
    });
  }

  /// Undoes batch [batchId] completely: soft-deletes all its transactions,
  /// marks the batch undone and, with [removeCreated], deletes the
  /// accounts, categories and tags it created when nothing uses them any
  /// more. Returns the number of deleted transactions.
  Future<int> undo(String batchId, {bool removeCreated = true}) =>
      writer.transaction(() async {
        final rows =
            await (db.select(db.transactions)..where(
                  (t) => t.importBatchId.equals(batchId) & t.deletedAt.isNull(),
                ))
                .get();
        // Deleting one leg of a transfer deletes its peer.
        final ids = <String>[];
        final covered = <String>{};
        for (final t in rows) {
          if (covered.contains(t.id)) continue;
          ids.add(t.id);
          covered.add(t.id);
          if (t.transferPeerId != null) covered.add(t.transferPeerId!);
        }
        await ledger.deleteAll(ids);
        await writer.update(
          db.importBatches,
          batchId,
          ImportBatchesCompanion(undoneAt: Value(_now())),
        );
        if (removeCreated) await _removeCreated(batchId);
        return rows.length;
      });

  Future<void> _removeCreated(String batchId) async {
    final b = await (db.select(
      db.importBatches,
    )..where((x) => x.id.equals(batchId))).getSingleOrNull();
    if (b == null) return;
    final s = _decodeSummary(b.summary);
    List<String> list(String k) => [
      for (final x in (s[k] as List? ?? const [])) '$x',
    ];
    for (final id in list('createdAccounts')) {
      if (!await _used(
        'SELECT 1 FROM transactions WHERE account_id = ? AND deleted_at IS NULL LIMIT 1',
        id,
      )) {
        await writer.delete(db.accounts, id);
      }
    }
    // Children before parents.
    final cats = list('createdCategories').reversed;
    for (final id in cats) {
      final used =
          await _used(
            'SELECT 1 FROM transactions WHERE category_id = ? AND deleted_at IS NULL LIMIT 1',
            id,
          ) ||
          await _used(
            'SELECT 1 FROM transaction_splits WHERE category_id = ? AND deleted_at IS NULL LIMIT 1',
            id,
          ) ||
          await _used(
            'SELECT 1 FROM categories WHERE parent_id = ? AND deleted_at IS NULL LIMIT 1',
            id,
          ) ||
          await _used(
            'SELECT 1 FROM budgets WHERE category_id = ? AND deleted_at IS NULL LIMIT 1',
            id,
          ) ||
          await _used(
            'SELECT 1 FROM budget_rules WHERE category_id = ? AND deleted_at IS NULL LIMIT 1',
            id,
          );
      if (!used) await writer.delete(db.categories, id);
    }
    for (final id in list('createdTags')) {
      if (!await _used(
        'SELECT 1 FROM transaction_tags WHERE tag_id = ? AND deleted_at IS NULL LIMIT 1',
        id,
      )) {
        await writer.delete(db.tags, id);
      }
    }
  }

  Future<bool> _used(String sql, String id) async {
    final rows = await db
        .customSelect(sql, variables: [Variable<String>(id)])
        .get();
    return rows.isNotEmpty;
  }

  Future<int> _maxSort(TableInfo<Table, dynamic> table, String column) async {
    final r = await db
        .customSelect(
          'SELECT COALESCE(MAX($column), 0) AS m FROM ${table.actualTableName} '
          'WHERE deleted_at IS NULL',
        )
        .getSingle();
    return r.read<int>('m');
  }

  static String _accountIcon(AccountType t) => switch (t) {
    AccountType.checking => 'bank',
    AccountType.savings => 'savings',
    AccountType.cash => 'cash',
    AccountType.creditCard => 'card',
    AccountType.investment => 'investment',
    AccountType.loan || AccountType.otherLiability => 'loan',
    AccountType.otherAsset => 'asset',
  };

  static Map<String, Object?> _decodeSummary(String s) {
    try {
      final v = jsonDecode(s);
      return v is Map ? v.cast<String, Object?>() : const {};
    } on FormatException {
      return const {};
    }
  }

  static List<String> _decodeOptions(String s) {
    try {
      final v = jsonDecode(s);
      return v is List ? [for (final x in v) '$x'] : const [];
    } on FormatException {
      return const [];
    }
  }
}
