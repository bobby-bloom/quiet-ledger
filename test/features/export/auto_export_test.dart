import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/core/sync/sync_backend.dart';
import 'package:personal_finance/core/sync/sync_providers.dart';
import 'package:personal_finance/features/export/data/auto_export.dart';
import 'package:personal_finance/features/export/data/bundle_service.dart';
import 'package:personal_finance/features/export/data/export_folder.dart';
import 'package:personal_finance/features/export/data/export_folder_io.dart';
import 'package:personal_finance/features/export/domain/auto_export_plan.dart';
import 'package:personal_finance/features/export/export_startup.dart';

import '../../helpers/test_app.dart';
import 'export_fixtures.dart';

PlatformCapabilities caps({required bool folders}) => PlatformCapabilities(
  isWeb: !folders,
  isDesktop: folders,
  isMobile: false,
  biometrics: false,
  notifications: folders,
  chooseFolder: folders,
  dbEncryption: false,
  dynamicColor: false,
  blockScreenshots: false,
  hideInAppSwitcher: false,
  customStorageLocation: folders,
);

void main() {
  group('schedule rules', () {
    final now = DateTime(2026, 10, 23, 9);

    test('off is never due', () {
      expect(isAutoExportDue(AutoExportSchedule.off, null, now), isFalse);
    });

    test('daily: once per calendar day', () {
      const d = AutoExportSchedule.daily;
      expect(isAutoExportDue(d, null, now), isTrue);
      expect(isAutoExportDue(d, DateTime(2026, 10, 23, 1), now), isFalse);
      expect(isAutoExportDue(d, DateTime(2026, 10, 22, 23), now), isTrue);
      // Clock moved backwards: treat as due.
      expect(isAutoExportDue(d, DateTime(2026, 10, 24), now), isTrue);
    });

    test('weekly: seven calendar days, across DST', () {
      const w = AutoExportSchedule.weekly;
      expect(isAutoExportDue(w, DateTime(2026, 10, 17, 23), now), isFalse);
      expect(isAutoExportDue(w, DateTime(2026, 10, 16), now), isTrue);
      // 25 Oct 2026 is the DST switch in Europe.
      expect(
        isAutoExportDue(w, DateTime(2026, 10, 22), DateTime(2026, 10, 29)),
        isTrue,
      );
    });

    test('file names and retention', () {
      final name = autoExportFileName(DateTime(2026, 1, 2, 3, 4, 5));
      expect(name, 'quiet-ledger-backup-20260102-030405.zip');
      expect(isAutoExportFile(name), isTrue);
      expect(isAutoExportFile('notes.txt'), isFalse);
      final names = [
        'quiet-ledger-backup-20260101-000000.zip',
        'quiet-ledger-backup-20260103-000000.zip',
        'holiday.jpg',
        'quiet-ledger-backup-20260102-000000.zip',
      ];
      expect(autoExportFilesToPrune(names, 2), [
        'quiet-ledger-backup-20260101-000000.zip',
      ]);
      expect(autoExportFilesToPrune(names, 5), isEmpty);
    });

    test('backups from before the rename still count, by their time', () {
      expect(
        isAutoExportFile('personal-finance-backup-20260101-000000.pfbackup'),
        isTrue,
      );
      expect(
        isAutoExportFile('personal-finance-manual-20260101-000000.zip'),
        isFalse,
      );
      expect(
        isAutoExportFile('quiet-ledger-manual-20260101-000000.zip'),
        isFalse,
      );
      final names = [
        'personal-finance-backup-20260105-000000.zip', // newer than q…0104
        'quiet-ledger-backup-20260104-000000.zip',
        'personal-finance-backup-20260102-000000.zip',
        'quiet-ledger-backup-20260103-000000.zip',
        'quiet-ledger-backup-20260103-000000-1.zip',
        'personal-finance-manual-20260101-000000.zip',
      ];
      expect(sortedAutoExportFiles(names), [
        'personal-finance-backup-20260105-000000.zip',
        'quiet-ledger-backup-20260104-000000.zip',
        'quiet-ledger-backup-20260103-000000-1.zip',
        'quiet-ledger-backup-20260103-000000.zip',
        'personal-finance-backup-20260102-000000.zip',
      ]);
      expect(autoExportFilesToPrune(names, 3), [
        'quiet-ledger-backup-20260103-000000.zip',
        'personal-finance-backup-20260102-000000.zip',
      ]);
    });
  });

  group('runAutoExportIfDue', () {
    late AppDatabase db;
    late MemoryExportFolder folder;
    late ProviderContainer c;
    var folders = true;

    setUp(() async {
      db = newTestDb();
      await seed(db);
      folder = MemoryExportFolder();
      folders = true;
      c = testContainer(
        db,
        overrides: [
          platformCapabilitiesProvider.overrideWith(
            (ref) => caps(folders: folders),
          ),
          exportFolderFactoryProvider.overrideWithValue((path) => folder),
        ],
      );
      final s = c.read(settingsProvider.notifier);
      await s.set(ImportExportSettings.autoExport, AutoExportSchedule.daily);
      await s.set(ImportExportSettings.autoExportFolder, '/backups');
      await s.set(ImportExportSettings.autoExportKeep, 3);
    });

    tearDown(() async {
      c.dispose();
      await db.close();
    });

    test('writes a valid backup, then waits for the next day', () async {
      final day1 = DateTime(2026, 10, 1, 8);
      expect(await runAutoExportIfDue(c, now: day1), isTrue);
      expect(folder.files.keys, [autoExportFileName(day1)]);
      final contents = readBundle(db, folder.files.values.single);
      expect(contents.manifest.rowsOf('transactions'), 6);
      expect(
        c.read(settingsProvider).get(ImportExportSettings.lastAutoExport),
        day1.toIso8601String(),
      );
      expect(
        await runAutoExportIfDue(c, now: day1.add(const Duration(hours: 2))),
        isFalse,
      );
      expect(folder.files, hasLength(1));
    });

    test('keeps only the newest N backups and ignores other files', () async {
      folder.files['my-notes.txt'] = Uint8List(1);
      for (var d = 1; d <= 5; d++) {
        expect(
          await runAutoExportIfDue(c, now: DateTime(2026, 10, d, 8)),
          isTrue,
        );
      }
      expect(folder.files.keys.toList()..sort(), [
        'my-notes.txt',
        autoExportFileName(DateTime(2026, 10, 3, 8)),
        autoExportFileName(DateTime(2026, 10, 4, 8)),
        autoExportFileName(DateTime(2026, 10, 5, 8)),
      ]);
    });

    test('skipped without folder capability or folder', () async {
      folders = false;
      c.invalidate(platformCapabilitiesProvider);
      expect(await runAutoExportIfDue(c, now: DateTime(2026, 10)), isFalse);
      folders = true;
      c.invalidate(platformCapabilitiesProvider);
      await c
          .read(settingsProvider.notifier)
          .reset(ImportExportSettings.autoExportFolder);
      expect(await runAutoExportIfDue(c, now: DateTime(2026, 10)), isFalse);
      expect(folder.files, isEmpty);
    });

    test('errors are reported, not thrown', () async {
      final failing = testContainer(
        db,
        overrides: [
          platformCapabilitiesProvider.overrideWithValue(caps(folders: true)),
          exportFolderFactoryProvider.overrideWithValue(
            (path) => throw const FileSystemException('denied'),
          ),
        ],
      );
      addTearDown(failing.dispose);
      expect(
        await runAutoExportIfDue(failing, now: DateTime(2026, 10)),
        isFalse,
      );
      final r = await runAutoExportNow(failing.read);
      expect(r.written, isFalse);
      expect(r.error, isA<FileSystemException>());
      // The startup task never throws either.
      await autoExportStartupTask(failing);
    });

    test('a missing folder is an error, never recreated', () async {
      // E.g. on a drive that is not connected: recreating the path would put
      // the backups on the system disk.
      final dir = await Directory.systemTemp.createTemp('pf-export');
      addTearDown(() => dir.delete(recursive: true));
      final io = IoExportFolder('${dir.path}/usb/backups');
      await expectLater(
        io.listFiles(),
        throwsA(isA<BackupFolderMissingException>()),
      );
      await expectLater(
        io.writeFile('a.zip', Uint8List(1)),
        throwsA(isA<BackupFolderMissingException>()),
      );
      expect(Directory('${dir.path}/usb').existsSync(), isFalse);
    });

    test('io folder writes atomically and lists files', () async {
      final dir = await Directory.systemTemp.createTemp('pf-export');
      addTearDown(() => dir.delete(recursive: true));
      final io = IoExportFolder('${dir.path}/sub');
      Directory('${dir.path}/sub').createSync();
      await io.writeFile('a.zip', Uint8List.fromList([1, 2, 3]));
      await io.writeFile('a.zip', Uint8List.fromList([4]));
      expect(await io.listFiles(), ['a.zip']);
      expect(File('${dir.path}/sub/a.zip').readAsBytesSync(), [4]);
      await io.deleteFile('a.zip');
      expect(await io.listFiles(), isEmpty);
    });
  });

  group('tombstone purge task', () {
    late AppDatabase db;

    setUp(() async {
      db = newTestDb();
      await seed(db);
    });

    tearDown(() => db.close());

    test('runs weekly at most and only without sync backend', () async {
      final c = testContainer(db);
      addTearDown(c.dispose);
      final later = DateTime.now().add(const Duration(days: 365));
      // The seeded tombstones are a year "old" at `later`.
      expect(await runTombstonePurgeIfDue(c, now: later), greaterThan(0));
      expect(
        c.read(settingsProvider).get(DataSettings.lastTombstonePurge),
        later.toIso8601String(),
      );
      // Within a week: skipped.
      expect(
        await runTombstonePurgeIfDue(
          c,
          now: later.add(const Duration(days: 3)),
        ),
        0,
      );

      final synced = testContainer(
        db,
        overrides: [
          syncBackendProvider.overrideWithValue(InMemorySyncBackend()),
        ],
      );
      addTearDown(synced.dispose);
      expect(
        await runTombstonePurgeIfDue(
          synced,
          now: later.add(const Duration(days: 30)),
        ),
        0,
      );
      await tombstonePurgeStartupTask(synced);
    });
  });
}
