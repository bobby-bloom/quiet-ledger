import 'package:intl/intl.dart';
import 'package:personal_finance/core/settings/app_settings.dart';

// Pure scheduling/retention rules of the automatic backup.

const autoExportPrefix = 'quiet-ledger-backup-';

/// Scheduled backups written before the app was named Quiet Ledger
/// (`personal-finance-backup-…`) still count: they are listed for restore
/// and pruned like new ones.
final _fileName = RegExp(
  r'^(?:quiet-ledger|personal-finance)-backup-(\d{8}-\d{6})(?:-(\d+))?'
  r'\.(?:zip|pfbackup)$',
);

/// How long to wait after [failures] scheduled backups failed in a row
/// before trying again: 1 h, 4 h, 12 h, then once a day. The health banner
/// shows the failure all the time; this only spaces out the work.
Duration backupRetryDelay(int failures) => switch (failures) {
  <= 1 => const Duration(hours: 1),
  2 => const Duration(hours: 4),
  3 => const Duration(hours: 12),
  _ => const Duration(days: 1),
};

/// Whether a failed scheduled backup should be tried again at [now], given
/// the start of the last attempt.
bool isBackupRetryDue(int failures, DateTime? lastAttempt, DateTime now) =>
    lastAttempt == null ||
    lastAttempt.isAfter(now) ||
    !now.isBefore(lastAttempt.add(backupRetryDelay(failures)));

/// Whether an automatic backup is due at [now]. Daily: once per calendar
/// day. Weekly: when the last one is at least 7 calendar days old. A
/// [last] in the future (clock change) counts as due.
bool isAutoExportDue(
  AutoExportSchedule schedule,
  DateTime? last,
  DateTime now,
) {
  if (schedule == AutoExportSchedule.off) return false;
  if (last == null || last.isAfter(now)) return true;
  final lastDay = DateTime(last.year, last.month, last.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = (today.difference(lastDay).inHours / 24).round();
  return switch (schedule) {
    AutoExportSchedule.daily => days >= 1,
    AutoExportSchedule.weekly => days >= 7,
    AutoExportSchedule.off => false,
  };
}

/// `quiet-ledger-backup-20261023-081500.zip` (local time),
/// `.pfbackup` when [extension] says so.
String autoExportFileName(DateTime now, [String extension = '.zip']) =>
    '$autoExportPrefix${DateFormat('yyyyMMdd-HHmmss').format(now)}$extension';

/// Whether [name] was written by the automatic backup.
bool isAutoExportFile(String name) => _fileName.hasMatch(name);

/// The automatic backups among [names], newest first: by the time in the
/// name, so old and new prefixes interleave correctly.
List<String> sortedAutoExportFiles(Iterable<String> names) {
  (String, int) key(String name) {
    final m = _fileName.firstMatch(name)!;
    return (m[1]!, int.tryParse(m[2] ?? '') ?? 0);
  }

  return names.where(isAutoExportFile).toList()..sort((a, b) {
    final (ta, na) = key(a);
    final (tb, nb) = key(b);
    final byTime = tb.compareTo(ta);
    if (byTime != 0) return byTime;
    final bySuffix = nb.compareTo(na);
    return bySuffix != 0 ? bySuffix : b.compareTo(a);
  });
}

/// Automatic backup files to delete so that only the newest [keep] remain.
/// Other files in the folder are never touched, and neither is [protect]
/// (the backup just written: after a clock change it may sort as oldest).
List<String> autoExportFilesToPrune(
  Iterable<String> names,
  int keep, {
  String? protect,
}) {
  final ours = sortedAutoExportFiles(names.where((n) => n != protect));
  final rest = protect == null ? keep : keep - 1;
  return ours.length <= rest ? const [] : ours.sublist(rest.clamp(0, keep));
}
