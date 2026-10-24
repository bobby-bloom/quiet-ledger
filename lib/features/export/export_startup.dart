import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/features/export/data/auto_export.dart';

/// Startup task: writes the scheduled automatic backup when due, then keeps
/// checking while the app is open (resume, hourly).
Future<void> autoExportStartupTask(ProviderContainer container) async {
  await checkBackupFolderAccess(container.read);
  await runAutoExportIfDue(container);
  try {
    container
        .read(backupSchedulerProvider)
        .start(() => runAutoExportIfDue(container));
  } on Object catch (e) {
    debugPrint('Backup scheduler not started: $e');
  }
}

/// Startup task: purges old tombstones (weekly at most, only without sync).
Future<void> tombstonePurgeStartupTask(ProviderContainer container) async {
  await runTombstonePurgeIfDue(container);
}
