import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/features/export/data/data_tools.dart';

import '../../helpers/test_app.dart';
import 'export_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = newTestDb();
    await seed(db);
  });

  tearDown(() => db.close());

  test('statistics', () async {
    final s = await dbStatistics(db);
    expect(s.tables.map((t) => t.table), syncedTableNames);
    expect(s['transactions']!.live, 5);
    expect(s['transactions']!.deleted, 1);
    expect(s['accounts']!.total, 2);
    expect(s.liveRows, greaterThan(10));
    expect(s.changeLogEntries, greaterThan(0));
    expect(s.changeLogUnsynced, s.changeLogEntries);
    expect(s.sizeBytes, greaterThan(0));
  });

  test('rebuild search index', () async {
    await db.customStatement('DELETE FROM txn_search');
    await rebuildSearchIndex(db);
    final rows = await db.customSelect('SELECT rowid FROM txn_search').get();
    expect(rows, hasLength(6));
  });

  test('purge delegates with the cut-off', () async {
    expect(await purgeTombstones(db, const Duration(days: 90)), 0);
    expect(
      await purgeTombstones(
        db,
        const Duration(days: 90),
        now: DateTime.now().add(const Duration(days: 91)),
      ),
      1,
    );
  });

  test('reset wipes everything', () async {
    await resetAppData(db);
    final s = await dbStatistics(db);
    expect(s.liveRows + s.deletedRows, 0);
    expect(s.changeLogEntries, 0);
    final fts = await db.customSelect('SELECT rowid FROM txn_search').get();
    expect(fts, isEmpty);
  });
}
