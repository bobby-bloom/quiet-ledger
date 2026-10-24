import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/app_icons.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/calendar/recurrence.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/budgets/data/budget_period_provider.dart';
import 'package:personal_finance/features/budgets/data/budget_providers.dart';
import 'package:personal_finance/features/budgets/data/budgets_repository.dart';
import 'package:personal_finance/features/budgets/domain/budget_math.dart';
import 'package:personal_finance/features/budgets/domain/outstanding.dart';
import 'package:personal_finance/features/budgets/presentation/budget_actions.dart';
import 'package:personal_finance/features/plan/plan_providers.dart';
import 'package:personal_finance/features/plan/presentation/money_text.dart';
import 'package:personal_finance/features/plan/presentation/plan_widgets.dart';
import 'package:personal_finance/features/recurring/data/recurring_repository.dart';
import 'package:personal_finance/features/recurring/data/reminders.dart';
import 'package:personal_finance/features/recurring/domain/recurring_logic.dart';

/// Transactions and split lines of a category (with children) in a period.
final categoryPeriodLinesProvider = StreamProvider.autoDispose
    .family<List<BudgetTxnLine>, ({String categoryId, DateRange period})>((
      ref,
      key,
    ) {
      final cats = ref.watch(categoriesProvider).value ?? const <Category>[];
      final ids = {
        key.categoryId,
        for (final c in cats)
          if (c.parentId == key.categoryId) c.id,
      };
      return ref
          .watch(budgetsRepositoryProvider)
          .watchCategoryLines(ids, key.period);
    });

/// Budget vs. spent of a category over the last periods (oldest first).
final categoryBudgetHistoryProvider = FutureProvider.autoDispose
    .family<
      List<({DateRange period, int? budgetMinor, int spentMinor})>,
      ({String categoryId, DateRange period})
    >((ref, key) async {
      final periods = ref.watch(budgetPeriodsProvider);
      final repo = ref.watch(budgetsRepositoryProvider);
      // Refresh with the shown period's data.
      ref.watch(periodActualsProvider(key.period));
      ref.watch(periodBudgetsProvider(key.period.start));
      final cats = await ref.watch(categoriesProvider.future);
      final children = [
        for (final c in cats)
          if (c.parentId == key.categoryId) c.id,
      ];
      final list = <DateRange>[key.period];
      for (var i = 0; i < 5; i++) {
        list.insert(0, periods.previous(list.first));
      }
      return [
        for (final p in list)
          (
            period: p,
            budgetMinor: (await repo.period(p.start))
                .where((b) => b.categoryId == key.categoryId)
                .firstOrNull
                ?.amountMinor,
            spentMinor: (await repo.actuals(p))
                .spentOf(key.categoryId, children),
          ),
      ];
    });

/// '/plan/budgets/:categoryId' — full-screen budget detail with its own
/// period navigation.
class BudgetDetailScreen extends ConsumerStatefulWidget {
  const BudgetDetailScreen({
    required this.categoryId,
    super.key,
    this.periodStart,
  });

  final String categoryId;
  final DateTime? periodStart;

