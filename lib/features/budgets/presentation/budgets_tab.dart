import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/app_icons.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/tables.dart' show BudgetCadence;
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/budgets/data/budget_period_provider.dart';
import 'package:personal_finance/features/budgets/data/budget_providers.dart';
import 'package:personal_finance/features/budgets/domain/budget_math.dart';
import 'package:personal_finance/features/budgets/presentation/budget_actions.dart';
import 'package:personal_finance/features/budgets/presentation/budget_detail_screen.dart';
import 'package:personal_finance/features/plan/presentation/money_text.dart';
import 'package:personal_finance/features/plan/presentation/plan_widgets.dart';

/// Plan › Budgets: period navigation, summary, per-category progress.
/// On expanded screens the selected category's detail is shown beside the
/// list.
class BudgetsTab extends ConsumerStatefulWidget {
  const BudgetsTab({super.key});

  @override
  ConsumerState<BudgetsTab> createState() => _BudgetsTabState();
}

class _BudgetsTabState extends ConsumerState<BudgetsTab> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(shownBudgetPeriodProvider);
    final wide = WindowSize.of(context).isExpanded;
    final list = BudgetBoard(
      period: period,
      selectedCategoryId: wide ? _selected : null,
      onOpen: (id) {
        if (wide) {
          setState(() => _selected = id);
        } else {
          unawaited(
            context.push('/plan/budgets/$id?period=${isoDate(period.start)}'),
          );
        }
      },
    );
    if (!wide) return list;
    return ListDetail(
      listWidth: 440,
      list: list,
      detail: _selected == null
          ? EmptyState(
              icon: Icons.donut_large_outlined,
              message: context.l10n.budgetsSelectHint,
            )
          : BudgetDetailView(
              key: ValueKey(_selected),
              categoryId: _selected!,
              period: period,
              embedded: true,
            ),
    );
  }
}

/// The budget list of [period] (also used inside the list-detail layout).
class BudgetBoard extends ConsumerWidget {
  const BudgetBoard({
    required this.period,
    required this.onOpen,
    super.key,
    this.selectedCategoryId,
  });

  final DateRange period;
  final ValueChanged<String> onOpen;
  final String? selectedCategoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final periods = ref.watch(budgetPeriodsProvider);
    final current = ref.watch(currentBudgetPeriodProvider);
    final board = ref.watch(budgetBoardProvider(period));
    final selector = ref.read(selectedBudgetPeriodProvider.notifier);

    final header = PeriodSwitcher(
      period: period,
      onPrevious: () => selector.select(periods.previous(period)),
      onNext: () => selector.select(periods.next(period)),
      onToday: period == current ? null : selector.reset,
    );

