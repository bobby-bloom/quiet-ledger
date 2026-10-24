import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/app_icons.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/budgets/data/budget_period_provider.dart';
import 'package:personal_finance/features/budgets/data/budget_providers.dart';
import 'package:personal_finance/features/budgets/data/budgets_repository.dart';
import 'package:personal_finance/features/budgets/domain/budget_math.dart';
import 'package:personal_finance/features/budgets/domain/budget_rules.dart';
import 'package:personal_finance/features/plan/plan_providers.dart';
import 'package:personal_finance/features/plan/presentation/money_text.dart';
import 'package:personal_finance/features/plan/presentation/plan_widgets.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void _snack(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

Future<bool> _confirmOverwrite(
  BuildContext context,
  WidgetRef ref,
  DateRange period,
) async {
  final existing = await ref
      .read(budgetsRepositoryProvider)
      .period(period.start);
  if (existing.isEmpty || !context.mounted) return true;
  return await confirmDialog(
    context,
    title: context.l10n.budgetsOverwriteTitle,
    message: context.l10n.budgetsOverwriteMessage,
    confirmLabel: context.l10n.budgetsOverwriteConfirm,
    destructive: false,
  );
}

/// Copies the previous period's amounts into [period].
Future<void> copyPreviousPeriod(
  BuildContext context,
  WidgetRef ref,
  DateRange period,
) async {
  final l = context.l10n;
  final repo = ref.read(budgetsRepositoryProvider);
  final prev = ref.read(budgetPeriodsProvider).previous(period);
  if ((await repo.period(prev.start)).isEmpty) {
    if (context.mounted) _snack(context, l.budgetsNothingToCopy);
    return;
  }
  if (!context.mounted || !await _confirmOverwrite(context, ref, period)) {
    return;
  }
  final n = await repo.copyPeriod(prev, period);
  if (context.mounted) _snack(context, l.budgetsFilledCount(n));
}

/// Fills [period] from the average spending of the [n] previous periods.
Future<void> fillFromAverage(
  BuildContext context,
  WidgetRef ref,
  DateRange period,
  int n,
) async {
  final l = context.l10n;
  if (!await _confirmOverwrite(context, ref, period)) return;
  final count = await ref
      .read(budgetsRepositoryProvider)
      .fillFromAverage(ref.read(budgetPeriodsProvider), period, n);
  if (!context.mounted) return;
  _snack(
    context,
    count == 0 ? l.budgetsNoSpendingHistory : l.budgetsFilledCount(count),
  );
}

/// Picks an expense category and sets its budget.
Future<void> addBudget(
  BuildContext context,
  WidgetRef ref,
  DateRange period,
) async {
  final id = await showCategoryPicker(context, kind: CategoryKind.expense);
  if (id == null || id.isEmpty || !context.mounted) return;
  final cat = ref.read(categoryMapProvider)[id];
  await editCategoryBudget(context, ref, period, id, name: cat?.name ?? '');
}

/// Edits (or removes) the budget of [line].
Future<void> editBudgetAmount(
  BuildContext context,
  WidgetRef ref,
  DateRange period,
  BudgetLine line,
) => editCategoryBudget(context, ref, period, line.categoryId, name: line.name);

/// What a budget edit applies to: a budget period, or one window of a
/// budget with its own length.
typedef BudgetSlot = ({DateRange range, BudgetCadence cadence});

/// The budget of [categoryId] the board of [period] shows: its budget of
/// the period, else its window budget for the period, else a new budget of
/// the period. Returns the slot and the row (null for a new budget).
Future<(BudgetSlot, Budget?)> budgetSlotFor(
  BudgetsRepository repo,
  BudgetPeriods periods,
  DateRange period,
  String categoryId,
  DateTime today,
) async {
  final row = (await repo.period(period.start))
      .where((b) => b.categoryId == categoryId)
      .firstOrNull;
  if (row != null) return ((range: period, cadence: BudgetCadence.period), row);
  final windows = [
    for (final b in await repo.windows(period))
      if (b.categoryId == categoryId) b,
  ];
  final w = pickBoardWindows(windows, period, today)[categoryId];
  if (w == null) {
    return ((range: period, cadence: BudgetCadence.period), null);
  }
  final range = DateRange(w.periodStart, w.periodEnd!);
  return (
    (
      range: range,
      cadence: cadenceOfWindow(periods, range) ?? BudgetCadence.month,
    ),
    w,
  );
}

