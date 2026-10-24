import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/router.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/platform/notifications.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/budgets/data/budget_providers.dart';
import 'package:personal_finance/features/budgets/domain/budget_math.dart';
import 'package:personal_finance/features/recurring/data/reminders.dart';

// Startup tasks of the Plan feature (registered in app/startup_tasks.dart).
// Each is idempotent and never throws.

/// Posts due auto-post recurring transactions since `lastPostedDate`.
Future<void> planPostDueRecurringTask(ProviderContainer c) async {
  await postDueRecurring(c.read);
}

StreamSubscription<String>? _tapSub;

/// Initialises notifications, re-schedules bill reminders and routes
/// notification taps.
Future<void> planRemindersTask(ProviderContainer c) async {
  await rescheduleAllReminders(c.read);
  try {
    await _tapSub?.cancel();
    _tapSub = c.read(notificationServiceProvider).taps.listen((payload) {
      try {
        final router = c.read(routerProvider);
        if (payload == 'plan:recurring') {
          router.go('/plan?tab=recurring');
        } else if (payload.startsWith('budget:')) {
          router.go('/plan/budgets/${payload.substring(7)}');
        } else if (payload.startsWith('account:')) {
          router.go('/accounts');
        } else if (payload == 'backup') {
          router.go('/more/export');
        }
      } on Object {
        // Navigation is best effort.
      }
    });
  } on Object {
    // ignore
  }
}

const _alertedKey = 'plan.notifiedAlerts';

/// Budget warnings (≥ threshold / over) and low-balance alerts, each shown
/// once (per period and category, or per account and day).
Future<void> planAlertsTask(ProviderContainer c) async {
  try {
    final prefs = c.read(sharedPreferencesProvider);
    if (prefs == null) return;
    final service = c.read(notificationServiceProvider);
    final l = planL10n(c.read);
    if (!await service.init(channelNames: notificationChannelNames(l))) return;
    final settings = c.read(settingsProvider);
    final fmt = c.read(moneyFormatterProvider);
    final today = DateTime.now();
    final dayKey = '${today.year}-${today.month}-${today.day}';

    final done = <String>{};
    try {
      final raw = prefs.getString(_alertedKey);
      if (raw != null) done.addAll((jsonDecode(raw) as List).cast<String>());
    } on Object {
      // corrupt: start over
    }
    final next = <String>{};

    if (settings.moduleEnabled(AppModule.budgets)) {
      final sub = c.listen(budgetSummaryProvider, (_, _) {});
      try {
        final summary = await c.read(budgetSummaryProvider.future);
        final start = summary.period.start;
        final periodKey = '${start.year}-${start.month}-${start.day}';
        for (final line in summary.lines) {
          if (line.state == BudgetState.onTrack) continue;
          final key = 'b|$periodKey|${line.categoryId}|${line.state.name}';
          next.add(key);
          if (done.contains(key)) continue;
          await service.showBudgetAlert(
            key: '$periodKey|${line.categoryId}',
            title: line.state == BudgetState.over
                ? l.budgetsAlertOverTitle(line.name)
                : l.budgetsAlertWarningTitle(line.name),
            body: line.state == BudgetState.over
                ? l.budgetsAlertOverBody(fmt.minor(line.overMinor))
                : l.budgetsAlertWarningBody(
                    line.percentUsed,
                    fmt.minor(line.remainingMinor),
                  ),
            payload: 'budget:${line.categoryId}',
          );
        }
      } finally {
        sub.close();
      }
    }

    final accountsSub = c.listen(accountsProvider, (_, _) {});
    final balancesSub = c.listen(accountBalancesProvider, (_, _) {});
    try {
      final accounts = await c.read(accountsProvider.future);
      final balances = await c.read(accountBalancesProvider.future);
      for (final a in accounts) {
        if (a.archived || a.type.isLiability) continue;
        final threshold =
            a.lowBalanceThresholdMinor ??
            settings.get(
              ForecastSettings.lowBalanceThreshold,
              scope: 'account:${a.id}',
            );
        if (threshold == null) continue;
        final balance = balances[a.id] ?? a.openingBalanceMinor;
        if (balance >= threshold) continue;
        final key = 'l|$dayKey|${a.id}';
        next.add(key);
        if (done.contains(key)) continue;
        await service.showLowBalance(
          accountId: a.id,
          title: l.budgetsAlertLowBalanceTitle(a.name),
          body: l.budgetsAlertLowBalanceBody(
            fmt.minor(balance),
            fmt.minor(threshold),
          ),
        );
      }
    } finally {
      accountsSub.close();
      balancesSub.close();
    }
    await prefs.setString(_alertedKey, jsonEncode(next.toList()));
  } on Object {
    // Alerts are best effort.
  }
}
