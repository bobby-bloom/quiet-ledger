import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_finance/core/db/connection/connection.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefDeviceId = 'sync.deviceId';
const _prefDbEncrypted = 'db.encrypted';
const _secureDbKey = 'db.key';

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
  final db = AppDatabase(
    openAppConnection(
      name: appDbName,
      encryptionKey: key,
      directory: storage.isEmpty ? null : storage,
    ),
  );
  final clock = await restoreClock(db, deviceId);
  final settings = await loadSettings(db);

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
    if (encrypted ?? false) throw const _MissingKey();
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await storage.write(key: _secureDbKey, value: hex);
    await prefs.setBool(_prefDbEncrypted, true);
    return hex;
  } on _MissingKey {
    rethrow;
  } on Object catch (e) {
    if (encrypted ?? false) rethrow;
    debugPrint('Secure storage unavailable, database not encrypted: $e');
    await prefs.setBool(_prefDbEncrypted, false);
    return null;
  }
}

class _MissingKey implements Exception {
  const _MissingKey();

  @override
  String toString() => 'Database key missing from secure storage';
}