/// The first window of a budget with length [cadence] when it starts in
/// the board period [period] (the one containing the period's first day),
/// or [period] itself.
DateRange slotRangeFor(
  BudgetPeriods periods,
  DateRange period,
  BudgetCadence cadence,
) => cadence == BudgetCadence.period
    ? period
    : windowPeriods(periods, cadence).periodOf(period.start);

/// Sets, changes or removes the budget of [categoryId] shown in [period]
/// through the amount dialog, including its length and how it repeats.
/// Changing or removing a repeating budget asks whether it applies to this
/// period (window) only or to this and the following ones. A new length
/// starts with the window containing the period's first day.
Future<void> editCategoryBudget(
  BuildContext context,
  WidgetRef ref,
  DateRange period,
  String categoryId, {
  required String name,
}) async {
  final l = context.l10n;
  final repo = ref.read(budgetsRepositoryProvider);
  final periods = ref.read(budgetPeriodsProvider);
  final today = ref.read(planTodayProvider);
  final (slot, row) = await budgetSlotFor(
    repo,
    periods,
    period,
    categoryId,
    today,
  );
  final windowed = slot.cadence != BudgetCadence.period;
  final rule = ruleFor(
    await repo.rules(),
    periods,
    categoryId,
    slot.range.start,
    windowed: windowed,
  );
  if (!context.mounted) return;
  // A count is shown as what is left from this period on.
  final current = rule == null
      ? (row == null
            ? const BudgetRepeat.everyPeriod()
            : BudgetRepeat.single(cadence: slot.cadence))
      : rule.count == null
      ? rule.repeat
      : BudgetRepeat.forPeriods(
          rule.remainingCountFrom(periods, slot.range.start)!,
          every: rule.every,
          cadence: rule.cadence,
        );
  final r = await showBudgetAmountDialog(
    context,
    title: name,
    periodType: periods.config.type,
    rangeFor: (c) =>
        c == slot.cadence ? slot.range : slotRangeFor(periods, period, c),
    initialMinor: row?.amountMinor ?? rule?.amountMinor,
    initialRepeat: current,
    allowRemove: row != null,
  );
  if (r == null || !context.mounted) return;
  final amount = r.amount;

  Future<List<String>> removeSlot() => windowed
      ? repo.removeWindow(periods, categoryId, slot.range)
      : repo.removeFromPeriod(periods, categoryId, slot.range);

  if (amount == null) {
    var following = false;
    if (rule != null) {
      final scope = await _askScope(context, remove: true);
      if (scope == null) return;
      following = scope;
    }
    final removed = <String>[
      if (following) ...await repo.stopRepeating(categoryId, slot.range.start),
      ...await removeSlot(),
    ];
    if (!context.mounted || following || removed.isEmpty) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.budgetsRemoved(name)),
          action: SnackBarAction(
            label: l.commonUndo,
            onPressed: () => unawaited(repo.restoreBudgets(removed)),
          ),
        ),
      );
    return;
  }

  final repeat = r.repeat;
  final sameLength = repeat.cadence == slot.cadence;
  final target = sameLength
      ? slot.range
      : slotRangeFor(periods, period, repeat.cadence);
  Future<void> repeatFromTarget() => repo.repeatFrom(
    periods: periods,
    categoryId: categoryId,
    from: target,
    amountMinor: amount,
    repeat: repeat,
  );
  Future<void> setOnce(DateRange range, BudgetCadence cadence) =>
      cadence == BudgetCadence.period
      ? repo.setAmount(categoryId, range.start, amount)
      : repo.setWindowAmount(categoryId, range, amount);

  if (repeat.repeats && (rule == null || repeat != current)) {
    // New repeat setting or length: applies from here on.
    await repeatFromTarget();
    return;
  }
  if (!repeat.repeats && (rule == null || repeat != current)) {
    // Just this one: the old budget ends with it or is replaced.
    if (rule != null) {
      await repo.stopRepeating(
        categoryId,
        sameLength ? slot.range.end : slot.range.start,
      );
    }
    if (!sameLength && row != null) await removeSlot();
    await setOnce(target, repeat.cadence);
    return;
  }
  if (amount == row?.amountMinor) return;
  final following = await _askScope(context, remove: false);
  if (following == null) return;
  if (following) {
    await repeatFromTarget();
  } else {
    await setOnce(slot.range, slot.cadence);
  }
}

