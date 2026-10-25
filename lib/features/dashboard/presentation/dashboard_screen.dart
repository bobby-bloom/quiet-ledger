import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/dashboard/data/dashboard_layout.dart';
import 'package:personal_finance/features/dashboard/domain/board_layout.dart';
import 'package:personal_finance/features/dashboard/domain/dashboard_view.dart';
import 'package:personal_finance/features/dashboard/presentation/board/arrange_board.dart';
import 'package:personal_finance/features/dashboard/presentation/dashboard_layout_actions.dart';
import 'package:personal_finance/features/dashboard/presentation/dashboard_menu.dart';
import 'package:personal_finance/features/dashboard/presentation/dashboard_period.dart';
import 'package:personal_finance/features/dashboard/presentation/phone_editor_sheet.dart';
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
  /// The layout button: focus comes back to it when arrange mode ends.
  final _layoutButton = FocusNode(debugLabel: 'dashboard layout');

  /// Whether an arrange session waits for a window wide enough (paused).
  var _isPaused = false;

  @override
  void dispose() {
    _layoutButton.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = WindowSize.of(context);
    final view = size.isCompact
        ? DashboardView.compact
        : DashboardView.expanded;
    final saved =
        ref.watch(dashboardViewProvider(view)).value ??
        DashboardViewState.empty;
    final session = ref.watch(arrangeSessionProvider);
    ref.listen(arrangeSessionProvider, (previous, next) {
      if (previous != null && next == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _layoutButton.requestFocus();
        });
      }
    });
    // A paused session whose saved layout changed meanwhile (a Layout pick,
    // an undo, another device) would resume on a stale base: it goes.
    ref.listen(dashboardViewProvider(DashboardView.expanded), (_, next) {
      final s = ref.read(arrangeSessionProvider);
      final value = next.value;
      if (s != null && _isPaused && value != null && value != s.before) {
        ref.read(arrangeSessionProvider.notifier).end();
      }
    });
    final gutter = size.isCompact ? Space.phoneGutter : Space.xxl;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth - 2 * gutter;
            final Widget header;
            final Widget board;
            if (view == DashboardView.compact) {
              _isPaused = session != null;
              header = _PhoneHeader(
                saved: saved,
                layoutButtonFocus: _layoutButton,
              );
              final order = phoneOrder(saved);
              board = order.isEmpty
                  ? const _EmptyDashboard(view: DashboardView.compact)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 10,
                      children: [
                        for (final t in order)
                          KeyedSubtree(
                            key: ValueKey(t),
                            child: _card(context, view, saved, null, t),
                          ),
                      ],
                    );
            } else {
              final layout = wideLayout(saved, fittingColumns(width));
              final arranging = session != null && layout.canArrange;
              _isPaused = session != null && !layout.canArrange;
              final l = context.l10n;
              String title(String id) => widgetName(
                ref,
                l,
                DashboardWidgetType.values.byName(id),
                session?.working ?? saved,
              );
              IconData icon(String id) =>
                  widgetIcon(DashboardWidgetType.values.byName(id));
              header = arranging
                  ? _ArrangeBar(session: session, fits: layout.fits)
                  : _WideHeader(
                      saved: saved,
                      layout: layout,
                      layoutButtonFocus: _layoutButton,
                    );
              board = arranging
                  ? ArrangeBoard(
                      rows: session.rows,
                      present: presentIds(
                        session.working,
                        DashboardView.expanded,
                      ).toSet(),
                      fits: layout.fits,
                      title: title,
                      icon: icon,
                      onChanged: ref
                          .read(arrangeSessionProvider.notifier)
                          .update,
                      onRemove: ref
                          .read(arrangeSessionProvider.notifier)
                          .remove,
                    )
                  : layout.rows.isEmpty
                  ? const _EmptyDashboard(view: DashboardView.expanded)
                  : _WideBoard(
                      layout: layout,
                      width: width,
                      card: (t) => _card(context, view, saved, layout, t),
                    );
            }
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: header),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  sliver: const SliverToBoxAdapter(child: BackupHealthBanner()),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 32),
                  sliver: SliverToBoxAdapter(child: board),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The widget [type] with its ⋮ menu: its own options, Remove (with
  /// Undo) and the way to arrange — Arrange widgets… on wide windows that
  /// fit two columns, Edit dashboard… on phones.
  Widget _card(
    BuildContext context,
    DashboardView view,
    DashboardViewState saved,
    BoardLayout? layout,
    DashboardWidgetType type,
  ) {
    final l = context.l10n;
    final item = DashboardItem(type, options: saved.optionsOf(type));
    final options = [
      ...widgetOptions(context, ref, item, (updated) {
        unawaited(setWidgetOptions(ref, view, type, updated.options));
      }),
      DashOption(
        l.dashRemove,
        Icons.remove_circle_outline,
        () => unawaited(removeWidget(context, ref, view, type)),
      ),
      if (layout != null && layout.canArrange)
        DashOption(
          l.dashLayoutArrange,
          Icons.drag_indicator,
          () => ref
              .read(arrangeSessionProvider.notifier)
              .enter(saved, layout.placed),
        )
      else if (view == DashboardView.compact)
        DashOption(
          l.dashLayoutEditMenu,
          Icons.dashboard_customize_outlined,
          () => unawaited(showPhoneEditor(context)),
        ),
    ];
    return buildDashboardWidget(
      context,
      item,
      compact: view == DashboardView.compact,
      options: options,
    );
  }
}

