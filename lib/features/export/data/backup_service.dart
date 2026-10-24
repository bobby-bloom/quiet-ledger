import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:personal_finance/core/attachments/receipt_store.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/features/export/data/backup_keys.dart';
import 'package:personal_finance/features/export/data/bundle_service.dart';
import 'package:personal_finance/features/export/domain/backup_crypto.dart';
import 'package:personal_finance/features/export/domain/bundle_manifest.dart';

/// Reads a provider; both `ProviderContainer.read` and `WidgetRef.read`
/// fit.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// A backup that has been read back and fully validated after it was
/// created (and, when encrypted, decrypted again), ready to be stored.
@immutable
class VerifiedBackup {
  const VerifiedBackup(this.bytes, this.manifest, {this.encrypted = false});
  final Uint8List bytes;
  final BundleManifest manifest;
  final bool encrypted;

  /// `.pfbackup` or `.zip`.
  String get extension => encrypted ? encryptedBackupExtension : '.zip';

  String get mimeType =>
      encrypted ? 'application/octet-stream' : 'application/zip';
}

/// The single way the app creates a backup that leaves the device (manual,
/// scheduled, saved safety copy): exports all data and receipts (or wraps
/// [zip] when given), validates the bundle and, when a backup password is
/// set, encrypts it and checks that it decrypts to the same bytes. Throws
/// [BackupPasswordMissingException] when encryption is required but no
/// password is set; throws on any other failure.
Future<VerifiedBackup> createVerifiedBackup(
  ProviderReader read, {
  Uint8List? zip,
}) async {
  final db = read(databaseProvider);
  final bundle =
      zip ??
      await exportBundle(
        db,
        deviceId: read(deviceIdProvider),
        receipts: read(receiptStoreProvider),
      );
  final manifest = readBundle(db, bundle).manifest;
  final ring = await read(backupKeyRepositoryProvider).load();
  if (ring == null) {
    if (read(backupEncryptionRequiredProvider)) {
      throw const BackupPasswordMissingException();
    }
    return VerifiedBackup(bundle, manifest);
  }
  final encrypted = await encryptInBackground(bundle, ring.current);
  final back = await decryptInBackground(
    encrypted,
    BackupUnlock(known: [ring.current]),
  );
  if (!listEquals(back, bundle)) {
    throw StateError('The encrypted backup does not decrypt correctly');
  }
  return VerifiedBackup(encrypted, manifest, encrypted: true);
}

/// Opens backup [bytes] (plain zip or `.pfbackup`) and validates them with
/// [readBundle]. Encrypted files are tried with the keys stored on this
/// device first, then with [password] / [recoveryKey]. Throws
/// [BackupCryptoException] or [BundleException].
Future<BundleContents> openBackup(
  ProviderReader read,
  Uint8List bytes, {
  String? password,
  Uint8List? recoveryKey,
}) async {
  var zip = bytes;
  if (isEncryptedBackup(bytes)) {
    final ring = await read(backupKeyRepositoryProvider).load();
    zip = await decryptInBackground(
      bytes,
      BackupUnlock(
        known: ring?.all ?? const [],
        password: password,
        recoveryKey: recoveryKey,
      ),
    );
  }
  return readBundle(read(databaseProvider), zip);
}
