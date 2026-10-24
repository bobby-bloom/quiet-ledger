import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/features/import/domain/import_config.dart';

final importProfileRepositoryProvider = Provider<ImportProfileRepository>(
  (ref) => ImportProfileRepository(
    ref.watch(databaseProvider),
    ref.watch(syncWriterProvider),
  ),
);

final importProfilesProvider = StreamProvider<List<ImportProfile>>(
  (ref) => ref.watch(importProfileRepositoryProvider).watchAll(),
);

/// Saved wizard configurations (`import_profiles`), exportable as JSON.
class ImportProfileRepository {
  ImportProfileRepository(this.db, this.writer);

  final AppDatabase db;
  final SyncWriter writer;

  /// File format marker of exported profiles.
  static const formatId = 'personal_finance.import_profile';

  Stream<List<ImportProfile>> watchAll() =>
      (db.select(db.importProfiles)
            ..where((p) => p.deletedAt.isNull())
            ..orderBy([(p) => OrderingTerm(expression: p.name)]))
          .watch();

  Future<List<ImportProfile>> all() =>
      (db.select(db.importProfiles)
            ..where((p) => p.deletedAt.isNull())
            ..orderBy([(p) => OrderingTerm(expression: p.name)]))
          .get();

  Future<ImportProfile?> byId(String id) => (db.select(
    db.importProfiles,
  )..where((p) => p.id.equals(id) & p.deletedAt.isNull())).getSingleOrNull();

  /// Decodes a stored profile's config (tolerates damaged JSON).
  static ImportConfig configOf(ImportProfile p) {
    try {
      return ImportConfig.decode(p.config);
    } on FormatException {
      return const ImportConfig();
    }
  }

  /// Creates or (with [id]) updates a profile. Returns its id.
  Future<String> save({
    required String name,
    required ImportConfig config,
    String? id,
  }) async {
    final c = ImportProfilesCompanion(
      name: Value(name.trim()),
      config: Value(config.encode()),
    );
    if (id != null) {
      await writer.update(db.importProfiles, id, c);
      return id;
    }
    return await writer.insert(db.importProfiles, c);
  }

  Future<void> rename(String id, String name) => writer.update(
    db.importProfiles,
    id,
    ImportProfilesCompanion(name: Value(name.trim())),
  );

  Future<void> delete(String id) => writer.delete(db.importProfiles, id);

  /// JSON file content for sharing a profile.
  static String exportJson(ImportProfile p) =>
      const JsonEncoder.withIndent('  ').convert({
        'format': formatId,
        'version': 1,
        'name': p.name,
        'config': jsonDecode(p.config),
      });

  /// Parses an exported profile. Throws [FormatException] when [json] is
  /// not a profile file.
  static ({String name, ImportConfig config}) parseExport(String json) {
    final v = jsonDecode(json);
    if (v is! Map || v['format'] != formatId || v['config'] is! Map) {
      throw const FormatException('Not an import profile');
    }
    return (
      name: (v['name'] as String?)?.trim().isNotEmpty ?? false
          ? (v['name']! as String).trim()
          : 'Profile',
      config: ImportConfig.fromJson((v['config']! as Map).cast()),
    );
  }

  /// Imports an exported profile; a name clash gets a " (2)" suffix.
  Future<String> importJson(String json) async {
    final parsed = parseExport(json);
    final names = {for (final p in await all()) p.name.toLowerCase()};
    var name = parsed.name;
    var n = 2;
    while (names.contains(name.toLowerCase())) {
      name = '${parsed.name} ($n)';
      n++;
    }
    return await save(name: name, config: parsed.config);
  }
}
