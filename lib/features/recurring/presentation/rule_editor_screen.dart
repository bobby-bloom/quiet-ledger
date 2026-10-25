import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/app_icons.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/calendar/recurrence.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/budgets/data/budget_period_provider.dart';
import 'package:personal_finance/features/plan/plan_providers.dart';
import 'package:personal_finance/features/plan/presentation/money_text.dart';
import 'package:personal_finance/features/plan/presentation/plan_widgets.dart';
import 'package:personal_finance/features/recurring/data/recurring_providers.dart';
import 'package:personal_finance/features/recurring/data/recurring_repository.dart';
import 'package:personal_finance/features/recurring/data/reminders.dart';
import 'package:personal_finance/features/recurring/domain/recurring_logic.dart';
import 'package:personal_finance/features/recurring/domain/schedule.dart';
import 'package:personal_finance/features/recurring/presentation/schedule_builder.dart';

/// Transactions posted by a rule, newest first.
final postedByRuleProvider = StreamProvider.autoDispose
    .family<List<Txn>, String>(
      (ref, id) => ref.watch(recurringRepositoryProvider).watchPosted(id),
    );

/// '/plan/recurring/new' and '/plan/recurring/:id'.
class RuleEditorScreen extends StatelessWidget {
  const RuleEditorScreen({super.key, this.ruleId, this.initialType});

  final String? ruleId;

  /// Preset type for new rules (route query `type`).
  final TxnType? initialType;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(ruleId == null ? l.recurringNew : l.recurringEdit),
      ),
      body: RuleEditor(
        ruleId: ruleId,
        initialType: initialType,
        onDone: () {
          if (context.canPop()) context.pop();
        },
      ),
    );
  }
}

enum _EndMode { never, onDate, afterCount }

class _SplitRow {
  _SplitRow({this.categoryId, this.amountAbs});

  String? categoryId;
  int? amountAbs;
  final key = UniqueKey();
}

/// The rule form (also embedded in the list-detail pane).
class RuleEditor extends ConsumerStatefulWidget {
  const RuleEditor({
    required this.onDone,
    super.key,
    this.ruleId,
    this.initialType,
    this.embedded = false,
  });

  final String? ruleId;
  final TxnType? initialType;
  final VoidCallback onDone;
  final bool embedded;

  @override
  ConsumerState<RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends ConsumerState<RuleEditor> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _payee = TextEditingController();
  final _note = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _notFound = false;
  String? _error;

  TxnType _type = TxnType.expense;
  int? _amountAbs;
  String? _accountId;
  String? _transferId;
  String? _categoryId;
  bool _split = false;
  List<_SplitRow> _splits = [];
  Set<String> _tagIds = {};
  ScheduleSpec _schedule = const ScheduleSpec();
  late DateTime _start;
  _EndMode _endMode = _EndMode.never;
  DateTime? _endDate;
  int _count = 12;
  WeekendShift _shift = WeekendShift.none;
  PostingMode _mode = PostingMode.remindConfirm;
  int _remindDays = 2;
  int _notifyTime = 9 * 60;
  bool _active = true;
  DateTime? _lastPosted;
  final List<(DateTime, int)> _pendingChanges = [];

  bool get _isNew => widget.ruleId == null;

  @override
  void initState() {
    super.initState();
    _start = ref.read(planTodayProvider);
    _schedule = ScheduleSpec.monthlyFrom(_start);
    unawaited(_load());
  }

