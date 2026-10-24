import 'package:personal_finance/core/settings/setting_def.dart';

// Hidden settings of the backup (not in the settings catalogue; shown and
// edited on the export screens). The timestamps, the error and the folder
// name describe this device: never synced and kept by a restore
// (`SettingDef.deviceLocal`).

abstract final class BackupSettings {
  /// ISO timestamp of the last start of a scheduled backup. Newer than
  /// `lastAutoExport` without an error means it never finished (e.g. the
  /// app was killed).
  static final lastAttempt = SettingDef.optionalString(
    key: 'export.lastAutoExportAttempt',
    section: SettingSection.importExport,
    label: (l) => l.exportAutoTitle,
    hidden: true,
    deviceLocal: true,
  );

  /// Message of the last failed scheduled backup; null after a success.
  static final lastError = SettingDef.optionalString(
    key: 'export.lastAutoExportError',
    section: SettingSection.importExport,
    label: (l) => l.exportAutoTitle,
    hidden: true,
    deviceLocal: true,
  );

  /// Scheduled backups that failed in a row; 0 after a success. Spaces out
  /// the retries (`backupRetryDelay`).
  static final failureCount = SettingDef.integer(
    key: 'export.backupFailureCount',
    section: SettingSection.importExport,
    defaultValue: 0,
    min: 0,
    max: 100000,
    label: (l) => l.exportAutoTitle,
    hidden: true,
    deviceLocal: true,
  );

  /// ISO timestamp of the last backup that was verified and stored outside
  /// the app (scheduled, or saved/shared/downloaded by hand).
  static final lastVerified = SettingDef.optionalString(
    key: 'export.lastVerifiedBackup',
    section: SettingSection.importExport,
    label: (l) => l.exportAutoTitle,
    hidden: true,
    deviceLocal: true,
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
    deviceLocal: true,
  );

  /// ISO timestamp of the last time the backup password was typed
  /// correctly (set, checked or changed).
  static final passwordCheckedAt = SettingDef.optionalString(
    key: 'export.backupPasswordCheckedAt',
    section: SettingSection.importExport,
    label: (l) => l.exportAutoTitle,
    hidden: true,
    deviceLocal: true,
  );

  static final all = <SettingDef<Object?>>[
    lastAttempt,
    lastError,
    failureCount,
    lastVerified,
    staleDays,
    folderName,
    passwordCheckedAt,
  ];
}
