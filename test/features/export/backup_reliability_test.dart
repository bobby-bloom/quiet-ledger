import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/platform/notifications.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/setting_def.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/export/data/auto_export.dart';
import 'package:personal_finance/features/export/data/bundle_service.dart';
import 'package:personal_finance/features/export/data/export_folder.dart';
import 'package:personal_finance/features/export/data/safety_copies.dart';
import 'package:personal_finance/features/export/domain/auto_export_plan.dart';
import 'package:personal_finance/features/export/domain/backup_health.dart';
import 'package:personal_finance/features/export/domain/backup_settings.dart';

import '../../helpers/test_app.dart';
import 'auto_export_test.dart' show caps;
import 'export_fixtures.dart';

class _Notifications extends NoopNotificationService {
  final shown = <String>[];

  @override
  Future<bool> init({Map<NotificationKind, String> channelNames = const {}}) =>
      Future.value(true);

  @override
  Future<void> showBackupProblem({
    required String title,
    required String body,
  }) async => shown.add(title);
}

/// A folder whose reads can be made to return something else than was
/// written (a broken cloud sync client or SD card).
class _FlakyFolder extends MemoryExportFolder {
  bool corruptReads = false;
  bool failWrites = false;
  int writes = 0;

  @override
  Future<void> writeFile(String name, Uint8List bytes) async {
    writes++;
    if (failWrites) throw StateError('disk full');
    await super.writeFile(name, bytes);
  }

  @override
  Future<Uint8List?> readFile(String name) async {
    final b = await super.readFile(name);
    if (!corruptReads || b == null) return b;
    return Uint8List.fromList([...b]..[b.length ~/ 2] ^= 0xff);
  }
}

