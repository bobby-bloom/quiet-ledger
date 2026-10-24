import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/csv/csv_reader.dart';
import 'package:personal_finance/core/csv/csv_writer.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/sync/hlc.dart';
import 'package:personal_finance/core/sync/raw_rows.dart';
import 'package:personal_finance/features/export/domain/bundle_manifest.dart';

// Full backup bundle (PLAN.md §2.6): a zip with one CSV per synced table
// (`<table>.csv`, written with `CsvOptions.bundle`: RFC 4180, comma, UTF-8,
// header = SQL column names, raw SQL values — dates as unix seconds, bools
// as 0/1, blobs as base64, null as an unquoted empty field) plus
// `manifest.json` with format/schema/app version, creation time, device id,
// row counts and the SHA-256 of every file.

/// `change_log.entity` of the marker written by [restoreBundle].
const restoreMarkerEntity = '_restore';

/// Settings that describe this device rather than the data set. A restore
/// keeps the current device's values for these.
const deviceLocalSettingKeys = {
  'export.autoExportFolder',
  'export.lastAutoExport',
  'data.storageLocation',
  'data.lastTombstonePurge',
};

/// A parsed table of a bundle: column names and raw SQL rows.
@immutable
class BundleTable {
  const BundleTable(this.columns, this.rows);
  final List<String> columns;
  final List<List<Object?>> rows;
}

/// A validated bundle ready to restore.
@immutable
class BundleContents {
  const BundleContents(this.manifest, this.tables);
  final BundleManifest manifest;

  /// SQL table name → content. Tables missing from the bundle restore empty.
  final Map<String, BundleTable> tables;
}

String _sha256(List<int> bytes) => sha256.convert(bytes).toString();

/// Writes all synced tables (including soft-deleted rows and all sync
/// columns) into a bundle zip.
Future<Uint8List> exportBundle(
  AppDatabase db, {
  required String deviceId,
  String appVersion = kAppVersion,
  DateTime? now,
}) async {
  final writer = CsvWriter(CsvOptions.bundle);
  final archive = Archive();
  final infos = <String, BundleTableInfo>{};
  // One read transaction for a consistent snapshot.
  await db.transaction(() async {
    for (final name in syncedTableNames) {
      final table = db.tableByName(name);
      final cols = [for (final c in table.$columns) c.name];
      final rows = await selectRawRows(db, table, orderBy: 'id');
      final text = writer.encodeRowsToString([
        cols,
        for (final r in rows) [for (final c in cols) toJsonValue(r[c])],
      ]);
      final bytes = utf8.encode(text);
      final file = '$name.csv';
      archive.add(ArchiveFile.bytes(file, bytes));
      infos[name] = BundleTableInfo(
        file: file,
        rows: rows.length,
        sha256: _sha256(bytes),
      );
    }
  });
  final manifest = BundleManifest(
    formatVersion: bundleFormatVersion,
    schemaVersion: db.schemaVersion,
    appVersion: appVersion,
    createdAt: (now ?? DateTime.now()).toUtc(),
    deviceId: deviceId,
    tables: infos,
  );
  archive.add(
    ArchiveFile.string(
      bundleManifestFile,
      const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
    ),
  );
  return ZipEncoder().encodeBytes(archive);
}

/// Reads and fully validates a bundle against [db]'s schema: manifest,
/// versions, checksums, row counts, columns and every value. Throws
/// [BundleException]; never touches the data.
BundleContents readBundle(AppDatabase db, Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes, verify: true);
  } on Object {
    throw const BundleException(BundleErrorKind.notABundle, 'zip');
  }
  ArchiveFile? find(String name) =>
      archive.files.where((f) => f.isFile && f.name == name).firstOrNull;

  final manifestFile = find(bundleManifestFile);
  if (manifestFile == null) {
    throw const BundleException(BundleErrorKind.notABundle, bundleManifestFile);
  }
  final BundleManifest manifest;
  try {
    final json = jsonDecode(utf8.decode(manifestFile.content));
    manifest = BundleManifest.fromJson((json as Map).cast<String, Object?>());
  } on Object {
    throw const BundleException(BundleErrorKind.notABundle, bundleManifestFile);
  }
  if (manifest.formatVersion > bundleFormatVersion) {
    throw BundleException(
      BundleErrorKind.newerFormat,
      '${manifest.formatVersion}',
    );
  }
  if (manifest.schemaVersion > db.schemaVersion) {
    throw BundleException(
      BundleErrorKind.newerSchema,
      '${manifest.schemaVersion}',
    );
  }

  final tables = <String, BundleTable>{};
  for (final entry in manifest.tables.entries) {
    final name = entry.key;
    final info = entry.value;
    if (!syncedTableNames.contains(name)) {
      throw BundleException(BundleErrorKind.invalidContent, name);
    }
    final file = find(info.file);
    if (file == null) {
      throw BundleException(BundleErrorKind.checksumMismatch, info.file);
    }
    final content = file.content;
    if (_sha256(content) != info.sha256.toLowerCase()) {
      throw BundleException(BundleErrorKind.checksumMismatch, info.file);
    }
    tables[name] = _parseTable(db.tableByName(name), info, content);
  }
  return BundleContents(manifest, tables);
}

