import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/sync/change.dart';
import 'package:personal_finance/core/sync/hlc.dart';
import 'package:personal_finance/core/sync/raw_rows.dart';
import 'package:personal_finance/core/sync/sync_backend.dart';

/// Result of one [SyncEngine.sync] round.
@immutable
class SyncResult {
  const SyncResult({required this.pushed, required this.pulled});

  /// Changes sent to the backend.
  final int pushed;

  /// Remote changes received and merged (own echoes excluded).
  final int pulled;

  @override
  String toString() => 'SyncResult(pushed: $pushed, pulled: $pulled)';
}

/// Replicates the local `change_log` through a [SyncBackend] and merges
/// remote changes (PLAN.md §4.3).
///
/// Merge policy
/// * **Last writer wins per field** by HLC. The HLC of each local field is
///   derived from the `change_log` (the highest entry for that row that
///   mentions the column); rows without log entries (e.g. after a restore)
///   use the row's `updated_at`. Remote changes are written with raw SQL,
///   bypassing `SyncWriter`, and recorded in `change_log` with
///   `synced = true` and their *remote* HLC. That keeps the per-field HLCs
///   derivable without a schema change and guarantees applied remote
///   changes are never pushed again as local ones.
/// * **Tombstones** are the `deleted_at` field under the same rule: the
///   latest change of a row in each push carries the row's current
///   `deleted_at`, so "delete" vs "edit" is decided by HLC (an edit made
///   after a delete on another device resurrects the row; a later delete
///   wins over an earlier edit).
/// * **Transaction splits are merged as a unit** (and likewise the tags
///   and custom field values of an entity, see [childSetTables]): local
///   child rows are pushed as one [SyncOp.replaceSet] change per parent
///   holding all its child rows (including tombstones). The newer set (by
///   HLC) replaces the older one completely; child rows unknown to the
///   winning set become tombstones.
/// * Remote changes for rows that do not exist yet (out-of-order delivery)
///   are logged and folded in when the insert arrives.
/// * Every remote HLC goes through [HlcClock.receive], so later local
///   writes are ordered after everything seen. A remote clock more than
///   [Hlc.maxDrift] ahead aborts the pull with [ClockDriftException]
///   (nothing of that pull is applied).
class SyncEngine {
  SyncEngine({
    required this.db,
    required this.clock,
    required this.deviceId,
    required this.backend,
  });

  final AppDatabase db;
  final HlcClock clock;
  final String deviceId;
  final SyncBackend backend;

  /// Child tables merged as a unit per parent: table -> parent id column.
  /// `LedgerRepository` rewrites these sets wholesale on every edit, so a
  /// row-level merge of two concurrent edits would duplicate lines.
  static const childSetTables = {
    'transaction_splits': 'transaction_id',
    'transaction_tags': 'transaction_id',
    'custom_field_values': 'entity_id',
  };

  /// `change_log.entity` of the marker recording an applied set of [table].
  static String setMarkerEntity(String table) => '$table#set';

  static const _nonLwwColumns = {'id', 'updated_at', 'created_at'};

  late final Map<String, TableInfo<Table, dynamic>> _tables = {
    for (final n in syncedTableNames) n: db.tableByName(n),
  };

  /// Pushes local changes, then pulls and merges remote ones.
  Future<SyncResult> sync() async {
    final pushed = await push();
    final pulled = await pull();
    return SyncResult(pushed: pushed, pulled: pulled);
  }

  /// Device-local settings (`SettingDef.deviceLocal`) are never sent or
  /// taken over. `SyncWriter` does not log them; this also covers entries
  /// logged before a setting became device-local.
  static bool _deviceLocal(String entity, String id) =>
      entity == 'settings' && isDeviceLocalSettingRow(id);

