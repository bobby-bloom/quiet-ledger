import 'package:drift/drift.dart';
import 'package:personal_finance/core/db/database.dart';

/// Number of rows [purgeTombstones] would remove.
Future<int> countPurgeableTombstones(
  AppDatabase db,
  Duration olderThan, {
  DateTime? now,
}) async {
  final cutoffMs = (now ?? DateTime.now())
      .subtract(olderThan)
      .millisecondsSinceEpoch;
  var total = 0;
  for (final name in syncedTableNames) {
    final r = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM "$name" '
          'WHERE deleted_at IS NOT NULL AND deleted_at < ?',
          variables: [Variable<int>(cutoffMs)],
        )
        .getSingle();
    total += r.data['n']! as int;
  }
  return total;
}

/// Hard-deletes soft-deleted rows whose `deleted_at` is older than
/// [olderThan] in every synced table, together with their `change_log`
/// entries (and stale full-text index rows). Returns the number of rows
/// removed. Runs in one DB transaction.
///
/// Only safe while no sync backend is configured (PLAN.md §4.3): other
/// devices could otherwise miss the deletes. The startup task checks this.
Future<int> purgeTombstones(
  AppDatabase db,
  Duration olderThan, {
  DateTime? now,
}) async {
  final cutoff = (now ?? DateTime.now()).subtract(olderThan);
  final cutoffMs = cutoff.millisecondsSinceEpoch;
  var removed = 0;
  final touched = <String>[];
  await db.transaction(() async {
    for (final name in syncedTableNames) {
      const cond = 'deleted_at IS NOT NULL AND deleted_at < ?';
      final count = await db
          .customSelect(
            'SELECT COUNT(*) AS n FROM "$name" WHERE $cond',
            variables: [Variable<int>(cutoffMs)],
          )
          .getSingle();
      final n = count.data['n']! as int;
      if (n == 0) continue;
      touched.add(name);
      await db.customStatement(
        'DELETE FROM change_log WHERE entity = ? AND entity_id IN '
        '(SELECT id FROM "$name" WHERE $cond)',
        [name, cutoffMs],
      );
      // Child-set markers keyed by the purged parent.
      await db.customStatement(
        "DELETE FROM change_log WHERE entity LIKE '%#set' AND entity_id IN "
        '(SELECT id FROM "$name" WHERE $cond)',
        [cutoffMs],
      );
      if (name == 'transactions') {
        await db.customStatement(
          'DELETE FROM txn_search WHERE rowid IN '
          '(SELECT rowid FROM transactions WHERE $cond)',
          [cutoffMs],
        );
      }
      await db.customStatement('DELETE FROM "$name" WHERE $cond', [cutoffMs]);
      removed += n;
    }
  });
  if (touched.isNotEmpty) {
    db.markTablesUpdated([for (final t in touched) db.tableByName(t)]);
  }
  return removed;
}