  Future<void> _load() async {
    final settings = ref.read(settingsProvider);
    if (_isNew) {
      _type = widget.initialType ?? TxnType.expense;
      _mode = settings.get(RecurringSettings.defaultPostingMode) == 'autoPost'
          ? PostingMode.autoPost
          : PostingMode.remindConfirm;
      _remindDays = settings.get(RecurringSettings.reminderLeadDays);
      _notifyTime = settings.get(RecurringSettings.notificationTime);
      final accounts = (ref.read(accountsProvider).value ?? const <Account>[])
          .where((a) => !a.archived)
          .toList();
      if (accounts.isNotEmpty) _accountId = accounts.first.id;
      setState(() => _loading = false);
      return;
    }
    final rule = await ref
        .read(recurringRepositoryProvider)
        .ruleById(widget.ruleId!);
    if (!mounted) return;
    if (rule == null) {
      setState(() {
        _loading = false;
        _notFound = true;
      });
      return;
    }
    final d = RecurringRuleDraft.fromRow(rule);
    final t = d.template;
    _name.text = d.name;
    _type = t.type;
    _amountAbs = t.amountMinor.abs();
    _accountId = t.accountId.isEmpty ? null : t.accountId;
    _transferId = t.transferAccountId;
    _categoryId = t.categoryId;
    _split = t.splits.isNotEmpty;
    _splits = [
      for (final s in t.splits)
        _SplitRow(categoryId: s.categoryId, amountAbs: s.amountMinor.abs()),
    ];
    _payee.text = t.payee ?? '';
    _note.text = t.note ?? '';
    _tagIds = {...t.tagIds};
    _schedule = ScheduleSpec.parse(d.rrule);
    _start = d.startDate;
    _endDate = d.endDate;
    _count = d.count ?? 12;
    _endMode = d.endDate != null
        ? _EndMode.onDate
        : d.count != null
        ? _EndMode.afterCount
        : _EndMode.never;
    _shift = d.weekendShift;
    _mode = d.postingMode;
    _remindDays = d.remindDaysBefore;
    _notifyTime = d.notifyTime;
    _active = d.active;
    _lastPosted = rule.lastPostedDate;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _payee.dispose();
    _note.dispose();
    super.dispose();
  }

  int _signed(int abs) => _type == TxnType.income ? abs : -abs;

  TxnDraft _template() => TxnDraft(
    accountId: _accountId ?? '',
    amountMinor: _signed(_amountAbs ?? 0),
    date: _start,
    type: _type,
    payee: _payee.text.trim().isEmpty ? null : _payee.text.trim(),
    note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    categoryId: _type == TxnType.transfer || _split ? null : _categoryId,
    transferAccountId: _type == TxnType.transfer ? _transferId : null,
    splits: _type == TxnType.transfer || !_split
        ? const []
        : [
            for (final s in _splits)
              SplitDraft(
                amountMinor: _signed(s.amountAbs ?? 0),
                categoryId: s.categoryId,
              ),
          ],
    tagIds: _tagIds.toList(),
  );

  RecurringRuleDraft _draft() => RecurringRuleDraft(
    name: _name.text,
    rrule: _schedule.toRRule(),
    startDate: _start,
    endDate: _endMode == _EndMode.onDate ? _endDate : null,
    count: _endMode == _EndMode.afterCount ? _count : null,
    template: _template(),
    postingMode: _mode,
    remindDaysBefore: _remindDays,
    notifyTime: _notifyTime,
    weekendShift: _shift,
    active: _active,
  );

  String? _problemText(List<String> problems) {
    final l = context.l10n;
    if (problems.isEmpty) return null;
    return switch (problems.first) {
      'name' => l.recurringErrorName,
      'rrule' => l.recurringRRuleInvalid,
      'amount' => l.recurringErrorAmount,
      'endBeforeStart' => l.recurringErrorEndBeforeStart,
      'count' => l.recurringErrorCount,
      'accountId' => l.recurringErrorAccount,
      'transferAccountId' => l.recurringErrorTransferAccount,
      'sameAccount' => l.recurringErrorSameAccount,
      'splitRemainder' => l.recurringErrorSplits,
      _ => problems.first,
    };
  }