  /// Number of local changes not yet pushed.
  Future<int> unsyncedCount() async {
    final rows = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM change_log WHERE synced = 0',
          readsFrom: {db.changeLog},
        )
        .get();
    return rows.first.data['n']! as int;
  }

  // ---------------------------------------------------------------- push --

  /// Sends all unsynced `change_log` entries and marks them synced. Returns
  /// the number of [Change]s pushed.
  Future<int> push() async {
    final entries =
        await (db.select(db.changeLog)
              ..where((c) => c.synced.equals(false))
              ..orderBy([(c) => OrderingTerm(expression: c.seq)]))
            .get();
    if (entries.isEmpty) return 0;

    final changes = <Change>[];
    final rewrites = <int, String>{};

    // Latest entry per row decides the replicated `deleted_at`.
    final latestOf = <String, ({int seq, Hlc hlc})>{};
    final setEntries = <String, List<ChangeLogEntry>>{};
    for (final e in entries) {
      if (!_tables.containsKey(e.entity)) continue;
      if (childSetTables.containsKey(e.entity)) {
        (setEntries[e.entity] ??= []).add(e);
        continue;
      }
      final k = '${e.entity}|${e.entityId}';
      final h = Hlc.parse(e.hlc);
      final prev = latestOf[k];
      if (prev == null || h > prev.hlc) latestOf[k] = (seq: e.seq, hlc: h);
    }
    final latest = {for (final v in latestOf.values) v.seq};

    final rowCache = <String, Map<String, Object?>?>{};
    Future<Map<String, Object?>?> rowOf(String entity, String id) async {
      final k = '$entity|$id';
      if (rowCache.containsKey(k)) return rowCache[k];
      return rowCache[k] = await selectRawRow(db, _tables[entity]!, id);
    }

    for (final e in entries) {
      if (!_tables.containsKey(e.entity) ||
          childSetTables.containsKey(e.entity) ||
          _deviceLocal(e.entity, e.entityId)) {
        continue;
      }
      final change = Change.fromLogEntry(e, originDeviceId: deviceId);
      final fields = Map<String, Object?>.of(change.fields);
      final row = await rowOf(e.entity, e.entityId);
      var enriched = false;
      if (row != null) {
        if (e.op == ChangeOp.insert) {
          fields['created_at'] = row['created_at'];
          fields['origin_device_id'] = row['origin_device_id'];
          enriched = true;
        }
        if (latest.contains(e.seq) && !fields.containsKey('deleted_at')) {
          fields['deleted_at'] = row['deleted_at'];
          enriched = true;
        }
      }
      if (enriched) rewrites[e.seq] = jsonEncode(fields);
      changes.add(change.withFields(fields));
    }

    for (final e in setEntries.entries) {
      changes.addAll(await _setChanges(e.key, e.value));
    }

    await backend.push(changes);

    await db.transaction(() async {
      for (final e in entries) {
        await (db.update(
          db.changeLog,
        )..where((c) => c.seq.equals(e.seq))).write(
          ChangeLogCompanion(
            synced: const Value(true),
            changedFields: rewrites.containsKey(e.seq)
                ? Value(rewrites[e.seq]!)
                : const Value.absent(),
          ),
        );
      }
      final state = await _state();
      await _saveState(
        lastPulled: state?.lastPulledHlc,
        lastPushedSeq: entries.last.seq,
      );
    });
    return changes.length;
  }

  Future<List<Change>> _setChanges(
    String tableName,
    List<ChangeLogEntry> entries,
  ) async {
    final table = _tables[tableName]!;
    final parentCol = childSetTables[tableName]!;
    final hlcByChild = <String, Hlc>{};
    for (final e in entries) {
      final h = Hlc.parse(e.hlc);
      final prev = hlcByChild[e.entityId];
      if (prev == null || h > prev) hlcByChild[e.entityId] = h;
    }
    // child id -> parent id
    final setHlc = <String, Hlc>{};
    final ids = hlcByChild.keys.toList();
    for (var i = 0; i < ids.length; i += 500) {
      final chunk = ids.sublist(i, (i + 500).clamp(0, ids.length));
      final rows = await selectRawRows(
        db,
        table,
        where: 'id IN (${List.filled(chunk.length, '?').join(', ')})',
        args: chunk,
      );
      for (final r in rows) {
        final parent = r[parentCol]! as String;
        final h = hlcByChild[r['id']! as String]!;
        final prev = setHlc[parent];
        if (prev == null || h > prev) setHlc[parent] = h;
      }
    }
    return [
      for (final e in setHlc.entries)
        Change(
          entity: tableName,
          entityId: e.key,
          op: SyncOp.replaceSet,
          hlc: e.value,
          fields: {
            'rows': [
              for (final r in await selectRawRows(
                db,
                table,
                where: '"$parentCol" = ?',
                args: [e.key],
                orderBy: 'id',
              ))
                {for (final c in r.entries) c.key: toJsonValue(c.value)},
            ],
          },
          originDeviceId: deviceId,
        ),
    ];
  }

  // ---------------------------------------------------------------- pull --

  /// Pulls remote changes since the stored cursor and merges them. Returns
  /// the number of changes merged.
  Future<int> pull() async {
    final state = await _state();
    final since = state?.lastPulledHlc == null
        ? Hlc.zero(deviceId)
        : Hlc.parse(state!.lastPulledHlc!);
    final changes = await backend.pull(since).toList();
    if (changes.isEmpty) return 0;
    var cursor = since;
    for (final c in changes) {
      final pos = c.received ?? c.hlc;
      if (pos > cursor) cursor = pos;
    }
    final applied = await applyRemote(
      changes,
      onCommit: () async {
        await _saveState(
          lastPulled: cursor.toString(),
          lastPushedSeq: state?.lastPushedSeq ?? 0,
        );
      },
    );
    return applied;
  }

  /// Merges [changes] in one DB transaction (in the given order; the result
  /// does not depend on it). Changes already applied (or made by this
  /// device) are skipped. Returns the number of changes merged.
  /// [onCommit] runs inside the same transaction after the changes.
  Future<int> applyRemote(
    Iterable<Change> changes, {
    Future<void> Function()? onCommit,
  }) async {
    final touched = <TableInfo<Table, dynamic>>{};
    final n = await db.transaction(() async {
      var count = 0;
      for (final c in changes) {
        final table = _tables[c.entity];
        if (table == null) continue; // unknown entity (newer schema)
        if (_deviceLocal(c.entity, c.entityId)) continue;
        clock.receive(c.hlc);
        final merged =
            c.op == SyncOp.replaceSet && childSetTables.containsKey(c.entity)
            ? await _applySet(table, c)
            : await _applyRow(table, c);
        if (merged) {
          count++;
          touched.add(table);
        }
      }
      await onCommit?.call();
      return count;
    });
    if (touched.isNotEmpty) db.markTablesUpdated(touched);
    return n;
  }

  Future<bool> _seen(String entity, String entityId, Hlc hlc) async {
    final r = await db
        .customSelect(
          'SELECT 1 FROM change_log WHERE entity = ? AND entity_id = ? '
          'AND hlc = ? LIMIT 1',
          variables: [
            Variable<String>(entity),
            Variable<String>(entityId),
            Variable<String>(hlc.toString()),
          ],
          readsFrom: {db.changeLog},
        )
        .get();
    return r.isNotEmpty;
  }

  Future<void> _logRemote(
    String entity,
    String entityId,
    SyncOp op,
    Hlc hlc,
    Map<String, Object?> fields,
  ) => db
      .into(db.changeLog)
      .insert(
        ChangeLogCompanion.insert(
          entity: entity,
          entityId: entityId,
          op: op.changeOp,
          hlc: hlc.toString(),
          changedFields: jsonEncode(fields),
          synced: const Value(true),
        ),
      );

  Future<List<({Hlc hlc, SyncOp op, Map<String, Object?> fields})>> _entries(
    String entity,
    String entityId,
  ) async {
    final rows =
        await (db.select(db.changeLog)..where(
              (c) => c.entity.equals(entity) & c.entityId.equals(entityId),
            ))
            .get();
    return [
      for (final r in rows)
        (
          hlc: Hlc.parse(r.hlc),
          op: SyncOp.fromChangeOp(r.op),
          fields: switch (jsonDecode(r.changedFields)) {
            final Map<String, Object?> m => m,
            _ => const <String, Object?>{},
          },
        ),
    ];
  }

  Future<bool> _applyRow(TableInfo<Table, dynamic> table, Change c) async {
    if (await _seen(c.entity, c.entityId, c.hlc)) return false;
    final entries = await _entries(c.entity, c.entityId);
    final row = await selectRawRow(db, table, c.entityId);

    if (row == null) {
      // Materialise from every known change of this row, oldest first.
      final all = [...entries, (hlc: c.hlc, op: c.op, fields: c.fields)]
        ..sort((a, b) => a.hlc.compareTo(b.hlc));
      final insert = all.where((e) => e.op == SyncOp.insert).firstOrNull;
      if (insert != null) {
        final merged = <String, Object?>{};
        for (final e in all) {
          for (final f in e.fields.entries) {
            if (_nonLwwColumns.contains(f.key) || f.key == 'origin_device_id') {
              continue;
            }
            final col = columnOf(table, f.key);
            if (col != null) merged[f.key] = toSqlValue(col, f.value);
          }
        }
        await upsertRawRow(db, table, {
          ...merged,
          'id': c.entityId,
          'created_at':
              toSqlValue(
                columnOf(table, 'created_at')!,
                insert.fields['created_at'],
              ) ??
              insert.hlc.millis,
          'origin_device_id':
              insert.fields['origin_device_id'] as String? ?? insert.hlc.nodeId,
          'updated_at': all.last.hlc.toString(),
        });
      }
      await _logRemote(c.entity, c.entityId, c.op, c.hlc, c.fields);
      return true;
    }

    // Per-field HLCs from the log.
    final fieldHlc = <String, Hlc>{};
    Hlc? oldest;
    for (final e in entries) {
      if (oldest == null || e.hlc < oldest) oldest = e.hlc;
      for (final k in e.fields.keys) {
        final prev = fieldHlc[k];
        if (prev == null || e.hlc > prev) fieldHlc[k] = e.hlc;
      }
    }
    final rowHlc = Hlc.parse(row['updated_at']! as String);
    final fallback = oldest ?? rowHlc;

    final updates = <String, Object?>{};
    for (final f in c.fields.entries) {
      if (_nonLwwColumns.contains(f.key) || f.key == 'origin_device_id') {
        continue;
      }
      final col = columnOf(table, f.key);
      if (col == null) continue;
      if (c.hlc > (fieldHlc[f.key] ?? fallback)) {
        updates[f.key] = toSqlValue(col, f.value);
      }
    }
    if (c.hlc > rowHlc) updates['updated_at'] = c.hlc.toString();
    await updateRawRow(db, table, c.entityId, updates);
    await _logRemote(c.entity, c.entityId, c.op, c.hlc, c.fields);
    return true;
  }

  Future<bool> _applySet(TableInfo<Table, dynamic> table, Change c) async {
    final parentId = c.entityId;
    final name = table.actualTableName;
    final parentCol = childSetTables[name]!;
    final marker = setMarkerEntity(name);
    if (await _seen(marker, parentId, c.hlc)) return false;
    final local = await selectRawRows(
      db,
      table,
      where: '"$parentCol" = ?',
      args: [parentId],
    );
    final localIds = {for (final r in local) r['id']! as String};

    final maxRow = await db
        .customSelect(
          'SELECT MAX(hlc) AS h FROM change_log WHERE '
          '(entity = ? AND entity_id IN '
          '(SELECT id FROM "$name" WHERE "$parentCol" = ?)) '
          'OR (entity = ? AND entity_id = ?)',
          variables: [
            Variable<String>(name),
            Variable<String>(parentId),
            Variable<String>(marker),
            Variable<String>(parentId),
          ],
          readsFrom: {db.changeLog, table},
        )
        .getSingle();
    var localSet = switch (maxRow.data['h']) {
      final String s => Hlc.parse(s),
      _ => null as Hlc?,
    };
    for (final r in local) {
      final h = Hlc.parse(r['updated_at']! as String);
      if (localSet == null || h > localSet) localSet = h;
    }

    final remoteRows = <Map<String, Object?>>[
      for (final r in (c.fields['rows'] as List?) ?? const [])
        if (r is Map) r.cast<String, Object?>(),
    ];

    Map<String, Object?> sqlRow(Map<String, Object?> r) => {
      for (final e in r.entries)
        if (columnOf(table, e.key) != null)
          e.key: toSqlValue(columnOf(table, e.key)!, e.value),
    };

    if (localSet == null || c.hlc > localSet) {
      final remoteIds = <String>{};
      for (final r in remoteRows) {
        remoteIds.add(r['id']! as String);
        await upsertRawRow(db, table, sqlRow(r));
      }
      for (final id in localIds.difference(remoteIds)) {
        await updateRawRow(db, table, id, {
          'deleted_at': c.hlc.millis,
          'updated_at': c.hlc.toString(),
        });
      }
    } else {
      // The local set is newer: keep it, but remember rows of the losing
      // set as tombstones so every device ends with the same rows.
      for (final r in remoteRows) {
        if (localIds.contains(r['id'])) continue;
        await upsertRawRow(db, table, {
          ...sqlRow(r),
          'deleted_at': localSet.millis,
          'updated_at': localSet.toString(),
        });
      }
    }
    await _logRemote(marker, parentId, SyncOp.replaceSet, c.hlc, {
      'rows': remoteRows.length,
    });
    return true;
  }

  // --------------------------------------------------------------- state --

  Future<SyncStateRow?> _state() => (db.select(
    db.syncState,
  )..where((s) => s.backendId.equals(backend.id))).getSingleOrNull();

  Future<void> _saveState({
    required String? lastPulled,
    required int lastPushedSeq,
  }) => db
      .into(db.syncState)
      .insertOnConflictUpdate(
        SyncStateCompanion.insert(
          backendId: backend.id,
          lastPulledHlc: Value(lastPulled),
          lastPushedSeq: Value(lastPushedSeq),
        ),
      );
}
