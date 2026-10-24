import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/features/categories/domain/drafts.dart';

final customFieldsRepositoryProvider = Provider<CustomFieldsRepository>(
  (ref) => CustomFieldsRepository(
    ref.watch(databaseProvider),
    ref.watch(syncWriterProvider),
  ),
);

/// Thrown when changing the type of a field that already has values.
class CustomFieldTypeLockedException implements Exception {
  const CustomFieldTypeLockedException();
}

/// Writes for custom field definitions (`custom_field_defs`). Values are
/// written by the transactions/accounts features (through
/// `LedgerRepository` for transactions).
class CustomFieldsRepository {
  CustomFieldsRepository(this.db, this.writer);

  final AppDatabase db;
  final SyncWriter writer;

  Future<String> create(CustomFieldDraft draft) => writer.transaction(() async {
    _check(draft);
    final max = db.customFieldDefs.sortOrder.max();
    final row =
        await (db.selectOnly(db.customFieldDefs)
              ..addColumns([max])
              ..where(db.customFieldDefs.deletedAt.isNull()))
            .getSingle();
    return await writer.insert(
      db.customFieldDefs,
      _companion(draft).copyWith(sortOrder: Value((row.read(max) ?? -1) + 1)),
    );
  });

  /// Updates a definition. The type can only change while no values exist
  /// (see [valueCount]); otherwise [CustomFieldTypeLockedException] is
  /// thrown.
  Future<void> update(String id, CustomFieldDraft draft) =>
      writer.transaction(() async {
        _check(draft);
        final existing = await (db.select(
          db.customFieldDefs,
        )..where((d) => d.id.equals(id))).getSingleOrNull();
        if (existing == null) throw StateError('Custom field $id not found');
        if (existing.type != draft.type && await valueCount(id) > 0) {
          throw const CustomFieldTypeLockedException();
        }
        await writer.update(db.customFieldDefs, id, _companion(draft));
      });

  Future<void> setArchived(String id, {required bool archived}) =>
      writer.update(
        db.customFieldDefs,
        id,
        CustomFieldDefsCompanion(archived: Value(archived)),
      );

  /// Soft-deletes the definition and all its values.
  Future<void> delete(String id) => writer.transaction(() async {
    await writer.deleteWhere(db.customFieldValues, 'field_id', id);
    await writer.delete(db.customFieldDefs, id);
  });

  Future<void> reorder(List<String> orderedIds) => writer.transaction(() async {
    for (var i = 0; i < orderedIds.length; i++) {
      await writer.update(
        db.customFieldDefs,
        orderedIds[i],
        CustomFieldDefsCompanion(sortOrder: Value(i)),
      );
    }
  });

  Future<int> valueCount(String id) async {
    final c = db.customFieldValues.id.count();
    final row =
        await (db.selectOnly(db.customFieldValues)
              ..addColumns([c])
              ..where(
                db.customFieldValues.fieldId.equals(id) &
                    db.customFieldValues.deletedAt.isNull(),
              ))
            .getSingle();
    final n = row.read(c);
    return n ?? 0;
  }

  void _check(CustomFieldDraft d) {
    final p = d.validate();
    if (p.isNotEmpty) {
      throw ArgumentError('Invalid custom field: ${p.join(', ')}');
    }
  }

  CustomFieldDefsCompanion _companion(CustomFieldDraft d) =>
      CustomFieldDefsCompanion(
        name: Value(d.name.trim()),
        type: Value(d.type),
        options: Value(jsonEncode(d.hasOptions ? d.cleanOptions : const [])),
        appliesTo: Value(d.appliesTo.name),
        archived: Value(d.archived),
      );
}

/// Number of live values per custom field id.
final customFieldValueCountsProvider = StreamProvider<Map<String, int>>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT field_id AS id, COUNT(*) AS c FROM custom_field_values '
        'WHERE deleted_at IS NULL GROUP BY field_id',
        readsFrom: {db.customFieldValues},
      )
      .watch()
      .map(
        (rows) => {
          for (final r in rows) r.read<String>('id'): r.read<int>('c'),
        },
      );
});
