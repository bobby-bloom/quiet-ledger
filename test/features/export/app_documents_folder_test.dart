import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/backup_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/export/data/export_folder.dart';
import 'package:personal_finance/features/export/presentation/folder_backups.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('appdocs'));
  tearDown(() => root.deleteSync(recursive: true));

  test('the app Documents folder is stored as a marker, not a path', () {
    expect(
      openExportFolder(appDocumentsFolderRef),
      isA<AppDocumentsExportFolder>(),
    );
  });

  test('follows the app container when iOS moves it on an update', () async {
    // Before the update the container is `old`, afterwards `new`; iOS
    // moves the files along.
    var container = p.join(root.path, 'old');
    final folder = AppDocumentsExportFolder(
      resolve: () async => p.join(container, 'Documents', 'Backups'),
    );
    await folder.writeFile('a.zip', Uint8List.fromList([1, 2, 3]));

    final moved = p.join(root.path, 'new');
    Directory(container).renameSync(moved);
    container = moved;

    expect(await folder.listFiles(), ['a.zip']);
    expect(await folder.readFile('a.zip'), [1, 2, 3]);
    await folder.writeFile('b.zip', Uint8List.fromList([4]));
    expect(
      File(p.join(moved, 'Documents', 'Backups', 'b.zip')).existsSync(),
      isTrue,
    );
  });

  test('without an app Documents folder it fails instead of guessing', () {
    final folder = AppDocumentsExportFolder(resolve: () async => null);
    expect(folder.listFiles(), throwsUnsupportedError);
  });

  test('backupFolderLabel', () {
    final l = lookupAppLocalizations(const Locale('en'));
    SettingsSnapshot with_(Map<String, Object?> values) => SettingsSnapshot({
      for (final e in values.entries)
        SettingsSnapshot.rowId(e.key, 'global'): e.value,
    });
    final folderKey = ImportExportSettings.autoExportFolder.key;

    expect(backupFolderLabel(l, with_({})), isNull);
    expect(
      backupFolderLabel(l, with_({folderKey: appDocumentsFolderRef})),
      l.backupAppDocumentsFolder,
    );
    expect(
      backupFolderLabel(
        l,
        with_({
          folderKey: 'content://tree/x',
          BackupSettings.folderName.key: 'Drive › Backups',
        }),
      ),
      'Drive › Backups',
    );
    expect(backupFolderLabel(l, with_({folderKey: '/home/me'})), '/home/me');
  });
}
