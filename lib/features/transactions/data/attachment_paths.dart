import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:personal_finance/core/attachments/attachment_files.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';

/// Rewrites receipt paths stored as absolute paths by versions before 0.2.0
/// to the file name inside `attachments/`, so receipts survive the app
/// container moving (iOS updates, restores). Only rows whose file is found
/// in the current `attachments/` folder change. Idempotent; returns the
/// number of rows updated. Errors are logged, never thrown.
Future<int> migrateAttachmentPaths(
  AppDatabase db,
  SyncWriter writer, {
  Future<String?> Function(String stored) relative = relativeAttachmentPath,
}) async {
  try {
    final rows = await (db.select(
      db.attachments,
    )..where((a) => a.filePath.isNotNull())).get();
    var changed = 0;
    for (final a in rows) {
      final name = await relative(a.filePath!);
      if (name == null || name == a.filePath) continue;
      await writer.update(
        db.attachments,
        a.id,
        AttachmentsCompanion(filePath: Value(name)),
      );
      changed++;
    }
    return changed;
  } on Object catch (e, st) {
    debugPrint('Attachment path migration failed: $e\n$st');
    return 0;
  }
}
