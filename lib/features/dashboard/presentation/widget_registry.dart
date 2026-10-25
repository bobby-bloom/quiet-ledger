import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/features/dashboard/data/dashboard_layout.dart';
import 'package:personal_finance/features/dashboard/presentation/widgets/core_widgets.dart';
import 'package:personal_finance/features/dashboard/presentation/widgets/dash_card.dart';
import 'package:personal_finance/features/dashboard/presentation/widgets/plan_widgets.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

String widgetTypeLabel(AppLocalizations l, DashboardWidgetType t) =>
    switch (t) {
      DashboardWidgetType.netWorth => l.dashWTypenetWorth,
      DashboardWidgetType.monthSummary => l.dashWTypemonthSummary,
      DashboardWidgetType.budgets => l.dashWTypebudgets,
      DashboardWidgetType.upcomingBills => l.dashWTypeupcomingBills,
      DashboardWidgetType.forecast => l.dashWTypeforecast,
      DashboardWidgetType.accounts => l.dashWTypeaccounts,
      DashboardWidgetType.goals => l.dashWTypegoals,
      DashboardWidgetType.topCategories => l.dashWTypetopCategories,
      DashboardWidgetType.recentTransactions => l.dashWTyperecentTransactions,
    };

IconData widgetIcon(DashboardWidgetType t) => switch (t) {
  DashboardWidgetType.netWorth => Icons.account_balance_wallet_outlined,
  DashboardWidgetType.monthSummary => Icons.calendar_view_month_outlined,
  DashboardWidgetType.budgets => Icons.donut_large_outlined,
  DashboardWidgetType.upcomingBills => Icons.event_outlined,
  DashboardWidgetType.forecast => Icons.show_chart,
  DashboardWidgetType.accounts => Icons.account_balance_outlined,
  DashboardWidgetType.goals => Icons.flag_outlined,
  DashboardWidgetType.topCategories => Icons.pie_chart_outline,
  DashboardWidgetType.recentTransactions => Icons.receipt_long_outlined,
};

/// Row counts a list widget offers in its "⋮" (Rows 3 · 5 · 10, plus the
/// widget's own default where that is not one of them), or null for widgets
/// that are not lists. The default is today's length.
({List<int> values, int defaultValue})? rowChoices(DashboardWidgetType t) =>
    switch (t) {
      DashboardWidgetType.budgets || DashboardWidgetType.upcomingBills => (
        values: const [3, 4, 5, 10],
        defaultValue: 4,
      ),
      DashboardWidgetType.goals => (values: const [3, 5, 10], defaultValue: 3),
      DashboardWidgetType.topCategories ||
      DashboardWidgetType.recentTransactions => (
        values: const [3, 5, 10],
        defaultValue: 5,
      ),
      DashboardWidgetType.accounts => (
        values: const [3, 5, 8, 10],
        defaultValue: 8,
      ),
      DashboardWidgetType.netWorth ||
      DashboardWidgetType.monthSummary ||
      DashboardWidgetType.forecast => null,
    };

/// Rows a list widget shows: `options['limit']` when it is positive, else
/// the widget's default; null for widgets that are not lists.
int? rowLimit(DashboardItem item) {
  final choices = rowChoices(item.type);
  if (choices == null) return null;
  final v = item.options['limit'];
  return v is num && v >= 1 && v <= 50 ? v.toInt() : choices.defaultValue;
}

/// Widget-specific entries for the options menu: the forecast's account and,
/// for lists, the Rows group.
List<CardOption> widgetOptions(
  BuildContext context,
  WidgetRef ref,
  DashboardItem item,
  ValueChanged<DashboardItem> update,
) {
  final l = context.l10n;
  final choices = rowChoices(item.type);
  final limit = rowLimit(item);
  return [
    if (item.type == DashboardWidgetType.forecast)
      CardOption(l.dashChooseAccount, Icons.account_balance_outlined, () async {
        final id = await showAccountPicker(
          context,
          selectedId: item.options['accountId'] as String?,
        );
        if (id != null) {
          update(item.copyWith(options: {...item.options, 'accountId': id}));
        }
      }),
    if (choices != null)
      for (final n in choices.values)
        CardOption(
          '$n',
          Icons.format_list_numbered,
          () => update(item.copyWith(options: {...item.options, 'limit': n})),
          group: l.dashCardRows,
          checked: n == limit,
        ),
  ];
}

Widget buildDashboardWidget(
  BuildContext context,
  DashboardItem item, {
  required bool compact,
  required List<CardOption> options,
}) {
  // Non-null for every list widget below.
  final limit = rowLimit(item) ?? 0;
  return switch (item.type) {
    DashboardWidgetType.netWorth => NetWorthWidget(
      card: !compact,
      options: options,
    ),
    DashboardWidgetType.monthSummary => MonthSummaryWidget(options: options),
    DashboardWidgetType.topCategories => TopCategoriesWidget(
      options: options,
      limit: limit,
    ),
    DashboardWidgetType.forecast => MiniForecastWidget(
      accountId: item.options['accountId'] as String?,
      options: options,
    ),
    DashboardWidgetType.accounts => AccountsWidget(
      options: options,
      limit: limit,
    ),
    DashboardWidgetType.budgets => BudgetsWidget(
      options: options,
      limit: limit,
    ),
    DashboardWidgetType.upcomingBills => UpcomingBillsWidget(
      options: options,
      limit: limit,
    ),
    DashboardWidgetType.goals => GoalsWidget(options: options, limit: limit),
    DashboardWidgetType.recentTransactions => RecentTransactionsWidget(
      options: options,
      limit: limit,
    ),
  };
}