/// "Only this period" (false) or "This and following periods" (true);
/// null when cancelled.
Future<bool?> _askScope(BuildContext context, {required bool remove}) {
  final l = context.l10n;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(
        remove ? l.budgetsScopeRemoveTitle : l.budgetsScopeChangeTitle,
      ),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.budgetsScopeThis),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.budgetsScopeFollowing),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.lg, 0),
          child: Text(
            l.budgetsScopeHint,
            style: ctx.text.bodySmall?.copyWith(
              color: ctx.colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}

/// "every month", "every 2 weeks", "every period", ...
String everyText(AppLocalizations l, BudgetCadence cadence, int every) =>
    switch (cadence) {
      BudgetCadence.period => l.budgetsEveryN(every),
      BudgetCadence.week => l.budgetsEveryWeek(every),
      BudgetCadence.month => l.budgetsEveryMonth(every),
      BudgetCadence.quarter => l.budgetsEveryQuarter(every),
      BudgetCadence.year => l.budgetsEveryYear(every),
    };

/// "Weekly", "Monthly", ... (the adjective of a budget's own length).
String lengthAdjective(AppLocalizations l, BudgetCadence cadence) =>
    switch (cadence) {
      BudgetCadence.period || BudgetCadence.month => l.setOptMonthly,
      BudgetCadence.week => l.setOptWeekly,
      BudgetCadence.quarter => l.setOptQuarterly,
      BudgetCadence.year => l.setOptYearly,
    };

/// "Repeats every period from November 2026" and friends; [periodLabel]
/// names the first period (window).
String repeatSummary(
  AppLocalizations l,
  BudgetRepeat repeat,
  String periodLabel,
  String Function(DateTime) date,
) {
  final every = everyText(l, repeat.cadence, repeat.every);
  return switch (repeat.kind) {
    BudgetRepeatKind.once =>
      repeat.windowed ? l.budgetsOnlyIn(periodLabel) : l.budgetsRepeatOnce,
    BudgetRepeatKind.every => l.budgetsRepeatsEvery(every, periodLabel),
    BudgetRepeatKind.count => l.budgetsRepeatsCount(
      repeat.count ?? 1,
      every,
      periodLabel,
    ),
    BudgetRepeatKind.until => l.budgetsRepeatsUntil(
      every,
      periodLabel,
      date(repeat.until!),
    ),
  };
}

/// Asks for a budget amount, its length and how it repeats. [rangeFor]
/// gives the first period (window) for a length, [periodType] the budget
/// period type (its own length is offered as "Budget period"). Returns null
/// when cancelled; `amount: null` means "remove the budget".
Future<({int? amount, BudgetRepeat repeat})?> showBudgetAmountDialog(
  BuildContext context, {
  required String title,
  required BudgetPeriodType periodType,
  required DateRange Function(BudgetCadence) rangeFor,
  int? initialMinor,
  BudgetRepeat initialRepeat = const BudgetRepeat.everyPeriod(),
  bool allowRemove = false,
}) {
  return showDialog<({int? amount, BudgetRepeat repeat})>(
    context: context,
    builder: (ctx) => _AmountDialog(
      title: title,
      periodType: periodType,
      rangeFor: rangeFor,
      initialMinor: initialMinor,
      initialRepeat: initialRepeat,
      allowRemove: allowRemove,
    ),
  );
}

class _AmountDialog extends ConsumerStatefulWidget {
  const _AmountDialog({
    required this.title,
    required this.periodType,
    required this.rangeFor,
    required this.allowRemove,
    required this.initialRepeat,
    this.initialMinor,
  });

  final String title;
  final BudgetPeriodType periodType;
  final DateRange Function(BudgetCadence) rangeFor;
  final int? initialMinor;
  final BudgetRepeat initialRepeat;
  final bool allowRemove;

  @override
  ConsumerState<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends ConsumerState<_AmountDialog> {
  final _form = GlobalKey<FormState>();
  late int? _amount = widget.initialMinor;
  late BudgetRepeatKind _kind = widget.initialRepeat.kind;
  late BudgetCadence _cadence = widget.initialRepeat.cadence;
  late int _every = widget.initialRepeat.every;
  late int _count = widget.initialRepeat.count ?? 3;
  late DateTime _until = widget.initialRepeat.until ?? _defaultUntil();

  DateRange get _range => widget.rangeFor(_cadence);

  DateTime _defaultUntil() {
    final start = widget.rangeFor(widget.initialRepeat.cadence).start;
    return DateTime(start.year + 1, start.month, start.day - 1);
  }

  BudgetRepeat get _repeat => switch (_kind) {
    BudgetRepeatKind.once => BudgetRepeat.single(cadence: _cadence),
    BudgetRepeatKind.every => BudgetRepeat.everyPeriod(
      every: _every,
      cadence: _cadence,
    ),
    BudgetRepeatKind.count => BudgetRepeat.forPeriods(
      _count,
      every: _every,
      cadence: _cadence,
    ),
    BudgetRepeatKind.until => BudgetRepeat.until(
      _until,
      every: _every,
      cadence: _cadence,
    ),
  };

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.pop(context, (amount: _amount ?? 0, repeat: _repeat));
  }

  String? _positive(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    return n == null || n < 1 ? context.l10n.budgetsRepeatNumberInvalid : null;
  }

  Future<void> _pickUntil() async {
    final first = _range.start;
    final d = await showDatePicker(
      context: context,
      initialDate: _until.isBefore(first) ? first : _until,
      firstDate: first,
      lastDate: DateTime(first.year + 50),
    );
    if (d != null) setState(() => _until = d);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dates = ref.watch(dateFormatsProvider);
    final locale = ref.watch(formatLocaleProvider);
    final repeats = _kind != BudgetRepeatKind.once;
    final sameAsPeriod = cadenceOfPeriodType(widget.periodType);
    final typeLabel = switch (widget.periodType) {
      BudgetPeriodType.weekly => l.setOptWeekly,
      BudgetPeriodType.biWeekly => l.setOptBiWeekly,
      BudgetPeriodType.monthly => l.setOptMonthly,
      BudgetPeriodType.quarterly => l.setOptQuarterly,
      BudgetPeriodType.yearly => l.setOptYearly,
    };
    final lengths = [
      (BudgetCadence.period, l.budgetsLengthPeriod(typeLabel)),
      (BudgetCadence.week, l.budgetsLengthWeek),
      (BudgetCadence.month, l.budgetsLengthMonth),
      (BudgetCadence.quarter, l.budgetsLengthQuarter),
      (BudgetCadence.year, l.budgetsLengthYear),
    ].where((e) => e.$1 != sameAsPeriod || e.$1 == _cadence);
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MoneyField(
                autofocus: true,
                label: l.budgetsAmountLabel,
                initialMinor: widget.initialMinor,
                onChanged: (v) => _amount = v,
                validator: (v) =>
                    v == null || v < 0 ? l.budgetsAmountInvalid : null,
              ),
              const SizedBox(height: Space.md),
              DropdownButtonFormField<BudgetCadence>(
                key: const ValueKey('budget-length'),
                initialValue: _cadence,
                decoration: InputDecoration(labelText: l.budgetsLength),
                items: [
                  for (final (c, label) in lengths)
                    DropdownMenuItem(value: c, child: Text(label)),
                ],
                onChanged: (c) => setState(() => _cadence = c ?? _cadence),
              ),
              const SizedBox(height: Space.sm),
              DropdownButtonFormField<BudgetRepeatKind>(
                key: const ValueKey('budget-repeat'),
                initialValue: _kind,
                decoration: InputDecoration(labelText: l.budgetsRepeat),
                items: [
                  for (final (k, label) in [
                    (BudgetRepeatKind.once, l.budgetsRepeatOnce),
                    (BudgetRepeatKind.every, l.budgetsRepeatEvery),
                    (BudgetRepeatKind.count, l.budgetsRepeatCount),
                    (BudgetRepeatKind.until, l.budgetsRepeatUntil),
                  ])
                    DropdownMenuItem(value: k, child: Text(label)),
                ],
                onChanged: (k) => setState(() => _kind = k ?? _kind),
              ),
              if (repeats) ...[
                const SizedBox(height: Space.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('budget-repeat-every'),
                        initialValue: '$_every',
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l.budgetsRepeatInterval,
                        ),
                        validator: _positive,
                        onChanged: (v) => setState(
                          () => _every = int.tryParse(v.trim()) ?? _every,
                        ),
                      ),
                    ),
                    if (_kind == BudgetRepeatKind.count) ...[
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: TextFormField(
                          key: const ValueKey('budget-repeat-count'),
                          initialValue: '$_count',
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l.budgetsRepeatPeriods,
                          ),
                          validator: _positive,
                          onChanged: (v) => setState(
                            () => _count = int.tryParse(v.trim()) ?? _count,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_kind == BudgetRepeatKind.until)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        l.budgetsRepeatUntilDate(dates.short(_until)),
                      ),
                      onPressed: _pickUntil,
                    ),
                  ),
              ],
              const SizedBox(height: Space.xs),
              Text(
                repeatSummary(
                  l,
                  _repeat,
                  periodTitle(_range, locale),
                  dates.short,
                ),
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.allowRemove)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, (amount: null, repeat: _repeat)),
            child: Text(l.budgetsRemove),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l.commonSave)),
      ],
    );
  }
}

