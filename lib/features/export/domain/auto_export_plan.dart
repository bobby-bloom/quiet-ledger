import 'package:intl/intl.dart';
import 'package:personal_finance/core/settings/app_settings.dart';

// Pure scheduling/retention rules of the automatic backup.

const autoExportPrefix = 'personal-finance-backup-';

final _fileName = RegExp(
  r'^personal-finance-backup-(\d{8}-\d{6})(?:-\d+)?\.zip$',
);

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

/// `personal-finance-backup-20261023-081500.zip` (local time; sorts
/// chronologically).
String autoExportFileName(DateTime now) =>
    '$autoExportPrefix${DateFormat('yyyyMMdd-HHmmss').format(now)}.zip';

/// Whether [name] was written by the automatic backup.
bool isAutoExportFile(String name) => _fileName.hasMatch(name);

/// Automatic backup files to delete so that only the newest [keep] remain.
/// Other files in the folder are never touched, and neither is [protect]
/// (the backup just written: after a clock change it may sort as oldest).
List<String> autoExportFilesToPrune(
  Iterable<String> names,
  int keep, {
  String? protect,
}) {
  final ours = names.where((n) => isAutoExportFile(n) && n != protect).toList()
    ..sort((a, b) => b.compareTo(a));
  final rest = protect == null ? keep : keep - 1;
  return ours.length <= rest ? const [] : ours.sublist(rest.clamp(0, keep));
}
