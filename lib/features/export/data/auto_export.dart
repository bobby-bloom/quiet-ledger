import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/platform/notifications.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/core/sync/sync_providers.dart';
import 'package:personal_finance/core/sync/tombstone_purge.dart'
    show countPurgeableTombstones;
import 'package:personal_finance/features/export/data/backup_keys.dart';
import 'package:personal_finance/features/export/data/backup_service.dart';
import 'package:personal_finance/features/export/data/data_tools.dart';
import 'package:personal_finance/features/export/data/export_folder.dart';
import 'package:personal_finance/features/export/data/export_folder_native.dart';
import 'package:personal_finance/features/export/data/safety_copies.dart';
import 'package:personal_finance/features/export/domain/auto_export_plan.dart';
import 'package:personal_finance/features/export/domain/backup_settings.dart';
import 'package:personal_finance/features/export/domain/export_settings.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

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

/// Runs the scheduled backup when it is due (docs/BACKUP.md): native
/// platforms only, schedule not off, folder chosen. See [runAutoExportNow].
/// Returns whether a backup was written. Errors are recorded and logged,
/// never thrown.
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
    final schedule = s.get(ImportExportSettings.autoExport);
    if (schedule == AutoExportSchedule.off) return false;
    // After a failure, retry on every run instead of waiting for the next
    // scheduled day.
    final failed = s.get(BackupSettings.lastError) != null;
    if (!failed && !isAutoExportDue(schedule, last, at)) return false;
    final r = await runAutoExportNow(read, now: at);
    return r.written;
  } on Object catch (e, st) {
    debugPrint('Auto-export failed: $e\n$st');
    return false;
  }
}

Future<AutoExportResult>? _running;

/// Writes a backup to the configured folder now, regardless of the
/// schedule ("Back up now"). Concurrent calls share one run.
///
/// Order (docs/BACKUP.md, "write → verify → then prune"): record the
/// attempt; create a verified backup; write it; read it back from the
/// folder and validate it again; only then prune old backups (never the
/// file just written) and record success. A failure is recorded in
/// [BackupSettings.lastError] and notified once. Never throws; see
/// [AutoExportResult.error].
Future<AutoExportResult> runAutoExportNow(
  ProviderReader read, {
  DateTime? now,
}) {
  final running = _running;
  if (running != null) return running;
  final run = _runAutoExport(read, now ?? DateTime.now());
  _running = run;
  return run.whenComplete(() => _running = null);
}

Future<AutoExportResult> _runAutoExport(
  ProviderReader read,
  DateTime at,
) async {
  final settings = read(settingsProvider.notifier);
  final stamp = at.toIso8601String();
  try {
    await settings.set(BackupSettings.lastAttempt, stamp);
    final s = await loadSettings(read(databaseProvider));
    final path = s.get(ImportExportSettings.autoExportFolder);
    if (path == null || path.isEmpty) {
      throw StateError('No export folder');
    }
    final backup = await createVerifiedBackup(read);
    final folder = read(exportFolderFactoryProvider)(path);
    final name = autoExportFileName(at, backup.extension);
    await folder.writeFile(name, backup.bytes);

    // Verify what actually landed in the folder: same bytes, and it opens
    // (decrypts) and validates.
    final stored = await folder.readFile(name);
    if (!listEquals(stored, backup.bytes)) {
      throw StateError(
        'The backup in the folder differs from what was written',
      );
    }
    await openBackup(read, stored!);

    final prune = autoExportFilesToPrune(
      await folder.listFiles(),
      s.get(ImportExportSettings.autoExportKeep),
      protect: name,
    );
    for (final f in prune) {
      await folder.deleteFile(f);
    }
    await settings.set(ImportExportSettings.lastAutoExport, stamp);
    await settings.set(BackupSettings.lastVerified, stamp);
    await settings.reset(BackupSettings.lastError);
    return AutoExportResult(fileName: name, pruned: prune);
  } on Object catch (e, st) {
    debugPrint('Auto-export failed: $e\n$st');
    await _recordFailure(read, e);
    return AutoExportResult(error: e);
  }
}

