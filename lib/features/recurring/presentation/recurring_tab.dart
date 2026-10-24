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
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/plan/presentation/plan_widgets.dart';
import 'package:personal_finance/features/recurring/data/recurring_providers.dart';
import 'package:personal_finance/features/recurring/data/recurring_repository.dart';
import 'package:personal_finance/features/recurring/data/reminders.dart';
import 'package:personal_finance/features/recurring/domain/recurring_logic.dart';
import 'package:personal_finance/features/recurring/domain/schedule_text.dart';
import 'package:personal_finance/features/recurring/presentation/rule_editor_screen.dart';

/// Plan › Recurring: due items (remind & confirm), a 30-day outlook and all
/// rules. On expanded screens the selected rule's editor is shown beside the
/// list.
class RecurringTab extends ConsumerStatefulWidget {
  const RecurringTab({super.key});

  @override
  ConsumerState<RecurringTab> createState() => _RecurringTabState();
}

class _RecurringTabState extends ConsumerState<RecurringTab> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final wide = WindowSize.of(context).isExpanded;
    final list = RecurringList(
      selectedId: wide ? _selected : null,
      onOpen: (id) {
        if (wide) {
          setState(() => _selected = id);
        } else {
          unawaited(context.push('/plan/recurring/$id'));
        }
      },
    );
    if (!wide) return list;
    return ListDetail(
      listWidth: 440,
      list: list,
      detail: _selected == null
          ? EmptyState(
              icon: Icons.event_repeat_outlined,
              message: context.l10n.recurringSelectHint,
            )
          : RuleEditor(
              key: ValueKey(_selected),
              ruleId: _selected,
              embedded: true,
              onDone: () => setState(() => _selected = null),
            ),
    );
  }
}

class RecurringList extends ConsumerWidget {
  const RecurringList({required this.onOpen, super.key, this.selectedId});

  final ValueChanged<String> onOpen;
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final plans = ref.watch(recurringPlansProvider);
    final due = ref.watch(dueOccurrencesProvider).value ?? const <DueItem>[];
    final next = ref.watch(nextOccurrenceProvider).value ?? const {};
    final upcoming =
        ref.watch(upcomingOccurrencesProvider(30)).value ??
        const <UpcomingOccurrence>[];
    final list = plans.value;
    if (list == null) {
      return plans.hasError
          ? Center(child: Text(l.commonError(plans.error.toString())))
          : const Center(child: CircularProgressIndicator.adaptive());
    }
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.event_repeat_outlined,
        message: l.recurringEmpty,
        actionLabel: l.recurringNew,
        onAction: () => context.push('/plan/recurring/new'),
      );
    }
    final active =
        list.where((p) => p.active && next.containsKey(p.id)).toList()
          ..sort((a, b) => next[a.id]!.date.compareTo(next[b.id]!.date));
    final inactive = list
        .where((p) => !p.active || !next.containsKey(p.id))
        .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _OutlookCard(upcoming: upcoming),
        if (due.isNotEmpty) ...[
          PlanSectionHeader(l.recurringDueTitle),
          for (final d in due) _DueTile(item: d),
        ],
        PlanSectionHeader(l.recurringActiveRules(active.length)),
        if (active.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.listInset),
            child: Text(
              l.recurringNoActive,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        for (final p in active)
          RuleTile(
            plan: p,
            next: next[p.id],
            selected: p.id == selectedId,
            onTap: () => onOpen(p.id),
          ),
        if (inactive.isNotEmpty) ...[
          PlanSectionHeader(l.recurringInactiveRules),
          for (final p in inactive)
            RuleTile(
              plan: p,
              next: null,
              selected: p.id == selectedId,
              onTap: () => onOpen(p.id),
            ),
        ],
      ],
    );
  }
}

class _OutlookCard extends ConsumerWidget {
  const _OutlookCard({required this.upcoming});

