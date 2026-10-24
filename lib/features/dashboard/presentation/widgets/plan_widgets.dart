import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/money/money.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/budgets/data/budget_providers.dart';
import 'package:personal_finance/features/budgets/domain/budget_math.dart';
import 'package:personal_finance/features/dashboard/data/dashboard_layout.dart';
import 'package:personal_finance/features/dashboard/presentation/dashboard_period.dart';
import 'package:personal_finance/features/dashboard/presentation/widgets/dash_card.dart';
import 'package:personal_finance/features/goals/data/goals_providers.dart';
import 'package:personal_finance/features/recurring/data/recurring_providers.dart';
import 'package:personal_finance/features/transactions/presentation/txn_labels.dart';
import 'package:personal_finance/features/transactions/transactions.dart';

/// Budget progress for the dashboard period: the lines most at risk first.
class BudgetsWidget extends ConsumerWidget {
  const BudgetsWidget({super.key, this.options = const [], this.limit = 4});

  final List<DashOption> options;
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final range = ref.watch(dashboardPeriodProvider);
    final board = ref.watch(budgetBoardProvider(range));
    final fmt = ref.watch(moneyFormatterProvider);
    final lines =
        (board.value?.lines ?? const <BudgetLine>[])
            .where((x) => x.isRoot && x.budgetId != null)
            .toList()
          ..sort((a, b) => b.ratio.compareTo(a.ratio));
    return DashCard(
      type: DashboardWidgetType.budgets,
      title: l.dashBudgets,
      actionLabel: l.dashAllBudgets,
      onAction: () => context.go('/plan?tab=budgets'),
      options: options,
      peek: board.hasValue ? _BudgetsPeek(lines: lines) : null,
      child: board.when(
        loading: () => const SizedBox(height: 96),
        error: (e, _) => Text(l.commonError('$e')),
        data: (summary) {
          if (lines.isEmpty) return const SizedBox.shrink();
          return Column(
            children: [
              for (final line in lines.take(limit))
                _BudgetRow(
                  line: line,
                  tick:
                      line.window?.progressAt(DateTime.now()) ??
                      summary.period.progressAt(DateTime.now()),
                  fmtAvailable: fmt.format(
                    Money(line.availableMinor),
                    cents: false,
                  ),
                  fmtOver: fmt.format(Money(line.overMinor)),
                  fmtPlanned: fmt.format(Money(line.plannedMinor)),
                  onTap: () => context.push(
                    '/plan/budgets/${line.categoryId}?period=${_iso(summary.period.start)}',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// "1 over · 2 near limit · 4 budgets" as badges, or the empty state.
class _BudgetsPeek extends StatelessWidget {
  const _BudgetsPeek({required this.lines});

  final List<BudgetLine> lines;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = context.colors;
    final fin = context.finance;
    if (lines.isEmpty) {
      return Row(
        children: [
          Expanded(child: Text(l.dashNoBudgets, style: context.text.bodySmall)),
          TextButton(
            onPressed: () => context.go('/plan?tab=budgets'),
            child: Text(l.dashSetUpBudgets),
          ),
        ],
      );
    }
    final over = lines.where((x) => x.state == BudgetState.over).length;
    final near = lines.where((x) => x.state == BudgetState.warning).length;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (over > 0)
          StatusBadge(
            l.dashCardBudgetsOver(over),
            background: cs.errorContainer,
            foreground: cs.onErrorContainer,
          ),
        if (near > 0)
          StatusBadge(
            l.dashCardBudgetsNear(near),
            background: fin.warningContainer,
            foreground: fin.onWarningContainer,
          ),
        if (over == 0 && near == 0)
          StatusBadge(
            l.dashCardBudgetsOnTrack,
            background: cs.primaryContainer,
            foreground: cs.onPrimaryContainer,
          ),
        StatusBadge(
          l.dashCardBudgetsCount(lines.length),
          background: cs.surfaceContainerHigh,
          foreground: cs.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.line,
    required this.tick,
    required this.fmtAvailable,
    required this.fmtOver,
    required this.fmtPlanned,
    required this.onTap,
  });

  final BudgetLine line;
  final double tick;
  final String fmtAvailable;
  final String fmtOver;
  final String fmtPlanned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fin = context.finance;
    final cs = context.colors;
    final state = switch (line.state) {
      BudgetState.onTrack => ProgressState.onTrack,
      BudgetState.warning => ProgressState.warning,
      BudgetState.over => ProgressState.over,
    };
    Widget? badge;
    if (line.state == BudgetState.over) {
      badge = StatusBadge(
        l.dashOver(fmtOver),
        background: cs.errorContainer,
        foreground: cs.onErrorContainer,
      );
    } else if (line.state == BudgetState.warning) {
      badge = StatusBadge(
        '${line.percentUsed}%',
        background: fin.warningContainer,
        foreground: fin.onWarningContainer,
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    line.name,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (badge != null) ...[const SizedBox(width: 8), badge],
                const Spacer(),
                AmountText(
                  line.spentMinor,
                  colored: false,
                  style: context.text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  ' ${l.dashOf(fmtAvailable)}',
                  style: context.text.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Semantics(
              // The striped part of the bar, in words.
              label: line.plannedMinor > 0
                  ? l.budgetsPlannedAmount(fmtPlanned)
                  : null,
              child: ProgressBar(
                value: line.ratio,
                state: state,
                tick: tick,
                pending: line.plannedMinor > 0 && line.state != BudgetState.over
                    ? line.projectedRatio - line.ratio
                    : 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Upcoming recurring items (Settings › Dashboard › upcoming window).
class UpcomingBillsWidget extends ConsumerWidget {
  const UpcomingBillsWidget({
    super.key,
    this.options = const [],
    this.limit = 4,
  });

  final List<DashOption> options;
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final days = ref.watch(
      settingsProvider.select((s) => s.get(DashboardSettings.upcomingDays)),
    );
    final upcoming = ref.watch(upcomingOccurrencesProvider(days));
    final dates = ref.watch(dateFormatsProvider);
    final cs = context.colors;
    final open = (upcoming.value ?? const [])
        .where((o) => !o.isPosted)
        .toList();
    return DashCard(
      type: DashboardWidgetType.upcomingBills,
      title: l.dashUpcoming,
      subtitle: l.dashNextDays(days),
      actionLabel: l.dashCalendar,
      onAction: () => context.push('/plan/calendar'),
      options: options,
      peek: !upcoming.hasValue
          ? null
          : open.isEmpty
          ? Text(l.dashNoUpcoming(days), style: context.text.bodySmall)
          : PeekText(
              '${l.dashCardUpcomingNext(open.first.name, dates.dayHeader(open.first.date))}'
              ' · ${l.dashCardUpcomingDue(open.length, days)}',
            ),
      child: upcoming.when(
        loading: () => const SizedBox(height: 96),
        error: (e, _) => Text(l.commonError('$e')),
        data: (_) {
          if (open.isEmpty) return const SizedBox.shrink();
          return Column(
            children: [
              for (final (i, o) in open.take(limit).indexed)
                InkWell(
                  onTap: () => context.push('/plan/recurring/${o.ruleId}'),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      border: i == 0
                          ? null
                          : Border(
                              top: BorderSide(color: cs.surfaceContainerHigh),
                            ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: o.isOverdue
                                ? context.finance.warningContainer
                                : cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                dates.weekdayShort(o.date),
                                style: context.text.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurfaceVariant,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${o.date.day}',
                                style: context.text.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                o.name,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                [
                                  if (o.account != null) o.account!.name,
                                  if (o.postingMode == PostingMode.autoPost)
                                    l.dashAutoPost
                                  else
                                    l.dashConfirmDaysBefore(
                                      o.plan.remindDaysBefore,
                                    ),
                                ].join(' · '),
                                overflow: TextOverflow.ellipsis,
                                style: context.text.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w400,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AmountText(
                          o.amountMinor,
                          type: o.type,
                          style: context.text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Savings goals with progress.
class GoalsWidget extends ConsumerWidget {
  const GoalsWidget({super.key, this.options = const [], this.limit = 3});

  final List<DashOption> options;
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final goals = ref.watch(goalsProgressProvider);
    final fmt = ref.watch(moneyFormatterProvider);
    final dates = ref.watch(dateFormatsProvider);
    final all = goals.value ?? const [];
    // The goal closest to its target (not yet reached), else the first.
    final open = all.where((g) => g.fraction < 1).toList()
      ..sort((a, b) => b.fraction.compareTo(a.fraction));
    final nearest = open.isNotEmpty ? open.first : all.firstOrNull;
    return DashCard(
      type: DashboardWidgetType.goals,
      title: l.dashGoals,
      actionLabel: l.dashViewAll,
      onAction: () => context.go('/plan?tab=goals'),
      options: options,
      peek: !goals.hasValue
          ? null
          : nearest == null
          ? Text(l.dashNoGoals, style: context.text.bodySmall)
          : PeekText(
              '${l.dashCardGoalsCount(all.length)} · ${nearest.name} '
              '${(nearest.fraction * 100).clamp(0, 999).round()}%',
            ),
      child: goals.when(
        loading: () => const SizedBox(height: 96),
        error: (e, _) => Text(l.commonError('$e')),
        data: (list) {
          if (list.isEmpty) return const SizedBox.shrink();
          return Column(
            children: [
              for (final g in list.take(limit))
                InkWell(
                  onTap: () => context.push('/plan/goals/${g.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                g.name,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${(g.fraction * 100).clamp(0, 999).round()}%',
                              style: context.text.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ProgressBar(
                          value: g.fraction,
                          color: context.colors.primary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            '${fmt.format(Money(g.savedMinor), cents: false)} / ${fmt.format(Money(g.targetMinor), cents: false)}',
                            if (g.projection.projectedDate != null)
                              dates.monthYear(g.projection.projectedDate!),
                          ].join(' · '),
                          style: context.text.labelMedium?.copyWith(
                            fontWeight: FontWeight.w400,
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The latest transactions.
class RecentTransactionsWidget extends ConsumerWidget {
  const RecentTransactionsWidget({
    super.key,
    this.options = const [],
    this.limit = 5,
  });

  final List<DashOption> options;
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final recent = ref.watch(recentTransactionsProvider(limit));
    final latest = recent.value?.firstOrNull;
    final latestTitle = latest == null
        ? null
        : TxnLabels.title(
            l,
            latest,
            accounts: ref.watch(accountMapProvider),
            categories: ref.watch(categoryMapProvider),
          );
    return DashCard(
      type: DashboardWidgetType.recentTransactions,
      title: l.dashRecent,
      actionLabel: l.dashViewAll,
      onAction: () => context.go('/transactions'),
      options: options,
      peek: !recent.hasValue
          ? null
          : latest == null
          ? Text(l.dashWelcomeEmpty, style: context.text.bodySmall)
          : PeekText(
              '${l.dashCardLatest(latestTitle!)} · ${PeekText.slot()} · '
              '${ref.watch(dateFormatsProvider).dayHeader(latest.date)}',
              amounts: [latest.amountMinor],
            ),
      child: recent.when(
        loading: () => const SizedBox(height: 120),
        error: (e, _) => Text(l.commonError('$e')),
        data: (items) => items.isEmpty
            ? const SizedBox.shrink()
            : Column(
                children: [
                  for (final (i, item) in items.indexed)
                    TransactionTile(
                      item: item,
                      showDate: true,
                      divider: i > 0,
                      inset: 0,
                      onTap: () => context.push('/transactions/${item.id}'),
                    ),
                ],
              ),
      ),
    );
  }
}
