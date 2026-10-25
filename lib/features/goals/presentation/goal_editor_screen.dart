import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/goals/data/goals_providers.dart';
import 'package:personal_finance/features/goals/data/goals_repository.dart';
import 'package:personal_finance/features/goals/presentation/goals_tab.dart';
import 'package:personal_finance/features/plan/plan_providers.dart';
import 'package:personal_finance/features/plan/presentation/plan_widgets.dart';

/// '/plan/goals/new' and '/plan/goals/:id'.
class GoalEditorScreen extends ConsumerWidget {
  const GoalEditorScreen({super.key, this.goalId});

  final String? goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final enabled = ref.watch(
      settingsProvider.select((s) => s.moduleEnabled(AppModule.goals)),
    );
    return Scaffold(
      appBar: AppBar(title: Text(goalId == null ? l.goalsNew : l.goalsEdit)),
      body: enabled
          ? GoalEditor(
              goalId: goalId,
              onDone: () {
                if (context.canPop()) context.pop();
              },
            )
          : EmptyState(icon: Icons.flag_outlined, message: l.goalsModuleOff),
    );
  }
}

/// Goal form with its current projection (also embedded in the list-detail
/// pane).
class GoalEditor extends ConsumerStatefulWidget {
  const GoalEditor({
    required this.onDone,
    super.key,
    this.goalId,
    this.embedded = false,
  });

  final String? goalId;
  final VoidCallback onDone;
  final bool embedded;

  @override
  ConsumerState<GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends ConsumerState<GoalEditor> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _loading = true;
  bool _notFound = false;
  bool _saving = false;
  int? _target;
  DateTime? _targetDate;
  String? _accountId;
  int? _saved;
  int? _contribution;
  bool _archived = false;
  int? _color;
  String? _icon;

