import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/budgets/data/budget_period_provider.dart';
import 'package:personal_finance/features/budgets/data/budgets_repository.dart';

/// Generates the rows of repeating budgets for the current and the next
/// budget period (registered in app/startup_tasks.dart before the budget
/// alerts). Idempotent; never throws.
Future<void> budgetRulesStartupTask(ProviderContainer c) async {
  try {
    if (!c.read(settingsProvider).moduleEnabled(AppModule.budgets)) return;
    // Salary-based periods need the salary dates loaded first.
    final sub = c.listen(salaryDatesProvider, (_, _) {});
    try {
      await c.read(salaryDatesProvider.future);
      final periods = c.read(budgetPeriodsProvider);
      final next = periods.next(c.read(currentBudgetPeriodProvider));
      await c
          .read(budgetsRepositoryProvider)
          .ensureFromRules(periods, next.start);
    } finally {
      sub.close();
    }
  } on Object catch (e) {
    debugPrint('Repeating budgets: $e');
  }
}
