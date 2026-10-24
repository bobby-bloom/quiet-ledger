import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/csv/file_output.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/features/export/data/bundle_service.dart';
import 'package:personal_finance/features/export/data/export_folder.dart';
import 'package:personal_finance/features/export/presentation/folder_backups.dart';
import 'package:personal_finance/features/export/presentation/restore_flow.dart';

import '../../helpers/test_app.dart';
import 'export_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = newTestDb());
  tearDown(() => db.close());

  test('changes made after a backup are counted', () async {
    final w = SyncWriter(db, testClock(start: 1800000000000), 'dev-1');
    await seed(db, writer: w);
    final contents = readBundle(db, await exportBundle(db, deviceId: 'd'));
    expect(await rowsChangedAfter(db, contents), 0);
    await w.insert(db.tags, const TagsCompanion(name: Value('neu')));
    expect(await rowsChangedAfter(db, contents), 1);
  });

  test('backup file names give their time', () {
    expect(
      autoExportFileTime('personal-finance-backup-20261024-081500.pfbackup'),
      DateTime(2026, 10, 24, 8, 15),
    );
    expect(autoExportFileTime('notes.txt'), isNull);
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        Scaffold(body: child),
        db: db,
        overrides: overrides,
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('check a backup reports what it holds', (tester) async {
    final zip = await tester.runAsync(() async {
      await seed(db);
      return await exportBundle(db, deviceId: 'd');
    });
    await pump(
      tester,
      Consumer(
        builder: (context, ref, _) => FilledButton(
          onPressed: () => checkBackupFile(
            context,
            ref,
            file: PickedFile('backup.zip', zip!),
          ),
          child: const Text('check'),
        ),
      ),
    );
    await tester.tap(find.text('check'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Backup is complete'), findsOneWidget);
    expect(find.textContaining('backup.zip'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('backups in the folder can be restored, newer data is named', (
    tester,
  ) async {
    final folder = MemoryExportFolder();
    await tester.runAsync(() async {
      final w = SyncWriter(db, testClock(start: 1800000000000), 'dev-1');
      await seed(db, writer: w);
      folder.files['personal-finance-backup-20261024-081500.zip'] =
          await exportBundle(db, deviceId: 'd');
      folder.files['notes.txt'] = Uint8List(1);
      await w.insert(db.tags, const TagsCompanion(name: Value('später')));
    });
    await pump(
      tester,
      const FolderBackupsCard(folder: '/backups'),
      overrides: [exportFolderFactoryProvider.overrideWithValue((_) => folder)],
    );
    expect(
      find.textContaining('personal-finance-backup-20261024'),
      findsOneWidget,
    );
    expect(find.text('notes.txt'), findsNothing);

    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('1 change on this device is newer'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await unmount(tester);
  });
}
