import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';

/// Opens the app database. [encryptionKey] is a hex string; null = plain.
///
/// Native builds link SQLite3MultipleCiphers (see `hooks:` in pubspec.yaml),
/// so `PRAGMA key` encrypts the file with ChaCha20-Poly1305.
QueryExecutor openAppConnection({
  required String name,
  String? encryptionKey,
  String? directory,
}) {
  return driftDatabase(
    name: name,
    native: DriftNativeOptions(
      shareAcrossIsolates: true,
      // App support dir, not Documents: the DB is app-private.
      databaseDirectory: () async =>
          directory ?? (await getApplicationSupportDirectory()).path,
      setup: encryptionKey == null ? null : _keySetup(encryptionKey),
    ),
  );
}

void Function(CommonDatabase) _keySetup(String key) {
  return (db) {
    final cipher = db.select('PRAGMA cipher');
    if (cipher.isEmpty) {
      throw StateError('SQLite build does not support encryption');
    }
    db.execute("PRAGMA key = \"x'$key'\"");
    // Fails fast if the key is wrong.
    db.select('SELECT count(*) FROM sqlite_master');
  };
}

const bool supportsDbEncryption = true;
