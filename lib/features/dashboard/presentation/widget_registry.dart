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

/// Widget-specific entries for the options menu.
List<DashOption> widgetOptions(
  BuildContext context,
  WidgetRef ref,
  DashboardItem item,
  ValueChanged<DashboardItem> update,
) {
  final l = context.l10n;
  return switch (item.type) {
    DashboardWidgetType.forecast => [
      DashOption(l.dashChooseAccount, Icons.account_balance_outlined, () async {
        final id = await showAccountPicker(
          context,
          selectedId: item.options['accountId'] as String?,
        );
        if (id != null) {
          update(item.copyWith(options: {...item.options, 'accountId': id}));
        }
      }),
    ],
    _ => const [],
  };
}

Widget buildDashboardWidget(
  BuildContext context,
  DashboardItem item, {
  required bool compact,
  required List<DashOption> options,
}) {
  return switch (item.type) {
    DashboardWidgetType.netWorth => NetWorthWidget(
      card: !compact,
      options: options,
    ),
    DashboardWidgetType.monthSummary => MonthSummaryWidget(options: options),
    DashboardWidgetType.topCategories => TopCategoriesWidget(options: options),
    DashboardWidgetType.forecast => MiniForecastWidget(
      accountId: item.options['accountId'] as String?,
      options: options,
    ),
    DashboardWidgetType.accounts => AccountsWidget(options: options),
    DashboardWidgetType.budgets => BudgetsWidget(options: options),
    DashboardWidgetType.upcomingBills => UpcomingBillsWidget(options: options),
    DashboardWidgetType.goals => GoalsWidget(options: options),
    DashboardWidgetType.recentTransactions => RecentTransactionsWidget(
      options: options,
    ),
  };
}
