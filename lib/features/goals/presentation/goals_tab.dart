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
import 'package:personal_finance/features/goals/data/goals_providers.dart';
import 'package:personal_finance/features/goals/data/goals_repository.dart';
import 'package:personal_finance/features/goals/presentation/goal_editor_screen.dart';
import 'package:personal_finance/features/plan/presentation/money_text.dart';
import 'package:personal_finance/features/plan/presentation/plan_widgets.dart';

/// Plan › Goals: prioritised (drag to reorder) savings goals with progress,
/// required contribution and projected date; archived goals below.
class GoalsTab extends ConsumerStatefulWidget {
  const GoalsTab({super.key});

  @override
  ConsumerState<GoalsTab> createState() => _GoalsTabState();
}

class _GoalsTabState extends ConsumerState<GoalsTab> {
  String? _selected;
  bool _showArchived = false;

  void _open(String id) {
    if (WindowSize.of(context).isExpanded) {
      setState(() => _selected = id);
    } else {
      unawaited(context.push('/plan/goals/$id'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final wide = WindowSize.of(context).isExpanded;
    final data = ref.watch(allGoalsProgressProvider);
    final all = data.value;
    Widget list;
    if (all == null) {
      list = data.hasError
          ? Center(child: Text(l.commonError(data.error.toString())))
          : const Center(child: CircularProgressIndicator.adaptive());
    } else if (all.isEmpty) {
      list = EmptyState(
        icon: Icons.flag_outlined,
        message: l.goalsEmpty,
        actionLabel: l.goalsNew,
        onAction: () => context.push('/plan/goals/new'),
      );
    } else {
      final active = all.where((g) => !g.goal.archived).toList();
      final archived = all.where((g) => g.goal.archived).toList();
      list = CustomScrollView(
        slivers: [
          if (active.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(Space.xl),
                child: Text(
                  l.goalsNoActive,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(child: PlanSectionHeader(l.goalsByPriority)),
            SliverReorderableList(
              itemCount: active.length,
              onReorderItem: (from, to) {
                final ids = [for (final g in active) g.id];
                final id = ids.removeAt(from);
                ids.insert(to, id);
                unawaited(ref.read(goalsRepositoryProvider).reorder(ids));
              },
              itemBuilder: (context, i) => GoalCard(
                key: ValueKey(active[i].id),
                progress: active[i],
                index: i,
                selected: wide && active[i].id == _selected,
                onTap: () => _open(active[i].id),
              ),
            ),
          ],
          if (archived.isNotEmpty)
            SliverToBoxAdapter(
              child: PlanSectionHeader(
                l.goalsArchived(archived.length),
                trailing: TextButton(
                  onPressed: () =>
                      setState(() => _showArchived = !_showArchived),
                  child: Text(_showArchived ? l.goalsHide : l.goalsShow),
                ),
              ),
            ),
          if (_showArchived)
            SliverList.list(
              children: [
                for (final g in archived)
                  GoalCard(
                    key: ValueKey('a-${g.id}'),
                    progress: g,
                    selected: wide && g.id == _selected,
                    onTap: () => _open(g.id),
                  ),
              ],
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      );
    }
    if (!wide) return list;
    return ListDetail(
      listWidth: 440,
      list: list,
      detail: _selected == null
          ? EmptyState(icon: Icons.flag_outlined, message: l.goalsSelectHint)
          : GoalEditor(
              key: ValueKey(_selected),
              goalId: _selected,
              embedded: true,
              onDone: () => setState(() => _selected = null),
            ),
    );
  }
}

/// A goal with progress bar, amounts, required contribution and ETA.
class GoalCard extends ConsumerWidget {
  const GoalCard({
    required this.progress,
    super.key,
    this.index,
    this.onTap,
    this.selected = false,
  });

  final GoalProgress progress;

  /// Position in the reorderable list (enables the drag handle).
  final int? index;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final money = moneyText(ref);
    final dates = ref.watch(dateFormatsProvider);
    final p = progress.projection;
    final g = progress.goal;
    final color = g.color == null ? null : Color(g.color!);
    final lines = <(String, Color?)>[];
    if (p.reached) {
      lines.add((l.goalsReached, context.colors.primary));
    } else {
      if (p.requiredPerPeriodMinor != null && p.targetDate != null) {
        lines.add((
          l.goalsRequiredPerPeriod(
            money(p.requiredPerPeriodMinor!),
            dates.medium(p.targetDate!),
          ),
          null,
        ));
      }
      if (p.projectedDate != null) {
        lines.add((
          l.goalsProjected(dates.medium(p.projectedDate!)),
          p.targetDate != null && !p.onTrack ? context.finance.warning : null,
        ));
      } else {
        lines.add((l.goalsNoPace, context.colors.onSurfaceVariant));
      }
    }
    final badge = p.reached
        ? null
        : p.targetDate == null
        ? null
        : p.onTrack
        ? (
            l.goalsOnTrack,
            context.colors.secondaryContainer,
            context.colors.onSecondaryContainer,
          )
        : (
            l.goalsBehind,
            context.finance.warningContainer,
            context.finance.onWarningContainer,
          );

    final card = Card(
      color: selected
          ? context.colors.secondaryContainer.withValues(alpha: 0.5)
          : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.sm,
            Space.xs,
            Space.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(
                icon: AppIcons.of(g.icon, fallback: Icons.flag_outlined),
                color: color,
                size: 36,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            g.name,
                            style: context.text.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badge != null)
                          StatusBadge(
                            badge.$1,
                            background: badge.$2,
                            foreground: badge.$3,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        AmountText(
                          p.savedMinor,
                          colored: false,
                          style: context.text.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [
                              l.goalsOfTarget(money(p.targetMinor)),
                              if (progress.account != null)
                                progress.account!.name,
                            ].join(' · '),
                            style: context.text.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${(p.fraction * 100).floor()} %',
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ProgressBar(value: p.fraction, color: color),
                    const SizedBox(height: 6),
                    for (final (text, c) in lines)
                      Text(
                        text,
                        style: context.text.bodySmall?.copyWith(
                          color: c ?? context.colors.onSurfaceVariant,
                          fontWeight: c != null ? FontWeight.w600 : null,
                        ),
                      ),
                    if (progress.account == null && !g.archived && !p.reached)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(l.goalsAddContribution),
                          onPressed: () =>
                              addGoalContribution(context, ref, g.id, g.name),
                        ),
                      ),
                  ],
                ),
              ),
              if (index != null)
                ReorderableDragStartListener(
                  index: index!,
                  child: Padding(
                    padding: const EdgeInsets.all(Space.xs),
                    child: Icon(
                      Icons.drag_indicator,
                      semanticLabel: l.goalsReorder,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 4),
      child: Semantics(
        label: [
          g.name,
          l.goalsSemanticProgress(money(p.savedMinor), money(p.targetMinor)),
          ...lines.map((e) => e.$1),
        ].join(', '),
        child: card,
      ),
    );
  }
}

/// Asks for a contribution (or withdrawal) and adds it to a manual goal.
Future<void> addGoalContribution(
  BuildContext context,
  WidgetRef ref,
  String goalId,
  String name,
) async {
  final l = context.l10n;
  int? amount;
  var withdraw = false;
  final form = GlobalKey<FormState>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(name),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l.goalsDeposit)),
                  ButtonSegment(value: true, label: Text(l.goalsWithdraw)),
                ],
                selected: {withdraw},
                onSelectionChanged: (s) => setState(() => withdraw = s.first),
              ),
              const SizedBox(height: Space.sm),
              MoneyField(
                autofocus: true,
                label: l.fieldAmount,
                onChanged: (v) => amount = v,
                validator: (v) =>
                    v == null || v == 0 ? l.goalsAmountInvalid : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(l.commonSave),
          ),
        ],
      ),
    ),
  );
  if (!(ok ?? false) || amount == null) return;
  await ref
      .read(goalsRepositoryProvider)
      .addContribution(goalId, withdraw ? -amount!.abs() : amount!.abs());
}
