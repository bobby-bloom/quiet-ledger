import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/app_version.dart' as app;
import 'package:personal_finance/features/export/domain/backup_crypto.dart';
import 'package:personal_finance/features/security/data/secret_store.dart';

// Backup password state of this device (docs/BACKUP.md): the derived keys
// live in secure storage (never in the database or a backup). The password
// is optional: without one, backups are plain zips and the app says so.

/// Stored keys: the current password and the earlier ones, so backups
/// made before a password change still open on this device.
@immutable
class BackupKeyring {
  const BackupKeyring(this.current, [this.previous = const []]);

  factory BackupKeyring.fromJson(Map<String, Object?> j) => BackupKeyring(
    BackupKeys.fromJson((j['current']! as Map).cast<String, Object?>()),
    [
      for (final p in (j['previous'] as List?) ?? const [])
        BackupKeys.fromJson((p as Map).cast<String, Object?>()),
    ],
  );

  final BackupKeys current;
  final List<BackupKeys> previous;

  List<BackupKeys> get all => [current, ...previous];

  Map<String, Object?> toJson() => {
    'current': current.toJson(),
    'previous': [for (final p in previous) p.toJson()],
  };
}

class BackupKeyRepository {
  BackupKeyRepository(this._store);
  final SecretStore _store;

  static const storageKey = 'backup.keys';

  Future<BackupKeyring?> load() async {
    final raw = await _store.read(storageKey);
    if (raw == null) return null;
    return BackupKeyring.fromJson(
      (jsonDecode(raw) as Map).cast<String, Object?>(),
    );
  }

  /// Saves [keys] as current; the previous current key is kept for
  /// opening older backups.
  Future<void> save(BackupKeys keys) async {
    final old = await load();
    final ring = BackupKeyring(keys, [
      if (old != null && old.current.keyId != keys.keyId) old.current,
      ...?old?.previous.where((p) => p.keyId != keys.keyId),
    ]);
    await _store.write(storageKey, jsonEncode(ring.toJson()));
  }

  Future<void> delete() => _store.delete(storageKey);
}

final backupKeyRepositoryProvider = Provider<BackupKeyRepository>(
  (ref) => BackupKeyRepository(ref.watch(secretStoreProvider)),
);

/// The keyring; invalidate after saving.
final backupKeyringProvider = FutureProvider<BackupKeyring?>(
  (ref) => ref.watch(backupKeyRepositoryProvider).load(),
);

// The KDF and AES work runs in a background isolate (`compute`; inline on
// the web) so the UI keeps running during large backups.

/// Runs a callback with its message in the background. Widget tests
/// replace it with an inline runner (isolates do not advance under fake
/// time).
@visibleForTesting
Future<R> Function<M, R>(ComputeCallback<M, R> callback, M message)
backupCompute = compute;

/// PBKDF2 iterations for new passwords; lowered in tests only.
@visibleForTesting
int backupPbkdf2Iterations = defaultPbkdf2Iterations;

Future<Uint8List> encryptInBackground(Uint8List zip, BackupKeys keys) =>
    backupCompute(_encrypt, (zip, jsonEncode(keys.toJson()), app.appVersion));

Future<Uint8List> _encrypt((Uint8List, String, String) a) => encryptBackup(
  a.$1,
  BackupKeys.fromJson((jsonDecode(a.$2) as Map).cast<String, Object?>()),
  appVersion: a.$3,
);

/// Decrypts with [unlock]; throws [BackupCryptoException].
Future<Uint8List> decryptInBackground(Uint8List bytes, BackupUnlock unlock) =>
    backupCompute(_decrypt, (
      bytes,
      jsonEncode([for (final k in unlock.known) k.toJson()]),
      unlock.password,
      unlock.recoveryKey,
    ));

Future<Uint8List> _decrypt((Uint8List, String, String?, Uint8List?) a) =>
    decryptBackup(
      a.$1,
      BackupUnlock(
        known: [
          for (final k in jsonDecode(a.$2) as List)
            BackupKeys.fromJson((k as Map).cast<String, Object?>()),
        ],
        password: a.$3,
        recoveryKey: a.$4,
      ),
    );

/// Derives new keys (slow KDF) in the background.
Future<BackupKeys> createKeysInBackground(
  String password,
  Uint8List recoveryKey,
) async => BackupKeys.fromJson(
  (jsonDecode(
    await backupCompute(_create, (
      password,
      recoveryKey,
      backupPbkdf2Iterations,
    )),
  ) as Map).cast<String, Object?>(),
);

Future<String> _create((String, Uint8List, int) a) async =>
    jsonEncode((await createBackupKeys(a.$1, a.$2, iterations: a.$3)).toJson());

Future<BackupKeys> newPasswordInBackground(
  BackupKeys keys,
  String password,
) async => BackupKeys.fromJson(
  (jsonDecode(
    await backupCompute(_newPassword, (
      jsonEncode(keys.toJson()),
      password,
      backupPbkdf2Iterations,
    )),
  ) as Map).cast<String, Object?>(),
);

Future<String> _newPassword((String, String, int) a) async => jsonEncode(
  (await withNewPassword(
    BackupKeys.fromJson((jsonDecode(a.$1) as Map).cast<String, Object?>()),
    a.$2,
    iterations: a.$3,
  )).toJson(),
);

/// Whether [password] is the current backup password (constant time).
Future<bool> checkPasswordInBackground(BackupKeys keys, String password) =>
    backupCompute(_check, (jsonEncode(keys.toJson()), password));

Future<bool> _check((String, String) a) async {
  final keys = BackupKeys.fromJson(
    (jsonDecode(a.$1) as Map).cast<String, Object?>(),
  );
  final kek = await derivePasswordKek(a.$2, keys.salt, keys.iterations);
  return sameKey(kek, keys.passwordKek);
}
