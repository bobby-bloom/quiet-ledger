import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';

final ledgerRepositoryProvider = Provider<LedgerRepository>(
  (ref) => LedgerRepository(
    ref.watch(databaseProvider),
    ref.watch(syncWriterProvider),
  ),
);

/// Shared write/read path for transactions, including transfers (two linked
/// legs), splits, tags and custom field values. Every write goes through
/// [SyncWriter].
class LedgerRepository {
  LedgerRepository(this.db, this.writer);

  final AppDatabase db;
  final SyncWriter writer;

  // ------------------------------------------------------------- writes ---

  /// Creates a transaction (both legs for a transfer). Returns the id of the
  /// leg in `draft.accountId`.
  Future<String> create(TxnDraft draft) {
    final problems = draft.validate();
    if (problems.isNotEmpty) {
      throw ArgumentError('Invalid transaction: ${problems.join(', ')}');
    }
    return writer.transaction(() async {
      final d = draft.copyWith(date: dateOnly(draft.date));
      final id = await writer.insert(db.transactions, _companion(d));
      if (d.isTransfer) {
        final peer = await writer.insert(
          db.transactions,
          _companion(
            d.copyWith(
              accountId: d.transferAccountId,
              amountMinor: -d.amountMinor,
              transferAccountId: d.accountId,
            ),
          ),
        );
        await writer.update(
          db.transactions,
          id,
          TransactionsCompanion(transferPeerId: Value(peer)),
        );
        await writer.update(
          db.transactions,
          peer,
          TransactionsCompanion(transferPeerId: Value(id)),
        );
        await _writeChildren(peer, d.copyWith(splits: const []));
      }
      await _writeChildren(id, d);
      return id;
    });
  }

  /// Creates many transactions in one DB transaction (import, recurring).
  Future<List<String>> createAll(List<TxnDraft> drafts) =>
      writer.transaction(() async => [for (final d in drafts) await create(d)]);

  /// Replaces transaction [id] with [draft]. Handles type changes to and from
  /// transfers.
  Future<void> update(String id, TxnDraft draft) {
    final problems = draft.validate();
    if (problems.isNotEmpty) {
      throw ArgumentError('Invalid transaction: ${problems.join(', ')}');
    }
    return writer.transaction(() async {
      final existing = await txnById(id);
      if (existing == null) throw StateError('Transaction $id not found');
      final d = draft.copyWith(date: dateOnly(draft.date));
      final wasTransfer = existing.transferPeerId != null;

      if (wasTransfer && !d.isTransfer) {
        await _deleteSingle(existing.transferPeerId!);
      }
      await writer.update(db.transactions, id, _companion(d, forUpdate: true));
      await _clearChildren(id);
      await _writeChildren(id, d);

      if (d.isTransfer) {
        final peerDraft = d.copyWith(
          accountId: d.transferAccountId,
          amountMinor: -d.amountMinor,
          transferAccountId: d.accountId,
          splits: const [],
        );
        String peerId;
        if (wasTransfer) {
          peerId = existing.transferPeerId!;
          await writer.update(
            db.transactions,
            peerId,
            _companion(peerDraft, forUpdate: true),
          );
          await _clearChildren(peerId);
        } else {
          peerId = await writer.insert(
            db.transactions,
            _companion(peerDraft).copyWith(transferPeerId: Value(id)),
          );
        }
        await _writeChildren(peerId, peerDraft);
        await writer.update(
          db.transactions,
          id,
          TransactionsCompanion(transferPeerId: Value(peerId)),
        );
      } else if (wasTransfer) {
        await writer.update(
          db.transactions,
          id,
          const TransactionsCompanion(transferPeerId: Value(null)),
        );
      }
    });
  }

  /// Updates selected columns on many transactions (bulk edit). Transfer
  /// peers get the same date/status.
  Future<void> bulkUpdate(
    Iterable<String> ids, {
    String? categoryId,
    TxnStatus? status,
    DateTime? date,
    String? accountId,
    List<String>? addTagIds,
  }) {
    return writer.transaction(() async {
      for (final id in ids) {
        final t = await txnById(id);
        if (t == null) continue;
        final isTransfer = t.transferPeerId != null;
        final c = TransactionsCompanion(
          categoryId: categoryId != null && !isTransfer
              ? Value(categoryId)
              : const Value.absent(),
          status: status != null ? Value(status) : const Value.absent(),
          date: date != null ? Value(dateOnly(date)) : const Value.absent(),
          accountId: accountId != null && !isTransfer
              ? Value(accountId)
              : const Value.absent(),
        );
        await writer.update(db.transactions, id, c);
        if (isTransfer && (status != null || date != null)) {
          await writer.update(
            db.transactions,
            t.transferPeerId!,
            TransactionsCompanion(status: c.status, date: c.date),
          );
        }
        if (addTagIds != null) {
          final existing = await tagIdsFor(id);
          for (final tag in addTagIds.where((x) => !existing.contains(x))) {
            await writer.insert(
              db.transactionTags,
              TransactionTagsCompanion(
                transactionId: Value(id),
                tagId: Value(tag),
              ),
            );
          }
        }
      }
    });
  }

