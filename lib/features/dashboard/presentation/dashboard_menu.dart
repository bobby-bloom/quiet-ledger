import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/board/board_labels.dart';
import 'package:personal_finance/app/ui/board/board_menu.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/core/board/board_layout.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/dashboard/domain/dashboard_view.dart';
import 'package:personal_finance/features/dashboard/presentation/widget_registry.dart';
import 'package:personal_finance/features/dashboard/presentation/widgets/dash_card.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// The dashboard's words for its board (docs/DASHBOARD.md), its widgets
/// named as [state] has them (the forecast by its account).
BoardLabels dashboardLabels(
  BuildContext context,
  WidgetRef ref,
  BoardState state,
) {
  final l = context.l10n;
  DashboardWidgetType type(String id) => DashboardWidgetType.values.byName(id);
  return BoardLabels(
    menu: l.dashLayoutMenu,
    menuCustom: l.dashLayoutMenuCustom,
    autoHint: l.dashLayoutAutoHint,
    customHint: l.dashLayoutCustomHint,
    orderAutoHint: l.dashLayoutPhoneAutoHint,
    orderCustomHint: l.dashLayoutPhoneCustomHint,
    arrangeMenu: l.dashLayoutArrange,
    arrangeTitle: l.dashLayoutArrangeTitle,
    addMenu: l.dashLayoutAddMenu,
    addTitle: l.dashAddWidget,
    emptyColumn: l.dashLayoutEmptyColumn,
    removeFromBoard: l.dashLayoutRemoveFromDashboard,
    notOnBoard: l.dashLayoutNotOnDashboard,
    orderTitle: l.dashEditTitle,
    resetDone: l.dashLayoutResetDone,
    cardName: (id) => widgetName(ref, l, type(id), state),
    cardTitle: (id) => widgetTypeLabel(l, type(id)),
    cardIcon: (id) => widgetIcon(type(id)),
    cardDescription: (id) => widgetDescription(l, type(id)),
  );
}

/// The dashboard's layout button: the board's, with Expand all / Collapse
/// all in its menu and in the phone's order sheet.
class DashboardLayoutButton extends ConsumerWidget {
  const DashboardLayoutButton({
    required this.view,
    required this.saved,
    required this.layout,
    super.key,
    this.focusNode,
  });

  final FocusNode? focusNode;
  final BoardView view;
  final BoardState saved;

  /// What the wide board shows now; null on phones.
  final BoardLayout? layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) => BoardLayoutButton(
    def: dashboardBoard,
    labels: dashboardLabels(context, ref, saved),
    view: view,
    saved: saved,
    layout: layout,
    focusNode: focusNode,
    menuExtras: expandCollapseItems(context, ref, shownWidgets(saved, view)),
    orderExtras: (shown) => _FoldAll(
      types: [for (final id in shown) DashboardWidgetType.values.byName(id)],
    ),
  );
}

/// Expand all and Collapse all for the widgets [types] that show: they
/// change only the cards that fold (not Net worth on phones) and are
/// disabled when they would change nothing.
List<Widget> expandCollapseItems(
  BuildContext context,
  WidgetRef ref,
  List<DashboardWidgetType> types,
) {
  final l = context.l10n;
  final expansion = ref.watch(dashboardFoldsProvider);
  final foldable = [
    for (final t in types)
      if (!WindowSize.of(context).isCompact ||
          t != DashboardWidgetType.netWorth)
        t.name,
  ];
  void setAll(bool open) =>
      ref.read(dashboardFoldsProvider.notifier).setAll(foldable, open);
  return [
    MenuItemButton(
      leadingIcon: const Icon(Icons.unfold_more),
      onPressed: expansion.wouldChange(foldable, true)
          ? () => setAll(true)
          : null,
      child: Text(l.dashLayoutExpandAll),
    ),
    MenuItemButton(
      leadingIcon: const Icon(Icons.unfold_less),
      onPressed: expansion.wouldChange(foldable, false)
          ? () => setAll(false)
          : null,
      child: Text(l.dashLayoutCollapseAll),
    ),
  ];
}

/// Expand all and Collapse all for the phone's cards that fold (all but
/// Net worth, the hero); each disabled when it would change nothing.
class _FoldAll extends ConsumerWidget {
  const _FoldAll({required this.types});

  final List<DashboardWidgetType> types;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final expansion = ref.watch(dashboardFoldsProvider);
    final foldable = [
      for (final t in types)
        if (t != DashboardWidgetType.netWorth) t.name,
    ];
    void setAll(bool open) =>
        ref.read(dashboardFoldsProvider.notifier).setAll(foldable, open);
    return Wrap(
      spacing: Space.xs,
      children: [
        TextButton.icon(
          onPressed: expansion.wouldChange(foldable, true)
              ? () => setAll(true)
              : null,
          icon: const Icon(Icons.unfold_more),
          label: Text(l.dashLayoutExpandAll),
        ),
        TextButton.icon(
          onPressed: expansion.wouldChange(foldable, false)
              ? () => setAll(false)
              : null,
          icon: const Icon(Icons.unfold_less),
          label: Text(l.dashLayoutCollapseAll),
        ),
      ],
    );
  }
}

/// What [type] shows, one line for Add widget.
String widgetDescription(AppLocalizations l, DashboardWidgetType type) =>
    switch (type) {
      DashboardWidgetType.netWorth => l.dashLayoutDescnetWorth,
      DashboardWidgetType.monthSummary => l.dashLayoutDescmonthSummary,
      DashboardWidgetType.budgets => l.dashLayoutDescbudgets,
      DashboardWidgetType.upcomingBills => l.dashLayoutDescupcomingBills,
      DashboardWidgetType.forecast => l.dashLayoutDescforecast,
      DashboardWidgetType.accounts => l.dashLayoutDescaccounts,
      DashboardWidgetType.goals => l.dashLayoutDescgoals,
      DashboardWidgetType.topCategories => l.dashLayoutDesctopCategories,
      DashboardWidgetType.recentTransactions =>
        l.dashLayoutDescrecentTransactions,
    };

/// [type]'s name in arrange mode and the phone sheet: its type, and for the
/// forecast the account it shows ("Mini forecast · Everyday checking").
String widgetName(
  WidgetRef ref,
  AppLocalizations l,
  DashboardWidgetType type,
  BoardState state,
) {
  final name = widgetTypeLabel(l, type);
  if (type != DashboardWidgetType.forecast) return name;
  final accounts = ref.watch(accountMapProvider);
  final defaultId = ref.watch(
    settingsProvider.select((s) => s.get(EntrySettings.defaultAccountId)),
  );
  final chosen = state.optionsOf(type.name)['accountId'] as String?;
  final id = chosen ?? (accounts.containsKey(defaultId) ? defaultId : null);
  return '$name · ${id == null ? l.dashAllAccounts : accounts[id]?.name ?? ''}';
}
