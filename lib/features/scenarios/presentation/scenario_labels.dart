import 'package:flutter/material.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/money/money.dart';
import 'package:personal_finance/core/money/money_format.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_format.dart';
import 'package:personal_finance/features/scenarios/domain/scenario.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// Kinds of adjustment offered in the editor, in menu order.
enum AdjustmentKind {
  oneOff,
  category,
  recurringChange,
  addRecurring,
  endRecurring,
  returnRate,
  inflation,
}

AdjustmentKind? kindOf(ScenarioAdjustment a) => switch (a) {
  OneOffAdjustment() => AdjustmentKind.oneOff,
  CategoryChangeAdjustment() => AdjustmentKind.category,
  RecurringChangeAdjustment() => AdjustmentKind.recurringChange,
  AddRecurringAdjustment() => AdjustmentKind.addRecurring,
  EndRecurringAdjustment() => AdjustmentKind.endRecurring,
  ReturnAdjustment() => AdjustmentKind.returnRate,
  InflationAdjustment() => AdjustmentKind.inflation,
  UnknownAdjustment() => null,
};

String kindLabel(AppLocalizations l, AdjustmentKind? k) => switch (k) {
  AdjustmentKind.oneOff => l.scenariosTypeOneOff,
  AdjustmentKind.category => l.scenariosTypeCategory,
  AdjustmentKind.recurringChange => l.scenariosTypeRecurringChange,
  AdjustmentKind.addRecurring => l.scenariosTypeAddRecurring,
  AdjustmentKind.endRecurring => l.scenariosTypeEndRecurring,
  AdjustmentKind.returnRate => l.scenariosTypeReturn,
  AdjustmentKind.inflation => l.scenariosTypeInflation,
  null => l.scenariosTypeUnknown,
};

IconData kindIcon(AdjustmentKind? k) => switch (k) {
  AdjustmentKind.oneOff => Icons.event_outlined,
  AdjustmentKind.category => Icons.category_outlined,
  AdjustmentKind.recurringChange => Icons.tune,
  AdjustmentKind.addRecurring => Icons.event_repeat_outlined,
  AdjustmentKind.endRecurring => Icons.event_busy_outlined,
  AdjustmentKind.returnRate => Icons.trending_up,
  AdjustmentKind.inflation => Icons.price_change_outlined,
  null => Icons.help_outline,
};

/// Frequencies offered for added recurring items.
enum ScenarioFrequency { weekly, monthly, quarterly, yearly }

/// RRULE for [f] anchored on [start] (monthly rules fall back to the last
/// day of shorter months).
String rruleFor(ScenarioFrequency f, DateTime start) => switch (f) {
  ScenarioFrequency.weekly => 'FREQ=WEEKLY',
  ScenarioFrequency.monthly => _monthly(start.day, 1),
  ScenarioFrequency.quarterly => _monthly(start.day, 3),
  ScenarioFrequency.yearly => 'FREQ=YEARLY',
};

String _monthly(int day, int interval) {
  if (day <= 28) return 'FREQ=MONTHLY;INTERVAL=$interval;BYMONTHDAY=$day';
  final days = [for (var d = 28; d <= day; d++) d].join(',');
  return 'FREQ=MONTHLY;INTERVAL=$interval;BYMONTHDAY=$days;BYSETPOS=-1';
}

/// The frequency an RRULE written by [rruleFor] represents, or null.
ScenarioFrequency? frequencyOf(String rrule) {
  final r = rrule.toUpperCase();
  if (r.startsWith('FREQ=WEEKLY')) return ScenarioFrequency.weekly;
  if (r.startsWith('FREQ=YEARLY')) return ScenarioFrequency.yearly;
  if (r.startsWith('FREQ=MONTHLY')) {
    return r.contains('INTERVAL=3')
        ? ScenarioFrequency.quarterly
        : ScenarioFrequency.monthly;
  }
  return null;
}

String frequencyLabel(AppLocalizations l, ScenarioFrequency? f) => switch (f) {
  ScenarioFrequency.weekly => l.scenariosFreqWeekly,
  ScenarioFrequency.monthly => l.scenariosFreqMonthly,
  ScenarioFrequency.quarterly => l.scenariosFreqQuarterly,
  ScenarioFrequency.yearly => l.scenariosFreqYearly,
  null => l.scenariosFreqCustom,
};

/// Context for describing adjustments.
class AdjustmentDescriber {
  AdjustmentDescriber({
    required this.l,
    required this.money,
    required this.date,
    required this.locale,
    required this.accounts,
    required this.categories,
    required this.rules,
  });

  final AppLocalizations l;
  final MoneyFormatter money;
  final String Function(DateTime) date;
  final String locale;
  final Map<String, Account> accounts;
  final Map<String, Category> categories;

  /// Recurring rule id -> name.
  final Map<String, String> rules;

  String _m(int minor, {bool plus = false}) =>
      money.format(Money(minor), explicitPlus: plus);

  String title(ScenarioAdjustment a) => switch (a) {
    OneOffAdjustment(:final label) when label.isNotEmpty => label,
    AddRecurringAdjustment(:final label) when label.isNotEmpty => label,
    CategoryChangeAdjustment(:final categoryId) =>
      categories[categoryId]?.name ?? l.scenariosUnknownItem,
    RecurringChangeAdjustment(:final ruleId) ||
    EndRecurringAdjustment(
      :final ruleId,
    ) => rules[ruleId] ?? l.scenariosUnknownItem,
    _ => kindLabel(l, kindOf(a)),
  };

  String subtitle(ScenarioAdjustment a) => switch (a) {
    OneOffAdjustment() => l.scenariosSumOneOff(
      _m(a.amountMinor, plus: true),
      date(a.date),
    ),
    CategoryChangeAdjustment(mode: ChangeMode.percent) => l.scenariosSumPercent(
      formatBp(a.value, locale, explicitPlus: true),
      date(a.from),
    ),
    CategoryChangeAdjustment() => l.scenariosSumCategoryAbsolute(
      _m(a.value, plus: true),
      date(a.from),
    ),
    RecurringChangeAdjustment(mode: ChangeMode.percent) =>
      l.scenariosSumPercent(
        formatBp(a.value, locale, explicitPlus: true),
        date(a.from),
      ),
    RecurringChangeAdjustment() => l.scenariosSumRecurringAbsolute(
      _m(a.value, plus: true),
      date(a.from),
    ),
    AddRecurringAdjustment() => l.scenariosSumAddRecurring(
      _m(a.amountMinor, plus: true),
      frequencyLabel(l, frequencyOf(a.rrule)),
      date(a.start),
    ),
    EndRecurringAdjustment() => l.scenariosSumEndRecurring(date(a.from)),
    ReturnAdjustment(accountId: final String id) => l.scenariosSumReturnAccount(
      formatBp(a.returnBp, locale),
      accounts[id]?.name ?? l.scenariosUnknownItem,
    ),
    ReturnAdjustment() => l.scenariosSumReturnAll(formatBp(a.returnBp, locale)),
    InflationAdjustment() => l.scenariosSumInflation(
      formatBp(a.inflationBp, locale),
    ),
    UnknownAdjustment() => a.type,
  };

  /// Short summary of a whole scenario ("first change · +2 more").
  String summary(ScenarioDef s) {
    if (s.adjustments.isEmpty) return l.scenariosChangeCount(0);
    final first = s.adjustments.first;
    final text = '${title(first)} · ${subtitle(first)}';
    return s.adjustments.length == 1
        ? text
        : '$text · ${l.scenariosChangeCount(s.adjustments.length)}';
  }
}
