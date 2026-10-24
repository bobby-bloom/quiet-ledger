import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/platform/notifications.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/backup_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/export/data/auto_export.dart';
import 'package:personal_finance/features/export/data/export_folder.dart';
import 'package:personal_finance/features/export/data/export_folder_native.dart';

import '../../helpers/test_app.dart';
import 'auto_export_test.dart' show caps;
import 'export_fixtures.dart';

/// Plays the native side of `personal_finance/backup_folder` (what
/// BackupFolderChannel.kt / .swift do) over an in-memory folder.
class _FakeNative {
  final files = <String, Uint8List>{};
  bool access = true;
  final calls = <String>[];

  /// Set when the saved access is outdated: the renewed ref (iOS/macOS).
  String? renewTo;

  Future<Object?> handle(MethodCall call) async {
    calls.add(call.method);
    final args = (call.arguments as Map?)?.cast<String, Object?>() ?? {};
    if (call.method == 'pick') {
      return {'folder': 'content://tree/backups', 'name': 'Backups'};
    }
    if (call.method == 'check') return access;
    if (!access) {
      throw PlatformException(code: 'access', message: 'revoked');
    }
    final name = args['name'] as String?;
    switch (call.method) {
      case 'refresh':
        final to = renewTo;
        return to == null ? null : {'folder': to, 'name': 'Moved backups'};
      case 'write':
        files[name!] = args['bytes']! as Uint8List;
        return null;
      case 'read':
        return files[name];
      case 'list':
        return files.keys.toList();
      case 'delete':
        files.remove(name);
        return null;
    }
    throw MissingPluginException();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeNative native;

  setUp(() {
    native = _FakeNative();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(backupFolderChannel, native.handle);
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(backupFolderChannel, null),
  );

  test('platform folder refs open the channel folder', () async {
    expect(isNativeFolderRef('content://tree/x'), isTrue);
    expect(isNativeFolderRef('bookmark:AAAA'), isTrue);
    expect(isNativeFolderRef('/home/me/Backups'), isFalse);
    final folder = openExportFolder('content://tree/backups');
    expect(folder, isA<NativeExportFolder>());

    await folder.writeFile('a.zip', Uint8List.fromList([1, 2]));
    expect(await folder.readFile('a.zip'), [1, 2]);
    expect(await folder.readFile('missing.zip'), isNull);
    expect(await folder.listFiles(), ['a.zip']);
    await folder.deleteFile('a.zip');
    expect(await folder.listFiles(), isEmpty);

    final picked = await pickNativeFolder();
    expect(picked!.ref, 'content://tree/backups');
    expect(picked.name, 'Backups');
  });

  test('a revoked permission becomes BackupFolderAccessException', () async {
    native.access = false;
    await expectLater(
      const NativeExportFolder('content://tree/backups')
          .writeFile('a.zip', Uint8List(1)),
      throwsA(isA<BackupFolderAccessException>()),
    );
    expect(await nativeFolderAccessible('content://tree/backups'), isFalse);
  });

  group('scheduled backup to a platform folder', () {
    late AppDatabase db;
    late ProviderContainer c;

    setUp(() async {
      db = newTestDb();
      await seed(db);
      c = testContainer(
        db,
        overrides: [
          platformCapabilitiesProvider.overrideWithValue(caps(folders: true)),
          notificationServiceProvider.overrideWithValue(
            const NoopNotificationService(),
          ),
        ],
      );
      final s = c.read(settingsProvider.notifier);
      await s.set(ImportExportSettings.autoExport, AutoExportSchedule.daily);
      await s.set(
        ImportExportSettings.autoExportFolder,
        'content://tree/backups',
      );
    });

    tearDown(() async {
      c.dispose();
      await db.close();
    });

    test('writes and verifies through the channel', () async {
      final r = await runAutoExportNow(c.read, now: DateTime(2026, 10, 1, 8));
      expect(r.written, isTrue);
      expect(native.files, hasLength(1));
      // Written, then read back for verification.
      expect(native.calls, containsAllInOrder(['write', 'read']));
    });

    test('outdated access is renewed and saved before writing', () async {
      native.renewTo = 'bookmark:renewed';
      final r = await runAutoExportNow(c.read, now: DateTime(2026, 10, 1, 8));
      expect(r.written, isTrue);
      final s = c.read(settingsProvider);
      expect(s.get(ImportExportSettings.autoExportFolder), 'bookmark:renewed');
      expect(s.get(BackupSettings.folderName), 'Moved backups');
      expect(native.calls.take(3), ['refresh', 'list', 'write']);
    });

    test('the startup check renews outdated access too', () async {
      native.renewTo = 'bookmark:renewed';
      await checkBackupFolderAccess(c.read);
      expect(
        c.read(settingsProvider).get(ImportExportSettings.autoExportFolder),
        'bookmark:renewed',
      );
      expect(c.read(settingsProvider).get(BackupSettings.lastError), isNull);
    });

    test('a platform without refresh keeps the saved folder', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(backupFolderChannel, (call) {
            if (call.method == 'refresh') throw MissingPluginException();
            return native.handle(call);
          });
      final r = await runAutoExportNow(c.read, now: DateTime(2026, 10, 1, 8));
      expect(r.written, isTrue);
      expect(
        c.read(settingsProvider).get(ImportExportSettings.autoExportFolder),
        'content://tree/backups',
      );
    });

    test('a lost permission is reported at startup in plain words', () async {
      native.access = false;
      await checkBackupFolderAccess(c.read);
      // The fixture's language is German.
      expect(
        c.read(settingsProvider).get(BackupSettings.lastError),
        startsWith('Die App hat keinen Zugriff mehr'),
      );
    });
  });
}