BundleTable _parseTable(
  TableInfo<Table, dynamic> table,
  BundleTableInfo info,
  Uint8List content,
) {
  Never invalid(String detail) =>
      throw BundleException(BundleErrorKind.invalidContent, detail);
  final List<List<String?>> csv;
  try {
    csv = parseCsv(utf8.decode(content), unquotedEmptyAsNull: true);
  } on FormatException catch (e) {
    invalid('${info.file}: ${e.message}');
  }
  if (csv.isEmpty) invalid('${info.file}: no header');
  final header = [for (final h in csv.first) h ?? ''];
  final cols = <GeneratedColumn<Object>>[];
  for (final h in header) {
    cols.add(columnOf(table, h) ?? invalid('${info.file}: column $h'));
  }
  for (final required in syncColumnNames) {
    if (!header.contains(required)) invalid('${info.file}: missing $required');
  }
  final rows = <List<Object?>>[];
  for (var i = 1; i < csv.length; i++) {
    final line = csv[i];
    if (line.length != cols.length) {
      invalid('${info.file}: row $i has ${line.length} fields');
    }
    final row = List<Object?>.filled(cols.length, null);
    for (var c = 0; c < cols.length; c++) {
      final v = line[c];
      if (v == null) continue;
      try {
        row[c] = _parseValue(cols[c], v);
      } on FormatException {
        invalid('${info.file}: row $i, ${header[c]}');
      }
    }
    rows.add(row);
  }
  if (rows.length != info.rows) {
    invalid('${info.file}: ${rows.length} rows, manifest says ${info.rows}');
  }
  return BundleTable(header, rows);
}

Object? _parseValue(GeneratedColumn<Object> col, String v) {
  final t = col.type;
  if (t == DriftSqlType.int ||
      t == DriftSqlType.bigInt ||
      t == DriftSqlType.bool ||
      t == DriftSqlType.dateTime) {
    return int.parse(v);
  }
  if (t == DriftSqlType.double) return double.parse(v);
  if (t == DriftSqlType.blob) return base64Decode(v);
  return v;
}

/// Replaces the contents of all synced tables with [contents] in one DB
/// transaction, preserving ids and sync columns. Clears `change_log` and
/// `sync_state` (recording a single restore marker so the HLC clock stays
/// ahead of the restored rows after a restart), keeps this device's
/// [deviceLocalSettingKeys] and rebuilds the full-text index. [clock] is
/// advanced past the restored HLCs. Returns the number of rows restored.
///
/// Callers must have validated [contents] with [readBundle] and confirmed
/// with the user; this cannot be undone.
Future<int> restoreBundle(
  AppDatabase db,
  BundleContents contents, {
  HlcClock? clock,
}) async {
  var total = 0;
  await db.transaction(() async {
    final keep = await selectRawRows(
      db,
      db.settings,
      where:
          'key IN (${List.filled(deviceLocalSettingKeys.length, '?').join(', ')})',
      args: deviceLocalSettingKeys.toList(),
    );

    for (final name in syncedTableNames) {
      await db.customStatement('DELETE FROM "$name"');
    }
    String? maxHlc;
    for (final e in contents.tables.entries) {
      final t = e.value;
      await insertRawRows(db, db.tableByName(e.key), t.columns, t.rows);
      total += t.rows.length;
      final u = t.columns.indexOf('updated_at');
      for (final r in t.rows) {
        final h = r[u] as String?;
        if (h != null && (maxHlc == null || h.compareTo(maxHlc) > 0)) {
          maxHlc = h;
        }
      }
    }

    await db.customStatement(
      'DELETE FROM settings WHERE '
      'key IN (${List.filled(deviceLocalSettingKeys.length, '?').join(', ')})',
      deviceLocalSettingKeys.toList(),
    );
    for (final r in keep) {
      await upsertRawRow(db, db.settings, r);
    }

    await db.customStatement('DELETE FROM change_log');
    await db.customStatement('DELETE FROM sync_state');

    Hlc? marker;
    if (clock != null) {
      if (maxHlc != null) {
        try {
          clock.receive(Hlc.parse(maxHlc));
        } on ClockDriftException {
          // Backup from a device whose clock was ahead; fall back below.
        }
      }
      marker = clock.tick();
    }
    var markerHlc = marker?.toString() ?? maxHlc ?? '';
    if (maxHlc != null && maxHlc.compareTo(markerHlc) > 0) {
      markerHlc = maxHlc;
    }
    if (markerHlc.isNotEmpty) {
      await db
          .into(db.changeLog)
          .insert(
            ChangeLogCompanion.insert(
              entity: restoreMarkerEntity,
              entityId: contents.manifest.createdAt.toIso8601String(),
              op: ChangeOp.update,
              hlc: markerHlc,
              changedFields: jsonEncode({
                'rows': total,
                'deviceId': contents.manifest.deviceId,
                'appVersion': contents.manifest.appVersion,
              }),
              synced: const Value(true),
            ),
          );
    }
    await db.rebuildSearch();
  });
  db.markTablesUpdated(db.allTables);
  return total;
}