  @override
  ConsumerState<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends ConsumerState<BudgetDetailScreen> {
  late DateTime? _anchor = widget.periodStart;

  @override
  Widget build(BuildContext context) {
    final periods = ref.watch(budgetPeriodsProvider);
    final current = ref.watch(currentBudgetPeriodProvider);
    final period = _anchor == null ? current : periods.periodOf(_anchor!);
    final cat = ref.watch(categoryMapProvider)[widget.categoryId];
    return Scaffold(
      appBar: AppBar(title: Text(cat?.name ?? context.l10n.budgetsTitle)),
      body: ReadableWidth(
        child: Column(
          children: [
            PeriodSwitcher(
              period: period,
              onPrevious: () =>
                  setState(() => _anchor = periods.previous(period).start),
              onNext: () =>
                  setState(() => _anchor = periods.next(period).start),
              onToday: period == current
                  ? null
                  : () => setState(() => _anchor = null),
            ),
            Expanded(
              child: BudgetDetailView(
                categoryId: widget.categoryId,
                period: period,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Budget detail content: progress, rollover, options, history and the
/// period's transactions.
class BudgetDetailView extends ConsumerWidget {
  const BudgetDetailView({
    required this.categoryId,
    required this.period,
    super.key,
    this.embedded = false,
  });

  final String categoryId;
  final DateRange period;

  /// True inside the list-detail pane (shows a title row).
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cat = ref.watch(categoryMapProvider)[categoryId];
    if (cat == null) {
      return EmptyState(message: l.budgetsCategoryMissing);
    }
    final board = ref.watch(budgetBoardProvider(period)).value;
    final actuals = ref.watch(periodActualsProvider(period)).value;
    final planned = ref.watch(periodPlannedProvider(period)).value;
    final settings = ref.watch(settingsProvider);
    final children = [
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        if (c.parentId == categoryId) c.id,
    ];
    final line =
        board?.lineFor(categoryId) ??
        BudgetLine(
          categoryId: categoryId,
          parentId: cat.parentId,
          name: cat.name,
          icon: cat.icon,
          color: cat.color,
          budgetedMinor: 0,
          rolloverMinor: 0,
          spentMinor: actuals?.spentOf(categoryId, children) ?? 0,
          plannedMinor: planned?.spentOf(categoryId, children) ?? 0,
          thresholdPercent: warnThresholdFor(cat, settings),
          rolloverMode: rolloverModeFor(cat, settings),
        );
    final hasBudget = line.budgetId != null;
    final outstanding =
        planned?.itemsFor({categoryId, ...children}) ??
        const <OutstandingItem>[];
    final lines = ref.watch(
      categoryPeriodLinesProvider((categoryId: categoryId, period: period)),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        if (embedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.listInset,
              Space.md,
              Space.listInset,
              0,
            ),
            child: Row(
              children: [
                IconTile(
                  icon: AppIcons.of(cat.icon),
                  color: cat.color == null ? null : Color(cat.color!),
                  size: 36,
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    cat.name,
                    style: context.text.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        _ProgressCard(
          line: line,
          hasBudget: hasBudget,
          tick: board?.todayTick,
          onEdit: () =>
              editCategoryBudget(context, ref, period, cat.id, name: cat.name),
        ),
        _OptionsCard(category: cat, line: line, period: period),
        _HistoryCard(categoryId: categoryId, period: period),
        if (outstanding.isNotEmpty) ...[
          PlanSectionHeader(l.budgetsOutstanding),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.listInset,
              0,
              Space.listInset,
              Space.xxs,
            ),
            child: Text(
              l.budgetsOutstandingHint,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          for (final i in outstanding) _OutstandingRow(item: i),
        ],
        PlanSectionHeader(l.budgetsTransactionsInPeriod),
        AsyncView(
          value: lines,
          data: (list) => list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(Space.xl),
                  child: Text(
                    l.budgetsNoTransactions,
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                )
              : Column(children: [for (final t in list) _TxnRow(line: t)]),
        ),
      ],
    );
  }
}

class _ProgressCard extends ConsumerWidget {
  const _ProgressCard({
    required this.line,
    required this.hasBudget,
    required this.onEdit,
    this.tick,
  });

  final BudgetLine line;
  final bool hasBudget;
  final double? tick;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final money = moneyText(ref);
    final state = line.state;
    final stateLabel = switch (state) {
      BudgetState.over => l.budgetsOverBudget(money(line.overMinor)),
      BudgetState.warning => l.budgetsUsedLeft(
        line.percentUsed,
        money(line.remainingMinor),
      ),
      BudgetState.onTrack => l.budgetsAmountLeft(money(line.remainingMinor)),
    };
    final stateColor = switch (state) {
      BudgetState.over => context.colors.error,
      BudgetState.warning => context.finance.warning,
      BudgetState.onTrack => context.colors.onSurfaceVariant,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Space.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  AmountText(
                    line.spentMinor,
                    colored: false,
                    style: context.text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: Space.xs),
                  Expanded(
                    child: Text(
                      hasBudget
                          ? l.budgetsOfAmount(money(line.availableMinor))
                          : l.budgetsSpentNoBudget,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              if (hasBudget) ...[
                const SizedBox(height: Space.sm),
                ProgressBar(
                  value: state == BudgetState.over ? 1 : line.ratio,
                  state: progressStateOf(state),
                  tick: tick,
                  pending: line.plannedMinor > 0 && state != BudgetState.over
                      ? line.projectedRatio - line.ratio
                      : 0,
                ),
                const SizedBox(height: Space.xs),
                Text(
                  stateLabel,
                  style: context.text.bodyMedium?.copyWith(
                    color: stateColor,
                    fontWeight: state == BudgetState.onTrack
                        ? null
                        : FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Space.sm),
                if (line.plannedMinor > 0)
                  Text(
                    line.plannedPushesOver
                        ? l.budgetsPlannedOver(money(line.projectedOverMinor))
                        : l.budgetsPlannedAmount(money(line.plannedMinor)),
                    style: context.text.bodyMedium?.copyWith(
                      color: line.plannedPushesOver
                          ? context.finance.warning
                          : context.colors.onSurfaceVariant,
                      fontWeight: line.plannedPushesOver
                          ? FontWeight.w700
                          : null,
                    ),
                  ),
                const SizedBox(height: Space.sm),
                _kv(
                  context,
                  l.budgetsBudgetedThisPeriod,
                  money(line.budgetedMinor),
                ),
                if (line.rolloverMinor != 0)
                  _kv(context, l.budgetsCarriedIn, money(line.rolloverMinor)),
                if (line.rolloverMode != RolloverMode.none)
                  _kv(
                    context,
                    l.budgetsRollsOverNext,
                    money(line.nextRolloverMinor),
                  ),
                _kv(context, l.budgetsWarningAt, '${line.thresholdPercent} %'),
              ],
              const SizedBox(height: Space.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  icon: Icon(hasBudget ? Icons.edit_outlined : Icons.add),
                  label: Text(
                    hasBudget ? l.budgetsEditAmount : l.budgetsSetBudget,
                  ),
                  onPressed: onEdit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            k,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          v,
          style: context.text.bodyMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

class _OptionsCard extends ConsumerWidget {
  const _OptionsCard({
    required this.category,
    required this.line,
    required this.period,
  });

  final Category category;
  final BudgetLine line;
  final DateRange period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    final defaultMode = settings.get(BudgetSettings.defaultRollover);
    final override = parseRolloverMode(category.rolloverOverride);
    final globalThreshold = settings.get(BudgetSettings.warnThreshold);
    final repo = ref.read(budgetsRepositoryProvider);
    final rule = line.rule;
    final periods = ref.watch(budgetPeriodsProvider);
    final locale = ref.watch(formatLocaleProvider);
    final dates = ref.watch(dateFormatsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
      child: Card(
        child: Column(
          children: [
            if (rule != null)
              ListTile(
                leading: const Icon(Icons.repeat),
                title: Text(l.budgetsRepeatOption),
                subtitle: Text(
                  repeatSummary(
                    l,
                    rule.repeat,
                    periodTitle(periods.periodOf(rule.start), locale),
                    dates.short,
                  ),
                ),
                trailing: TextButton(
                  onPressed: () => _stopRepeating(context, ref, periods),
                  child: Text(l.budgetsStopRepeating),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.redo),
              title: Text(l.budgetsRolloverOption),
              subtitle: Text(
                override == null
                    ? l.budgetsDefaultValue(rolloverLabel(l, defaultMode))
                    : rolloverLabel(l, override),
              ),
              trailing: PopupMenuButton<String>(
                tooltip: l.budgetsRolloverOption,
                icon: const Icon(Icons.arrow_drop_down),
                onSelected: (m) =>
                    repo.setCategoryRollover(category.id, parseRolloverMode(m)),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: '',
                    child: Text(
                      l.budgetsDefaultValue(rolloverLabel(l, defaultMode)),
                    ),
                  ),
                  for (final m in RolloverMode.values)
                    PopupMenuItem(
                      value: m.name,
                      child: Text(rolloverLabel(l, m)),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.warning_amber_outlined),
              title: Text(l.budgetsThresholdOption),
              subtitle: Text(
                category.warnThresholdOverride == null
                    ? l.budgetsDefaultValue('$globalThreshold %')
                    : '${category.warnThresholdOverride} %',
              ),
              onTap: () async {
                final v = await _askThreshold(
                  context,
                  category.warnThresholdOverride ?? line.thresholdPercent,
                  hasOverride: category.warnThresholdOverride != null,
                );
                if (v == null) return;
                await repo.setCategoryThreshold(category.id, v < 0 ? null : v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _stopRepeating(
    BuildContext context,
    WidgetRef ref,
    BudgetPeriods periods,
  ) async {
    final l = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l.budgetsStopRepeatingTitle(category.name),
      message: l.budgetsStopRepeatingMessage(category.name),
      confirmLabel: l.budgetsStopRepeating,
    );
    if (!ok) return;
    await ref
        .read(budgetsRepositoryProvider)
        .stopRepeating(category.id, periods.next(period).start);
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(l.budgetsStoppedRepeating(category.name))),
    );
  }

  /// Returns the new percent, -1 to reset, or null when cancelled.
  Future<int?> _askThreshold(
    BuildContext context,
    int initial, {
    required bool hasOverride,
  }) {
    final l = context.l10n;
    var value = initial.clamp(1, 100).toDouble();
    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l.budgetsThresholdOption),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${value.round()} %', style: ctx.text.headlineSmall),
              Slider(
                value: value,
                min: 50,
                max: 100,
                divisions: 50,
                label: '${value.round()} %',
                onChanged: (v) => setState(() => value = v),
              ),
            ],
          ),
          actions: [
            if (hasOverride)
              TextButton(
                onPressed: () => Navigator.pop(ctx, -1),
                child: Text(l.commonReset),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, value.round()),
              child: Text(l.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.categoryId, required this.period});

  final String categoryId;
  final DateRange period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final money = moneyText(ref);
    final locale = ref.watch(formatLocaleProvider);
    final history = ref
        .watch(
          categoryBudgetHistoryProvider((
            categoryId: categoryId,
            period: period,
          )),
        )
        .value;
    if (history == null) return const SizedBox.shrink();
    var max = 1;
    for (final h in history) {
      if ((h.budgetMinor ?? 0) > max) max = h.budgetMinor!;
      if (h.spentMinor > max) max = h.spentMinor;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
      child: SectionCard(
        title: l.budgetsHistory,
        child: Column(
          children: [
            for (final h in history)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Semantics(
                  label: l.budgetsHistoryRow(
                    periodTitle(h.period, locale),
                    money(h.spentMinor),
                    h.budgetMinor == null ? '—' : money(h.budgetMinor!),
                  ),
                  excludeSemantics: true,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          periodTitle(h.period, locale),
                          style: context.text.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: ProgressBar(
                          value: h.spentMinor <= 0 ? 0 : h.spentMinor / max,
                          state:
                              h.budgetMinor != null &&
                                  h.spentMinor > h.budgetMinor!
                              ? ProgressState.over
                              : ProgressState.onTrack,
                          tick: h.budgetMinor == null
                              ? null
                              : h.budgetMinor! / max,
                        ),
                      ),
                      const SizedBox(width: Space.xs),
                      SizedBox(
                        width: 96,
                        child: Text(
                          money(h.spentMinor),
                          textAlign: TextAlign.end,
                          style: context.text.bodySmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l.budgetsHistoryLegend,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TxnRow extends ConsumerWidget {
  const _TxnRow({required this.line});

  final BudgetTxnLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final accounts = ref.watch(accountMapProvider);
    final cats = ref.watch(categoryMapProvider);
    final dates = ref.watch(dateFormatsProvider);
    final title = (line.payee?.isNotEmpty ?? false)
        ? line.payee!
        : (line.note?.isNotEmpty ?? false)
        ? line.note!
        : (cats[line.categoryId]?.name ?? '');
    final sub = [
      dates.short(line.date),
      accounts[line.accountId]?.name ?? '',
      if (line.isSplit) l.budgetsSplitLine,
    ].where((s) => s.isNotEmpty).join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.listInset),
      title: Text(title, overflow: TextOverflow.ellipsis),
      subtitle: Text(sub, overflow: TextOverflow.ellipsis),
      trailing: AmountText(line.amountMinor),
      onTap: () => context.push('/transactions/${line.transactionId}'),
    );
  }
}

/// A planned entry or unposted recurring occurrence of the category. Planned
/// entries open the transaction; recurring ones open the rule and, for the
/// rule's next remind & confirm occurrence, offer confirm and skip.
class _OutstandingRow extends ConsumerWidget {
  const _OutstandingRow({required this.item});

  final OutstandingItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final accounts = ref.watch(accountMapProvider);
    final cats = ref.watch(categoryMapProvider);
    final dates = ref.watch(dateFormatsProvider);
    final today = ref.watch(planTodayProvider);
    final calendar = ref.watch(holidayCalendarProvider);
    final plan = item.plan;
    final occurrence = item.occurrence;
    final recurring = item.source == OutstandingSource.recurring;
    final badge = item.overdue
        ? l.budgetsOverdue
        : !recurring
        ? l.statusPlanned
        : item.date == today
        ? l.budgetsDue
        : l.budgetsUpcoming;
    final title = (item.title?.isNotEmpty ?? false)
        ? item.title!
        : (cats[item.categoryId]?.name ?? '');
    final sub = [
      dates.short(item.date),
      accounts[item.accountId]?.name ?? '',
      if (item.isSplit) l.budgetsSplitLine,
    ].where((s) => s.isNotEmpty).join(' · ');
    final canAct =
        recurring &&
        plan != null &&
        occurrence != null &&
        plan.mode == PostingMode.remindConfirm &&
        plan.nextPending(calendar) == occurrence;
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Space.listInset,
          ),
          leading: Icon(
            recurring ? Icons.repeat : Icons.schedule,
            color: colors.onSurfaceVariant,
          ),
          title: Row(
            children: [
              Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: Space.xs),
              StatusBadge(
                badge,
                background: item.overdue
                    ? context.finance.warningContainer
                    : null,
                foreground: item.overdue
                    ? context.finance.onWarningContainer
                    : null,
              ),
            ],
          ),
          subtitle: Text(sub, overflow: TextOverflow.ellipsis),
          trailing: AmountText(item.amountMinor, type: item.type),
          onTap: recurring
              ? (plan == null
                    ? null
                    : () => context.push('/plan/recurring/${plan.id}'))
              : () => context.push('/transactions/${item.transactionId}'),
        ),
        if (canAct)
          Padding(
            padding: const EdgeInsets.only(right: Space.listInset),
            child: Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _skip(context, ref, plan, occurrence),
                  child: Text(l.recurringSkip),
                ),
                FilledButton.tonal(
                  onPressed: () => _confirm(context, ref, plan, occurrence),
                  child: Text(l.commonConfirm),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    RecurringPlan plan,
    Occurrence o,
  ) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(recurringRepositoryProvider).confirm(plan, o);
      await rescheduleRuleReminders(ref.read, plan.id);
      messenger?.showSnackBar(
        SnackBar(content: Text(l.recurringConfirmed(plan.name))),
      );
    } on Object catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l.commonError(e.toString()))),
      );
    }
  }

  Future<void> _skip(
    BuildContext context,
    WidgetRef ref,
    RecurringPlan plan,
    Occurrence o,
  ) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await ref.read(recurringRepositoryProvider).skip(plan, o);
    await rescheduleRuleReminders(ref.read, plan.id);
    messenger?.showSnackBar(
      SnackBar(content: Text(l.recurringSkipped(plan.name))),
    );
  }
}
