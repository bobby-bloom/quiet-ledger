import 'package:personal_finance/app/startup.dart';
import 'package:personal_finance/features/export/export_startup.dart';
import 'package:personal_finance/features/plan/plan_startup.dart';

/// All startup tasks, in order. Features append theirs here.
final startupTasks = StartupTasks([
  planPostDueRecurringTask,
  planRemindersTask,
  planAlertsTask,
  autoExportStartupTask,
  tombstonePurgeStartupTask,
]);
