import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/features/dashboard/domain/board_layout.dart';
import 'package:personal_finance/features/dashboard/domain/dashboard_view.dart';
import 'package:personal_finance/features/dashboard/presentation/card_expansion.dart';
import 'package:personal_finance/features/dashboard/presentation/dashboard_layout_actions.dart';
import 'package:personal_finance/features/dashboard/presentation/phone_editor_sheet.dart';
import 'package:personal_finance/features/dashboard/presentation/widget_registry.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// The dashboard's layout button (docs/DASHBOARD.md, Board menu). Wide, it
/// opens the board menu: the Layout control, Arrange widgets…, Add
/// widget… and Expand all / Collapse all. On phones it opens the editor
/// sheet directly. Its tooltip says "· Custom" while not on Auto.
class DashboardLayoutButton extends ConsumerWidget {
  const DashboardLayoutButton({
    required this.view,
    required this.saved,
    required this.layout,
    super.key,
    this.focusNode,
  });

  /// The button's focus: it gets it back when arrange mode ends.
  final FocusNode? focusNode;

  final DashboardView view;
  final DashboardViewState saved;

  /// What the wide board shows now; null on phones.
  final BoardLayout? layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tooltip = saved.mode == LayoutMode.custom
        ? l.dashLayoutMenuCustom
        : l.dashLayoutMenu;
    const icon = Icon(Icons.dashboard_customize_outlined);
    final layout = this.layout;
    if (view == DashboardView.compact || layout == null) {
      return IconButton(
        focusNode: focusNode,
        tooltip: tooltip,
        icon: icon,
        onPressed: () => showPhoneEditor(context),
      );
    }

