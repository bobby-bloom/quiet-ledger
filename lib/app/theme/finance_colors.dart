import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/tokens.dart';

/// Money-direction and status colours that ColorScheme has no role for.
///
/// Access with `context.finance` (see `theme_ext.dart`).
@immutable
class FinanceColors extends ThemeExtension<FinanceColors> {
  const FinanceColors({
    required this.income,
    required this.incomeContainer,
    required this.onIncomeContainer,
    required this.expense,
    required this.expenseFill,
    required this.expenseContainer,
    required this.onExpenseContainer,
    required this.transfer,
    required this.transferContainer,
    required this.warning,
    required this.warningFill,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.chart,
    required this.chartOther,
  });

  static const light = FinanceColors(
    income: LightTokens.income,
    incomeContainer: LightTokens.incomeContainer,
    onIncomeContainer: LightTokens.onIncomeContainer,
    expense: LightTokens.expense,
    expenseFill: LightTokens.expenseFill,
    expenseContainer: LightTokens.expenseContainer,
    onExpenseContainer: LightTokens.onExpenseContainer,
    transfer: LightTokens.transfer,
    transferContainer: LightTokens.transferContainer,
    warning: LightTokens.warning,
    warningFill: LightTokens.warningFill,
    warningContainer: LightTokens.warningContainer,
    onWarningContainer: LightTokens.onWarningContainer,
    chart: ChartPalette.series,
    chartOther: ChartPalette.other,
  );

  static const dark = FinanceColors(
    income: DarkTokens.income,
    incomeContainer: DarkTokens.incomeContainer,
    onIncomeContainer: DarkTokens.onIncomeContainer,
    expense: DarkTokens.expense,
    expenseFill: DarkTokens.expenseFill,
    expenseContainer: DarkTokens.expenseContainer,
    onExpenseContainer: DarkTokens.onExpenseContainer,
    transfer: DarkTokens.transfer,
    transferContainer: DarkTokens.transferContainer,
    warning: DarkTokens.warning,
    warningFill: DarkTokens.warningFill,
    warningContainer: DarkTokens.warningContainer,
    onWarningContainer: DarkTokens.onWarningContainer,
    chart: ChartPalette.series,
    chartOther: ChartPalette.other,
  );

  final Color income;
  final Color incomeContainer;
  final Color onIncomeContainer;

  /// Expense amounts as text.
  final Color expense;

  /// Expense in charts and bars.
  final Color expenseFill;
  final Color expenseContainer;
  final Color onExpenseContainer;
  final Color transfer;
  final Color transferContainer;

  /// Warning as text.
  final Color warning;

  /// Warning in bars.
  final Color warningFill;
  final Color warningContainer;
  final Color onWarningContainer;
  final List<Color> chart;
  final Color chartOther;

  Color chartAt(int i) => chart[i % chart.length];

  @override
  FinanceColors copyWith({
    Color? income,
    Color? incomeContainer,
    Color? onIncomeContainer,
    Color? expense,
    Color? expenseFill,
    Color? expenseContainer,
    Color? onExpenseContainer,
    Color? transfer,
    Color? transferContainer,
    Color? warning,
    Color? warningFill,
    Color? warningContainer,
    Color? onWarningContainer,
    List<Color>? chart,
    Color? chartOther,
  }) => FinanceColors(
    income: income ?? this.income,
    incomeContainer: incomeContainer ?? this.incomeContainer,
    onIncomeContainer: onIncomeContainer ?? this.onIncomeContainer,
    expense: expense ?? this.expense,
    expenseFill: expenseFill ?? this.expenseFill,
    expenseContainer: expenseContainer ?? this.expenseContainer,
    onExpenseContainer: onExpenseContainer ?? this.onExpenseContainer,
    transfer: transfer ?? this.transfer,
    transferContainer: transferContainer ?? this.transferContainer,
    warning: warning ?? this.warning,
    warningFill: warningFill ?? this.warningFill,
    warningContainer: warningContainer ?? this.warningContainer,
    onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    chart: chart ?? this.chart,
    chartOther: chartOther ?? this.chartOther,
  );

  @override
  FinanceColors lerp(ThemeExtension<FinanceColors>? other, double t) {
    if (other is! FinanceColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return FinanceColors(
      income: c(income, other.income),
      incomeContainer: c(incomeContainer, other.incomeContainer),
      onIncomeContainer: c(onIncomeContainer, other.onIncomeContainer),
      expense: c(expense, other.expense),
      expenseFill: c(expenseFill, other.expenseFill),
      expenseContainer: c(expenseContainer, other.expenseContainer),
      onExpenseContainer: c(onExpenseContainer, other.onExpenseContainer),
      transfer: c(transfer, other.transfer),
      transferContainer: c(transferContainer, other.transferContainer),
      warning: c(warning, other.warning),
      warningFill: c(warningFill, other.warningFill),
      warningContainer: c(warningContainer, other.warningContainer),
      onWarningContainer: c(onWarningContainer, other.onWarningContainer),
      chart: t < 0.5 ? chart : other.chart,
      chartOther: c(chartOther, other.chartOther),
    );
  }
}
