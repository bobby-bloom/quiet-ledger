import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/setting_def.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Immutable view of all stored settings. Missing values fall back to the
/// definition's default; scoped lookups fall back to the global value.
class SettingsSnapshot {
  const SettingsSnapshot(this._raw);

  const SettingsSnapshot.empty() : _raw = const {};

  /// `<scope>|<key>` -> decoded JSON.
  final Map<String, Object?> _raw;

  static String rowId(String key, String scope) => '$scope|$key';

  /// Returns the value for [def]. Pass `scope: 'account:<id>'` or
  /// `'category:<id>'` for per-entity overrides.
  T get<T>(SettingDef<T> def, {String scope = 'global'}) {
    if (scope != 'global') {
      final id = rowId(def.key, scope);
      if (_raw.containsKey(id)) return def.decode(_raw[id]);
    }
    final id = rowId(def.key, 'global');
    if (_raw.containsKey(id)) return def.decode(_raw[id]);
    return def.defaultValue;
  }

  /// Whether a value is explicitly stored (not the default).
  bool isSet(SettingDef<Object?> def, {String scope = 'global'}) =>
      _raw.containsKey(rowId(def.key, scope));

  bool moduleEnabled(AppModule m) => get(NavigationSettings.module(m));

  Map<String, Object?> get raw => _raw;
}

/// Bootstrap snapshot, loaded before `runApp`. Overridden in main()/tests.
final initialSettingsProvider = Provider<SettingsSnapshot>(
  (ref) => const SettingsSnapshot.empty(),
);

final sharedPreferencesProvider = Provider<SharedPreferencesWithCache?>(
  (ref) => null,
);

/// Live settings. Read with `ref.watch(settingsProvider).get(def)`; for
/// fewer rebuilds use `ref.watch(settingsProvider.select((s) => s.get(def)))`.
final settingsProvider = NotifierProvider<SettingsController, SettingsSnapshot>(
  SettingsController.new,
);

class SettingsController extends Notifier<SettingsSnapshot> {
  StreamSubscription<List<SettingRow>>? _sub;

  AppDatabase get _db => ref.read(databaseProvider);

  @override
  SettingsSnapshot build() {
    final initial = ref.watch(initialSettingsProvider);
    _sub = _db.select(_db.settings).watch().listen((rows) {
      state = snapshotFromRows(rows);
    });
    ref.onDispose(() => _sub?.cancel());
    return initial;
  }

  /// Validates and stores [value]. Stored even if it equals the default so
  /// that exports reflect the user's explicit choice.
  Future<void> set<T>(
    SettingDef<T> def,
    T value, {
    String scope = 'global',
  }) async {
    final error = def.validateValue(value);
    if (error != null) throw ArgumentError.value(value, def.key, error);
    final encoded = jsonEncode(def.encodeValue(value));
    final id = SettingsSnapshot.rowId(def.key, scope);
    final writer = ref.read(syncWriterProvider);
    final log = !def.deviceLocal;
    await writer.transaction(() async {
      final existing = await (_db.select(
        _db.settings,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing == null) {
        await writer.insert(
          _db.settings,
          SettingsCompanion(
            key: Value(def.key),
            value: Value(encoded),
            scope: Value(scope),
          ),
          id: id,
          log: log,
        );
      } else {
        if (existing.deletedAt != null) {
          await writer.undelete(_db.settings, id, log: log);
        }
        await writer.update(
          _db.settings,
          id,
          SettingsCompanion(value: Value(encoded)),
          log: log,
        );
      }
    });
    // Update synchronously so callers see the value without waiting for the
    // stream round-trip.
    state = SettingsSnapshot({...state.raw, id: jsonDecode(encoded)});
    if (def.bootstrap) await _mirror(def.key, encoded);
  }

  /// Removes a stored value so the default (or the global value) applies.
  Future<void> reset(SettingDef<Object?> def, {String scope = 'global'}) async {
    final id = SettingsSnapshot.rowId(def.key, scope);
    final writer = ref.read(syncWriterProvider);
    final existing = await (_db.select(
      _db.settings,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    if (existing != null) {
      await writer.delete(_db.settings, id, log: !def.deviceLocal);
    }
    state = SettingsSnapshot({...state.raw}..remove(id));
    if (def.bootstrap) {
      await ref.read(sharedPreferencesProvider)?.remove(def.key);
    }
  }

  /// Resets all visible settings of [section]. Hidden settings (internal
  /// state such as `onboardingDone`) are kept.
  Future<void> resetSection(SettingSection section) async {
    for (final def in allSettings.where(
      (d) => d.section == section && !d.hidden,
    )) {
      await reset(def);
    }
  }

  Future<void> _mirror(String key, String encoded) async {
    await ref.read(sharedPreferencesProvider)?.setString(key, encoded);
  }
}

SettingsSnapshot snapshotFromRows(Iterable<SettingRow> rows) {
  final map = <String, Object?>{};
  for (final r in rows) {
    if (r.deletedAt != null) continue;
    try {
      map[r.id] = jsonDecode(r.value);
    } on FormatException {
      // Ignore corrupt values; the default applies.
    }
  }
  return SettingsSnapshot(map);
}

/// Loads all settings from the DB (bootstrap).
Future<SettingsSnapshot> loadSettings(AppDatabase db) async =>
    snapshotFromRows(await db.select(db.settings).get());

/// Reads bootstrap-mirrored settings from shared_preferences, for use before
/// the database is open (e.g. theming the lock screen).
SettingsSnapshot bootstrapSnapshot(SharedPreferencesWithCache prefs) {
  final map = <String, Object?>{};
  for (final def in allSettings.where((d) => d.bootstrap)) {
    final v = prefs.getString(def.key);
    if (v == null) continue;
    try {
      map[SettingsSnapshot.rowId(def.key, 'global')] = jsonDecode(v);
    } on FormatException {
      // ignore
    }
  }
  return SettingsSnapshot(map);
}
