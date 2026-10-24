import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/features/export/data/bundle_service.dart';

import '../../helpers/test_app.dart';
import 'export_fixtures.dart';

// Guarantees of docs/BACKUP.md ("no data is lost"). These tests guard the
// backup format itself; a failure here means backups would silently miss
// data.

void main() {
  test('every table is either backed up or deliberately excluded', () {
    final db = newTestDb();
    addTearDown(db.close);
    final all = {for (final t in db.allTables) t.actualTableName};
    final unclassified = all
        .difference(syncedTableNames.toSet())
        .difference(backupExcludedTables);
    expect(
      unclassified,
      isEmpty,
      reason:
          'Add new tables to syncedTableNames (backed up) or, only after '
          'review, to backupExcludedTables in core/db/database.dart.',
    );
    expect(
      syncedTableNames.toSet().intersection(backupExcludedTables),
      isEmpty,
    );
    expect(backupExcludedTables.difference(all), isEmpty);
    expect(syncedTableNames.toSet(), hasLength(syncedTableNames.length));
  });

  test('round trip keeps every column of every table', () async {
    final source = newTestDb();
    final target = newTestDb();
    addTearDown(source.close);
    addTearDown(target.close);
    await seed(source);
    await fillEveryColumn(source);
    final before = await dumpTables(source);

    // The fill row really sets every column (deleted_at: the tombstone row).
    for (final name in syncedTableNames) {
      final full = before[name]!.firstWhere((r) => r['id'] == 'fill-$name-0');
      final nulls = [
        for (final e in full.entries)
          if (e.value == null && e.key != 'deleted_at') e.key,
      ];
      expect(nulls, isEmpty, reason: name);
    }

    final first = await exportBundle(source, deviceId: 'dev-1');
    await restoreBundle(target, readBundle(target, first));
    expect(await dumpTables(target), before);

    // Exporting the restored data gives byte-identical tables.
    final second = await exportBundle(target, deviceId: 'dev-2');
    final a = readBundle(source, first).manifest.tables;
    final b = readBundle(target, second).manifest.tables;
    for (final name in syncedTableNames) {
      expect(b[name]!.sha256, a[name]!.sha256, reason: name);
    }
  });

  group('every released backup format restores', () {
    final dir = Directory('test/fixtures/bundles');
    final fixtures =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.zip'))
            .toList()
          ..sort((x, y) => x.path.compareTo(y.path));

    test('fixtures exist', () => expect(fixtures, isNotEmpty));

    for (final file in fixtures) {
      test(file.uri.pathSegments.last, () async {
        final db = newTestDb();
        addTearDown(db.close);
        final bytes = Uint8List.fromList(file.readAsBytesSync());
        final contents = readBundle(db, bytes);
        final rows = await restoreBundle(db, contents);
        expect(rows, contents.manifest.totalRows);

        // Nothing from the old backup is lost on the way into this schema:
        // every old column keeps its value.
        final restored = await dumpTables(db);
        for (final entry in contents.tables.entries) {
          final byId = {
            for (final r in restored[entry.key]!) r['id']! as String: r,
          };
          final t = entry.value;
          final id = t.columns.indexOf('id');
          expect(byId, hasLength(t.rows.length), reason: entry.key);
          for (final row in t.rows) {
            final now = byId[row[id]]!;
            for (var c = 0; c < t.columns.length; c++) {
              expect(
                now[t.columns[c]],
                row[c],
                reason: '${entry.key}.${t.columns[c]}',
              );
            }
          }
        }
      });
    }
  });
}