  final List<UpcomingOccurrence> upcoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    var out = 0;
    var inc = 0;
    for (final u in upcoming) {
      if (u.type == TxnType.transfer) continue;
      if (u.amountMinor < 0) {
        out += -u.amountMinor;
      } else {
        inc += u.amountMinor;
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.recurringNext30Days,
                style: context.text.labelMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Space.xxs),
              Row(
                children: [
                  Expanded(
                    child: Metric(
                      label: l.recurringBills(
                        upcoming
                            .where(
                              (u) =>
                                  u.amountMinor < 0 &&
                                  u.type != TxnType.transfer,
                            )
                            .length,
                      ),
                      value: AmountText(-out, type: TxnType.expense),
                    ),
                  ),
                  Expanded(
                    child: Metric(
                      alignEnd: true,
                      label: l.recurringIncomeCount(
                        upcoming.where((u) => u.type == TxnType.income).length,
                      ),
                      value: AmountText(inc, type: TxnType.income),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Due today", "Overdue by 3 days", "In 2 days".
String dueLabel(BuildContext context, UpcomingOccurrence u) {
  final l = context.l10n;
  final d = u.daysAway;
  if (d == 0) return l.recurringDueToday;
  if (d < 0) return l.recurringOverdueDays(-d);
  return l.recurringDueInDays(d);
}

class _DueTile extends ConsumerWidget {
  const _DueTile({required this.item});

  final DueItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final u = item.occurrence;
    final dates = ref.watch(dateFormatsProvider);
    final overdue = u.isOverdue;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, 4, Space.md, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.sm,
            Space.xs,
            Space.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.name,
                          style: context.text.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          [
                            dueLabel(context, u),
                            dates.dayHeader(u.date),
                            u.account?.name ?? '',
                          ].where((s) => s.isNotEmpty).join(' · '),
                          style: context.text.bodySmall?.copyWith(
                            color: overdue
                                ? context.colors.error
                                : context.colors.onSurfaceVariant,
                            fontWeight: overdue ? FontWeight.w700 : null,
                          ),
                        ),
                        if (item.morePending > 0)
                          Text(
                            l.recurringMorePending(item.morePending),
                            style: context.text.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  AmountText(
                    u.amountMinor,
                    type: u.type,
                    style: context.text.titleSmall,
                  ),
                  const SizedBox(width: Space.xs),
                ],
              ),
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _skip(context, ref, u),
                    child: Text(l.recurringSkip),
                  ),
                  TextButton(
                    onPressed: () => _editConfirm(context, ref, u),
                    child: Text(l.recurringEditConfirm),
                  ),
                  FilledButton.tonal(
                    onPressed: () => _confirm(context, ref, u),
                    child: Text(l.commonConfirm),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    UpcomingOccurrence u, {
    int? amountMinor,
    DateTime? date,
  }) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref
          .read(recurringRepositoryProvider)
          .confirm(u.plan, u.occurrence, amountMinor: amountMinor, date: date);
      await rescheduleRuleReminders(ref.read, u.ruleId);
      messenger?.showSnackBar(
        SnackBar(content: Text(l.recurringConfirmed(u.name))),
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
    UpcomingOccurrence u,
  ) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await ref.read(recurringRepositoryProvider).skip(u.plan, u.occurrence);
    await rescheduleRuleReminders(ref.read, u.ruleId);
    messenger?.showSnackBar(
      SnackBar(content: Text(l.recurringSkipped(u.name))),
    );
  }

  Future<void> _editConfirm(
    BuildContext context,
    WidgetRef ref,
    UpcomingOccurrence u,
  ) async {
    final r = await showDialog<(int, DateTime)>(
      context: context,
      builder: (_) => _EditConfirmDialog(occurrence: u),
    );
    if (r == null || !context.mounted) return;
    await _confirm(
      context,
      ref,
      u,
      amountMinor: signedAmount(u.type, r.$1),
      date: r.$2,
    );
  }
}

class _EditConfirmDialog extends ConsumerStatefulWidget {
  const _EditConfirmDialog({required this.occurrence});

  final UpcomingOccurrence occurrence;

  @override
  ConsumerState<_EditConfirmDialog> createState() => _EditConfirmDialogState();
}

class _EditConfirmDialogState extends ConsumerState<_EditConfirmDialog> {
  final _form = GlobalKey<FormState>();
  late int? _amount = widget.occurrence.amountMinor.abs();
  late DateTime _date = widget.occurrence.date;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dates = ref.watch(dateFormatsProvider);
    return AlertDialog(
      title: Text(widget.occurrence.name),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MoneyField(
              autofocus: true,
              label: l.fieldAmount,
              initialMinor: _amount,
              onChanged: (v) => _amount = v,
              validator: (v) =>
                  v == null || v == 0 ? l.recurringErrorAmount : null,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(l.fieldDate),
              subtitle: Text(dates.medium(_date)),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(1990),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _date = dateOnly(d));
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            if (!(_form.currentState?.validate() ?? false)) return;
            Navigator.pop(context, (_amount!.abs(), _date));
          },
          child: Text(l.commonConfirm),
        ),
      ],
    );
  }
}

/// A rule row: icon, name, schedule text, next date · account · mode, amount.
class RuleTile extends ConsumerWidget {
  const RuleTile({
    required this.plan,
    required this.next,
    super.key,
    this.onTap,
    this.selected = false,
  });

  final RecurringPlan plan;
  final UpcomingOccurrence? next;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final lang = ref.watch(languageCodeProvider);
    final dates = ref.watch(dateFormatsProvider);
    final cats = ref.watch(categoryMapProvider);
    final accounts = ref.watch(accountMapProvider);
    final cat = cats[plan.template.categoryId];
    final icon = switch (plan.type) {
      TxnType.transfer => Icons.swap_horiz,
      TxnType.income => AppIcons.of(cat?.icon, fallback: Icons.south_west),
      TxnType.expense => AppIcons.of(
        cat?.icon,
        fallback: Icons.receipt_long_outlined,
      ),
    };
    final status = !plan.active
        ? l.recurringPaused
        : next == null
        ? l.recurringEnded
        : next!.isOverdue
        ? l.recurringOverdueDays(-next!.daysAway)
        : l.recurringNextOn(dates.dayHeader(next!.date));
    final sub = [
      describeSchedule(plan.rrule, lang),
      status,
      accounts[plan.template.accountId]?.name ?? '',
      if (plan.mode == PostingMode.autoPost)
        l.recurringAutoPostShort
      else
        l.recurringConfirmShort,
    ].where((s) => s.isNotEmpty).join(' · ');
    final amount = next?.amountMinor ?? plan.template.amountMinor;
    return ListTile(
      selected: selected,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.listInset),
      leading: IconTile(
        icon: icon,
        color: cat?.color == null ? null : Color(cat!.color!),
        size: 36,
      ),
      title: Text(plan.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: AmountText(amount, type: plan.type),
      onTap: onTap,
    );
  }
}
