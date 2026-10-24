import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/sync/tombstone_purge.dart' as purge;

// Data tools for Settings › Data (PLAN.md §2.7): DB statistics, rebuild the
// search index, reset the app, purge old tombstones. UI-free; the settings
// screen calls these and is responsible for confirmation dialogs.

/// Row counts of one table.
@immutable
class TableStats {
  const TableStats({
    required this.table,
    required this.live,
    required this.deleted,
  });

  /// SQL table name.
  final String table;
  final int live;

  /// Soft-deleted rows (tombstones).
  final int deleted;

  int get total => live + deleted;
}

/// Database statistics.
@immutable
class DbStats {
  const DbStats({
    required this.tables,
    required this.changeLogEntries,
    required this.changeLogUnsynced,
    required this.sizeBytes,
  });

  /// One entry per synced table, in `syncedTableNames` order.
  final List<TableStats> tables;
  final int changeLogEntries;

  /// Change-log entries not yet pushed to a sync backend.
  final int changeLogUnsynced;

  /// Database size (page count × page size), null if unavailable.
  final int? sizeBytes;

  int get liveRows => tables.fold(0, (s, t) => s + t.live);
  int get deletedRows => tables.fold(0, (s, t) => s + t.deleted);

  TableStats? operator [](String table) =>
      tables.where((t) => t.table == table).firstOrNull;
}

/// Collects row counts per synced table (live vs. deleted), the change-log
/// size and the database size. Works on all platforms (the size comes from
/// SQLite pragmas, not the file system).
Future<DbStats> dbStatistics(AppDatabase db) async {
  final tables = <TableStats>[];
  for (final name in syncedTableNames) {
    final r = await db
        .customSelect(
          'SELECT COUNT(*) AS total, COUNT(deleted_at) AS deleted '
          'FROM "$name"',
        )
        .getSingle();
    final total = r.data['total']! as int;
    final deleted = r.data['deleted']! as int;
    tables.add(
      TableStats(table: name, live: total - deleted, deleted: deleted),
    );
  }
  final log = await db
      .customSelect(
        'SELECT COUNT(*) AS total, '
        'COALESCE(SUM(CASE WHEN synced = 0 THEN 1 ELSE 0 END), 0) AS unsynced '
        'FROM change_log',
      )
      .getSingle();
  int? size;
  try {
    final pages = await db.customSelect('PRAGMA page_count').getSingle();
    final pageSize = await db.customSelect('PRAGMA page_size').getSingle();
    size =
        (pages.data.values.first! as int) *
        (pageSize.data.values.first! as int);
  } on Object {
    size = null;
  }
  return DbStats(
    tables: tables,
    changeLogEntries: log.data['total']! as int,
    changeLogUnsynced: log.data['unsynced']! as int,
    sizeBytes: size,
  );
}

/// Clears and rebuilds the full-text search index.
Future<void> rebuildSearchIndex(AppDatabase db) => db.rebuildSearch();

/// Deletes everything: all synced tables, the change log, sync state and the
/// search index, in one transaction. Settings are wiped too, so the app
/// returns to onboarding. Cannot be undone; confirm first.
Future<void> resetAppData(AppDatabase db) async {
  await db.transaction(() async {
    for (final name in syncedTableNames) {
      await db.customStatement('DELETE FROM "$name"');
    }
    await db.customStatement('DELETE FROM change_log');
    await db.customStatement('DELETE FROM sync_state');
    await db.customStatement('DELETE FROM txn_search');
  });
  db.markTablesUpdated(db.allTables);
}

/// Hard-deletes soft-deleted rows older than [olderThan] (and their change
/// log entries). Returns the number of rows removed. Only use while no sync
/// backend is configured.
Future<int> purgeTombstones(
  AppDatabase db,
  Duration olderThan, {
  DateTime? now,
}) => purge.purgeTombstones(db, olderThan, now: now);
