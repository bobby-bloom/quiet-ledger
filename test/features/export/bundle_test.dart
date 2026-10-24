import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/app_version.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/sync/hlc.dart';
import 'package:personal_finance/features/export/data/bundle_service.dart';
import 'package:personal_finance/features/export/domain/bundle_manifest.dart';

import '../../helpers/test_app.dart';
import 'export_fixtures.dart';

void main() {
  late AppDatabase source;
  late AppDatabase target;

  setUp(() async {
    source = newTestDb();
    target = newTestDb();
    await seed(source);
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  Future<Uint8List> export() => exportBundle(
    source,
    deviceId: 'dev-1',
    now: DateTime.utc(2026, 10, 23, 8),
  );

  /// Rebuilds the zip with [edit] applied to the manifest JSON and/or files.
  Uint8List tamper(
    Uint8List zip, {
    Map<String, Object?> Function(Map<String, Object?> m)? manifest,
    Map<String, List<int>> Function(Map<String, List<int>> files)? files,
  }) {
    final archive = ZipDecoder().decodeBytes(zip);
    var contents = {for (final f in archive.files) f.name: f.content.toList()};
    if (files != null) contents = files(contents);
    if (manifest != null) {
      final m = (jsonDecode(utf8.decode(contents[bundleManifestFile]!)) as Map)
          .cast<String, Object?>();
      contents[bundleManifestFile] = utf8.encode(jsonEncode(manifest(m)));
    }
    final out = Archive();
    for (final e in contents.entries) {
      out.add(ArchiveFile.bytes(e.key, e.value));
    }
    return ZipEncoder().encodeBytes(out);
  }

  test('manifest describes every synced table', () async {
    final zip = await export();
    final contents = readBundle(source, zip);
    final m = contents.manifest;
    expect(m.formatVersion, bundleFormatVersion);
    expect(m.schemaVersion, source.schemaVersion);
    expect(m.appVersion, appVersion);
    expect(m.deviceId, 'dev-1');
    expect(m.createdAt, DateTime.utc(2026, 10, 23, 8));
    expect(m.tables.keys, syncedTableNames);
    // Transfer = 2 legs, deleted transaction included as tombstone.
    expect(m.rowsOf('transactions'), 6);
    expect(m.rowsOf('transaction_splits'), 2);
    expect(m.rowsOf('attachments'), 1);
    expect(m.tables['accounts']!.sha256, hasLength(64));
  });

  test(
    'round trip: export → restore into an empty DB → identical rows',
    () async {
      final zip = await export();
      final before = await dumpTables(source);
      final clock = testClock(node: 'dev-2');
      final rows = await restoreBundle(
        target,
        readBundle(target, zip),
        clock: clock,
      );
      expect(rows, readBundle(source, zip).manifest.totalRows);
      expect(await dumpTables(target), before);

      // Blobs, nulls vs empty strings and line breaks survive.
      final acc = await target.select(target.accounts).get();
      expect(acc.every((a) => a.note == ''), isTrue);
      expect(acc.every((a) => a.color == null), isTrue);
      final att = await target.select(target.attachments).getSingle();
      expect(att.data, [0, 1, 2, 250, 255]);
      final txn = await (target.select(
        target.transactions,
      )..where((t) => t.note.equals('Zeile 1\nZeile 2'))).getSingle();
      expect(txn.payee, 'Bäckerei "Korn"; Filiale');

      // change_log holds only the restore marker, ahead of all restored HLCs.
      final log = await target.select(target.changeLog).get();
      expect(log, hasLength(1));
      expect(log.single.entity, restoreMarkerEntity);
      expect(log.single.synced, isTrue);
      final maxRestored = before.values
          .expand((r) => r)
          .map((r) => r['updated_at']! as String)
          .reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      expect(log.single.hlc.compareTo(maxRestored), greaterThan(0));
      expect(clock.last > Hlc.parse(maxRestored), isTrue);

      // Search index rebuilt.
      final hits = await target
          .customSelect(
            "SELECT rowid FROM txn_search WHERE txn_search MATCH 'Korn'",
          )
          .get();
      expect(hits, hasLength(1));
    },
  );

  test(
    'restore replaces existing data and keeps device-local settings',
    () async {
      final w = SyncWriter(target, testClock(node: 'dev-2'), 'dev-2');
      await w.insert(
        target.accounts,
        AccountsCompanion(
          name: const Value('Old'),
          type: const Value(AccountType.cash),
          openingDate: Value(DateTime(2020)),
        ),
      );
      await w.insert(
        target.settings,
        SettingsCompanion(
          key: const Value('export.autoExportFolder'),
          value: Value(jsonEncode('/home/me/Backups')),
        ),
        id: 'global|export.autoExportFolder',
      );
      // The source has another folder configured.
      await SyncWriter(source, testClock(), 'dev-1').insert(
        source.settings,
        SettingsCompanion(
          key: const Value('export.autoExportFolder'),
          value: Value(jsonEncode('/other/device')),
        ),
        id: 'global|export.autoExportFolder',
      );

      await restoreBundle(target, readBundle(target, await export()));
      final names = (await target.select(target.accounts).get()).map(
        (a) => a.name,
      );
      expect(names, isNot(contains('Old')));
      expect(names, containsAll(['Girokonto', 'Tagesgeld']));
      final folder = await (target.select(
        target.settings,
      )..where((s) => s.key.equals('export.autoExportFolder'))).getSingle();
      expect(jsonDecode(folder.value), '/home/me/Backups');
      final lang = await (target.select(
        target.settings,
      )..where((s) => s.key.equals('general.language'))).getSingle();
      expect(jsonDecode(lang.value), 'de');
    },
  );

  group('validation', () {
    Future<void> expectError(Uint8List bytes, BundleErrorKind kind) async {
      expect(
        () => readBundle(target, bytes),
        throwsA(isA<BundleException>().having((e) => e.kind, 'kind', kind)),
      );
    }

    test('not a zip', () async {
      await expectError(
        Uint8List.fromList(utf8.encode('date;amount\n')),
        BundleErrorKind.notABundle,
      );
    });

    test('zip without manifest', () async {
      final zip = tamper(
        await export(),
        files: (f) => f..remove(bundleManifestFile),
      );
      await expectError(zip, BundleErrorKind.notABundle);
    });

    test('bad checksum', () async {
      final zip = tamper(
        await export(),
        files: (f) {
          final csv = utf8.decode(f['accounts.csv']!);
          return f
            ..['accounts.csv'] = utf8.encode(
              csv.replaceAll('Girokonto', 'Hacked'),
            );
        },
      );
      await expectError(zip, BundleErrorKind.checksumMismatch);
    });

    test('missing table file', () async {
      final zip = tamper(await export(), files: (f) => f..remove('tags.csv'));
      await expectError(zip, BundleErrorKind.checksumMismatch);
    });

    test('newer format version', () async {
      final zip = tamper(
        await export(),
        manifest: (m) => m..['formatVersion'] = bundleFormatVersion + 1,
      );
      await expectError(zip, BundleErrorKind.newerFormat);
    });

    test('newer schema version', () async {
      final zip = tamper(
        await export(),
        manifest: (m) => m..['schemaVersion'] = 99,
      );
      await expectError(zip, BundleErrorKind.newerSchema);
    });

    test('row count mismatch', () async {
      final zip = tamper(
        await export(),
        manifest: (m) {
          final tables = (m['tables']! as Map).cast<String, Object?>();
          (tables['accounts']! as Map)['rows'] = 5;
          return m;
        },
      );
      await expectError(zip, BundleErrorKind.invalidContent);
    });

    test('a failed restore leaves the data untouched', () async {
      await seed(target);
      final before = await dumpTables(target);
      final contents = readBundle(target, await export());
      // Corrupt the parsed content so the insert fails mid-transaction.
      final broken = BundleContents(contents.manifest, {
        ...contents.tables,
        'accounts': BundleTable(contents.tables['accounts']!.columns, [
          ...contents.tables['accounts']!.rows,
          contents.tables['accounts']!.rows.first, // duplicate id
        ]),
      });
      await expectLater(restoreBundle(target, broken), throwsA(anything));
      expect(await dumpTables(target), before);
    });
  });
}
