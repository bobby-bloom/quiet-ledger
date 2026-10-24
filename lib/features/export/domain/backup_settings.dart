import 'package:personal_finance/core/settings/setting_def.dart';

// Hidden settings of the backup (not in the settings catalogue; shown and
// edited on the export screens). The timestamps and the error describe
// this device and are kept by a restore (`deviceLocalSettingKeys`).

abstract final class BackupSettings {
  /// ISO timestamp of the last start of a scheduled backup. Newer than
  /// `lastAutoExport` without an error means it never finished (e.g. the
  /// app was killed).
  static final lastAttempt = SettingDef.optionalString(
    key: 'export.lastAutoExportAttempt',
    section: SettingSection.importExport,
    label: (l) => l.exportAutoTitle,
    hidden: true,
  );

  /// Message of the last failed scheduled backup; null after a success.
  static final lastError = SettingDef.optionalString(
    key: 'export.lastAutoExportError',
    section: SettingSection.importExport,
    label: (l) => l.exportAutoTitle,
    hidden: true,
  );

  /// ISO timestamp of the last backup that was verified and stored outside
  /// the app (scheduled, or saved/shared/downloaded by hand).
  static final lastVerified = SettingDef.optionalString(
    key: 'export.lastVerifiedBackup',
    section: SettingSection.importExport,
    label: (l) => l.exportAutoTitle,
    hidden: true,
  );

  /// Warn when the last verified backup is older than this many days.
  static final staleDays = SettingDef.integer(
    key: 'export.backupStaleDays',
    section: SettingSection.importExport,
    defaultValue: 7,
    min: 1,
    max: 90,
    label: (l) => l.backupStaleDays,
    hidden: true,
  );

  /// Display name of a platform backup folder (`autoExportFolder` then
  /// holds an opaque reference).
  static final folderName = SettingDef.optionalString(
    key: 'export.autoExportFolderName',
    section: SettingSection.importExport,
    label: (l) => l.exportAutoTitle,
    hidden: true,
  );

  /// Keys that describe this device; a restore keeps the current values.
  static final deviceLocalKeys = {
    folderName.key,
    lastAttempt.key,
    lastError.key,
    lastVerified.key,
  };
}