  bool get _isNew => widget.goalId == null;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_isNew) {
      setState(() => _loading = false);
      return;
    }
    final g = await ref.read(goalsRepositoryProvider).goalById(widget.goalId!);
    if (!mounted) return;
    if (g == null) {
      setState(() {
        _loading = false;
        _notFound = true;
      });
      return;
    }
    _name.text = g.name;
    _target = g.targetMinor;
    _targetDate = g.targetDate;
    _accountId = g.accountId;
    _saved = g.savedMinor;
    _contribution = g.contributionMinor;
    _archived = g.archived;
    _color = g.color;
    _icon = g.icon;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  GoalDraft _draft() => GoalDraft(
    name: _name.text,
    targetMinor: _target ?? 0,
    targetDate: _targetDate,
    accountId: _accountId,
    savedMinor: _accountId == null ? (_saved ?? 0) : 0,
    contributionMinor: _contribution,
    color: _color,
    icon: _icon ?? 'goal',
  );

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final repo = ref.read(goalsRepositoryProvider);
    try {
      if (_isNew) {
        await repo.create(_draft());
      } else {
        await repo.update(widget.goalId!, _draft());
      }
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(context.l10n.goalsSaved)));
      widget.onDone();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l.commonDeleteConfirm(_name.text),
    );
    if (!ok) return;
    await ref.read(goalsRepositoryProvider).delete(widget.goalId!);
    widget.onDone();
  }

  Future<void> _toggleArchive() async {
    await ref
        .read(goalsRepositoryProvider)
        .setArchived(widget.goalId!, !_archived);
    setState(() => _archived = !_archived);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (_loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_notFound) return EmptyState(message: l.goalsNotFound);
    final dates = ref.watch(dateFormatsProvider);
    final accounts = ref.watch(accountMapProvider);
    final today = ref.watch(planTodayProvider);
    GoalProgress? progress;
    if (!_isNew) {
      for (final p
          in ref.watch(allGoalsProgressProvider).value ??
              const <GoalProgress>[]) {
        if (p.id == widget.goalId) progress = p;
      }
    }

    return Form(
      key: _form,
      child: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            if (widget.embedded)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.xl,
                  Space.md,
                  Space.md,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isNew ? l.goalsNew : l.goalsEdit,
                        style: context.text.titleLarge,
                      ),
                    ),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(l.commonSave),
                    ),
                    const SizedBox(width: Space.xs),
                    ClosePanelButton(onPressed: widget.onDone),
                  ],
                ),
              ),
            if (progress != null) GoalCard(progress: progress),
            Padding(
              // Under the GoalCard, whose own padding makes up the rest of
              // the card gap.
              padding: EdgeInsets.fromLTRB(
                Space.md,
                progress != null ? Space.cardGap / 2 : Space.sm,
                Space.md,
                0,
              ),
              child: SectionCard(
                title: l.goalsDetails,
                padding: const EdgeInsets.fromLTRB(
                  Space.md,
                  4,
                  Space.md,
                  Space.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: InputDecoration(labelText: l.goalsName),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? l.goalsNameRequired
                          : null,
                    ),
                    const SizedBox(height: Space.sm),
                    MoneyField(
                      label: l.goalsTarget,
                      initialMinor: _target,
                      onChanged: (v) => _target = v,
                      validator: (v) =>
                          v == null || v <= 0 ? l.goalsTargetRequired : null,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined),
                      title: Text(l.goalsTargetDate),
                      subtitle: Text(
                        _targetDate == null
                            ? l.goalsNoTargetDate
                            : dates.medium(_targetDate!),
                      ),
                      trailing: _targetDate == null
                          ? null
                          : IconButton(
                              tooltip: l.commonReset,
                              icon: const Icon(Icons.clear),
                              onPressed: () =>
                                  setState(() => _targetDate = null),
                            ),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate:
                              _targetDate ??
                              DateTime(today.year + 1, today.month, today.day),
                          firstDate: today,
                          lastDate: DateTime(today.year + 60),
                        );
                        if (d != null) {
                          setState(() => _targetDate = dateOnly(d));
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.account_balance_outlined),
                      title: Text(l.goalsLinkedAccount),
                      subtitle: Text(
                        _accountId == null
                            ? l.goalsNoAccount
                            : accounts[_accountId]?.name ?? l.goalsNoAccount,
                      ),
                      trailing: _accountId == null
                          ? null
                          : IconButton(
                              tooltip: l.commonReset,
                              icon: const Icon(Icons.link_off),
                              onPressed: () =>
                                  setState(() => _accountId = null),
                            ),
                      onTap: () async {
                        final id = await showAccountPicker(
                          context,
                          selectedId: _accountId,
                        );
                        if (id != null) setState(() => _accountId = id);
                      },
                    ),
                    if (_accountId == null)
                      MoneyField(
                        key: ValueKey('saved-$_saved'),
                        label: l.goalsSavedSoFar,
                        initialMinor: _saved,
                        onChanged: (v) => _saved = v,
                      )
                    else
                      Text(
                        l.goalsLinkedHelp,
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: Space.sm),
                    MoneyField(
                      label: l.goalsPlannedContribution,
                      initialMinor: _contribution,
                      onChanged: (v) => _contribution = v,
                    ),
                    const SizedBox(height: Space.xxs),
                    Text(
                      l.goalsPlannedContributionHelp,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.lg,
                Space.md,
                0,
              ),
              child: Wrap(
                spacing: Space.xs,
                runSpacing: Space.xs,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  if (!_isNew) ...[
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: context.colors.error,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l.commonDelete),
                      onPressed: _saving ? null : _delete,
                    ),
                    OutlinedButton.icon(
                      icon: Icon(
                        _archived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                      ),
                      label: Text(
                        _archived ? l.goalsUnarchive : l.goalsArchive,
                      ),
                      onPressed: _saving ? null : _toggleArchive,
                    ),
                    if (progress != null &&
                        progress.account == null &&
                        !_archived)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(l.goalsAddContribution),
                        onPressed: () async {
                          await addGoalContribution(
                            context,
                            ref,
                            widget.goalId!,
                            _name.text,
                          );
                          final g = await ref
                              .read(goalsRepositoryProvider)
                              .goalById(widget.goalId!);
                          if (g != null && mounted) {
                            setState(() => _saved = g.savedMinor);
                          }
                        },
                      ),
                  ],
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(l.commonSave),
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
