import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/features/transactions/domain/txn_filter.dart';

final savedFiltersRepositoryProvider = Provider<SavedFiltersRepository>(
  (ref) => SavedFiltersRepository(
    ref.watch(databaseProvider),
    ref.watch(syncWriterProvider),
  ),
);

/// Saved filters ("smart lists"), ordered by `sortOrder`.
final savedFiltersProvider = StreamProvider<List<SavedFilter>>(
  (ref) => ref.watch(savedFiltersRepositoryProvider).watchAll(),
);

/// Decodes a saved filter's JSON; corrupt JSON yields an empty filter.
TxnFilter decodeSavedFilter(SavedFilter f) {
  try {
    return TxnFilter.fromJson((jsonDecode(f.filter) as Map).cast());
  } on Object {
    return TxnFilter.empty;
  }
}

/// CRUD for `saved_filters`. Writes go through [SyncWriter].
class SavedFiltersRepository {
  SavedFiltersRepository(this.db, this.writer);

  final AppDatabase db;
  final SyncWriter writer;

  Stream<List<SavedFilter>> watchAll() =>
      (db.select(db.savedFilters)
            ..where((f) => f.deletedAt.isNull())
            ..orderBy([
              (f) => OrderingTerm(expression: f.sortOrder),
              (f) => OrderingTerm(expression: f.name),
            ]))
          .watch();

  Future<SavedFilter?> byId(String id) => (db.select(
    db.savedFilters,
  )..where((f) => f.id.equals(id) & f.deletedAt.isNull())).getSingleOrNull();

  Future<String> create(String name, TxnFilter filter) async {
    final max = db.savedFilters.sortOrder.max();
    final row =
        await (db.selectOnly(db.savedFilters)
              ..addColumns([max])
              ..where(db.savedFilters.deletedAt.isNull()))
            .getSingle();
    return await writer.insert(
      db.savedFilters,
      SavedFiltersCompanion(
        name: Value(name.trim()),
        filter: Value(jsonEncode(filter.toJson())),
        sortOrder: Value((row.read(max) ?? -1) + 1),
      ),
    );
  }

  Future<void> update(String id, {String? name, TxnFilter? filter}) =>
      writer.update(
        db.savedFilters,
        id,
        SavedFiltersCompanion(
          name: name == null ? const Value.absent() : Value(name.trim()),
          filter: filter == null
              ? const Value.absent()
              : Value(jsonEncode(filter.toJson())),
        ),
      );

  Future<void> delete(String id) => writer.delete(db.savedFilters, id);

  Future<void> restore(String id) => writer.undelete(db.savedFilters, id);

  /// Persists the order of [ids] (drag to reorder).
  Future<void> reorder(List<String> ids) => writer.transaction(() async {
    for (var i = 0; i < ids.length; i++) {
      await writer.update(
        db.savedFilters,
        ids[i],
        SavedFiltersCompanion(sortOrder: Value(i)),
      );
    }
  });
}
