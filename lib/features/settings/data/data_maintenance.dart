import 'package:intl/intl.dart';

/// Tables listed in Settings › Data › Statistics, in display order.
const statisticsTables = [
  'transactions',
  'accounts',
  'categories',
  'tags',
  'budgets',
  'recurring_rules',
  'goals',
  'rules',
  'import_batches',
];

/// Human-readable byte size (KB/MB with one decimal).
String formatBytes(int bytes, String locale) {
  final f = NumberFormat('0.0', locale);
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${f.format(kb)} KB';
  return '${f.format(kb / 1024)} MB';
}
