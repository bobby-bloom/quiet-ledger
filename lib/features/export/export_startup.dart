import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/features/export/data/auto_export.dart';

/// Startup task: writes the scheduled automatic backup when due.
Future<void> autoExportStartupTask(ProviderContainer container) async {
  await runAutoExportIfDue(container);
}

/// Startup task: purges old tombstones (weekly at most, only without sync).
Future<void> tombstonePurgeStartupTask(ProviderContainer container) async {
  await runTombstonePurgeIfDue(container);
}
