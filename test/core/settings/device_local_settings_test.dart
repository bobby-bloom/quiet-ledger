import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/backup_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';

import '../../helpers/test_app.dart';

void main() {
  test('the backup folder and status are device-local', () {
    expect(
      deviceLocalSettingKeys,
      containsAll([
        ImportExportSettings.autoExport.key,
        ImportExportSettings.autoExportKeep.key,
        ImportExportSettings.autoExportFolder.key,
        ImportExportSettings.lastAutoExport.key,
        DataSettings.storageLocation.key,
        DataSettings.lastTombstonePurge.key,
        BackupSettings.lastAttempt.key,
        BackupSettings.lastError.key,
        BackupSettings.lastVerified.key,
        BackupSettings.folderName.key,
        BackupSettings.passwordCheckedAt.key,
      ]),
    );
    // Preferences about the data set still sync.
    expect(
      deviceLocalSettingKeys,
      isNot(contains(BackupSettings.staleDays.key)),
    );
    expect(isDeviceLocalSettingRow('global|export.autoExportFolder'), isTrue);
    expect(isDeviceLocalSettingRow('global|budgets.warnThreshold'), isFalse);
  });

  test('every device-local setting is in allSettings', () {
    // Core code (sync) only sees settings listed there.
    for (final d in BackupSettings.all.where((d) => d.deviceLocal)) {
      expect(allSettings, contains(d));
    }
  });

  test('device-local settings are stored without a change_log entry', () async {
    final db = newTestDb();
    final c = testContainer(db);
    addTearDown(() async {
      c.dispose();
      await db.close();
    });
    final s = c.read(settingsProvider.notifier);
    await s.set(BackupSettings.lastError, 'disk full');
    await s.set(ImportExportSettings.autoExportFolder, '/backups');
    await s.reset(BackupSettings.lastError);
    expect(await db.select(db.changeLog).get(), isEmpty);
    expect(
      (await loadSettings(db)).get(ImportExportSettings.autoExportFolder),
      '/backups',
    );

    await s.set(BackupSettings.staleDays, 14);
    final logged = await db.select(db.changeLog).get();
    expect(logged.single.entityId, 'global|${BackupSettings.staleDays.key}');
  });
}
