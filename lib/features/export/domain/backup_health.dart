import 'package:meta/meta.dart';

// Whether the user's data is safely backed up (docs/BACKUP.md, "no silent
// failure"). Pure; the inputs come from settings.

enum BackupStatus {
  /// A verified backup newer than the threshold exists.
  ok,

  /// Backups must be encrypted but no backup password is set; they are
  /// paused until one is.
  needsPassword,

  /// Everything is fine, but the backup password has not been typed for a
  /// while: ask for it so a forgotten password shows up early.
  checkPassword,

  /// There is data but never was a backup.
  never,

  /// The last verified backup is older than the threshold.
  stale,

  /// The last scheduled backup failed.
  failing,

  /// The last scheduled backup started but never finished.
  interrupted,
}

@immutable
class BackupHealth {
  const BackupHealth(this.status, {this.lastVerified, this.error});

  final BackupStatus status;
  final DateTime? lastVerified;
  final String? error;

  bool get ok => status == BackupStatus.ok;
}

/// A run that started longer ago than this without finishing counts as
/// interrupted (shorter: it may still be running).
const interruptedAfter = Duration(minutes: 10);

/// Ask for the backup password again after this long.
const passwordCheckEvery = Duration(days: 30);

BackupHealth backupHealth({
  required DateTime now,
  required bool hasData,
  required int staleDays,
  DateTime? lastVerified,
  DateTime? lastScheduled,
  DateTime? lastAttempt,
  String? lastError,
  bool needsPassword = false,
  DateTime? passwordCheckedAt,
}) {
  if (needsPassword && hasData) {
    return BackupHealth(BackupStatus.needsPassword, lastVerified: lastVerified);
  }
  if (lastError != null && lastError.isNotEmpty) {
    return BackupHealth(
      BackupStatus.failing,
      lastVerified: lastVerified,
      error: lastError,
    );
  }
  if (lastAttempt != null &&
      (lastScheduled == null || lastAttempt.isAfter(lastScheduled)) &&
      now.difference(lastAttempt) > interruptedAfter) {
    return BackupHealth(BackupStatus.interrupted, lastVerified: lastVerified);
  }
  if (lastVerified == null) {
    return BackupHealth(hasData ? BackupStatus.never : BackupStatus.ok);
  }
  if (now.difference(lastVerified) > Duration(days: staleDays)) {
    return BackupHealth(BackupStatus.stale, lastVerified: lastVerified);
  }
  if (passwordCheckedAt != null &&
      now.difference(passwordCheckedAt) > passwordCheckEvery) {
    return BackupHealth(BackupStatus.checkPassword, lastVerified: lastVerified);
  }
  return BackupHealth(BackupStatus.ok, lastVerified: lastVerified);
}
