import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/attachments/receipt_store.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/features/export/data/backup_service.dart';
import 'package:personal_finance/features/export/data/bundle_service.dart';

// On-device safety copies (docs/BACKUP.md, "copy before destroy"): a full
// backup bundle *without* receipt files, stored in the `safety_copies`
// table of the app database (so it is encrypted with it and works on the
// web). Receipt files are never deleted by the operations below, so the
// copy's rows still find them. Restore and reset leave the table alone.

/// Why a safety copy was taken.
enum SafetyReason { restore, reset, importUndo, merge, purge, restoreCopy }

/// Copies kept; older ones are removed when a new one is taken.
const maxSafetyCopies = 10;

/// The safety copy could not be taken, so the operation was not run.
class SafetyCopyException implements Exception {
  const SafetyCopyException(this.cause);
  final Object cause;

  @override
  String toString() => 'Safety copy failed: $cause';
}

/// Takes a verified safety copy and returns its id. Throws
/// [SafetyCopyException] on any failure.
Future<String> takeSafetyCopy(
  AppDatabase db,
  SafetyReason reason, {
  required String deviceId,
  DateTime? now,
}) async {
  try {
    final at = now ?? DateTime.now();
    final bytes = await exportBundle(
      db,
      deviceId: deviceId,
      now: at,
      includeReceiptFiles: false,
    );
    final rows = readBundle(db, bytes).manifest.totalRows;
    final id = newId();
    await db.transaction(() async {
      await db
          .into(db.safetyCopies)
          .insert(
            SafetyCopiesCompanion.insert(
              id: id,
              createdAt: at,
              reason: reason.name,
              rowCount: rows,
              data: bytes,
            ),
          );
      await db.customStatement(
        'DELETE FROM safety_copies WHERE id NOT IN (SELECT id FROM '
        'safety_copies ORDER BY created_at DESC, id DESC LIMIT ?)',
        [maxSafetyCopies],
      );
    });
    // Read back what was stored.
    final stored = await (db.select(
      db.safetyCopies,
    )..where((c) => c.id.equals(id))).getSingle();
    if (!listEquals(stored.data, bytes)) {
      throw StateError('Stored safety copy differs');
    }
    return id;
  } on Object catch (e) {
    throw SafetyCopyException(e);
  }
}

/// Runs [operation] only after a safety copy was taken. If the copy fails
/// the operation does not run and [SafetyCopyException] is thrown.
Future<T> withSafetyCopy<T>(
  ProviderReader read,
  SafetyReason reason,
  Future<T> Function() operation,
) async {
  await takeSafetyCopy(
    read(databaseProvider),
    reason,
    deviceId: read(deviceIdProvider),
  );
  return await operation();
}

/// Metadata of a stored safety copy (without the bundle bytes).
@immutable
class SafetyCopyInfo {
  const SafetyCopyInfo({
    required this.id,
    required this.createdAt,
    required this.reason,
    required this.rowCount,
    required this.sizeBytes,
  });

  final String id;
  final DateTime createdAt;
  final SafetyReason? reason;
  final int rowCount;
  final int sizeBytes;
}

/// All safety copies, newest first.
Stream<List<SafetyCopyInfo>> watchSafetyCopies(AppDatabase db) => db
    .customSelect(
      'SELECT id, created_at, reason, row_count, length(data) AS size '
      'FROM safety_copies ORDER BY created_at DESC, id DESC',
      readsFrom: {db.safetyCopies},
    )
    .watch()
    .map(
      (rows) => [
        for (final r in rows)
          SafetyCopyInfo(
            id: r.read<String>('id'),
            createdAt: r.read<DateTime>('created_at'),
            reason: SafetyReason.values.asNameMap()[r.read<String>('reason')],
            rowCount: r.read<int>('row_count'),
            sizeBytes: r.read<int>('size'),
          ),
      ],
    );

final safetyCopiesProvider = StreamProvider<List<SafetyCopyInfo>>(
  (ref) => watchSafetyCopies(ref.watch(databaseProvider)),
);

/// The bundle bytes of safety copy [id].
Future<Uint8List> safetyCopyBytes(AppDatabase db, String id) async {
  final c = await (db.select(
    db.safetyCopies,
  )..where((c) => c.id.equals(id))).getSingle();
  return c.data;
}

/// Restores safety copy [id] after taking a new safety copy of the current
/// state (so this can be undone too). Returns the number of rows restored.
Future<int> restoreSafetyCopy(ProviderReader read, String id) async {
  final db = read(databaseProvider);
  final contents = readBundle(db, await safetyCopyBytes(db, id));
  return await withSafetyCopy(
    read,
    SafetyReason.restoreCopy,
    () => restoreBundle(
      db,
      contents,
      clock: read(hlcClockProvider),
      receipts: read(receiptStoreProvider),
    ),
  );
}

Future<void> deleteSafetyCopy(AppDatabase db, String id) =>
    (db.delete(db.safetyCopies)..where((c) => c.id.equals(id))).go();
