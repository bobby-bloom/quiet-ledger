import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:personal_finance/core/attachments/receipt_store.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/features/export/data/bundle_service.dart';
import 'package:personal_finance/features/export/domain/bundle_manifest.dart';

/// Reads a provider; both `ProviderContainer.read` and `WidgetRef.read`
/// fit.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// A backup that has been read back and fully validated after it was
/// written, ready to be stored.
@immutable
class VerifiedBackup {
  const VerifiedBackup(this.bytes, this.manifest);
  final Uint8List bytes;
  final BundleManifest manifest;
}

/// The single way the app creates a backup (manual, scheduled, safety
/// copy): exports all data and receipts, then validates the result with
/// [readBundle] so an unreadable backup is never stored. Throws on failure.
Future<VerifiedBackup> createVerifiedBackup(ProviderReader read) async {
  final db = read(databaseProvider);
  final bytes = await exportBundle(
    db,
    deviceId: read(deviceIdProvider),
    receipts: read(receiptStoreProvider),
  );
  final check = readBundle(db, bytes);
  return VerifiedBackup(bytes, check.manifest);
}
