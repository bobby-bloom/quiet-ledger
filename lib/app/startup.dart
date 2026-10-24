import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A task run once after the app has started (and again on resume where
/// noted), e.g. posting due recurring transactions, auto-export or purging
/// old tombstones. Tasks must be idempotent and never throw.
typedef StartupTask = Future<void> Function(ProviderContainer container);

/// Registry of startup tasks. Features add theirs in `app/startup_tasks.dart`.
class StartupTasks {
  StartupTasks(this.tasks);
  final List<StartupTask> tasks;

  Future<void> runAll(ProviderContainer container) async {
    for (final t in tasks) {
      try {
        await t(container);
      } on Object catch (_) {
        // Startup tasks are best effort.
      }
    }
  }
}
