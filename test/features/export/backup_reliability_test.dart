import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/platform/notifications.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/backup_settings.dart';
import 'package:personal_finance/core/settings/setting_def.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/export/data/auto_export.dart';
import 'package:personal_finance/features/export/data/bundle_service.dart';
import 'package:personal_finance/features/export/data/export_folder.dart';
import 'package:personal_finance/features/export/data/safety_copies.dart';
import 'package:personal_finance/features/export/domain/auto_export_plan.dart';
import 'package:personal_finance/features/export/domain/backup_health.dart';
import 'package:personal_finance/features/export/presentation/restore_flow.dart';

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
  bool failLists = false;
  int writes = 0;

  @override
  Future<List<String>> listFiles() async {
    if (failLists) throw StateError('folder offline');
    return await super.listFiles();
  }

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
      // Nothing old was pruned, the unverified file was removed again,
      // nothing recorded as done.
      expect(folder.files.keys, [
        'personal-finance-backup-20260101-000000.zip',
        'personal-finance-backup-20260102-000000.zip',
      ]);
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

      // Two failures in a row: the next try waits 4 hours.
      folder.failWrites = false;
      expect(
        await runAutoExportIfDue(c, now: day.add(const Duration(hours: 3))),
        isFalse,
      );
      expect(folder.writes, 2);
      expect(
        await runAutoExportIfDue(c, now: day.add(const Duration(hours: 5))),
        isTrue,
      );
      expect(get(BackupSettings.lastError), isNull);
      expect(c.read(settingsProvider).get(BackupSettings.failureCount), 0);
    });

    test('retries back off: 1 h, 4 h, 12 h, then daily', () {
      expect(
        [for (var n = 1; n <= 6; n++) backupRetryDelay(n).inHours],
        [1, 4, 12, 24, 24, 24],
      );
      final at = DateTime(2026, 10, 1, 8);
      expect(
        isBackupRetryDue(2, at, at.add(const Duration(hours: 3))),
        isFalse,
      );
      expect(isBackupRetryDue(2, at, at.add(const Duration(hours: 4))), isTrue);
      // Unknown or future attempt (clock change): try now.
      expect(isBackupRetryDue(5, null, at), isTrue);
      expect(isBackupRetryDue(5, at.add(const Duration(days: 1)), at), isTrue);
    });

    test('"Back up now" ignores the backoff and resets it', () async {
      folder.failWrites = true;
      final day = DateTime(2026, 10, 1, 8);
      for (var i = 0; i < 3; i++) {
        await runAutoExportNow(c.read, now: day.add(Duration(minutes: i)));
      }
      expect(c.read(settingsProvider).get(BackupSettings.failureCount), 3);
      folder.failWrites = false;
      final r = await runAutoExportNow(
        c.read,
        now: day.add(const Duration(minutes: 5)),
      );
      expect(r.written, isTrue);
      expect(c.read(settingsProvider).get(BackupSettings.failureCount), 0);
    });

    test('an unreachable folder fails before any export', () async {
      folder.failLists = true;
      final r = await runAutoExportNow(c.read, now: DateTime(2026, 10, 1, 8));
      expect(r.written, isFalse);
      expect(folder.writes, 0);
      expect(get(BackupSettings.lastError), contains('offline'));
      // Still counted as an attempt, so the retry backoff applies.
      expect(get(BackupSettings.lastAttempt), isNotNull);
    });

    test('a backup written after a clock change is never pruned', () async {
      // Names from before the rename: pruned alongside the new one.
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

    test('manual backups are never pruned by the schedule', () {
      final manual = backupFileName(DateTime(2026, 10, 1, 8));
      expect(isAutoExportFile(manual), isFalse);
      expect(
        autoExportFilesToPrune([
          manual,
          autoExportFileName(DateTime(2026, 10, 2)),
        ], 1),
        isEmpty,
      );
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
      // The schedule and retention of the other device are not imported
      // (a smaller "keep" would prune this device's backups at once).
      expect(s.get(ImportExportSettings.autoExportKeep), 10);
      expect(s.get(ImportExportSettings.autoExport), AutoExportSchedule.off);
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

    Future<void> changeData(int i) =>
        db.customStatement("UPDATE accounts SET name = 'Account $i'");

    test('keeps the newest $maxSafetyCopies', () async {
      for (var i = 0; i < maxSafetyCopies + 3; i++) {
        await changeData(i);
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

    test('unchanged data reuses the newest copy', () async {
      final first = await takeSafetyCopy(
        db,
        SafetyReason.merge,
        deviceId: 'd',
        now: DateTime(2026, 10, 1, 8),
      );
      for (var i = 1; i < 15; i++) {
        final id = await takeSafetyCopy(
          db,
          SafetyReason.purge,
          deviceId: 'd',
          now: DateTime(2026, 10, 1, 8, i),
        );
        expect(id, first);
      }
      expect(await watchSafetyCopies(db).first, hasLength(1));

      // A change gets its own copy again.
      await changeData(1);
      final next = await takeSafetyCopy(db, SafetyReason.merge, deviceId: 'd');
      expect(next, isNot(first));
      expect(await watchSafetyCopies(db).first, hasLength(2));
    });

    test('the copy before a restore or reset survives later copies', () async {
      await takeSafetyCopy(
        db,
        SafetyReason.restore,
        deviceId: 'd',
        now: DateTime(2026, 10, 1, 7),
      );
      await changeData(0);
      await takeSafetyCopy(
        db,
        SafetyReason.reset,
        deviceId: 'd',
        now: DateTime(2026, 10, 1, 7, 30),
      );
      for (var i = 1; i <= maxSafetyCopies + 2; i++) {
        await changeData(i);
        await takeSafetyCopy(
          db,
          SafetyReason.merge,
          deviceId: 'd',
          now: DateTime(2026, 10, 1, 8, i),
        );
      }
      final copies = await watchSafetyCopies(db).first;
      expect(copies, hasLength(maxSafetyCopies + 2));
      expect(
        copies.map((c) => c.reason),
        containsAll([SafetyReason.restore, SafetyReason.reset]),
      );
      expect(
        copies.where((c) => c.reason == SafetyReason.merge),
        hasLength(maxSafetyCopies),
      );

      // Only the newest restore copy is kept on top.
      await changeData(99);
      await takeSafetyCopy(db, SafetyReason.restore, deviceId: 'd');
      final after = await watchSafetyCopies(db).first;
      expect(
        after.where((c) => c.reason == SafetyReason.restore),
        hasLength(1),
      );
      expect(after, hasLength(maxSafetyCopies + 1));
    });

    test('a damaged newest copy does not block new copies', () async {
      final first = await takeSafetyCopy(db, SafetyReason.merge, deviceId: 'd');
      await db.customStatement("UPDATE safety_copies SET data = x'00'");
      final next = await takeSafetyCopy(db, SafetyReason.merge, deviceId: 'd');
      expect(next, isNot(first));
    });

    test(
      'a restore always gets its own copy, even of unchanged data',
      () async {
        final a = await takeSafetyCopy(db, SafetyReason.merge, deviceId: 'd');
        final b = await takeSafetyCopy(db, SafetyReason.restore, deviceId: 'd');
        expect(b, isNot(a));
      },
    );

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

    test('a dismissed reminder stays hidden for a week, until a backup', () {
      bool snoozed(BackupHealth h, DateTime? dismissed) =>
          reminderSnoozed(h, now: now, dismissedAt: dismissed);
      const never = BackupHealth(BackupStatus.never);
      expect(snoozed(never, null), isFalse);
      expect(snoozed(never, DateTime(2026, 10, 20)), isTrue);
      expect(snoozed(never, DateTime(2026, 10, 17, 12)), isFalse);
      // Dismissed before the last backup: this reminder is a new one.
      final stale = BackupHealth(
        BackupStatus.stale,
        lastVerified: DateTime(2026, 10, 22),
      );
      expect(snoozed(stale, DateTime(2026, 10, 21)), isFalse);
      expect(snoozed(stale, DateTime(2026, 10, 23)), isTrue);
      // Failures always show.
      const failing = BackupHealth(BackupStatus.failing, error: 'x');
      expect(snoozed(failing, DateTime(2026, 10, 24)), isFalse);
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
