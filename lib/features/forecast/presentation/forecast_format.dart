import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/forecast/domain/forecast_models.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// Formats basis points as a percentage, e.g. 250 → "2.5 %" / "2,5 %".
String formatBp(int bp, String locale, {bool explicitPlus = false}) {
  final f = NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 2);
  var text = f.format(bp / 100);
  // Drop trailing zeros of the fraction ("2,50" → "2,5", "3,00" → "3").
  final sep = f.symbols.DECIMAL_SEP;
  if (text.contains(sep)) {
    text = text.replaceAll(RegExp(r'0+$'), '');
    if (text.endsWith(sep)) text = text.substring(0, text.length - 1);
  }
  text = text.replaceFirst('-', '−');
  final sign = explicitPlus && bp > 0 ? '+' : '';
  return '$sign$text %';
}

/// Formats basis points for an input field ("2,5" / "2.5").
String bpInput(int bp, String locale) =>
    formatBp(bp, locale).replaceAll(' %', '').replaceAll('−', '-');

String variableMethodLabel(AppLocalizations l, VariableSpendingMethod m) =>
    switch (m) {
      VariableSpendingMethod.budget => l.setOptFromBudget,
      VariableSpendingMethod.mean3 => l.setOptMean(3),
      VariableSpendingMethod.mean6 => l.setOptMean(6),
      VariableSpendingMethod.mean12 => l.setOptMean(12),
      VariableSpendingMethod.median3 => l.setOptMedian(3),
      VariableSpendingMethod.median6 => l.setOptMedian(6),
      VariableSpendingMethod.median12 => l.setOptMedian(12),
    };

String eventKindLabel(AppLocalizations l, ForecastEventKind k) => switch (k) {
  ForecastEventKind.recurring => l.forecastEventRecurring,
  ForecastEventKind.scheduled => l.forecastEventScheduled,
  ForecastEventKind.goal => l.forecastEventGoal,
  ForecastEventKind.oneOff => l.forecastEventOneOff,
  ForecastEventKind.whatIf => l.forecastEventWhatIf,
};

/// Colour of the comparison slot [index] (0–2): tertiary, chart2, chart3
/// (design: Foundations › chart palette). A scenario's own [argb] wins.
Color scenarioColor(BuildContext context, int index, {int? argb}) {
  if (argb != null) return Color(argb);
  return switch (index % 3) {
    0 => context.colors.tertiary,
    1 => context.finance.chartAt(1),
    _ => context.finance.chartAt(2),
  };
}

/// Colour of the line with all compared scenarios combined (chart5; chart4
/// is too close to tertiary).
Color combinedScenarioColor(BuildContext context) => context.finance.chartAt(4);
