import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:meta/meta.dart';
import 'package:personal_finance/core/app_version.dart' as app;
import 'package:personal_finance/core/attachments/receipt_store.dart';
import 'package:personal_finance/core/csv/csv_reader.dart';
import 'package:personal_finance/core/csv/csv_writer.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/sync/hlc.dart';
import 'package:personal_finance/core/sync/raw_rows.dart';
import 'package:personal_finance/features/export/domain/bundle_manifest.dart';

// Full backup bundle (PLAN.md §2.6): a zip with one CSV per synced table
// (`<table>.csv`, written with `CsvOptions.bundle`: RFC 4180, comma, UTF-8,
// header = SQL column names, raw SQL values — dates as unix seconds, bools
// as 0/1, blobs as base64, null as an unquoted empty field) plus
// `manifest.json` with format/schema/app version, creation time, device id,
// row counts and the SHA-256 of every file. Native receipt files are stored
// uncompressed as `files/<sha256>` and listed by attachment id under
// `files` (web receipts are already in `attachments.data`). See
// docs/BACKUP.md.

/// `change_log.entity` of the marker written by [restoreBundle].
const restoreMarkerEntity = '_restore';


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
  const BundleContents(this.manifest, this.tables, [this.files = const {}]);
  final BundleManifest manifest;

  /// SQL table name → content. Tables missing from the bundle restore empty.
  final Map<String, BundleTable> tables;

  /// Receipt file name in the bundle (`files/<sha256>`) → bytes, verified.
  final Map<String, Uint8List> files;
}

String _sha256(List<int> bytes) => sha256.convert(bytes).toString();

