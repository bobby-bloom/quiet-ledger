import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/board/board_actions.dart';
import 'package:personal_finance/app/ui/board/board_labels.dart';
import 'package:personal_finance/app/ui/board/board_menu.dart';
import 'package:personal_finance/app/ui/board/board_order_sheet.dart';
import 'package:personal_finance/app/ui/board/card_board.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/core/board/board_layout.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/dashboard/data/dashboard_layout.dart';
import 'package:personal_finance/features/dashboard/presentation/dashboard_menu.dart';
import 'package:personal_finance/features/dashboard/presentation/dashboard_period.dart';
import 'package:personal_finance/features/dashboard/presentation/widget_registry.dart';
import 'package:personal_finance/features/dashboard/presentation/widgets/dash_card.dart';
import 'package:personal_finance/features/export/presentation/backup_health_banner.dart';

/// Home: configurable widgets (docs/DASHBOARD.md) — the phone's ordered
/// list, or on wider windows rows of columns, the app's Auto layout or the
/// person's own, arranged in place.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final size = WindowSize.of(context);
    final gutter = size.isCompact ? Space.phoneGutter : Space.desktopGutter;
    final view = size.isCompact ? BoardView.compact : BoardView.expanded;
    final labels = dashboardLabels(
      context,
      ref,
      ref.watch(dashboardViewProvider(view)).value ?? emptyDashboard,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) => CardBoard(
            def: dashboardBoard,
            labels: labels,
            width: constraints.maxWidth - 2 * gutter,
            card: (context, id, scene) => _card(
              context,
              labels,
              scene,
              DashboardWidgetType.values.byName(id),
            ),
            empty: (context, scene) =>
                _EmptyDashboard(view: scene.view, labels: labels),
            builder: (context, scene, arrangeBar, board) => CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child:
                      arrangeBar ??
                      (scene.view == BoardView.compact
                          ? _PhoneHeader(
                              saved: scene.saved,
                              layoutButtonFocus: scene.layoutButtonFocus,
                            )
                          : _WideHeader(
                              saved: scene.saved,
                              layout: scene.layout!,
                              layoutButtonFocus: scene.layoutButtonFocus,
                            )),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    size.isCompact ? 0 : Space.md,
                    gutter,
                    0,
                  ),
                  sliver: const SliverToBoxAdapter(
                    child: BackupHealthBanner(dismissible: true),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 32),
                  sliver: SliverToBoxAdapter(child: board),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The widget [type] with its ⋮ menu: its own options, Remove (with
  /// Undo) and the way to arrange — Arrange widgets… on wide windows that
  /// fit two columns, Edit dashboard… on phones.
  Widget _card(
    BuildContext context,
    BoardLabels labels,
    BoardScene scene,
    DashboardWidgetType type,
  ) {
    final l = context.l10n;
    final view = scene.view;
    final saved = scene.saved;
    final layout = scene.layout;
    final item = DashboardItem(type, options: saved.optionsOf(type.name));
    final options = [
      ...widgetOptions(context, ref, item, (updated) {
        unawaited(
          setCardOptions(ref, dashboardBoard, view, type.name, updated.options),
        );
      }),
      DashOption(
        l.dashRemove,
        Icons.remove_circle_outline,
        () => unawaited(
          removeCard(context, ref, dashboardBoard, labels, view, type.name),
        ),
      ),
      if (layout != null && layout.canArrange)
        DashOption(
          l.dashLayoutArrange,
          Icons.drag_indicator,
          () => ref
              .read(arrangeSessionProvider(dashboardBoard).notifier)
              .enter(saved, layout.placed),
        )
      else if (view == BoardView.compact)
        DashOption(
          l.dashLayoutEditMenu,
          Icons.dashboard_customize_outlined,
          () => unawaited(
            showBoardOrderSheet(context, def: dashboardBoard, labels: labels),
          ),
        ),
    ];
    return buildDashboardWidget(
      context,
      item,
      compact: view == BoardView.compact,
      options: options,
    );
  }
}

/// No widget shows: Add widget, or Reset to default (with Undo).
class _EmptyDashboard extends ConsumerWidget {
  const _EmptyDashboard({required this.view, required this.labels});