void main() {
  group('scheduled backup', () {
    late AppDatabase db;
    late _FlakyFolder folder;
    late _Notifications notes;
    late ProviderContainer c;

    setUp(() async {
      db = newTestDb();
      await seed(db);
      folder = _FlakyFolder();
      notes = _Notifications();
      c = testContainer(
        db,
        overrides: [
          platformCapabilitiesProvider.overrideWithValue(caps(folders: true)),
          exportFolderFactoryProvider.overrideWithValue((path) => folder),
          notificationServiceProvider.overrideWithValue(notes),
        ],
      );
      final s = c.read(settingsProvider.notifier);
      await s.set(ImportExportSettings.autoExport, AutoExportSchedule.daily);
      await s.set(ImportExportSettings.autoExportFolder, '/backups');
      await s.set(ImportExportSettings.autoExportKeep, 2);
    });

    tearDown(() async {
      c.dispose();
      await db.close();
    });

    String? get(SettingDef<String?> def) => c.read(settingsProvider).get(def);

    test(
      'success records attempt and verified time, clears the error',
      () async {
        await c
            .read(settingsProvider.notifier)
            .set(BackupSettings.lastError, 'old problem');
        final at = DateTime(2026, 10, 1, 8);
        final r = await runAutoExportNow(c.read, now: at);
        expect(r.written, isTrue);
        expect(get(BackupSettings.lastAttempt), at.toIso8601String());
        expect(get(BackupSettings.lastVerified), at.toIso8601String());
        expect(get(BackupSettings.lastError), isNull);
      },
    );

    test('a backup that reads back differently is a failure', () async {
      folder.files['personal-finance-backup-20260101-000000.zip'] = Uint8List(
        1,
      );
      folder.files['personal-finance-backup-20260102-000000.zip'] = Uint8List(
        1,
      );
      folder.corruptReads = true;
      final r = await runAutoExportNow(c.read, now: DateTime(2026, 10, 1, 8));
      expect(r.written, isFalse);
      // Nothing old was pruned, nothing recorded as done.
      expect(folder.files, hasLength(3));
      expect(get(ImportExportSettings.lastAutoExport), isNull);
      expect(get(BackupSettings.lastVerified), isNull);
      expect(get(BackupSettings.lastError), contains('differs'));
    });

    test('failures are notified once and retried on the next run', () async {
      folder.failWrites = true;
      final day = DateTime(2026, 10, 1, 8);
      expect(await runAutoExportIfDue(c, now: day), isFalse);
      // The fixture's language is German.
      expect(notes.shown, ['Sicherung fehlgeschlagen']);
      expect(get(BackupSettings.lastError), contains('disk full'));

      // Same day, still failing: retried (not "already done today"), not
      // notified again.
      expect(
        await runAutoExportIfDue(c, now: day.add(const Duration(hours: 1))),
        isFalse,
      );
      expect(folder.writes, 2);
      expect(notes.shown, hasLength(1));

      folder.failWrites = false;
      expect(
        await runAutoExportIfDue(c, now: day.add(const Duration(hours: 2))),
        isTrue,
      );
      expect(get(BackupSettings.lastError), isNull);
    });

    test('a backup written after a clock change is never pruned', () async {
      for (final d in ['20270101', '20270102', '20270103']) {
        folder.files['personal-finance-backup-$d-000000.zip'] = Uint8List(1);
      }
      final at = DateTime(2026, 10, 1, 8); // "older" than the files above
      final r = await runAutoExportNow(c.read, now: at);
      expect(r.written, isTrue);
      expect(folder.files.keys, contains(autoExportFileName(at)));
      expect(
        folder.files.keys,
        contains('personal-finance-backup-20270103-000000.zip'),
      );
      expect(folder.files, hasLength(2));
    });

    test('concurrent runs share one backup', () async {
      final a = runAutoExportNow(c.read, now: DateTime(2026, 10, 1, 8));
      final b = runAutoExportNow(c.read, now: DateTime(2026, 10, 1, 8));
      expect(identical(await a, await b), isTrue);
      expect(folder.writes, 1);
    });

    test('backup state of this device survives a restore', () async {
      await runAutoExportNow(c.read, now: DateTime(2026, 10, 1, 8));
      final zip = folder.files.values.single;
      final other = newTestDb();
      addTearDown(other.close);
      final ow = SyncWriter(other, testClock(node: 'o'), 'o');
      await ow.insert(
        other.settings,
        const SettingsCompanion(
          key: Value('export.lastVerifiedBackup'),
          value: Value('"2020-01-01T00:00:00.000"'),
        ),
        id: 'global|export.lastVerifiedBackup',
      );
      await restoreBundle(other, readBundle(other, zip));
      final s = await loadSettings(other);
      expect(s.get(BackupSettings.lastVerified), '2020-01-01T00:00:00.000');
    });
  });

  group('safety copies', () {
    late AppDatabase db;
    late ProviderContainer c;

    setUp(() async {
      db = newTestDb();
      await seed(db);
      c = testContainer(db);
    });

    tearDown(() async {
      c.dispose();
      await db.close();
    });

    test('a copy restores the data from before the operation', () async {
      final before = await dumpTables(db);
      await withSafetyCopy(c.read, SafetyReason.reset, () => resetDb(db));
      expect(await db.select(db.accounts).get(), isEmpty);

      final copies = await watchSafetyCopies(db).first;
      expect(copies.single.reason, SafetyReason.reset);
      expect(copies.single.rowCount, greaterThan(0));
      await restoreSafetyCopy(c.read, copies.single.id);
      expect(await dumpTables(db), before);

      // Restoring took a copy of the reset state, so it can be undone too.
      final after = await watchSafetyCopies(db).first;
      expect(after.first.reason, SafetyReason.restoreCopy);
      expect(after, hasLength(2));
    });

    test('the operation does not run when no copy can be taken', () async {
      await db.customStatement('DROP TABLE safety_copies');
      var ran = false;
      await expectLater(
        withSafetyCopy(c.read, SafetyReason.merge, () async => ran = true),
        throwsA(isA<SafetyCopyException>()),
      );
      expect(ran, isFalse);
    });

    test('keeps the newest $maxSafetyCopies', () async {
      for (var i = 0; i < maxSafetyCopies + 3; i++) {
        await takeSafetyCopy(
          db,
          SafetyReason.merge,
          deviceId: 'd',
          now: DateTime(2026, 10, 1, 8, i),
        );
      }
      final copies = await watchSafetyCopies(db).first;
      expect(copies, hasLength(maxSafetyCopies));
      expect(copies.first.createdAt, DateTime(2026, 10, 1, 8, 12));
    });

    test('purging old tombstones takes a copy first', () async {
      final later = DateTime.now().add(const Duration(days: 365));
      expect(await runTombstonePurgeIfDue(c, now: later), greaterThan(0));
      final copies = await watchSafetyCopies(db).first;
      expect(copies.single.reason, SafetyReason.purge);
      // The purged tombstone is still in the copy.
      final bytes = await safetyCopyBytes(db, copies.single.id);
      final t = readBundle(db, bytes).tables['transactions']!;
      final deleted = t.columns.indexOf('deleted_at');
      expect(t.rows.where((r) => r[deleted] != null), isNotEmpty);
    });

    test(
      'safety copies are not part of backups and survive a restore',
      () async {
        await takeSafetyCopy(db, SafetyReason.merge, deviceId: 'd');
        final zip = await exportBundle(db, deviceId: 'd');
        expect(
          readBundle(db, zip).tables.keys,
          isNot(contains('safety_copies')),
        );
        await restoreBundle(db, readBundle(db, zip));
        expect(await watchSafetyCopies(db).first, hasLength(1));
      },
    );
  });

  group('backup health', () {
    final now = DateTime(2026, 10, 24, 12);

    BackupStatus status({
      bool hasData = true,
      DateTime? verified,
      DateTime? scheduled,
      DateTime? attempt,
      String? error,
    }) => backupHealth(
      now: now,
      hasData: hasData,
      staleDays: 7,
      lastVerified: verified,
      lastScheduled: scheduled,
      lastAttempt: attempt,
      lastError: error,
    ).status;

    test('states', () {
      expect(status(hasData: false), BackupStatus.ok);
      expect(status(), BackupStatus.never);
      expect(status(verified: DateTime(2026, 10, 20)), BackupStatus.ok);
      expect(status(verified: DateTime(2026, 10, 2)), BackupStatus.stale);
      expect(
        status(verified: DateTime(2026, 10, 23), error: 'x'),
        BackupStatus.failing,
      );
      // Started an hour ago, never finished.
      expect(
        status(
          verified: DateTime(2026, 10, 23),
          scheduled: DateTime(2026, 10, 23),
          attempt: DateTime(2026, 10, 24, 11),
        ),
        BackupStatus.interrupted,
      );
      // Started a minute ago: may still be running.
      expect(
        status(
          verified: DateTime(2026, 10, 23),
          attempt: DateTime(2026, 10, 24, 11, 59),
        ),
        BackupStatus.ok,
      );
    });
  });
}

/// Same effect as Settings › Reset app on the data.
Future<void> resetDb(AppDatabase db) async {
  for (final name in syncedTableNames) {
    await db.customStatement('DELETE FROM "$name"');
  }
  await db.customStatement('DELETE FROM txn_search');
}