  /// Soft-deletes a transaction, its transfer peer and children.
  Future<void> delete(String id) => writer.transaction(() async {
    final t = await txnById(id, includeDeleted: true);
    if (t == null) return;
    await _deleteSingle(id);
    if (t.transferPeerId != null) await _deleteSingle(t.transferPeerId!);
  });

  Future<void> deleteAll(Iterable<String> ids) => writer.transaction(() async {
    for (final id in ids) {
      await delete(id);
    }
  });

  /// Restores a soft-deleted transaction (undo), including its peer and
  /// children that were deleted together with it.
  Future<void> restore(String id) => writer.transaction(() async {
    final t = await txnById(id, includeDeleted: true);
    if (t == null || t.deletedAt == null) return;
    await _restoreSingle(t);
    if (t.transferPeerId != null) {
      final p = await txnById(t.transferPeerId!, includeDeleted: true);
      if (p != null) await _restoreSingle(p);
    }
  });

  Future<void> _restoreSingle(Txn t) async {
    final at = t.deletedAt!;
    await writer.undelete(db.transactions, t.id);
    // Children deleted in the same operation share the timestamp (±2 s).
    final splits =
        await (db.select(db.transactionSplits)..where(
              (x) =>
                  x.transactionId.equals(t.id) &
                  x.deletedAt.isBetweenValues(at - 2000, at + 2000),
            ))
            .get();
    for (final x in splits) {
      await writer.undelete(db.transactionSplits, x.id);
    }
    final tags =
        await (db.select(db.transactionTags)..where(
              (x) =>
                  x.transactionId.equals(t.id) &
                  x.deletedAt.isBetweenValues(at - 2000, at + 2000),
            ))
            .get();
    for (final x in tags) {
      await writer.undelete(db.transactionTags, x.id);
    }
    final cfv =
        await (db.select(db.customFieldValues)..where(
              (v) =>
                  v.entityId.equals(t.id) &
                  v.deletedAt.isBetweenValues(at - 2000, at + 2000),
            ))
            .get();
    for (final v in cfv) {
      await writer.undelete(db.customFieldValues, v.id);
    }
  }

  Future<void> _deleteSingle(String id) async {
    await _clearChildren(id);
    await writer.delete(db.transactions, id);
  }

  Future<void> _clearChildren(String id) async {
    await writer.deleteWhere(db.transactionSplits, 'transaction_id', id);
    await writer.deleteWhere(db.transactionTags, 'transaction_id', id);
    await writer.deleteWhere(db.customFieldValues, 'entity_id', id);
  }

  Future<void> _writeChildren(String id, TxnDraft d) async {
    var i = 0;
    for (final s in d.splits) {
      await writer.insert(
        db.transactionSplits,
        TransactionSplitsCompanion(
          transactionId: Value(id),
          categoryId: Value(s.categoryId),
          amountMinor: Value(s.amountMinor),
          note: Value(s.note),
          sortOrder: Value(i++),
        ),
      );
    }
    for (final tag in d.tagIds.toSet()) {
      await writer.insert(
        db.transactionTags,
        TransactionTagsCompanion(transactionId: Value(id), tagId: Value(tag)),
      );
    }
    for (final e in d.customFields.entries) {
      if (e.value == null) continue;
      await writer.insert(
        db.customFieldValues,
        CustomFieldValuesCompanion(
          fieldId: Value(e.key),
          entityId: Value(id),
          value: Value(jsonEncode(e.value)),
        ),
      );
    }
  }

  TransactionsCompanion _companion(TxnDraft d, {bool forUpdate = false}) =>
      TransactionsCompanion(
        accountId: Value(d.accountId),
        date: Value(d.date),
        valueDate: Value(d.valueDate),
        amountMinor: Value(d.amountMinor),
        currency: Value(d.currency),
        type: Value(d.type),
        payee: Value(_blankToNull(d.payee)),
        note: Value(_blankToNull(d.note)),
        categoryId: Value(d.isSplit || d.isTransfer ? null : d.categoryId),
        status: Value(d.status),
        recurringRuleId: forUpdate && d.recurringRuleId == null
            ? const Value.absent()
            : Value(d.recurringRuleId),
        importBatchId: forUpdate && d.importBatchId == null
            ? const Value.absent()
            : Value(d.importBatchId),
        importRowRef: forUpdate && d.importRowRef == null
            ? const Value.absent()
            : Value(d.importRowRef),
        dedupeHash: forUpdate && d.dedupeHash == null
            ? const Value.absent()
            : Value(d.dedupeHash),
      );

