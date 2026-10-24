import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/platform/notifications.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/export/data/auto_export.dart';
import 'package:personal_finance/features/export/data/backup_keys.dart';
import 'package:personal_finance/features/export/data/backup_service.dart';
import 'package:personal_finance/features/export/data/bundle_service.dart';
import 'package:personal_finance/features/export/data/export_folder.dart';
import 'package:personal_finance/features/export/domain/backup_crypto.dart';
import 'package:personal_finance/features/export/domain/backup_health.dart';
import 'package:personal_finance/features/export/domain/backup_settings.dart';
import 'package:personal_finance/features/export/presentation/backup_health_banner.dart';
import 'package:personal_finance/features/export/presentation/backup_password_screen.dart';
import 'package:personal_finance/features/export/presentation/restore_flow.dart';

import '../../helpers/test_app.dart';
import 'auto_export_test.dart' show caps;
import 'export_fixtures.dart';

void main() {
  final recovery = newRecoveryKey(Random(7));
  late BackupKeys keys;

  setUpAll(() async {
    keys = await createBackupKeys('correct horse', recovery, iterations: 1000);
  });

  group('backups with a password', () {
    late AppDatabase db;
    late MemoryExportFolder folder;

    setUp(() async {
      db = newTestDb();
      await seed(db);
      folder = MemoryExportFolder();
    });
    tearDown(() => db.close());

    ProviderContainer container({bool required = false}) {
      final c = testContainer(
        db,
        overrides: [
          backupEncryptionRequiredProvider.overrideWithValue(required),
          platformCapabilitiesProvider.overrideWithValue(caps(folders: true)),
          exportFolderFactoryProvider.overrideWithValue((path) => folder),
          notificationServiceProvider.overrideWithValue(
            const NoopNotificationService(),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('no password, not required: a plain bundle', () async {
      final b = await createVerifiedBackup(container().read);
      expect(b.encrypted, isFalse);
      expect(b.extension, '.zip');
    });

    test('no password but required: refused, never written plain', () async {
      final c = container(required: true);
      await expectLater(
        createVerifiedBackup(c.read),
        throwsA(isA<BackupPasswordMissingException>()),
      );

      final s = c.read(settingsProvider.notifier);
      await s.set(ImportExportSettings.autoExport, AutoExportSchedule.daily);
      await s.set(ImportExportSettings.autoExportFolder, '/b');
      final r = await runAutoExportNow(c.read);
      expect(r.written, isFalse);
      expect(folder.files, isEmpty);
      expect(
        c.read(settingsProvider).get(BackupSettings.lastError),
        contains('Sicherungspasswort'), // fixture language: German
      );
      c.listen(hasLedgerDataProvider, (_, _) {});
      await c.read(hasLedgerDataProvider.future);
      await c.read(backupKeyringProvider.future);
      expect(c.read(backupHealthProvider).status, BackupStatus.needsPassword);
    });

    test(
      'with a password: encrypted, verified, restorable elsewhere',
      () async {
        final c = container(required: true);
        await c.read(backupKeyRepositoryProvider).save(keys);
        final s = c.read(settingsProvider.notifier);
        await s.set(ImportExportSettings.autoExport, AutoExportSchedule.daily);
        await s.set(ImportExportSettings.autoExportFolder, '/b');

        final r = await runAutoExportNow(c.read, now: DateTime(2026, 10, 1, 8));
        expect(r.written, isTrue);
        expect(r.fileName, endsWith('.pfbackup'));
        final file = folder.files.values.single;
        expect(isEncryptedBackup(file), isTrue);

        // This device opens it with its stored keys.
        final here = await openBackup(c.read, file);
        expect(here.manifest.rowsOf('transactions'), 6);

        // Another device needs the password or the recovery key.
        final other = newTestDb();
        addTearDown(other.close);
        final oc = testContainer(other);
        addTearDown(oc.dispose);
        await expectLater(
          openBackup(oc.read, file),
          throwsA(
            isA<BackupCryptoException>().having(
              (e) => e.error,
              'error',
              BackupCryptoError.wrongKey,
            ),
          ),
        );
        final viaPassword = await openBackup(
          oc.read,
          file,
          password: 'correct horse',
        );
        final viaRecovery = await openBackup(
          oc.read,
          file,
          recoveryKey: recovery,
        );
        expect(viaRecovery.manifest.totalRows, viaPassword.manifest.totalRows);
        await restoreBundle(other, viaPassword);
        // Everything but this device's own settings (kept by a restore).
        final restored = await dumpTables(other)
          ..remove('settings');
        final original = await dumpTables(db)
          ..remove('settings');
        expect(restored, original);
      },
    );

    test('backups made before a password change still open here', () async {
      final c = container();
      final repo = c.read(backupKeyRepositoryProvider);
      await repo.save(keys);
      final old = await createVerifiedBackup(c.read);
      await repo.save(
        await withNewPassword(keys, 'new pass', iterations: 1000),
      );
      final ring = await repo.load();
      expect(ring!.previous.single.keyId, keys.keyId);
      expect(
        (await openBackup(c.read, old.bytes)).manifest.totalRows,
        old.manifest.totalRows,
      );
    });
  });

  group('password UI', () {
    late AppDatabase db;
    setUp(() {
      db = newTestDb();
      backupCompute = <M, R>(cb, m) async => await cb(m);
      backupPbkdf2Iterations = 1000;
    });
    tearDown(() {
      backupCompute = compute;
      backupPbkdf2Iterations = defaultPbkdf2Iterations;
      return db.close();
    });

    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(testApp(child, db: db));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('setup: password, recovery key, confirmation', (tester) async {
      await pump(tester, const BackupPasswordScreen());
      await tester.tap(find.text('Set backup password'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('backup-password')),
        'short',
      );
      await tester.enterText(
        find.byKey(const ValueKey('backup-password-repeat')),
        'short',
      );
      await tester.pump();
      FilledButton next() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Next'),
      );
      expect(next().onPressed, isNull); // too short

      await tester.enterText(
        find.byKey(const ValueKey('backup-password')),
        'correct horse',
      );
      await tester.enterText(
        find.byKey(const ValueKey('backup-password-repeat')),
        'correct horse',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();

      // Recovery key step: must confirm it was stored.
      final text = tester
          .widget<SelectableText>(find.byKey(const ValueKey('recovery-key')))
          .data!;
      final groups = text.split(RegExp(r'\s+'));
      expect(groups, hasLength(8));
      expect(next().onPressed, isNull);
      await tester.tap(
        find.text('I have stored the recovery key in a safe place'),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();

      // Type the two requested groups.
      final fields = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('recovery-group-'),
      );
      for (final e in fields.evaluate()) {
        final key = (e.widget.key! as ValueKey<String>).value;
        final i = int.parse(key.substring('recovery-group-'.length));
        await tester.enterText(
          find.byKey(ValueKey(key)),
          groups[i].toLowerCase(),
        );
      }
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
      await settle(tester, find.text('Backups are encrypted'));
      expect(find.text('Backups are encrypted'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(BackupPasswordScreen)),
      );
      final ring = await tester.runAsync(
        () => container.read(backupKeyRepositoryProvider).load(),
      );
      // The typed recovery key derives the stored recovery key.
      final kek = await tester.runAsync(
        () => deriveRecoveryKek(
          parseRecoveryKey(groups.join())!,
          ring!.current.recoverySalt,
        ),
      );
      expect(sameKey(kek!, ring!.current.recoveryKek), isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('restore asks for the password of a foreign backup', (
      tester,
    ) async {
      final file = await tester.runAsync(() async {
        final other = newTestDb();
        await seed(other);
        final zip = await exportBundle(other, deviceId: 'x');
        await other.close();
        return await encryptBackup(zip, keys, appVersion: 'test');
      });
      BundleContents? opened;
      await pump(
        tester,
        Consumer(
          builder: (context, ref, _) => Scaffold(
            body: FilledButton(
              onPressed: () async =>
                  opened = await openPickedBackup(context, ref, file!),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester, find.text('Encrypted backup'));
      expect(find.text('Encrypted backup'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('backup-unlock')),
        'nope',
      );
      await tester.pump();
      await tester.tap(find.text('Open'));
      await settle(tester, find.textContaining('does not open this backup'));
      expect(find.textContaining('does not open this backup'), findsOneWidget);

      // Switch to the recovery key.
      await tester.tap(find.text('Recovery key').first);
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('backup-unlock')),
        formatRecoveryKey(recovery),
      );
      await tester.pump();
      await tester.tap(find.text('Open'));
      await settle(tester, find.text('Encrypted backup').hitTestable());
      for (var i = 0; i < 50 && opened == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(opened?.manifest.rowsOf('transactions'), 6);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}

/// Lets background isolates (`compute`) finish: real time passes in
/// [WidgetTester.runAsync], frames are pumped in between, until [until]
/// finds something (or about 20 s pass).
Future<void> settle(WidgetTester tester, Finder until) async {
  for (var i = 0; i < 200; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    if (until.evaluate().isNotEmpty) break;
  }
  await tester.pumpAndSettle();
}
