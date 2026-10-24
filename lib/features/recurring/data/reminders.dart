import 'dart:ui';

import 'package:flutter_riverpod/misc.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/core/calendar/holidays.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/platform/notifications.dart';
import 'package:personal_finance/features/budgets/data/budget_period_provider.dart';
import 'package:personal_finance/features/plan/plan_providers.dart';
import 'package:personal_finance/features/recurring/data/recurring_repository.dart';
import 'package:personal_finance/features/recurring/domain/recurring_logic.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// Reads a provider (`ref.read` or `container.read`).
typedef PlanReader = T Function<T>(ProviderListenable<T> provider);

/// Localised strings for code that runs without a BuildContext.
AppLocalizations planL10n(PlanReader read) =>
    lookupAppLocalizations(Locale(read(languageCodeProvider)));

/// Channel names in the UI language.
Map<NotificationKind, String> notificationChannelNames(AppLocalizations l) => {
  NotificationKind.bill: l.recurringChannelBills,
  NotificationKind.income: l.recurringChannelIncome,
  NotificationKind.lowBalance: l.recurringChannelLowBalance,
  NotificationKind.budget: l.recurringChannelBudgets,
  NotificationKind.backup: l.backupChannel,
};

/// Reminder requests for the next pending occurrences of [plan].
List<ReminderRequest> remindersFor(
  RecurringPlan plan, {
  required DateTime now,
  required HolidayCalendar calendar,
  required AppLocalizations l10n,
  required String Function(int minor) money,
  required String Function(DateTime d) date,
}) {
  if (!plan.active || plan.template.validate().isNotEmpty) return const [];
  final today = DateTime(now.year, now.month, now.day);
  final horizon = DateTime(today.year, today.month, today.day + 120);
  final out = <ReminderRequest>[];
  for (final o in plan.pending(horizon, calendar)) {
    if (o.date.isBefore(today)) continue;
    final at = reminderTime(o.date, plan.remindDaysBefore, plan.notifyTime);
    if (!at.isAfter(now)) continue;
    final amount = money(plan.amountFor(o).abs());
    out.add(
      ReminderRequest(
        at: at,
        title: plan.name,
        body: plan.isIncome
            ? l10n.recurringReminderIncomeBody(amount, date(o.date))
            : l10n.recurringReminderBillBody(amount, date(o.date)),
        kind: plan.isIncome ? NotificationKind.income : NotificationKind.bill,
        payload: 'plan:recurring',
      ),
    );
    if (out.length >= maxRemindersPerRule) break;
  }
  return out;
}

/// Re-schedules the reminders of rule [ruleId] (after it was created,
/// edited, posted or deleted). Never throws.
Future<void> rescheduleRuleReminders(PlanReader read, String ruleId) async {
  try {
    final service = read(notificationServiceProvider);
    final plan = await read(recurringRepositoryProvider).planById(ruleId);
    if (plan == null) {
      await service.cancelRule(ruleId);
      return;
    }
    final l = planL10n(read);
    final fmt = read(moneyFormatterProvider);
    final dates = read(dateFormatsProvider);
    await service.scheduleRuleReminders(
      ruleId,
      remindersFor(
        plan,
        now: DateTime.now(),
        calendar: read(holidayCalendarProvider),
        l10n: l,
        money: fmt.minor,
        date: dates.medium,
      ),
    );
  } on Object {
    // Reminders are best effort.
  }
}

/// Re-schedules the reminders of all rules (startup task). Never throws.
Future<void> rescheduleAllReminders(PlanReader read) async {
  try {
    final service = read(notificationServiceProvider);
    final l = planL10n(read);
    if (!await service.init(channelNames: notificationChannelNames(l))) {
      return;
    }
    final fmt = read(moneyFormatterProvider);
    final dates = read(dateFormatsProvider);
    final calendar = read(holidayCalendarProvider);
    final now = DateTime.now();
    final plans = await read(recurringRepositoryProvider).plans();
    await service.rescheduleAll({
      for (final p in plans)
        p.id: remindersFor(
          p,
          now: now,
          calendar: calendar,
          l10n: l,
          money: fmt.minor,
          date: dates.medium,
        ),
    });
  } on Object {
    // Reminders are best effort.
  }
}

/// Posts due auto-post occurrences (startup task). Never throws.
Future<int> postDueRecurring(PlanReader read) async {
  try {
    final r = await read(recurringRepositoryProvider).postDue(
      today: read(planTodayProvider),
      calendar: read(holidayCalendarProvider),
    );
    return r.posted;
  } on Object {
    return 0;
  }
}

/// Signed amount helper for the UI: [absMinor] with the sign of [type].
int signedAmount(TxnType type, int absMinor) =>
    type == TxnType.income ? absMinor.abs() : -absMinor.abs();