  static String? _blankToNull(String? s) =>
      s == null || s.trim().isEmpty ? null : s.trim();

  // -------------------------------------------------------------- reads ---

  Future<Txn?> txnById(String id, {bool includeDeleted = false}) =>
      (db.select(db.transactions)..where(
            (t) => includeDeleted
                ? t.id.equals(id)
                : t.id.equals(id) & t.deletedAt.isNull(),
          ))
          .getSingleOrNull();

  Future<List<String>> tagIdsFor(String txnId) async {
    final rows =
        await (db.select(db.transactionTags)..where(
              (t) => t.transactionId.equals(txnId) & t.deletedAt.isNull(),
            ))
            .get();
    return [for (final r in rows) r.tagId];
  }

  Future<List<TxnSplit>> splitsFor(String txnId) =>
      (db.select(db.transactionSplits)
            ..where((s) => s.transactionId.equals(txnId) & s.deletedAt.isNull())
            ..orderBy([(s) => OrderingTerm(expression: s.sortOrder)]))
          .get();

  Future<Map<String, Object?>> customFieldsFor(String entityId) async {
    final rows = await (db.select(
      db.customFieldValues,
    )..where((v) => v.entityId.equals(entityId) & v.deletedAt.isNull())).get();
    return {for (final r in rows) r.fieldId: jsonDecode(r.value)};
  }

  /// Rebuilds the editable draft for transaction [id]. For a transfer the
  /// draft is expressed from the outgoing leg's point of view.
  Future<TxnDraft?> draftFor(String id) async {
    var t = await txnById(id);
    if (t == null) return null;
    if (t.transferPeerId != null && t.amountMinor > 0) {
      final peer = await txnById(t.transferPeerId!);
      if (peer != null) t = peer;
    }
    final tx = t;
    String? target;
    if (tx.transferPeerId != null) {
      target = (await txnById(tx.transferPeerId!))?.accountId;
    }
    final splits = await splitsFor(tx.id);
    return TxnDraft(
      accountId: tx.accountId,
      amountMinor: tx.amountMinor,
      date: tx.date,
      type: tx.type,
      valueDate: tx.valueDate,
      payee: tx.payee,
      note: tx.note,
      categoryId: tx.categoryId,
      transferAccountId: target,
      status: tx.status,
      splits: [
        for (final s in splits)
          SplitDraft(
            amountMinor: s.amountMinor,
            categoryId: s.categoryId,
            note: s.note,
          ),
      ],
      tagIds: await tagIdsFor(tx.id),
      customFields: await customFieldsFor(tx.id),
      recurringRuleId: tx.recurringRuleId,
      importBatchId: tx.importBatchId,
      importRowRef: tx.importRowRef,
      dedupeHash: tx.dedupeHash,
      currency: tx.currency,
    );
  }

  /// Current balance per account: opening balance + all live transactions
  /// up to and including [asOf] (default: no limit). Planned entries are
  /// excluded unless [includePlanned]; pending ones unless
  /// [includePending] is false.
  Stream<Map<String, int>> watchBalances({
    DateTime? asOf,
    bool includePending = true,
    bool includePlanned = false,
  }) {
    final statuses = [
      TxnStatus.cleared.name,
      if (includePending) TxnStatus.pending.name,
      if (includePlanned) TxnStatus.planned.name,
    ];
    final placeholders = List.filled(statuses.length, '?').join(', ');
    final dateClause = asOf == null ? '' : 'AND t.date <= ?';
    return db
        .customSelect(
          'SELECT a.id AS id, a.opening_balance_minor + COALESCE(( '
          'SELECT SUM(t.amount_minor) FROM transactions t '
          'WHERE t.account_id = a.id AND t.deleted_at IS NULL '
          'AND t.status IN ($placeholders) $dateClause '
          '), 0) AS balance FROM accounts a WHERE a.deleted_at IS NULL',
          variables: [
            for (final s in statuses) Variable<String>(s),
            if (asOf != null) Variable<DateTime>(asOf),
          ],
          readsFrom: {db.accounts, db.transactions},
        )
        .watch()
        .map(
          (rows) => {
            for (final r in rows) r.read<String>('id'): r.read<int>('balance'),
          },
        );
  }

  Future<Map<String, int>> balances({
    DateTime? asOf,
    bool includePending = true,
    bool includePlanned = false,
  }) => watchBalances(
    asOf: asOf,
    includePending: includePending,
    includePlanned: includePlanned,
  ).first;
}
