import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/common.dart';

/// Opens the app database in the browser (OPFS or IndexedDB via the drift
/// worker in `web/drift_worker.js`, built from `web/drift_worker.dart`).
///
/// [encryptionKey] (64 hex chars from flutter_secure_storage, see
/// `app/bootstrap.dart`) encrypts the database with SQLite3 Multiple Ciphers
/// (`web/sqlite3mc.wasm`). The key reaches the worker in the fragment of the
/// WASM URI; the worker strips it before loading (see `web/drift_worker.dart`).
/// When workers are unavailable drift opens the database on this thread and
/// [_applyCipher] runs here instead.
QueryExecutor openAppConnection({
  required String name,
  String? encryptionKey,
  String? directory,
}) {
  final key = encryptionKey;
  if (key != null && !_hexKey.hasMatch(key)) {
    throw ArgumentError('Database key must be 64 hex characters');
  }
  final sqlite = Uri.parse(
    key == null ? 'sqlite3mc.wasm' : 'sqlite3mc.wasm#k=$key',
  );
  return DatabaseConnection.delayed(
    Future(() async {
      final result = await WasmDatabase.open(
        databaseName: name,
        sqlite3Uri: sqlite,
        driftWorkerUri: Uri.parse('drift_worker.js'),
        localSetup: key == null ? null : (db) => _applyCipher(db, key),
      );
      if (result.missingFeatures.isNotEmpty) {
        debugPrint(
          'Using ${result.chosenImplementation} due to missing browser '
          'features: ${result.missingFeatures}',
        );
      }
      return result.resolvedExecutor;
    }),
  );
}

final _hexKey = RegExp(r'^[0-9a-fA-F]{64}$');

/// Same as `applyCipher` in web/drift_worker.dart (keep in sync): key a new
/// or encrypted database, encrypt an existing plaintext one in place.
void _applyCipher(CommonDatabase db, String key) {
  if (db.select('PRAGMA cipher').isEmpty) {
    throw StateError('sqlite3mc.wasm is required for an encrypted database');
  }
  final literal = "\"x'$key'\"";
  var readableWithoutKey = true;
  try {
    db.select('SELECT count(*) FROM sqlite_master');
  } on SqliteException {
    readableWithoutKey = false;
  }
  if (!readableWithoutKey) {
    db.execute('PRAGMA key = $literal');
  } else {
    final pages = db.select('PRAGMA page_count').first.values.first;
    db.execute(
      pages == 0 ? 'PRAGMA key = $literal' : 'PRAGMA rekey = $literal',
    );
  }
  db.select('SELECT count(*) FROM sqlite_master');
}

/// The web build encrypts with sqlite3mc.wasm and the custom drift worker.
const bool supportsDbEncryption = true;