enum _FillAction {
  copyPrevious,
  average3,
  average6,
  average12,
  template,
  saveTemplate,
  repeatAll,
  editAll,
  clear,
}

/// "Fill" menu of the budgets board: copy, averages, templates, bulk edit.
class BudgetFillMenu extends ConsumerWidget {
  const BudgetFillMenu({
    required this.period,
    required this.hasBudgets,
    super.key,
  });

  final DateRange period;
  final bool hasBudgets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    PopupMenuItem<_FillAction> item(
      _FillAction a,
      IconData icon,
      String text,
    ) => PopupMenuItem(
      value: a,
      child: ListTile(
        leading: Icon(icon),
        title: Text(text),
        contentPadding: EdgeInsets.zero,
      ),
    );
    return PopupMenuButton<_FillAction>(
      tooltip: l.budgetsFillMenu,
      onSelected: (a) => _run(context, ref, a),
      itemBuilder: (_) => [
        item(
          _FillAction.copyPrevious,
          Icons.copy_all_outlined,
          l.budgetsCopyPrevious,
        ),
        item(_FillAction.average3, Icons.functions, l.budgetsFromAverage(3)),
        item(_FillAction.average6, Icons.functions, l.budgetsFromAverage(6)),
        item(_FillAction.average12, Icons.functions, l.budgetsFromAverage(12)),
        item(
          _FillAction.template,
          Icons.bookmarks_outlined,
          l.budgetsFromTemplate,
        ),
        if (hasBudgets) ...[
          const PopupMenuDivider(),
          item(
            _FillAction.saveTemplate,
            Icons.bookmark_add_outlined,
            l.budgetsSaveTemplate,
          ),
          item(_FillAction.repeatAll, Icons.repeat, l.budgetsRepeatAll),
          item(_FillAction.editAll, Icons.edit_note, l.budgetsEditAll),
          item(
            _FillAction.clear,
            Icons.delete_sweep_outlined,
            l.budgetsClearPeriod,
          ),
        ] else
          item(_FillAction.editAll, Icons.edit_note, l.budgetsEditAll),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.sm,
          vertical: Space.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_motion_outlined,
              size: 18,
              color: context.colors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              l.budgetsFillMenu,
              style: context.text.labelLarge?.copyWith(
                color: context.colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref, _FillAction a) async {
    final l = context.l10n;
    switch (a) {
      case _FillAction.copyPrevious:
        await copyPreviousPeriod(context, ref, period);
      case _FillAction.average3:
        await fillFromAverage(context, ref, period, 3);
      case _FillAction.average6:
        await fillFromAverage(context, ref, period, 6);
      case _FillAction.average12:
        await fillFromAverage(context, ref, period, 12);
      case _FillAction.template:
        final id = await showAdaptiveSheet<String>(
          context,
          builder: (_) => const _TemplatePicker(),
        );
        if (id == null || !context.mounted) return;
        if (!await _confirmOverwrite(context, ref, period)) return;
        final n = await ref
            .read(budgetsRepositoryProvider)
            .applyTemplate(id, period.start);
        if (context.mounted) _snack(context, l.budgetsFilledCount(n));
      case _FillAction.saveTemplate:
        final name = await _askTemplateName(context);
        if (name == null) return;
        await ref
            .read(budgetsRepositoryProvider)
            .saveTemplate(name, period.start);
        if (context.mounted) _snack(context, l.budgetsTemplateSaved(name));
      case _FillAction.repeatAll:
        final n = await ref
            .read(budgetsRepositoryProvider)
            .repeatPeriod(ref.read(budgetPeriodsProvider), period);
        if (context.mounted) _snack(context, l.budgetsRepeatAllDone(n));
      case _FillAction.editAll:
        await showAdaptiveSheet<void>(
          context,
          maxWidth: 640,
          builder: (_) => BulkBudgetEditor(period: period),
        );
      case _FillAction.clear:
        final ok = await confirmDialog(
          context,
          title: l.budgetsClearPeriodTitle,
          message: l.budgetsClearPeriodMessage,
        );
        if (ok) {
          await ref.read(budgetsRepositoryProvider).clearPeriod(period.start);
        }
    }
  }
}

Future<String?> _askTemplateName(BuildContext context) {
  final l = context.l10n;
  final c = TextEditingController();
  final form = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.budgetsSaveTemplate),
      content: Form(
        key: form,
        child: TextFormField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(labelText: l.budgetsTemplateName),
          validator: (v) => v == null || v.trim().isEmpty
              ? l.budgetsTemplateNameRequired
              : null,
          onFieldSubmitted: (_) {
            if (form.currentState?.validate() ?? false) {
              Navigator.pop(ctx, c.text.trim());
            }
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState?.validate() ?? false) {
              Navigator.pop(ctx, c.text.trim());
            }
          },
          child: Text(l.commonSave),
        ),
      ],
    ),
  ).whenComplete(c.dispose);
}