/// The wide board: [layout]'s rows top to bottom, each split into columns
/// as wide as its weights make them in [width], widgets stacked in each
/// column. A widget keeps its state wherever it moves.
class _WideBoard extends StatefulWidget {
  const _WideBoard({
    required this.layout,
    required this.width,
    required this.card,
  });

  final BoardLayout layout;
  final double width;
  final Widget Function(DashboardWidgetType type) card;

  @override
  State<_WideBoard> createState() => _WideBoardState();
}

class _WideBoardState extends State<_WideBoard> {
  final _keys = <String, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    final shown = widget.layout.order.toSet();
    _keys.removeWhere((id, _) => !shown.contains(id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: boardGap,
      children: [
        for (final row in widget.layout.rows)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: boardGap,
            children: [
              for (final (c, width) in columnWidths(
                row.split,
                widget.width,
              ).indexed)
                SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: boardGap,
                    children: [
                      for (final id in row.columns[c])
                        KeyedSubtree(
                          key: _keys.putIfAbsent(
                            id,
                            () => GlobalKey(debugLabel: id),
                          ),
                          child: widget.card(
                            DashboardWidgetType.values.byName(id),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// No widget shows: Add widget, or Reset to default (with Undo).
class _EmptyDashboard extends ConsumerWidget {
  const _EmptyDashboard({required this.view});

  final DashboardView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state =
        ref.watch(dashboardViewProvider(view)).value ??
        DashboardViewState.empty;
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
                  showAddWidget(
                    context,
                    view: view,
                    state: state,
                    onAdd: (t) => unawaited(addWidget(ref, view, t)),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: Text(l.dashAddWidget),
              ),
              TextButton(
                onPressed: () => unawaited(resetToDefault(context, ref, view)),
                child: Text(l.dashResetLayout),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The bar in place of the header while arranging: "Arrange widgets · Drag
/// to move", Add widget, Reset (the default rows inside the session;
/// disabled while they show), Cancel and Done.
class _ArrangeBar extends ConsumerWidget {
  const _ArrangeBar({required this.session, required this.fits});

  final ArrangeSession session;
  final int fits;

  /// The bar's width, at 1× text, from which the hint and the labels of
  /// Add widget and Reset show.
  static const double _roomyWidth = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final notifier = ref.read(arrangeSessionProvider.notifier);
    final present = presentIds(session.working, DashboardView.expanded);
    final defaults = wideLayout(
      session.working.copyWith(mode: LayoutMode.auto),
      fits,
    ).placed;
    final isDefault = listEquals(
      visibleRows(session.rows, present),
      visibleRows(defaults, present),
    );
    void addWidget() => unawaited(
      showAddWidget(
        context,
        view: DashboardView.expanded,
        state: session.working,
        onAdd: (t) => notifier.add(t, fits),
      ),
    );
    final onReset = isDefault ? null : () => notifier.reset(fits);
    return Container(
      color: context.colors.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(32, 14, 28, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Below this width at the text scale the hint goes and Add widget
          // and Reset keep only their icons; whatever still does not fit
          // wraps onto a second line rather than overflow.
          final roomy =
              constraints.maxWidth >=
              MediaQuery.textScalerOf(context).scale(_roomyWidth);
          return Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: Text.rich(
                  TextSpan(
                    text: l.dashLayoutArrangeTitle,
                    style: context.text.titleLarge,
                    children: [
                      if (roomy)
                        TextSpan(
                          text: '  ${l.dashLayoutArrangeHint}',
                          style: context.text.bodyMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Wrap(
                spacing: Space.xs,
                runSpacing: Space.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (roomy) ...[
                    TextButton.icon(
                      onPressed: addWidget,
                      icon: const Icon(Icons.add),
                      label: Text(l.dashAddWidget),
                    ),
                    TextButton.icon(
                      onPressed: onReset,
                      icon: const Icon(Icons.restart_alt),
                      label: Text(l.dashLayoutReset),
                    ),
                  ] else ...[
                    IconButton(
                      tooltip: l.dashAddWidget,
                      onPressed: addWidget,
                      icon: const Icon(Icons.add),
                    ),
                    IconButton(
                      tooltip: l.dashLayoutReset,
                      onPressed: onReset,
                      icon: const Icon(Icons.restart_alt),
                    ),
                  ],
                  OutlinedButton(
                    onPressed: () => cancelArrange(context, ref),
                    child: Text(l.commonCancel),
                  ),
                  FilledButton(
                    onPressed: () => unawaited(finishArrange(context, ref)),
                    child: Text(l.commonDone),
                  ),
                ],
              ),
            ],
          );
        },
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

  final DashboardViewState saved;
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
              view: DashboardView.compact,
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

  final DashboardViewState saved;
  final BoardLayout layout;
  final FocusNode layoutButtonFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final privacy = ref.watch(privacyModeProvider);
    return Padding(
      // The last icon's circle ends on the 32 px content margin.
      padding: const EdgeInsets.fromLTRB(32, 20, 28, 20),
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
                view: DashboardView.expanded,
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
