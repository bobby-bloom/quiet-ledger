import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/calendar/holidays.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/plan/plan_providers.dart';
import 'package:personal_finance/features/recurring/domain/recurring_logic.dart';

/// Holiday calendar from Settings › Budgets (country + region). Used for
/// budget period starts and per-rule business-day shifting.
final holidayCalendarProvider = Provider<HolidayCalendar>((ref) {
  final country = ref.watch(
    settingsProvider.select((s) => s.get(BudgetSettings.holidayCountry)),
  );
  final region = ref.watch(
    settingsProvider.select((s) => s.get(BudgetSettings.holidayRegion)),
  );
  if (country.isEmpty || country == 'none') return HolidayCalendar.none();
  return HolidayCalendar(country: country, region: region);
});

/// Computes salary arrival dates for a salary-based period start: the dates
/// of transactions actually posted by the rule plus the expected future
/// occurrences of the rule (after the last posted one), sorted ascending.
List<DateTime> salaryDates({
  required List<DateTime> posted,
  required RecurringPlan? rule,
  required HolidayCalendar calendar,
  required DateTime today,
  int horizonDays = 730,
}) {
  final days = <DateTime>{
    for (final d in posted) DateTime(d.year, d.month, d.day),
  };
  if (rule != null) {
    var after = rule.lastPostedDate;
    for (final d in days) {
      if (after == null || d.isAfter(after)) after = d;
    }
    final to = DateTime(today.year, today.month, today.day + horizonDays);
    final from = after == null
        ? rule.start
        : DateTime(after.year, after.month, after.day + 1);
    for (final o in rule.occurrences(from, to, calendar)) {
      if (after == null || o.date.isAfter(after)) days.add(o.date);
    }
  }
  return days.toList()..sort();
}

/// Salary dates for [BudgetSettings.salaryRuleId] when salary-based starts
/// are enabled; empty otherwise.
final salaryDatesProvider = StreamProvider<List<DateTime>>((ref) {
  final settings = ref.watch(settingsProvider);
  final enabled = settings.get(BudgetSettings.salaryBased);
  final ruleId = settings.get(BudgetSettings.salaryRuleId);
  if (!enabled || ruleId == null || ruleId.isEmpty) {
    return Stream.value(const []);
  }
  final db = ref.watch(databaseProvider);
  final calendar = ref.watch(holidayCalendarProvider);
  final today = ref.watch(planTodayProvider);
  return db
      .customSelect(
        'SELECT t.date AS d FROM transactions t '
        'WHERE t.deleted_at IS NULL AND t.recurring_rule_id = ? '
        'AND t.status <> ? GROUP BY t.date ORDER BY t.date',
        variables: [
          Variable<String>(ruleId),
          Variable<String>(TxnStatus.planned.name),
        ],
        readsFrom: {db.transactions, db.recurringRules},
      )
      .watch()
      .asyncMap((rows) async {
        final rule =
            await (db.select(db.recurringRules)
                  ..where((r) => r.id.equals(ruleId) & r.deletedAt.isNull()))
                .getSingleOrNull();
        return salaryDates(
          posted: [for (final r in rows) r.read<DateTime>('d')],
          rule: rule == null ? null : RecurringPlan.fromRow(rule),
          calendar: calendar,
          today: today,
        );
      });
});

/// Budget periods built from Settings › Budgets (period type, start day,
/// weekend/holiday shift), General (first day of week, fiscal year start)
/// and, for salary-based starts, the salary rule's actual and expected
/// arrival dates (falling back to the start day outside that range).
final budgetPeriodsProvider = Provider<BudgetPeriods>((ref) {
  final s = ref.watch(settingsProvider);
  final salary = ref.watch(salaryDatesProvider).value ?? const <DateTime>[];
  return BudgetPeriods(
    BudgetPeriodConfig(
      type: s.get(BudgetSettings.periodType),
      startDay: s.get(BudgetSettings.startDay),
      shift: s.get(BudgetSettings.weekendShift),
      calendar: ref.watch(holidayCalendarProvider),
      firstDayOfWeek: ref.watch(firstDayOfWeekProvider),
      fiscalYearStartMonth: s.get(GeneralSettings.fiscalYearStartMonth),
      salaryDates: salary,
    ),
  );
});

/// The budget period containing today.
final currentBudgetPeriodProvider = Provider<DateRange>(
  (ref) =>
      ref.watch(budgetPeriodsProvider).periodOf(ref.watch(planTodayProvider)),
);
