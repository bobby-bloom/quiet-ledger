import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';

final templatesRepositoryProvider = Provider<TemplatesRepository>(
  (ref) => TemplatesRepository(
    ref.watch(databaseProvider),
    ref.watch(syncWriterProvider),
  ),
);

/// Transaction templates ("favourite transactions"), ordered.
final templatesProvider = StreamProvider<List<TxnTemplate>>(
  (ref) => ref.watch(templatesRepositoryProvider).watchAll(),
);

/// Decodes a template's draft (`fields` JSON = [TxnDraft.toJson]). Returns
/// null when the JSON is corrupt.
TxnDraft? templateDraft(TxnTemplate t) {
  try {
    return TxnDraft.fromJson((jsonDecode(t.fields) as Map).cast());
  } on Object {
    return null;
  }
}

/// CRUD for `transaction_templates`. Writes go through [SyncWriter].
class TemplatesRepository {
  TemplatesRepository(this.db, this.writer);

  final AppDatabase db;
  final SyncWriter writer;

  Stream<List<TxnTemplate>> watchAll() =>
      (db.select(db.transactionTemplates)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm(expression: t.sortOrder),
              (t) => OrderingTerm(expression: t.name),
            ]))
          .watch();

  Future<TxnTemplate?> byId(String id) => (db.select(
    db.transactionTemplates,
  )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();

  /// Templates do not keep import/recurring bookkeeping.
  static String encode(TxnDraft d) => jsonEncode(
    d
        .copyWith(
          recurringRuleId: null,
          importBatchId: null,
          importRowRef: null,
          dedupeHash: null,
        )
        .toJson(),
  );

  Future<String> create(String name, TxnDraft draft) async {
    final max = db.transactionTemplates.sortOrder.max();
    final row =
        await (db.selectOnly(db.transactionTemplates)
              ..addColumns([max])
              ..where(db.transactionTemplates.deletedAt.isNull()))
            .getSingle();
    return await writer.insert(
      db.transactionTemplates,
      TransactionTemplatesCompanion(
        name: Value(name.trim()),
        fields: Value(encode(draft)),
        sortOrder: Value((row.read(max) ?? -1) + 1),
      ),
    );
  }

  Future<void> update(String id, {String? name, TxnDraft? draft}) =>
      writer.update(
        db.transactionTemplates,
        id,
        TransactionTemplatesCompanion(
          name: name == null ? const Value.absent() : Value(name.trim()),
          fields: draft == null ? const Value.absent() : Value(encode(draft)),
        ),
      );

  Future<void> delete(String id) => writer.delete(db.transactionTemplates, id);

  Future<void> restore(String id) =>
      writer.undelete(db.transactionTemplates, id);

  Future<void> reorder(List<String> ids) => writer.transaction(() async {
    for (var i = 0; i < ids.length; i++) {
      await writer.update(
        db.transactionTemplates,
        ids[i],
        TransactionTemplatesCompanion(sortOrder: Value(i)),
      );
    }
  });
}