/// Writes all synced tables (including soft-deleted rows and all sync
/// columns) and the receipt files of all attachments (also soft-deleted
/// ones, so undo keeps working after a restore) into a bundle zip.
/// [includeReceiptFiles] false leaves the files out (on-device safety
/// copies, whose receipt files stay where they are).
Future<Uint8List> exportBundle(
  AppDatabase db, {
  required String deviceId,
  String appVersion = app.appVersion,
  DateTime? now,
  ReceiptStore receipts = const PlatformReceiptStore(),
  bool includeReceiptFiles = true,
}) async {
  final writer = CsvWriter(CsvOptions.bundle);
  final archive = Archive();
  final infos = <String, BundleTableInfo>{};
  var attachments = const <Map<String, Object?>>[];
  // One read transaction for a consistent snapshot.
  await db.transaction(() async {
    for (final name in syncedTableNames) {
      final table = db.tableByName(name);
      final cols = [for (final c in table.$columns) c.name];
      final rows = await selectRawRows(db, table, orderBy: 'id');
      if (name == 'attachments') attachments = rows;
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

  final (:files, :missing) = await _addReceipts(
    archive,
    includeReceiptFiles ? attachments : const [],
    receipts,
  );

  final manifest = BundleManifest(
    formatVersion: bundleFormatVersion,
    schemaVersion: db.schemaVersion,
    appVersion: appVersion,
    createdAt: (now ?? DateTime.now()).toUtc(),
    deviceId: deviceId,
    tables: infos,
    files: files,
    missingFiles: missing,
  );
  archive.add(
    ArchiveFile.string(
      bundleManifestFile,
      const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
    ),
  );
  return ZipEncoder().encodeBytes(archive);
}

/// Adds the receipt files of [attachments] (raw rows) to [archive] as
/// `files/<sha256>`, once per content. Rows with bytes in `data` (web) need
/// no file.
Future<({Map<String, BundleFileInfo> files, List<String> missing})>
_addReceipts(
  Archive archive,
  Iterable<Map<String, Object?>> attachments,
  ReceiptStore receipts,
) async {
  final files = <String, BundleFileInfo>{};
  final written = <String>{};
  final missing = <String>[];
  for (final a in attachments) {
    final path = a['file_path'] as String?;
    if (path == null || a['data'] != null) continue;
    final id = a['id']! as String;
    final bytes = await receipts.read(path);
    if (bytes == null) {
      missing.add(id);
      continue;
    }
    final hash = _sha256(bytes);
    final file = 'files/$hash';
    if (written.add(file)) {
      archive.add(ArchiveFile.noCompress(file, bytes.length, bytes));
    }
    files[id] = BundleFileInfo(file: file, size: bytes.length, sha256: hash);
  }
  return (files: files, missing: missing);
}

/// [zip] (a bundle without receipt files, such as a safety copy) with the
/// receipt files its attachment rows point to, read from [receipts] now.
/// Receipts whose file is gone are listed in `missingFiles`. A bundle that
/// already carries files is returned unchanged.
Future<Uint8List> withReceiptFiles(
  AppDatabase db,
  Uint8List zip,
  ReceiptStore receipts,
) async {
  final contents = readBundle(db, zip);
  final att = contents.tables['attachments'];
  if (contents.manifest.files.isNotEmpty || att == null) return zip;
  final archive = Archive();
  for (final f in ZipDecoder().decodeBytes(zip).files) {
    if (f.isFile && f.name != bundleManifestFile) {
      archive.add(ArchiveFile.bytes(f.name, f.content));
    }
  }
  final rows = [
    for (final r in att.rows)
      {for (var c = 0; c < att.columns.length; c++) att.columns[c]: r[c]},
  ];
  final (:files, :missing) = await _addReceipts(archive, rows, receipts);
  final m = contents.manifest;
  final manifest = BundleManifest(
    formatVersion: m.formatVersion,
    schemaVersion: m.schemaVersion,
    appVersion: m.appVersion,
    createdAt: m.createdAt,
    deviceId: m.deviceId,
    tables: m.tables,
    files: files,
    missingFiles: missing,
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

  // Receipt files: present, intact and referenced by an attachment row.
  final attachmentIds = <Object?>{};
  final att = tables['attachments'];
  if (att != null) {
    final id = att.columns.indexOf('id');
    for (final r in att.rows) {
      attachmentIds.add(r[id]);
    }
  }
  final files = <String, Uint8List>{};
  for (final e in manifest.files.entries) {
    final info = e.value;
    if (!attachmentIds.contains(e.key)) {
      throw BundleException(BundleErrorKind.invalidContent, info.file);
    }
    if (files.containsKey(info.file)) continue;
    final file = find(info.file);
    if (file == null) {
      throw BundleException(BundleErrorKind.checksumMismatch, info.file);
    }
    final content = file.content;
    if (content.length != info.size ||
        _sha256(content) != info.sha256.toLowerCase()) {
      throw BundleException(BundleErrorKind.checksumMismatch, info.file);
    }
    files[info.file] = content;
  }
  return BundleContents(manifest, tables, files);
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

/// The newest change (HLC) in [contents], null when it holds no rows.
String? newestChangeOf(BundleContents contents) {
  String? max;
  for (final t in contents.tables.values) {
    final u = t.columns.indexOf('updated_at');
    if (u < 0) continue;
    for (final r in t.rows) {
      final h = r[u] as String?;
      if (h != null && (max == null || h.compareTo(max) > 0)) max = h;
    }
  }
  return max;
}

/// Rows of [db] changed after [contents] was made (their HLC is newer than
/// everything in it). A restore replaces these; they stay in the safety
/// copy.
Future<int> rowsChangedAfter(AppDatabase db, BundleContents contents) async {
  final newest = newestChangeOf(contents);
  var n = 0;
  for (final name in syncedTableNames) {
    if (name == 'settings') continue; // device settings change constantly
    final r = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM "$name"'
          '${newest == null ? '' : ' WHERE updated_at > ?'}',
          variables: [if (newest != null) Variable<String>(newest)],
        )
        .getSingle();
    n += r.data['n']! as int;
  }
  return n;
}

/// Replaces the contents of all synced tables with [contents] in one DB
/// transaction, preserving ids and sync columns. Clears `change_log` and
/// `sync_state` (recording a single restore marker so the HLC clock stays
/// ahead of the restored rows after a restart), keeps this device's
/// [deviceLocalSettingKeys] and rebuilds the full-text index. [clock] is
/// advanced past the restored HLCs. Returns the number of rows restored.
///
/// Receipt files are written to [receipts] under new names before the
/// transaction (existing files are never overwritten or deleted) and the
/// restored rows point at them; on the web their bytes go into
/// `attachments.data` instead. If the transaction fails, the files written
/// here are removed again and nothing else has changed.
///
/// Callers must have validated [contents] with [readBundle] and confirmed
/// with the user; this cannot be undone.
Future<int> restoreBundle(
  AppDatabase db,
  BundleContents contents, {
  HlcClock? clock,
  ReceiptStore receipts = const PlatformReceiptStore(),
}) async {
  final created = <String>[];
  final BundleContents restored;
  try {
    restored = await _placeReceipts(contents, receipts, created);
    return await _restoreRows(db, restored, clock);
  } on Object {
    for (final f in created) {
      try {
        await receipts.delete(f);
      } on Object catch (e) {
        // Only an orphaned copy remains; the data itself is unchanged.
        debugPrint('Could not remove restored receipt $f: $e');
      }
    }
    rethrow;
  }
}

/// Writes the bundle's receipt files and returns [contents] with the
/// attachment rows pointing at them.
Future<BundleContents> _placeReceipts(
  BundleContents contents,
  ReceiptStore receipts,
  List<String> created,
) async {
  final att = contents.tables['attachments'];
  if (att == null || contents.manifest.files.isEmpty) return contents;
  final idCol = att.columns.indexOf('id');
  final nameCol = att.columns.indexOf('file_name');
  final pathCol = att.columns.indexOf('file_path');
  final dataCol = att.columns.indexOf('data');
  if (pathCol < 0 || dataCol < 0) return contents;

  final stored = <String, String>{};
  final rows = <List<Object?>>[];
  for (final r in att.rows) {
    final info = contents.manifest.files[r[idCol]];
    if (info == null) {
      rows.add(r);
      continue;
    }
    final bytes = contents.files[info.file]!;
    final row = List<Object?>.of(r);
    if (receipts.usesFiles) {
      var path = stored[info.file];
      // Same device: the identical file is still there, keep using it.
      final old = r[pathCol] as String?;
      if (path == null && old != null) {
        final current = await receipts.read(old);
        if (current != null && _sha256(current) == info.sha256.toLowerCase()) {
          path = stored[info.file] = old;
        }
      }
      if (path == null) {
        final name = nameCol < 0 ? 'receipt' : (r[nameCol] as String? ?? '');
        path = await receipts.write(name, bytes);
        created.add(path);
        stored[info.file] = path;
      }
      row[pathCol] = path;
    } else {
      row
        ..[pathCol] = null
        ..[dataCol] = bytes;
    }
    rows.add(row);
  }
  return BundleContents(contents.manifest, {
    ...contents.tables,
    'attachments': BundleTable(att.columns, rows),
  }, contents.files);
}

Future<int> _restoreRows(
  AppDatabase db,
  BundleContents contents,
  HlcClock? clock,
) async {
  var total = 0;
  await db.transaction(() async {
    final keep = await selectRawRows(
      db,
      db.settings,
      where:
          'key IN (${List.filled(deviceLocalSettingKeys.length, '?').join(', ')})',
      args: deviceLocalSettingKeys.toList(),
    );

    // The FTS index has no delete trigger; clear it first or re-inserted
    // transactions collide with the old rowids.
    await db.customStatement('DELETE FROM txn_search');
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