    final hasNew = DashboardWidgetType.values.any((t) => saved.isNew(view, t));
    return MenuAnchor(
      menuChildren: [
        _LayoutChoice(saved: saved, layout: layout),
        const Divider(),
        MenuItemButton(
          leadingIcon: const Icon(Icons.drag_indicator),
          onPressed: layout.canArrange
              ? () => ref
                    .read(arrangeSessionProvider.notifier)
                    .enter(saved, layout.placed)
              : null,
          child: _TwoLines(
            title: l.dashLayoutArrange,
            subtitle: layout.canArrange ? null : l.dashLayoutArrangeNeeds,
          ),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.add),
          trailingIcon: hasNew ? const NewBadge() : null,
          onPressed: () => unawaited(
            showAddWidget(
              context,
              view: view,
              state: saved,
              onAdd: (t) => addWidget(ref, view, t),
            ),
          ),
          child: Text(l.dashLayoutAddMenu),
        ),
        const Divider(),
        ...expandCollapseItems(context, ref, saved.shown(view)),
      ],
      builder: (context, controller, _) => IconButton(
        focusNode: focusNode,
        tooltip: tooltip,
        icon: icon,
        isSelected: controller.isOpen,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
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
  final expansion = ref.watch(cardExpansionProvider);
  final foldable = [
    for (final t in types)
      if (!WindowSize.of(context).isCompact ||
          t != DashboardWidgetType.netWorth)
        t,
  ];
  void setAll(bool open) =>
      ref.read(cardExpansionProvider.notifier).setAll(foldable, open);
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

/// The menu's Layout control: Auto · 1 · 2 · 3 (· Custom while a layout is
/// saved that no number stands for). The selected segment is what shows;
/// numbers wider than the window are disabled, a selected one dimmed. The
/// line under it says whose arrangement shows, or that the window fits
/// fewer columns.
class _LayoutChoice extends ConsumerWidget {
  const _LayoutChoice({required this.saved, required this.layout});

  final DashboardViewState saved;
  final BoardLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final selected = selectedSegment(layout.mode, saved.rows);
    final segments = [
      LayoutSegment.auto,
      ...LayoutSegment.numbers,
      if (offersCustom(saved.rows)) LayoutSegment.custom,
    ];
    final fits = layout.fits;
    final selectedTooWide = (selected.columns ?? 0) > fits;
    final line = layout.isSqueezed || selectedTooWide
        ? (fits == 1 ? l.dashLayoutFitsOne : l.dashLayoutFitsUpTo(fits))
        : layout.mode == LayoutMode.custom
        ? l.dashLayoutCustomHint
        : l.dashLayoutAutoHint;

    return SizedBox(
      width: 320,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.md,
          Space.xs,
          Space.md,
          Space.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Space.xs,
          children: [
            ExcludeSemantics(
              child: Text(l.dashLayoutLabel, style: context.text.labelLarge),
            ),
            Semantics(
              label: l.dashLayoutLabel,
              hint: line,
              child: SegmentedButton<LayoutSegment>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                segments: [
                  for (final s in segments)
                    ButtonSegment(
                      value: s,
                      enabled: (s.columns ?? 0) <= fits,
                      tooltip: (s.columns ?? 0) > fits
                          ? l.dashLayoutSplitFits(fits)
                          : null,
                      label: Text(switch (s) {
                        LayoutSegment.auto => l.dashLayoutAuto,
                        LayoutSegment.custom => l.dashLayoutCustom,
                        _ => '${s.columns}',
                      }),
                    ),
                ],
                selected: {selected},
                onSelectionChanged: (picked) =>
                    unawaited(pickLayout(context, ref, picked.first, layout)),
              ),
            ),
            ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.xxs,
                children: [
                  if (layout.isSqueezed || selectedTooWide)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.info_outline,
                        size: 14,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      line,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TwoLines extends StatelessWidget {
  const _TwoLines({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    if (subtitle == null) return Text(title);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          Text(
            subtitle,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The small "New" badge of a widget type that shipped after the last save.
class NewBadge extends StatelessWidget {
  const NewBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: 2),
    decoration: BoxDecoration(
      color: context.colors.primaryContainer,
      borderRadius: BorderRadius.circular(Radii.full),
    ),
    child: Text(
      context.l10n.dashLayoutNew,
      style: context.text.labelSmall?.copyWith(
        color: context.colors.onPrimaryContainer,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// The widget types that do not show in [view]: removed ones ("its
/// settings are kept") and new ones ("New").
List<DashboardWidgetType> addableTypes(
  DashboardViewState state,
  DashboardView view,
) => [
  for (final t in DashboardWidgetType.values)
    if (!state.shows(view, t)) t,
];

/// The Add widget dialog (a sheet on phones): every type that does not show
/// in [view], with its icon and what it shows; tapping one adds it.
Future<void> showAddWidget(
  BuildContext context, {
  required DashboardView view,
  required DashboardViewState state,
  required ValueChanged<DashboardWidgetType> onAdd,
}) => showAdaptiveSheet<void>(
  context,
  builder: (ctx) {
    final l = ctx.l10n;
    final types = addableTypes(state, view);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.xl,
              Space.lg,
              Space.xl,
              Space.xs,
            ),
            child: Text(l.dashAddWidget, style: ctx.text.titleLarge),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final t in types)
                  ListTile(
                    leading: Icon(widgetIcon(t)),
                    title: Row(
                      spacing: Space.xs,
                      children: [
                        Flexible(child: Text(widgetTypeLabel(l, t))),
                        if (state.isNew(view, t)) const NewBadge(),
                      ],
                    ),
                    subtitle: Text(
                      state.isNew(view, t) || !state.items.containsKey(t.name)
                          ? widgetDescription(l, t)
                          : '${widgetDescription(l, t)}\n'
                                '${l.dashLayoutRemovedHint}',
                    ),
                    isThreeLine:
                        !state.isNew(view, t) &&
                        state.items.containsKey(t.name),
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onAdd(t);
                      },
                      child: Text(l.commonAdd),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onAdd(t);
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.xs),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.commonClose),
              ),
            ),
          ),
        ],
      ),
    );
  },
);

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