  Future<void> _save() async {
    final valid = _form.currentState?.validate() ?? false;
    final draft = _draft();
    final problems = draft.validate();
    if (_endMode == _EndMode.onDate && _endDate == null) {
      problems.add('endBeforeStart');
    }
    if (!valid || problems.isNotEmpty) {
      setState(() => _error = _problemText(problems));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(recurringRepositoryProvider);
    try {
      String id;
      if (_isNew) {
        id = await repo.create(
          draft,
          amountChanges: [
            for (final (d, abs) in _pendingChanges) (d, _signed(abs)),
          ],
        );
      } else {
        id = widget.ruleId!;
        await repo.update(id, draft);
      }
      await rescheduleRuleReminders(ref.read, id);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(context.l10n.recurringSaved)));
      widget.onDone();
    } on Object catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l.commonDeleteConfirm(_name.text),
      message: l.recurringDeleteMessage,
    );
    if (!ok) return;
    final id = widget.ruleId!;
    await ref.read(recurringRepositoryProvider).delete(id);
    await rescheduleRuleReminders(ref.read, id);
    widget.onDone();
  }

  Future<void> _pickDate(
    DateTime initial,
    ValueChanged<DateTime> onPicked,
  ) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (d != null) onPicked(dateOnly(d));
  }

  Future<void> _addAmountChange() async {
    final r = await showAmountChangeDialog(
      context,
      initialDate: ref.read(planTodayProvider),
      initialAbs: _amountAbs,
    );
    if (r == null) return;
    if (_isNew) {
      setState(() {
        _pendingChanges
          ..removeWhere((c) => c.$1 == r.$1)
          ..add(r)
          ..sort((a, b) => a.$1.compareTo(b.$1));
      });
    } else {
      await ref
          .read(recurringRepositoryProvider)
          .addAmountChange(widget.ruleId!, r.$1, _signed(r.$2));
      await rescheduleRuleReminders(ref.read, widget.ruleId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (_loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_notFound) return EmptyState(message: l.recurringNotFound);
    final dates = ref.watch(dateFormatsProvider);
    final accounts = ref.watch(accountMapProvider);
    final cats = ref.watch(categoryMapProvider);
    final settings = ref.watch(settingsProvider);
    final money = moneyText(ref);
    final kind = _type == TxnType.income
        ? CategoryKind.income
        : CategoryKind.expense;

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.cardGap, Space.md, 0),
      child: SectionCard(
        title: title,
        padding: const EdgeInsets.fromLTRB(Space.md, 4, Space.md, Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );

    Widget pickerTile({
      required IconData icon,
      required String label,
      required String? value,
      required VoidCallback onTap,
      String? error,
    }) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(
        value ?? l.recurringNotSet,
        style: error != null && value == null
            ? TextStyle(color: context.colors.error)
            : null,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );

    final splitSum = _splits.fold(0, (a, s) => a + (s.amountAbs ?? 0));
    final splitRemainder = (_amountAbs ?? 0) - splitSum;

    final children = <Widget>[
      if (widget.embedded)
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.md, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _isNew ? l.recurringNew : l.recurringEdit,
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
      section(l.recurringWhat, [
        const SizedBox(height: Space.xs),
        SegmentedButton<TxnType>(
          segments: [
            ButtonSegment(value: TxnType.expense, label: Text(l.typeExpense)),
            ButtonSegment(value: TxnType.income, label: Text(l.typeIncome)),
            ButtonSegment(value: TxnType.transfer, label: Text(l.typeTransfer)),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() {
            final next = s.first;
            if ((next == TxnType.income) != (_type == TxnType.income)) {
              _categoryId = null;
              for (final r in _splits) {
                r.categoryId = null;
              }
            }
            _type = next;
          }),
        ),
        const SizedBox(height: Space.sm),
        TextFormField(
          controller: _name,
          decoration: InputDecoration(labelText: l.recurringName),
          textCapitalization: TextCapitalization.sentences,
          validator: (v) =>
              v == null || v.trim().isEmpty ? l.recurringErrorName : null,
        ),
        const SizedBox(height: Space.sm),
        MoneyField(
          label: l.fieldAmount,
          initialMinor: _amountAbs,
          onChanged: (v) => setState(() => _amountAbs = v),
          validator: (v) => v == null || v == 0 ? l.recurringErrorAmount : null,
        ),
        pickerTile(
          icon: Icons.account_balance_outlined,
          label: _type == TxnType.transfer
              ? l.recurringFromAccount
              : l.fieldAccount,
          value: accounts[_accountId]?.name,
          error: l.recurringErrorAccount,
          onTap: () async {
            final id = await showAccountPicker(context, selectedId: _accountId);
            if (id != null) setState(() => _accountId = id);
          },
        ),
        if (_type == TxnType.transfer)
          pickerTile(
            icon: Icons.swap_horiz,
            label: l.recurringToAccount,
            value: accounts[_transferId]?.name,
            error: l.recurringErrorTransferAccount,
            onTap: () async {
              final id = await showAccountPicker(
                context,
                selectedId: _transferId,
                exclude: {?_accountId},
              );
              if (id != null) setState(() => _transferId = id);
            },
          )
        else ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.recurringSplit),
            value: _split,
            onChanged: (v) => setState(() {
              _split = v;
              if (v && _splits.isEmpty) {
                _splits = [
                  _SplitRow(categoryId: _categoryId, amountAbs: _amountAbs),
                  _SplitRow(),
                ];
              }
            }),
          ),
          if (!_split)
            pickerTile(
              icon: Icons.category_outlined,
              label: l.fieldCategory,
              value: _categoryId == null ? null : cats[_categoryId]?.name,
              onTap: () async {
                final id = await showCategoryPicker(
                  context,
                  kind: kind,
                  selectedId: _categoryId,
                  allowNone: true,
                );
                if (id != null) {
                  setState(() => _categoryId = id.isEmpty ? null : id);
                }
              },
            )
          else ...[
            for (final s in _splits)
              Padding(
                key: s.key,
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          minimumSize: const Size(0, Space.minTouch),
                        ),
                        icon: Icon(
                          AppIcons.of(cats[s.categoryId]?.icon),
                          size: 18,
                        ),
                        label: Text(
                          cats[s.categoryId]?.name ?? l.fieldCategory,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () async {
                          final id = await showCategoryPicker(
                            context,
                            kind: kind,
                            selectedId: s.categoryId,
                          );
                          if (id != null) setState(() => s.categoryId = id);
                        },
                      ),
                    ),
                    const SizedBox(width: Space.xs),
                    SizedBox(
                      width: 120,
                      child: MoneyField(
                        initialMinor: s.amountAbs,
                        onChanged: (v) => setState(() => s.amountAbs = v),
                      ),
                    ),
                    IconButton(
                      tooltip: l.commonDelete,
                      icon: const Icon(Icons.close),
                      onPressed: _splits.length <= 2
                          ? null
                          : () => setState(() => _splits.remove(s)),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(l.recurringAddSplit),
                  onPressed: () => setState(() => _splits.add(_SplitRow())),
                ),
                const Spacer(),
                Text(
                  splitRemainder == 0
                      ? l.recurringSplitBalanced
                      : l.recurringSplitRemainder(money(splitRemainder)),
                  style: context.text.bodySmall?.copyWith(
                    color: splitRemainder == 0
                        ? context.colors.onSurfaceVariant
                        : context.colors.error,
                  ),
                ),
              ],
            ),
          ],
        ],
        TextFormField(
          controller: _payee,
          decoration: InputDecoration(labelText: l.fieldPayee),
        ),
        const SizedBox(height: Space.sm),
        TextFormField(
          controller: _note,
          decoration: InputDecoration(labelText: l.fieldNote),
        ),
        if (settings.moduleEnabled(AppModule.tags)) _tagChips(),
      ]),
      section(l.recurringWhen, [
        const SizedBox(height: Space.xs),
        ScheduleBuilder(
          value: _schedule,
          start: _start,
          onChanged: (s) => setState(() => _schedule = s),
        ),
        const SizedBox(height: Space.xs),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: Text(l.recurringStartDate),
          subtitle: Text(dates.medium(_start)),
          onTap: () => _pickDate(_start, (d) => setState(() => _start = d)),
        ),
        Text(l.recurringEnds, style: context.text.labelLarge),
        const SizedBox(height: Space.xxs),
        SegmentedButton<_EndMode>(
          segments: [
            ButtonSegment(
              value: _EndMode.never,
              label: Text(l.recurringEndsNever),
            ),
            ButtonSegment(
              value: _EndMode.onDate,
              label: Text(l.recurringEndsOnDate),
            ),
            ButtonSegment(
              value: _EndMode.afterCount,
              label: Text(l.recurringEndsAfterCount),
            ),
          ],
          selected: {_endMode},
          onSelectionChanged: (s) => setState(() {
            _endMode = s.first;
            if (_endMode == _EndMode.onDate && _endDate == null) {
              _endDate = DateTime(_start.year + 1, _start.month, _start.day);
            }
          }),
        ),
        if (_endMode == _EndMode.onDate)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_busy_outlined),
            title: Text(l.recurringEndDate),
            subtitle: Text(
              _endDate == null ? l.recurringNotSet : dates.medium(_endDate!),
            ),
            onTap: () => _pickDate(
              _endDate ?? _start,
              (d) => setState(() => _endDate = d),
            ),
          ),
        if (_endMode == _EndMode.afterCount)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: TextFormField(
              initialValue: '$_count',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.recurringOccurrences),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n == null || n < 1 ? l.recurringErrorCount : null;
              },
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null) setState(() => _count = n);
              },
            ),
          ),
        const SizedBox(height: Space.sm),
        Text(l.recurringShift, style: context.text.labelLarge),
        const SizedBox(height: Space.xxs),
        SegmentedButton<WeekendShift>(
          segments: [
            ButtonSegment(
              value: WeekendShift.none,
              label: Text(l.recurringShiftNone),
            ),
            ButtonSegment(
              value: WeekendShift.previous,
              label: Text(l.recurringShiftEarlier),
            ),
            ButtonSegment(
              value: WeekendShift.next,
              label: Text(l.recurringShiftLater),
            ),
          ],
          selected: {_shift},
          onSelectionChanged: (s) => setState(() => _shift = s.first),
        ),
      ]),
      section(l.recurringPosting, [
        const SizedBox(height: Space.xs),
        SegmentedButton<PostingMode>(
          segments: [
            ButtonSegment(
              value: PostingMode.autoPost,
              label: Text(l.setOptAutoPost),
            ),
            ButtonSegment(
              value: PostingMode.remindConfirm,
              label: Text(l.setOptRemindConfirm),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        const SizedBox(height: Space.xxs),
        Text(
          _mode == PostingMode.autoPost
              ? l.recurringAutoPostHelp
              : l.recurringRemindHelp,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        Row(
          children: [
            Expanded(child: Text(l.recurringRemindDaysBefore(_remindDays))),
            IconButton(
              tooltip: l.recurringDecrease,
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: _remindDays > 0
                  ? () => setState(() => _remindDays--)
                  : null,
            ),
            IconButton(
              tooltip: l.recurringIncrease,
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _remindDays < 30
                  ? () => setState(() => _remindDays++)
                  : null,
            ),
          ],
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule),
          title: Text(l.recurringNotifyTime),
          subtitle: Text(
            dates.time(
              DateTime(2000, 1, 1, _notifyTime ~/ 60, _notifyTime % 60),
            ),
          ),
          onTap: () async {
            final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(
                hour: _notifyTime ~/ 60,
                minute: _notifyTime % 60,
              ),
            );
            if (t != null) setState(() => _notifyTime = t.hour * 60 + t.minute);
          },
        ),
        if (!_isNew)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.recurringActive),
            subtitle: Text(l.recurringActiveHelp),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
      ]),
      _amountChangesSection(section),
      _previewSection(section),
      if (!_isNew) _historySection(section),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.xl, 0),
          child: Text(_error!, style: TextStyle(color: context.colors.error)),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.lg, Space.md, 0),
        child: Row(
          children: [
            if (!_isNew)
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.error,
                ),
                icon: const Icon(Icons.delete_outline),
                label: Text(l.commonDelete),
                onPressed: _saving ? null : _delete,
              ),
            const Spacer(),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(l.commonSave),
            ),
          ],
        ),
      ),
      const SizedBox(height: 96),
    ];

    return Form(
      key: _form,
      child: ReadableWidth(child: ListView(children: children)),
    );
  }

  Widget _tagChips() {
    final l = context.l10n;
    final tags = (ref.watch(tagsProvider).value ?? const <Tag>[])
        .where((t) => !t.archived || _tagIds.contains(t.id))
        .toList();
    if (tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.recurringTags, style: context.text.labelLarge),
          const SizedBox(height: Space.xxs),
          Wrap(
            spacing: Space.xxs,
            runSpacing: Space.xxs,
            children: [
              for (final t in tags)
                FilterChip(
                  label: Text(t.name),
                  selected: _tagIds.contains(t.id),
                  onSelected: (v) => setState(
                    () => v ? _tagIds.add(t.id) : _tagIds.remove(t.id),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amountChangesSection(Widget Function(String, List<Widget>) section) {
    final l = context.l10n;
    final dates = ref.watch(dateFormatsProvider);
    final rows = <(String?, DateTime, int)>[];
    if (_isNew) {
      for (final (d, abs) in _pendingChanges) {
        rows.add((null, d, abs));
      }
    } else {
      final changes =
          ref.watch(recurringAmountChangesProvider).value?[widget.ruleId] ??
          const <RecurringAmountChange>[];
      for (final c in changes) {
        rows.add((c.id, dateOnly(c.fromDate), c.amountMinor.abs()));
      }
    }
    return section(l.recurringAmountChanges, [
      Text(
        l.recurringAmountChangesHelp,
        style: context.text.bodySmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
      for (final (id, d, abs) in rows)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.trending_up),
          title: Text(l.recurringFromDate(dates.medium(d))),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AmountText(_signed(abs), type: _type),
              IconButton(
                tooltip: l.commonDelete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (id == null) {
                    setState(
                      () => _pendingChanges.removeWhere((c) => c.$1 == d),
                    );
                  } else {
                    await ref
                        .read(recurringRepositoryProvider)
                        .deleteAmountChange(id);
                    await rescheduleRuleReminders(ref.read, widget.ruleId!);
                  }
                },
              ),
            ],
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.add),
          label: Text(l.recurringAddAmountChange),
          onPressed: _addAmountChange,
        ),
      ),
    ]);
  }

  Widget _previewSection(Widget Function(String, List<Widget>) section) {
    final l = context.l10n;
    final dates = ref.watch(dateFormatsProvider);
    final calendar = ref.watch(holidayCalendarProvider);
    final today = ref.watch(planTodayProvider);
    final draft = _draft();
    final changes = _isNew
        ? {for (final (d, abs) in _pendingChanges) d: _signed(abs)}
        : RecurringRepository.changeMap(
            ref.watch(recurringAmountChangesProvider).value?[widget.ruleId],
          );
    final plan = RecurringPlan(
      id: widget.ruleId ?? '',
      name: draft.name,
      rrule: draft.rrule,
      start: draft.startDate,
      end: draft.endDate,
      count: draft.count,
      shift: draft.weekendShift,
      template: draft.template,
      lastPostedDate: _lastPosted,
      amountChanges: changes,
    );
    final valid = isValidRRule(draft.rrule);
    final next = valid
        ? plan
              .occurrences(
                today,
                DateTime(today.year + 6, today.month, today.day),
                calendar,
              )
              .where((o) => _lastPosted == null || o.date.isAfter(_lastPosted!))
              .take(5)
              .toList()
        : const <Occurrence>[];
    return section(l.recurringNextOccurrences, [
      if (next.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Text(
            l.recurringNoUpcoming,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      for (final o in next)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  o.date == o.scheduled
                      ? dates.dayHeader(o.date)
                      : l.recurringShiftedFrom(
                          dates.dayHeader(o.date),
                          dates.short(o.scheduled),
                        ),
                ),
              ),
              AmountText(plan.amountFor(o), type: _type),
            ],
          ),
        ),
      if (_lastPosted != null)
        Padding(
          padding: const EdgeInsets.only(top: Space.xxs),
          child: Text(
            l.recurringLastPosted(dates.medium(_lastPosted!)),
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
    ]);
  }

  Widget _historySection(Widget Function(String, List<Widget>) section) {
    final l = context.l10n;
    final dates = ref.watch(dateFormatsProvider);
    final posted = ref.watch(postedByRuleProvider(widget.ruleId!)).value;
    return section(l.recurringPostedHistory, [
      if (posted == null || posted.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Text(
            l.recurringNothingPosted,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        )
      else
        for (final t in posted)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(dates.medium(t.date))),
                AmountText(t.amountMinor, type: t.type),
              ],
            ),
          ),
    ]);
  }
}