    final summary = board.value;
    Widget body;
    if (summary == null) {
      body = board.hasError
          ? Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Text(
                l.commonError(board.error.toString()),
                style: TextStyle(color: context.colors.error),
              ),
            )
          : const Padding(
              padding: EdgeInsets.all(Space.xxl),
              child: Center(child: CircularProgressIndicator.adaptive()),
            );
      return ListView(children: [header, body]);
    }

    final money = moneyText(ref);
    final children = <Widget>[
      header,
      _SummaryCard(summary: summary),
      if (summary.mode == BudgetMode.envelope)
        _EnvelopeBanner(summary: summary),
      _Toolbar(summary: summary),
    ];
    if (summary.isEmpty) {
      children.add(
        EmptyState(
          icon: Icons.donut_large_outlined,
          message: l.budgetsEmpty,
          actionLabel: l.budgetsCopyPrevious,
          onAction: () => copyPreviousPeriod(context, ref, period),
        ),
      );
      children.add(
        Center(
          child: Wrap(
            spacing: Space.xs,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.functions),
                label: Text(l.budgetsFromAverage(3)),
                onPressed: () => fillFromAverage(context, ref, period, 3),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l.budgetsAdd),
                onPressed: () => addBudget(context, ref, period),
              ),
            ],
          ),
        ),
      );
    } else {
      for (var i = 0; i < summary.lines.length; i++) {
        final line = summary.lines[i];
        children.add(
          BudgetLineTile(
            line: line,
            tick: summary.tickFor(line),
            divider: i > 0,
            selected: line.categoryId == selectedCategoryId,
            onTap: () => onOpen(line.categoryId),
            onLongPress: () => editBudgetAmount(context, ref, period, line),
          ),
        );
      }
      if (summary.unbudgetedSpentMinor > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.listInset,
              Space.sm,
              Space.listInset,
              0,
            ),
            child: Text(
              l.budgetsUnbudgetedSpent(money(summary.unbudgetedSpentMinor)),
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        );
      }
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.sm, Space.xs, Space.sm, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l.budgetsAdd),
              onPressed: () => addBudget(context, ref, period),
            ),
          ),
        ),
      );
    }
    children.add(const SizedBox(height: 96));
    return ListView(children: children);
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.summary});

  final BudgetSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final money = moneyText(ref);
    final remaining = summary.totalRemainingMinor;
    final planned = summary.totalPlannedMinor;
    final projected = summary.projectedRemainingMinor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        Space.xxs,
        Space.md,
        Space.xxs,
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Metric(
                      label: l.budgetsBudgeted,
                      value: AmountText(
                        summary.totalBudgetedMinor,
                        colored: false,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Metric(
                      label: l.budgetsSpent,
                      value: AmountText(
                        summary.totalSpentMinor,
                        colored: false,
                        style: TextStyle(color: context.finance.expense),
                      ),
                    ),
                  ),
                  if (planned != 0)
                    Expanded(
                      child: Metric(
                        label: l.budgetsPlanned,
                        value: AmountText(
                          planned,
                          colored: false,
                          style: TextStyle(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Metric(
                      alignEnd: true,
                      label: summary.isCurrent
                          ? l.budgetsLeftDays(summary.daysLeft)
                          : l.budgetsLeftLabel,
                      value: AmountText(
                        remaining,
                        colored: false,
                        style: remaining < 0
                            ? TextStyle(color: context.colors.error)
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              if (planned != 0)
                Padding(
                  padding: const EdgeInsets.only(top: Space.xxs),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 13,
                        color: projected < 0
                            ? context.finance.warning
                            : context.colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          projected < 0
                              ? l.budgetsAfterPlannedOver(money(-projected))
                              : l.budgetsAfterPlanned(money(projected)),
                          style: context.text.bodySmall?.copyWith(
                            color: projected < 0
                                ? context.finance.warning
                                : context.colors.onSurfaceVariant,
                            fontWeight: projected < 0 ? FontWeight.w700 : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (summary.hasWindowed)
                Padding(
                  padding: const EdgeInsets.only(top: Space.xxs),
                  child: Text(
                    l.budgetsWindowsNote,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnvelopeBanner extends ConsumerWidget {
  const _EnvelopeBanner({required this.summary});

  final BudgetSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final money = moneyText(ref);
    final tbb = summary.toBeBudgetedMinor;
    final (bg, fg, text) = tbb > 0
        ? (
            context.colors.primaryContainer,
            context.colors.onPrimaryContainer,
            l.budgetsLeftToAssign(money(tbb)),
          )
        : tbb == 0
        ? (
            context.colors.surfaceContainerHigh,
            context.colors.onSurface,
            l.budgetsAllAssigned,
          )
        : (
            context.colors.errorContainer,
            context.colors.onErrorContainer,
            l.budgetsOverAssigned(money(-tbb)),
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        Space.xxs,
        Space.md,
        Space.xxs,
      ),
      child: Semantics(
        container: true,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.sm,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: context.text.titleSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l.budgetsEnvelopeFormula(
                  money(summary.incomeMinor),
                  money(summary.carryMinor),
                  money(summary.assignedMinor),
                ),
                style: context.text.bodySmall?.copyWith(color: fg),
              ),
              if (summary.plannedIncomeMinor > 0)
                Text(
                  l.budgetsExpectedIncome(money(summary.plannedIncomeMinor)),
                  style: context.text.bodySmall?.copyWith(color: fg),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.summary});

  final BudgetSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return SizedBox(
      height: Space.minTouch,
      child: Row(
        children: [
          const SizedBox(width: Space.listInset),
          if (summary.isCurrent) ...[
            ExcludeSemantics(
              child: Container(
                width: 2,
                height: 12,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l.budgetsTodayDayOf(summary.dayOfPeriod, summary.period.days),
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            const Spacer(),
          BudgetFillMenu(period: summary.period, hasBudgets: !summary.isEmpty),
          const SizedBox(width: Space.xxs),
        ],
      ),
    );
  }
}

/// One budget row: icon, name, "€184.90 of €160", progress bar with today
/// tick and a state label ("€24.90 over budget", "92% used · €11.40 left").
class BudgetLineTile extends ConsumerWidget {
  const BudgetLineTile({
    required this.line,
    super.key,
    this.tick,
    this.onTap,
    this.onLongPress,
    this.divider = false,
    this.selected = false,
  });

  final BudgetLine line;
  final double? tick;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool divider;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final money = moneyText(ref);
    final state = line.state;
    final color = line.color == null ? null : Color(line.color!);
    final (labelColor, icon, label) = switch (state) {
      BudgetState.over => (
        context.colors.error,
        Icons.error_outline,
        l.budgetsOverBudget(money(line.overMinor)),
      ),
      BudgetState.warning => (
        context.finance.warning,
        Icons.warning_amber_outlined,
        l.budgetsUsedLeft(line.percentUsed, money(line.remainingMinor)),
      ),
      BudgetState.onTrack => (
        context.colors.onSurfaceVariant,
        null,
        l.budgetsAmountLeft(money(line.remainingMinor)),
      ),
    };
    final rollover = line.rolloverMinor;
    final rolloverLabel = rollover == 0
        ? null
        : rollover > 0
        ? l.budgetsInclRolledOver(money(rollover))
        : l.budgetsInclOverspentCarried(money(-rollover));
    final planned = line.plannedMinor;
    final plannedLabel = line.plannedPushesOver
        ? l.budgetsPlannedOver(money(line.projectedOverMinor))
        : planned > 0
        ? l.budgetsPlannedAmount(money(planned))
        : null;
    final plannedColor = line.plannedPushesOver
        ? context.finance.warning
        : context.colors.onSurfaceVariant;
    final window = line.window;
    final windowLabel = window == null
        ? null
        : l.budgetsWindowLabel(
            lengthAdjective(l, line.cadence ?? BudgetCadence.month),
            periodTitle(window, ref.watch(formatLocaleProvider)),
          );
    final semantics = [
      line.name,
      ?windowLabel,
      l.budgetsSpentOf(money(line.spentMinor), money(line.availableMinor)),
      label,
      ?plannedLabel,
      ?rolloverLabel,
      if (line.repeats) l.budgetsRepeatOption,
    ].join(', ');

    return Semantics(
      button: true,
      selected: selected,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? context.colors.secondaryContainer.withValues(alpha: 0.5)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            decoration: divider
                ? BoxDecoration(
                    border: Border(
                      top: BorderSide(color: context.colors.surfaceContainer),
                    ),
                  )
                : null,
            padding: EdgeInsets.fromLTRB(
              line.isRoot ? Space.listInset : Space.listInset + Space.xl,
              10,
              Space.listInset,
              10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(icon: AppIcons.of(line.icon), color: color, size: 36),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Flexible(
                                  child: Text(
                                    line.name,
                                    style: context.text.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (line.repeats) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.repeat,
                                    size: 14,
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          AmountText(
                            line.spentMinor,
                            colored: false,
                            style: context.text.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l.budgetsOfAmount(money(line.availableMinor)),
                            style: context.text.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ProgressBar(
                        value: state == BudgetState.over ? 1 : line.ratio,
                        state: progressStateOf(state),
                        tick: tick,
                        pending: planned > 0 && state != BudgetState.over
                            ? line.projectedRatio - line.ratio
                            : 0,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (icon != null) ...[
                                Icon(icon, size: 14, color: labelColor),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                label,
                                style: context.text.bodySmall?.copyWith(
                                  color: labelColor,
                                  fontWeight: state == BudgetState.onTrack
                                      ? null
                                      : FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          if (plannedLabel != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 13,
                                  color: plannedColor,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  plannedLabel,
                                  style: context.text.bodySmall?.copyWith(
                                    color: plannedColor,
                                    fontWeight: line.plannedPushesOver
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          if (windowLabel != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.date_range_outlined,
                                  size: 13,
                                  color: context.colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  windowLabel,
                                  style: context.text.bodySmall?.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          if (rolloverLabel != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.redo,
                                  size: 13,
                                  color: context.colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  rolloverLabel,
                                  style: context.text.bodySmall?.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
