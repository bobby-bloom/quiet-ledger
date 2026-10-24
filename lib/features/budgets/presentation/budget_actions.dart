import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/app_icons.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/features/budgets/data/budget_period_provider.dart';
import 'package:personal_finance/features/budgets/data/budget_providers.dart';
import 'package:personal_finance/features/budgets/data/budgets_repository.dart';
import 'package:personal_finance/features/budgets/domain/budget_math.dart';
import 'package:personal_finance/features/plan/presentation/money_text.dart';

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
  final existing =
      (await ref.read(budgetsRepositoryProvider).period(period.start))
          .where((b) => b.categoryId == id)
          .firstOrNull;
  if (!context.mounted) return;
  final r = await showBudgetAmountDialog(
    context,
    title: cat?.name ?? '',
    initialMinor: existing?.amountMinor,
    allowRemove: existing != null,
  );
  if (r == null) return;
  await ref
      .read(budgetsRepositoryProvider)
      .setAmount(id, period.start, r.amount);
}

/// Edits (or removes) the budget of [line].
Future<void> editBudgetAmount(
  BuildContext context,
  WidgetRef ref,
  DateRange period,
  BudgetLine line,
) async {
  final r = await showBudgetAmountDialog(
    context,
    title: line.name,
    initialMinor: line.budgetedMinor,
    allowRemove: true,
  );
  if (r == null) return;
  await ref
      .read(budgetsRepositoryProvider)
      .setAmount(line.categoryId, period.start, r.amount);
}

/// Asks for a budget amount. Returns null when cancelled; `amount: null`
/// means "remove the budget".
Future<({int? amount})?> showBudgetAmountDialog(
  BuildContext context, {
  required String title,
  int? initialMinor,
  bool allowRemove = false,
}) {
  return showDialog<({int? amount})>(
    context: context,
    builder: (ctx) => _AmountDialog(
      title: title,
      initialMinor: initialMinor,
      allowRemove: allowRemove,
    ),
  );
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({
    required this.title,
    required this.allowRemove,
    this.initialMinor,
  });

  final String title;
  final int? initialMinor;
  final bool allowRemove;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _form = GlobalKey<FormState>();
  late int? _amount = widget.initialMinor;

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.pop(context, (amount: _amount ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _form,
        child: MoneyField(
          autofocus: true,
          label: l.budgetsAmountLabel,
          initialMinor: widget.initialMinor,
          onChanged: (v) => _amount = v,
          validator: (v) => v == null || v < 0 ? l.budgetsAmountInvalid : null,
        ),
      ),
      actions: [
        if (widget.allowRemove)
          TextButton(
            onPressed: () => Navigator.pop(context, (amount: null)),
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
