import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/features/transactions/data/attachment_paths.dart';

/// Startup task: stores receipt paths relative to `attachments/`.
Future<void> attachmentPathsStartupTask(ProviderContainer c) async {
  await migrateAttachmentPaths(
    c.read(databaseProvider),
    c.read(syncWriterProvider),
  );
}
