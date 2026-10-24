import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_finance/core/db/connection/connection.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_files.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/core/sync/hlc.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefDeviceId = 'sync.deviceId';
const _prefDbEncrypted = 'db.encrypted';
const _secureDbKey = 'db.key';
const _prefSchemaVersion = 'db.schemaVersion';

/// Everything opened before `runApp`.
class BootstrapResult {
  BootstrapResult({
    required this.db,
    required this.prefs,
    required this.deviceId,
    required this.overrides,
  });

  final AppDatabase db;
  final SharedPreferencesWithCache prefs;
  final String deviceId;
  final List<Override> overrides;
}

/// Opens preferences, the (encrypted) database and loads settings.
Future<BootstrapResult> bootstrap() async {
  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
  await initializeDateFormatting();

  var deviceId = prefs.getString(_prefDeviceId);
  if (deviceId == null) {
    deviceId = newId();
    await prefs.setString(_prefDeviceId, deviceId);
  }

  final key = await _encryptionKey(prefs);
  final storage = bootstrapSnapshot(prefs).get(DataSettings.storageLocation);
  // Copy the file aside before a schema migration (or once, when the
  // version this device last opened is unknown).
  final opened = prefs.getInt(_prefSchemaVersion);
  if (opened == null || opened < AppDatabase.currentSchemaVersion) {
    await copyDatabaseBeforeMigration(
      label: 'v${opened ?? 'unknown'}',
      directory: storage.isEmpty ? null : storage,
    );
  }
  final db = AppDatabase(
    openAppConnection(
      name: appDbName,
      encryptionKey: key,
      directory: storage.isEmpty ? null : storage,
    ),
  );
  final HlcClock clock;
  final SettingsSnapshot settings;
  try {
    clock = await restoreClock(db, deviceId);
    settings = await loadSettings(db);
    if (opened != AppDatabase.currentSchemaVersion) {
      await prefs.setInt(_prefSchemaVersion, AppDatabase.currentSchemaVersion);
    }
  } on Object {
    // Release the file so it can be retried or moved aside.
    await db.close();
    rethrow;
  }

  return BootstrapResult(
    db: db,
    prefs: prefs,
    deviceId: deviceId,
    overrides: [
      ...dbOverrides(db, deviceId, clock: clock),
      initialSettingsProvider.overrideWithValue(settings),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
}

/// Returns the DB key (hex) from secure storage, creating it on first start.
///
/// If secure storage is unavailable on first start (e.g. no keyring on
/// Linux) the database is created unencrypted and that choice is
/// remembered, so an existing encrypted database is never opened without
/// its key.
Future<String?> _encryptionKey(SharedPreferencesWithCache prefs) async {
  if (!supportsDbEncryption) return null;
  const storage = FlutterSecureStorage();
  final encrypted = prefs.getBool(_prefDbEncrypted);
  if (encrypted == false) return null;
  try {
    final existing = await storage.read(key: _secureDbKey);
    if (existing != null) return existing;
    if (encrypted ?? false) throw const MissingDatabaseKeyException();
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await storage.write(key: _secureDbKey, value: hex);
    await prefs.setBool(_prefDbEncrypted, true);
    return hex;
  } on MissingDatabaseKeyException {
    rethrow;
  } on Object catch (e) {
    if (encrypted ?? false) rethrow;
    debugPrint('Secure storage unavailable, database not encrypted: $e');
    await prefs.setBool(_prefDbEncrypted, false);
    return null;
  }
}

/// The database is marked encrypted but its key is gone from secure
/// storage (e.g. app data restored without the Keystore/keychain).
class MissingDatabaseKeyException implements Exception {
  const MissingDatabaseKeyException();

  @override
  String toString() => 'Database key missing from secure storage';
}

/// Recovery after [bootstrap] failed: moves the unreadable database files to
/// `<app support>/unreadable/<timestamp>/` and keeps their key in secure
/// storage as `db.key.unreadable.<timestamp>`, so the next [bootstrap]
/// creates an empty database. Nothing is deleted. Returns the folder the
/// files were moved to (null when there was no file). Native only.
Future<String?> startWithEmptyDatabase({DateTime? now}) async {
  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
  final at = now ?? DateTime.now();
  final storage = bootstrapSnapshot(prefs).get(DataSettings.storageLocation);
  final moved = await quarantineDatabaseFiles(
    directory: storage.isEmpty ? null : storage,
    now: at,
  );
  if (supportsDbEncryption) {
    const secure = FlutterSecureStorage();
    try {
      final key = await secure.read(key: _secureDbKey);
      if (key != null) {
        await secure.write(
          key: '$_secureDbKey.unreadable.${at.millisecondsSinceEpoch}',
          value: key,
        );
        await secure.delete(key: _secureDbKey);
      }
    } on Object catch (e) {
      debugPrint('Could not move the database key aside: $e');
    }
  }
  await prefs.remove(_prefDbEncrypted);
  return moved;
}