Future<void> _recordFailure(ProviderReader read, Object error) async {
  try {
    final settings = read(settingsProvider.notifier);
    final first = read(settingsProvider).get(BackupSettings.lastError) == null;
    final l = lookupAppLocalizations(Locale(read(languageCodeProvider)));
    await settings.set(BackupSettings.lastError, switch (error) {
      BackupFolderAccessException() => l.backupFolderAccessLost,
      BackupPasswordMissingException() => l.backupPasswordMissing,
      _ => '$error',
    });
    if (!first) return;
    final service = read(notificationServiceProvider);
    if (await service.init()) {
      await service.showBackupProblem(
        title: l.backupNotifyFailedTitle,
        body: l.backupNotifyFailedBody,
      );
    }
  } on Object catch (e) {
    debugPrint('Could not record the backup failure: $e');
  }
}

/// Startup check: a platform backup folder whose permission is gone is
/// reported right away (banner, notification) instead of at the next due
/// backup. Never throws.
Future<void> checkBackupFolderAccess(ProviderReader read) async {
  try {
    final folder = read(settingsProvider)
        .get(ImportExportSettings.autoExportFolder);
    if (folder == null || !isNativeFolderRef(folder)) return;
    if (read(settingsProvider).get(ImportExportSettings.autoExport) ==
        AutoExportSchedule.off) {
      return;
    }
    if (!await nativeFolderAccessible(folder)) {
      await _recordFailure(read, const BackupFolderAccessException());
    }
  } on Object catch (e) {
    debugPrint('Backup folder check failed: $e');
  }
}

/// Records that a backup was verified and stored outside the app (manual
/// save, share or download).
Future<void> recordVerifiedBackup(ProviderReader read, {DateTime? now}) => read(
  settingsProvider.notifier,
).set(BackupSettings.lastVerified, (now ?? DateTime.now()).toIso8601String());

/// Purges tombstones older than `DataSettings.tombstoneDays`, at most once a
/// week and only while no sync backend is configured. When rows would be
/// removed a safety copy is taken first; if that fails nothing is purged
/// and the next start tries again. Returns the number of rows removed (0
/// when skipped). Errors are logged, never thrown.
Future<int> runTombstonePurgeIfDue(
  ProviderContainer container, {
  DateTime? now,
}) async {
  try {
    final read = container.read;
    if (read(syncConfiguredProvider)) return 0;
    final at = now ?? DateTime.now();
    final db = read(databaseProvider);
    final s = await loadSettings(db);
    final lastRaw = s.get(ExportSettings.lastTombstonePurge);
    final last = lastRaw == null ? null : DateTime.tryParse(lastRaw);
    if (last != null &&
        !last.isAfter(at) &&
        at.difference(last) < const Duration(days: 7)) {
      return 0;
    }
    final age = Duration(days: s.get(DataSettings.tombstoneDays));
    var removed = 0;
    if (await countPurgeableTombstones(db, age, now: at) > 0) {
      await takeSafetyCopy(
        db,
        SafetyReason.purge,
        deviceId: read(deviceIdProvider),
        now: at,
      );
      removed = await purgeTombstones(db, age, now: at);
    }
    await read(settingsProvider.notifier)
        .set(ExportSettings.lastTombstonePurge, at.toIso8601String());
    return removed;
  } on Object catch (e, st) {
    debugPrint('Tombstone purge failed: $e\n$st');
    return 0;
  }
}

/// Runs the scheduled backup while the app stays open: when it returns to
/// the foreground and every hour (the run itself checks whether it is due).
/// Started by the export startup task; stopped when the container is
/// disposed.
class BackupScheduler {
  AppLifecycleListener? _lifecycle;
  Timer? _timer;

  void start(Future<void> Function() tick) {
    if (_timer != null) return;
    void run() => unawaited(tick());
    _timer = Timer.periodic(const Duration(hours: 1), (_) => run());
    try {
      _lifecycle = AppLifecycleListener(onResume: run);
    } on Object catch (e) {
      // No widgets binding (tests, headless): the timer still runs.
      debugPrint('Backup scheduler without lifecycle events: $e');
    }
  }

  void dispose() {
    _lifecycle?.dispose();
    _timer?.cancel();
    _timer = null;
  }
}

final backupSchedulerProvider = Provider<BackupScheduler>((ref) {
  final s = BackupScheduler();
  ref.onDispose(s.dispose);
  return s;
});