  final BoardView view;
  final BoardLabels labels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state =
        ref.watch(dashboardViewProvider(view)).value ?? emptyDashboard;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xxxl),
      child: Column(
        spacing: Space.sm,
        children: [
          Icon(
            Icons.dashboard_customize_outlined,
            size: 40,
            color: context.colors.onSurfaceVariant,
          ),
          Text(l.dashLayoutEmptyTitle, style: context.text.titleMedium),
          Text(
            l.dashLayoutEmptyBody,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => unawaited(
                  showAddCards(
                    context,
                    labels: labels,
                    view: view,
                    state: state,
                    onAdd: (id) =>
                        unawaited(addCard(ref, dashboardBoard, view, id)),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: Text(l.dashAddWidget),
              ),
              TextButton(
                onPressed: () => unawaited(
                  resetToDefault(context, ref, dashboardBoard, labels, view),
                ),
                child: Text(l.dashResetLayout),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodButton extends ConsumerWidget {
  const _PeriodButton({this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final range = ref.watch(dashboardPeriodProvider);
    final notifier = ref.read(dashboardPeriodProvider.notifier);
    final label = _label(ref, range);
    return MenuAnchor(
      builder: (context, controller, _) => TextButton(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        style: TextButton.styleFrom(
          foregroundColor: context.colors.onSurface,
          textStyle: context.text.titleMedium,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(48, 48),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more, size: 20),
          ],
        ),
      ),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.chevron_left),
          onPressed: notifier.previous,
          child: Text(l.dashPrevPeriod),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.chevron_right),
          onPressed: notifier.next,
          child: Text(l.dashNextPeriod),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.today_outlined),
          onPressed: notifier.today,
          child: Text(l.dashToday),
        ),
      ],
    );
  }

  static String _label(WidgetRef ref, DateRange r) {
    final dates = ref.watch(dateFormatsProvider);
    final monthly =
        ref.watch(
          settingsProvider.select((s) => s.get(BudgetSettings.periodType)),
        ) ==
        BudgetPeriodType.monthly;
    final calendarMonth =
        r.start.day == 1 && r.end == DateTime(r.start.year, r.start.month + 1);
    if (calendarMonth) return dates.monthYear(r.start);
    // A shifted monthly budget period (e.g. 30 Sep – 29 Oct) is named after
    // the month holding most of its days, like the Plan screen.
    if (monthly && r.days >= 27 && r.days <= 33) {
      return dates.monthYear(
        DateTime(r.start.year, r.start.month, r.start.day + r.days ~/ 2),
      );
    }
    return '${dates.medium(r.start)} – ${dates.medium(r.last)}';
  }
}

class _PhoneHeader extends ConsumerWidget {
  const _PhoneHeader({required this.saved, required this.layoutButtonFocus});

  final BoardState saved;
  final FocusNode layoutButtonFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final privacy = ref.watch(privacyModeProvider);
    return SizedBox(
      height: 56,
      child: Padding(
        // The last icon's circle ends on the 16 px page margin.
        padding: const EdgeInsets.only(left: 4, right: Space.sm),
        child: Row(
          children: [
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _PeriodButton(),
              ),
            ),
            IconButton(
              tooltip: l.commonSearch,
              icon: const Icon(Icons.search),
              onPressed: () => context.go('/transactions?focus=search'),
            ),
            IconButton(
              tooltip: l.privacyToggle,
              isSelected: privacy,
              icon: const Icon(Icons.visibility_outlined),
              selectedIcon: const Icon(Icons.visibility_off_outlined),
              onPressed: () => ref.read(privacyModeProvider.notifier).toggle(),
            ),
            IconButton(
              tooltip: l.navReports,
              icon: const Icon(Icons.bar_chart),
              onPressed: () => context.push('/reports'),
            ),
            DashboardLayoutButton(
              view: BoardView.compact,
              saved: saved,
              layout: null,
              focusNode: layoutButtonFocus,
            ),
          ],
        ),
      ),
    );
  }
}

class _WideHeader extends ConsumerWidget {
  const _WideHeader({
    required this.saved,
    required this.layout,
    required this.layoutButtonFocus,
  });

  final BoardState saved;
  final BoardLayout layout;
  final FocusNode layoutButtonFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final privacy = ref.watch(privacyModeProvider);
    return Padding(
      // Same height and margins as the other screens' PageAppBar: the
      // title and the last icon's circle on the content's 24 px margins.
      padding: const EdgeInsets.fromLTRB(
        Space.desktopGutter,
        Space.xxs,
        Space.desktopGutter - Space.xxs,
        Space.xxs,
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.navHome, style: context.text.titleLarge),
              const SizedBox(width: 12),
              const _PeriodButton(large: true),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 300,
                height: 44,
                child: TextField(
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l.dashSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: context.colors.surfaceContainer,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.full),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.full),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (q) => context.go(
                    Uri(
                      path: '/transactions',
                      queryParameters: {if (q.trim().isNotEmpty) 'q': q.trim()},
                    ).toString(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: l.privacyToggle,
                isSelected: privacy,
                icon: const Icon(Icons.visibility_outlined),
                selectedIcon: const Icon(Icons.visibility_off_outlined),
                onPressed: () =>
                    ref.read(privacyModeProvider.notifier).toggle(),
              ),
              DashboardLayoutButton(
                view: BoardView.expanded,
                saved: saved,
                layout: layout,
                focusNode: layoutButtonFocus,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