/// Asks for an amount change: effective date and new (unsigned) amount.
Future<(DateTime, int)?> showAmountChangeDialog(
  BuildContext context, {
  required DateTime initialDate,
  int? initialAbs,
}) {
  return showDialog<(DateTime, int)>(
    context: context,
    builder: (ctx) =>
        _AmountChangeDialog(initialDate: initialDate, initialAbs: initialAbs),
  );
}

class _AmountChangeDialog extends ConsumerStatefulWidget {
  const _AmountChangeDialog({required this.initialDate, this.initialAbs});

  final DateTime initialDate;
  final int? initialAbs;

  @override
  ConsumerState<_AmountChangeDialog> createState() =>
      _AmountChangeDialogState();
}

class _AmountChangeDialogState extends ConsumerState<_AmountChangeDialog> {
  final _form = GlobalKey<FormState>();
  late DateTime _date = widget.initialDate;
  late int? _amount = widget.initialAbs;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dates = ref.watch(dateFormatsProvider);
    return AlertDialog(
      title: Text(l.recurringAddAmountChange),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(l.recurringEffectiveFrom),
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
            MoneyField(
              autofocus: true,
              label: l.recurringNewAmount,
              initialMinor: widget.initialAbs,
              onChanged: (v) => _amount = v,
              validator: (v) =>
                  v == null || v == 0 ? l.recurringErrorAmount : null,
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
            Navigator.pop(context, (_date, _amount!.abs()));
          },
          child: Text(l.commonSave),
        ),
      ],
    );
  }
}