class _TemplatePicker extends ConsumerWidget {
  const _TemplatePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final templates = ref.watch(budgetTemplatesProvider);
    final money = moneyText(ref);
    return Column(
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
          child: Text(l.budgetsFromTemplate, style: context.text.titleLarge),
        ),
        Flexible(
          child: AsyncView(
            value: templates,
            data: (list) => list.isEmpty
                ? EmptyState(
                    icon: Icons.bookmarks_outlined,
                    message: l.budgetsNoTemplates,
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final t in list)
                        Builder(
                          builder: (context) {
                            final items = BudgetTemplateItem.decodeList(
                              t.items,
                            );
                            final total = items.fold(
                              0,
                              (a, i) => a + i.amountMinor,
                            );
                            return ListTile(
                              leading: const Icon(Icons.bookmark_outline),
                              title: Text(t.name),
                              subtitle: Text(
                                l.budgetsTemplateSummary(
                                  items.length,
                                  money(total),
                                ),
                              ),
                              onTap: () => Navigator.pop(context, t.id),
                              trailing: IconButton(
                                tooltip: l.commonDelete,
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  final ok = await confirmDialog(
                                    context,
                                    title: l.commonDeleteConfirm(t.name),
                                  );
                                  if (ok) {
                                    await ref
                                        .read(budgetsRepositoryProvider)
                                        .deleteTemplate(t.id);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: Space.md),
      ],
    );
  }
}

/// Bulk edit of all expense category budgets of a period.
class BulkBudgetEditor extends ConsumerStatefulWidget {
  const BulkBudgetEditor({required this.period, super.key});

  final DateRange period;

  @override
  ConsumerState<BulkBudgetEditor> createState() => _BulkBudgetEditorState();
}

class _BulkBudgetEditorState extends ConsumerState<BulkBudgetEditor> {
  final Map<String, int?> _edits = {};
  Map<String, int>? _initial;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitial());
  }

  Future<void> _loadInitial() async {
    final rows = await ref
        .read(budgetsRepositoryProvider)
        .period(widget.period.start);
    if (mounted) {
      setState(
        () => _initial = {for (final r in rows) r.categoryId: r.amountMinor},
      );
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final changes = <String, int?>{};
    for (final e in _edits.entries) {
      final before = _initial?[e.key];
      final after = e.value == null || e.value == 0 ? null : e.value;
      if (before != after) changes[e.key] = after;
    }
    await ref
        .read(budgetsRepositoryProvider)
        .setAmounts(widget.period.start, changes);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final initial = _initial;
    final all = ref.watch(categoriesProvider).value ?? const <Category>[];
    final tree = categoryTree(all, kind: CategoryKind.expense);
    final money = moneyText(ref);
    final total = <String, int>{...?initial};
    for (final e in _edits.entries) {
      if (e.value == null || e.value == 0) {
        total.remove(e.key);
      } else {
        total[e.key] = e.value!;
      }
    }
    var sum = 0;
    for (final (parent, children) in tree) {
      final p = total[parent.id];
      if (p != null) {
        sum += p;
      } else {
        for (final c in children) {
          sum += total[c.id] ?? 0;
        }
      }
    }
    Widget row(Category c, {required bool child}) => Padding(
      padding: EdgeInsets.fromLTRB(
        child ? Space.xxl + Space.md : Space.xl,
        2,
        Space.xl,
        2,
      ),
      child: Row(
        children: [
          IconTile(
            icon: AppIcons.of(c.icon),
            color: c.color == null ? null : Color(c.color!),
            size: 32,
          ),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(c.name, overflow: TextOverflow.ellipsis)),
          SizedBox(
            width: 140,
            child: MoneyField(
              key: ValueKey('bulk-${c.id}'),
              initialMinor: initial?[c.id],
              label: l.budgetsAmountLabel,
              onChanged: (v) => setState(() => _edits[c.id] = v),
            ),
          ),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, 0),
          child: Text(l.budgetsEditAll, style: context.text.titleLarge),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.xl, 4, Space.xl, Space.xs),
          child: Text(
            l.budgetsBulkTotal(money(sum)),
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        Flexible(
          child: initial == null
              ? const Padding(
                  padding: EdgeInsets.all(Space.xxl),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                )
              : tree.isEmpty
              ? EmptyState(message: l.budgetsNoCategories)
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (parent, children) in tree) ...[
                      row(parent, child: false),
                      for (final c in children) row(c, child: true),
                    ],
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.commonCancel),
              ),
              const SizedBox(width: Space.xs),
              FilledButton(
                onPressed: _saving || initial == null ? null : _save,
                child: Text(l.commonSave),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Maps a budget state to the shared progress bar state.
ProgressState progressStateOf(BudgetState s) => switch (s) {
  BudgetState.onTrack => ProgressState.onTrack,
  BudgetState.warning => ProgressState.warning,
  BudgetState.over => ProgressState.over,
};
