import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/core/sync/sync_providers.dart';
import 'package:personal_finance/features/export/data/backup_service.dart';
import 'package:personal_finance/features/export/data/data_tools.dart';
import 'package:personal_finance/features/export/data/export_folder.dart';
import 'package:personal_finance/features/export/domain/auto_export_plan.dart';
import 'package:personal_finance/features/export/domain/export_settings.dart';

/// Outcome of an automatic backup run.
@immutable
class AutoExportResult {
  const AutoExportResult({this.fileName, this.pruned = const [], this.error});

  /// The written file, null when nothing was written.
  final String? fileName;
  final List<String> pruned;
  final Object? error;

  bool get written => fileName != null;
}

/// Runs the scheduled backup when it is due (PLAN.md §2.6): native
/// platforms only, schedule not off, folder chosen. Writes a verified bundle
/// to the folder, keeps the newest `autoExportKeep` backups and records
/// `lastAutoExport`. Returns whether a backup was written. Errors are
/// logged, never thrown.
Future<bool> runAutoExportIfDue(
  ProviderContainer container, {
  DateTime? now,
}) async {
  try {
    final read = container.read;
    final at = now ?? DateTime.now();
    if (!read(platformCapabilitiesProvider).chooseFolder) return false;
    final s = await loadSettings(read(databaseProvider));
    final folder = s.get(ImportExportSettings.autoExportFolder);
    if (folder == null || folder.isEmpty) return false;
    final lastRaw = s.get(ImportExportSettings.lastAutoExport);
    final last = lastRaw == null ? null : DateTime.tryParse(lastRaw);
    if (!isAutoExportDue(s.get(ImportExportSettings.autoExport), last, at)) {
      return false;
    }
    final r = await runAutoExportNow(read, now: at);
    return r.written;
  } on Object catch (e, st) {
    debugPrint('Auto-export failed: $e\n$st');
    return false;
  }
}

/// Writes a backup to the configured folder now, regardless of the
/// schedule ("Back up now"). Never throws; see [AutoExportResult.error].
Future<AutoExportResult> runAutoExportNow(
  ProviderReader read, {
  DateTime? now,
}) async {
  try {
    final at = now ?? DateTime.now();
    final s = await loadSettings(read(databaseProvider));
    final path = s.get(ImportExportSettings.autoExportFolder);
    if (path == null || path.isEmpty) {
      return AutoExportResult(error: StateError('No export folder'));
    }
    final backup = await createVerifiedBackup(read);
    final bytes = backup.bytes;
    final folder = read(exportFolderFactoryProvider)(path);
    final name = autoExportFileName(at);
    await folder.writeFile(name, bytes);
    final prune = autoExportFilesToPrune(
      await folder.listFiles(),
      s.get(ImportExportSettings.autoExportKeep),
    );
    for (final f in prune) {
      await folder.deleteFile(f);
    }
    await read(settingsProvider.notifier)
        .set(ImportExportSettings.lastAutoExport, at.toIso8601String());
    return AutoExportResult(fileName: name, pruned: prune);
  } on Object catch (e, st) {
    debugPrint('Auto-export failed: $e\n$st');
    return AutoExportResult(error: e);
  }
}

/// Purges tombstones older than `DataSettings.tombstoneDays`, at most once a
/// week and only while no sync backend is configured. Returns the number of
/// rows removed (0 when skipped). Errors are logged, never thrown.
Future<int> runTombstonePurgeIfDue(
  ProviderContainer container, {
  DateTime? now,
}) async {
  try {
    final read = container.read;
    if (read(syncConfiguredProvider)) return 0;
    final at = now ?? DateTime.now();
    final s = await loadSettings(read(databaseProvider));
    final lastRaw = s.get(ExportSettings.lastTombstonePurge);
    final last = lastRaw == null ? null : DateTime.tryParse(lastRaw);
    if (last != null &&
        !last.isAfter(at) &&
        at.difference(last) < const Duration(days: 7)) {
      return 0;
    }
    final removed = await purgeTombstones(
      read(databaseProvider),
      Duration(days: s.get(DataSettings.tombstoneDays)),
      now: at,
    );
    await read(settingsProvider.notifier)
        .set(ExportSettings.lastTombstonePurge, at.toIso8601String());
    return removed;
  } on Object catch (e, st) {
    debugPrint('Tombstone purge failed: $e\n$st');
    return 0;
  }
}
