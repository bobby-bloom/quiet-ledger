import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/money/money_input.dart';
import 'package:personal_finance/features/rules/data/db_rule_service.dart';
import 'package:personal_finance/features/rules/data/rule_repository.dart';
import 'package:personal_finance/features/rules/domain/rule_engine.dart';
import 'package:personal_finance/features/rules/domain/rule_model.dart';
import 'package:personal_finance/features/rules/presentation/rule_summary.dart';

/// Opens the rule editor. With [from] the new rule is pre-filled from a
/// transaction ("create rule from this transaction"): payee (or note)
/// condition, its category and tags as actions.
Future<void> openRuleEditor(BuildContext context, {TxnDraft? from}) =>
    context.push('/more/rules/new', extra: from);

/// A new rule pre-filled from [d].
RuleDef ruleFromDraft(TxnDraft d) {
  final payee = d.payee?.trim() ?? '';
  final note = d.note?.trim() ?? '';
  final useNote = payee.isEmpty && note.isNotEmpty;
  final text = useNote ? note : payee;
  return RuleDef(
    name: text,
    conditions: RuleConditions(
      items: [
        if (text.isNotEmpty)
          TextCondition(
            field: useNote ? RuleTextField.note : RuleTextField.payee,
            value: text,
          ),
        if (text.isEmpty) TypeCondition([d.type]),
      ],
    ),
    actions: RuleActions(
      categoryId: d.isTransfer || d.isSplit ? null : d.categoryId,
      addTagIds: d.tagIds,
    ),
  );
}

/// `/more/rules/new` and `/more/rules/:id`.
class RuleEditorScreen extends ConsumerStatefulWidget {
  const RuleEditorScreen({super.key, this.ruleId, this.from});

  final String? ruleId;
  final TxnDraft? from;

  @override
  ConsumerState<RuleEditorScreen> createState() => _RuleEditorScreenState();
}

class _RuleEditorScreenState extends ConsumerState<RuleEditorScreen> {
  RuleDef? _rule;
  late final TextEditingController _name = TextEditingController();
  late final TextEditingController _payee = TextEditingController();
  late final TextEditingController _note = TextEditingController();
  int _conditionSeed = 0;
  final List<int> _conditionKeys = [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    RuleDef rule;
    if (widget.ruleId != null) {
      rule =
          await ref.read(ruleRepositoryProvider).byId(widget.ruleId!) ??
          const RuleDef(name: '');
    } else if (widget.from != null) {
      rule = ruleFromDraft(widget.from!);
    } else {
      rule = const RuleDef(
        name: '',
        conditions: RuleConditions(items: [TextCondition()]),
      );
    }
    if (!mounted) return;
    _name.text = rule.name;
    _payee.text = rule.actions.payee ?? '';
    _note.text = rule.actions.note ?? '';
    setState(() {
      _rule = rule;
      _conditionKeys
        ..clear()
        ..addAll([for (final _ in rule.conditions.items) _conditionSeed++]);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _payee.dispose();
    _note.dispose();
    super.dispose();
  }

  void _update(RuleDef r) => setState(() => _rule = r);

  RuleDef get _current {
    final r = _rule!;
    return r.copyWith(
      name: _name.text,
      actions: r.actions.copyWith(
        payee: _payee.text.trim().isEmpty ? null : _payee.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }

  void _setConditions(List<RuleCondition> items) => _update(
    _rule!.copyWith(conditions: _rule!.conditions.copyWith(items: items)),
  );

  void _addCondition(RuleCondition c) {
    _conditionKeys.add(_conditionSeed++);
    _setConditions([..._rule!.conditions.items, c]);
  }

  void _removeCondition(int i) {
    _conditionKeys.removeAt(i);
    _setConditions([..._rule!.conditions.items]..removeAt(i));
  }

  Future<void> _save() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final rule = _current;
    if (!rule.isValid) {
      messenger.showSnackBar(SnackBar(content: Text(l.rulesInvalid)));
      return;
    }
    await ref.read(ruleRepositoryProvider).save(rule);
    messenger.showSnackBar(SnackBar(content: Text(l.rulesSaved)));
    if (mounted) await Navigator.of(context).maybePop();
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDialog(
      context,
      title: l.commonDeleteConfirm(_current.name),
    );
    if (!ok) return;
    await ref.read(ruleRepositoryProvider).delete(_rule!.id!);
    messenger.showSnackBar(SnackBar(content: Text(l.rulesDeleted)));
    if (mounted) await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rule = _rule;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ruleId == null ? l.rulesNew : l.rulesEdit),
        actions: [
          if (rule?.id != null)
            IconButton(
              tooltip: l.commonDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          FilledButton(
            onPressed: rule == null ? null : _save,
            child: Text(l.commonSave),
          ),
        ],
      ),
      body: rule == null
          ? const Center(child: CircularProgressIndicator.adaptive())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Space.md,
                    Space.sm,
                    Space.md,
                    Space.xxxl,
                  ),
                  children: [
                    TextField(
                      controller: _name,
                      decoration: InputDecoration(labelText: l.rulesName),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                    ),
                    _Header(
                      l.rulesConditions,
                      trailing: SegmentedButton<MatchMode>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: MatchMode.all,
                            label: Text(l.rulesMatchAll),
                          ),
                          ButtonSegment(
                            value: MatchMode.any,
                            label: Text(l.rulesMatchAny),
                          ),
                        ],
                        selected: {rule.conditions.mode},
                        onSelectionChanged: (m) => _update(
                          rule.copyWith(
                            conditions: rule.conditions.copyWith(mode: m.first),
                          ),
                        ),
                      ),
                    ),
                    for (var i = 0; i < rule.conditions.items.length; i++)
                      _ConditionCard(
                        key: ValueKey(_conditionKeys[i]),
                        condition: rule.conditions.items[i],
                        onChanged: (c) {
                          final items = [...rule.conditions.items];
                          items[i] = c;
                          _setConditions(items);
                        },
                        onRemove: () => _removeCondition(i),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: MenuAnchor(
                        builder: (context, controller, _) => TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: Text(l.rulesAddCondition),
                          onPressed: () => controller.isOpen
                              ? controller.close()
                              : controller.open(),
                        ),
                        menuChildren: [
                          MenuItemButton(
                            onPressed: () =>
                                _addCondition(const TextCondition()),
                            child: Text(l.rulesCondText),
                          ),
                          MenuItemButton(
                            onPressed: () =>
                                _addCondition(const AmountCondition()),
                            child: Text(l.rulesCondAmount),
                          ),
                          MenuItemButton(
                            onPressed: () =>
                                _addCondition(const AccountCondition([])),
                            child: Text(l.rulesCondAccount),
                          ),
                          MenuItemButton(
                            onPressed: () =>
                                _addCondition(const TypeCondition([])),
                            child: Text(l.rulesCondType),
                          ),
                        ],
                      ),
                    ),
                    _Header(l.rulesActions),
                    _ActionsEditor(
                      actions: rule.actions,
                      payee: _payee,
                      note: _note,
                      onChanged: (a) => _update(rule.copyWith(actions: a)),
                    ),
                    const SizedBox(height: Space.sm),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.rulesApplyOnEntry),
                      value: rule.applyOnEntry,
                      onChanged: (v) => _update(rule.copyWith(applyOnEntry: v)),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.rulesApplyOnImport),
                      value: rule.applyOnImport,
                      onChanged: (v) =>
                          _update(rule.copyWith(applyOnImport: v)),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.rulesEnable),
                      value: rule.enabled,
                      onChanged: (v) => _update(rule.copyWith(enabled: v)),
                    ),
                    _Header(l.rulesTest),
                    _TestCard(rule: _current, initial: widget.from),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xs),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Space.sm,
        runSpacing: Space.xs,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: context.text.titleMedium),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _ConditionCard extends ConsumerStatefulWidget {
  const _ConditionCard({
    required this.condition,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final RuleCondition condition;
  final ValueChanged<RuleCondition> onChanged;
  final VoidCallback onRemove;

  @override
  ConsumerState<_ConditionCard> createState() => _ConditionCardState();
}

class _ConditionCardState extends ConsumerState<_ConditionCard> {
  late final TextEditingController _text = TextEditingController(
    text: switch (widget.condition) {
      TextCondition(:final value) => value,
      _ => '',
    },
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = widget.condition;
    Widget body;
    String title;
    switch (c) {
      case TextCondition():
        title = l.rulesCondText;
        final regexError =
            c.operator == TextOperator.regex &&
                c.value.isNotEmpty &&
                !isValidRegex(c.value)
            ? l.rulesInvalidRegex
            : null;
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<RuleTextField>(
                    initialValue: c.field,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    items: [
                      for (final f in RuleTextField.values)
                        DropdownMenuItem(
                          value: f,
                          child: Text(l.rulesFieldLabel(f)),
                        ),
                    ],
                    onChanged: (f) => widget.onChanged(c.copyWith(field: f)),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<TextOperator>(
                    initialValue: c.operator,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    items: [
                      for (final o in TextOperator.values)
                        DropdownMenuItem(
                          value: o,
                          child: Text(l.rulesOperatorLabel(o)),
                        ),
                    ],
                    onChanged: (o) => widget.onChanged(c.copyWith(operator: o)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            TextField(
              controller: _text,
              style: c.operator == TextOperator.regex ? context.mono : null,
              decoration: InputDecoration(
                labelText: l.rulesText,
                errorText: regexError,
              ),
              onChanged: (v) => widget.onChanged(c.copyWith(value: v)),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l.rulesNegate),
              value: c.negate,
              onChanged: (v) =>
                  widget.onChanged(c.copyWith(negate: v ?? false)),
            ),
          ],
        );
      case AmountCondition():
        title = l.rulesCondAmount;
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: MoneyField(
                    label: l.rulesAmountMin,
                    initialMinor: c.minMinor,
                    allowNegative: !c.absolute,
                    onChanged: (v) => widget.onChanged(c.copyWith(minMinor: v)),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: MoneyField(
                    label: l.rulesAmountMax,
                    initialMinor: c.maxMinor,
                    allowNegative: !c.absolute,
                    onChanged: (v) => widget.onChanged(c.copyWith(maxMinor: v)),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.rulesAmountAbs),
              value: c.absolute,
              onChanged: (v) => widget.onChanged(c.copyWith(absolute: v)),
            ),
          ],
        );
      case AccountCondition():
        title = l.rulesCondAccount;
        final accounts = ref.watch(accountMapProvider);
        body = Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.account_balance_outlined, size: 18),
            label: Text(
              c.accountIds.isEmpty
                  ? l.rulesChooseAccounts
                  : c.accountIds
                        .map((id) => accounts[id]?.name ?? '?')
                        .join(', '),
            ),
            onPressed: () async {
              final ids = await showAccountMultiPicker(
                context,
                selected: c.accountIds.toSet(),
              );
              if (ids != null) widget.onChanged(AccountCondition(ids.toList()));
            },
          ),
        );
      case TypeCondition():
        title = l.rulesCondType;
        body = Wrap(
          spacing: Space.xs,
          children: [
            for (final t in TxnType.values)
              FilterChip(
                label: Text(l.typeLabel(t)),
                selected: c.types.contains(t),
                onSelected: (sel) => widget.onChanged(
                  TypeCondition([
                    for (final x in TxnType.values)
                      if (x == t ? sel : c.types.contains(x)) x,
                  ]),
                ),
              ),
          ],
        );
    }
    return Card(
      margin: const EdgeInsets.only(bottom: Space.xs),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.md,
          Space.xxs,
          Space.xxs,
          Space.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: context.text.labelLarge)),
                IconButton(
                  tooltip: l.rulesRemoveCondition,
                  icon: const Icon(Icons.close),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: body,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionsEditor extends ConsumerWidget {
  const _ActionsEditor({
    required this.actions,
    required this.payee,
    required this.note,
    required this.onChanged,
  });

  final RuleActions actions;
  final TextEditingController payee;
  final TextEditingController note;
  final ValueChanged<RuleActions> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final categories = ref.watch(categoryMapProvider);
    final tags = (ref.watch(tagsProvider).value ?? const <Tag>[])
        .where((t) => !t.archived || actions.addTagIds.contains(t.id))
        .toList();
    final fields =
        (ref.watch(customFieldDefsProvider).value ?? const <CustomFieldDef>[])
            .where((f) => !f.archived && f.appliesTo == 'transaction')
            .toList();
    final cat = actions.categoryId == null
        ? null
        : categories[actions.categoryId];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          padding: const EdgeInsets.all(Space.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.category_outlined),
                title: Text(l.rulesActCategory),
                subtitle: Text(
                  cat == null ? l.rulesKeep : categoryPath(cat, categories),
                ),
                trailing: cat == null
                    ? const Icon(Icons.chevron_right)
                    : IconButton(
                        tooltip: l.commonNone,
                        icon: const Icon(Icons.clear),
                        onPressed: () =>
                            onChanged(actions.copyWith(categoryId: null)),
                      ),
                onTap: () async {
                  final id = await showCategoryPicker(
                    context,
                    selectedId: actions.categoryId,
                    allowNone: true,
                  );
                  if (id == null) return;
                  onChanged(
                    actions.copyWith(categoryId: id.isEmpty ? null : id),
                  );
                },
              ),
              if (tags.isNotEmpty) ...[
                Text(l.rulesActTags, style: context.text.labelLarge),
                const SizedBox(height: Space.xxs),
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: [
                    for (final t in tags)
                      FilterChip(
                        label: Text(t.name),
                        selected: actions.addTagIds.contains(t.id),
                        onSelected: (sel) => onChanged(
                          actions.copyWith(
                            addTagIds: sel
                                ? [...actions.addTagIds, t.id]
                                : [
                                    for (final x in actions.addTagIds)
                                      if (x != t.id) x,
                                  ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Space.sm),
              ],
              TextField(
                controller: payee,
                decoration: InputDecoration(
                  labelText: l.rulesActPayee,
                  prefixIcon: const Icon(Icons.storefront_outlined),
                ),
                onChanged: (_) => onChanged(actions),
              ),
              const SizedBox(height: Space.sm),
              TextField(
                controller: note,
                decoration: InputDecoration(
                  labelText: l.rulesActNote,
                  prefixIcon: const Icon(Icons.notes),
                ),
                onChanged: (_) => onChanged(actions),
              ),
              const SizedBox(height: Space.sm),
              DropdownButtonFormField<TxnStatus?>(
                initialValue: actions.status,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.rulesActStatus),
                items: [
                  DropdownMenuItem(child: Text(l.rulesKeep)),
                  for (final s in TxnStatus.values)
                    DropdownMenuItem(value: s, child: Text(l.statusLabel(s))),
                ],
                onChanged: (s) => onChanged(actions.copyWith(status: s)),
              ),
              if (fields.isNotEmpty) ...[
                const SizedBox(height: Space.sm),
                Text(l.rulesActCustomFields, style: context.text.labelLarge),
                for (final f in fields)
                  _CustomFieldInput(
                    key: ValueKey(f.id),
                    def: f,
                    value: actions.customFields[f.id],
                    onChanged: (v) {
                      final next = {...actions.customFields};
                      if (v == null) {
                        next.remove(f.id);
                      } else {
                        next[f.id] = v;
                      }
                      onChanged(actions.copyWith(customFields: next));
                    },
                  ),
              ],
            ],
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.rulesOverwrite),
          subtitle: Text(l.rulesOverwriteHint),
          value: actions.overwrite,
          onChanged: (v) => onChanged(actions.copyWith(overwrite: v)),
        ),
      ],
    );
  }
}

class _CustomFieldInput extends StatefulWidget {
  const _CustomFieldInput({
    required this.def,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final CustomFieldDef def;
  final Object? value;
  final ValueChanged<Object?> onChanged;

  @override
  State<_CustomFieldInput> createState() => _CustomFieldInputState();
}

class _CustomFieldInputState extends State<_CustomFieldInput> {
  late final _c = TextEditingController(
    text: widget.value == null ? '' : '${widget.value}',
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  List<String> get _options {
    try {
      final v = widget.def.options;
      return [
        for (final m in RegExp(r'"((?:[^"\\]|\\.)*)"').allMatches(v)) m[1]!,
      ];
    } on FormatException {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = widget.def;
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: switch (d.type) {
        CustomFieldType.boolean => DropdownButtonFormField<bool?>(
          initialValue: widget.value is bool ? widget.value! as bool : null,
          decoration: InputDecoration(labelText: d.name),
          items: [
            DropdownMenuItem(child: Text(l.rulesKeep)),
            DropdownMenuItem(value: true, child: Text(l.rulesYes)),
            DropdownMenuItem(value: false, child: Text(l.rulesNo)),
          ],
          onChanged: widget.onChanged,
        ),
        CustomFieldType.select => DropdownButtonFormField<String?>(
          initialValue: _options.firstWhereOrNull((o) => o == widget.value),
          isExpanded: true,
          decoration: InputDecoration(labelText: d.name),
          items: [
            DropdownMenuItem(child: Text(l.rulesKeep)),
            for (final o in _options)
              DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: widget.onChanged,
        ),
        CustomFieldType.number => TextField(
          controller: _c,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: InputDecoration(labelText: d.name),
          onChanged: (v) {
            final minor = parseAmountInput(v);
            widget.onChanged(
              minor == null
                  ? null
                  : (minor % 100 == 0 ? minor ~/ 100 : minor / 100),
            );
          },
        ),
        CustomFieldType.text ||
        CustomFieldType.date ||
        CustomFieldType.multiselect => TextField(
          controller: _c,
          decoration: InputDecoration(
            labelText: d.name,
            helperText: d.type == CustomFieldType.date ? 'YYYY-MM-DD' : null,
          ),
          onChanged: (v) {
            final t = v.trim();
            if (t.isEmpty) {
              widget.onChanged(null);
            } else if (d.type == CustomFieldType.multiselect) {
              widget.onChanged([
                for (final p in t.split(','))
                  if (p.trim().isNotEmpty) p.trim(),
              ]);
            } else {
              widget.onChanged(t);
            }
          },
        ),
      },
    );
  }
}

/// Live "try with payee/amount" field.
class _TestCard extends ConsumerStatefulWidget {
  const _TestCard({required this.rule, this.initial});

  final RuleDef rule;
  final TxnDraft? initial;

  @override
  ConsumerState<_TestCard> createState() => _TestCardState();
}

class _TestCardState extends ConsumerState<_TestCard> {
  late final _payee = TextEditingController(text: widget.initial?.payee ?? '');
  late final _note = TextEditingController(text: widget.initial?.note ?? '');
  late final _amount = TextEditingController(
    text: widget.initial == null
        ? ''
        : formatAmountInput(widget.initial!.amountMinor),
  );

  @override
  void dispose() {
    _payee.dispose();
    _note.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final categories = ref.watch(categoryMapProvider);
    final tagNames = ref.watch(tagMapProvider);
    final amount = parseAmountInput(_amount.text) ?? 0;
    final draft = TxnDraft(
      accountId: widget.initial?.accountId ?? '',
      amountMinor: amount,
      date: DateTime.now(),
      type: amount > 0 ? TxnType.income : TxnType.expense,
      payee: _payee.text,
      note: _note.text,
    );
    final hasInput =
        _payee.text.isNotEmpty ||
        _note.text.isNotEmpty ||
        _amount.text.isNotEmpty;
    final matched =
        hasInput &&
        RuleEngine([widget.rule.copyWith(enabled: true)])
            .matches(widget.rule, draft);
    final outcome = DbRuleService.test(widget.rule, draft);
    final d = outcome.draft;
    final changes = <String>[
      for (final f in outcome.changed)
        switch (f) {
          RuleField.category =>
            '${l.rulesActCategory}: ${categories[d.categoryId] == null ? '?' : categoryPath(categories[d.categoryId]!, categories)}',
          RuleField.tags =>
            '${l.rulesActTags}: ${d.tagIds.map((t) => tagNames[t]?.name ?? '?').join(', ')}',
          RuleField.payee => '${l.rulesActPayee}: ${d.payee}',
          RuleField.note => '${l.rulesActNote}: ${d.note}',
          RuleField.status => '${l.rulesActStatus}: ${l.statusLabel(d.status)}',
          RuleField.customFields =>
            '${l.rulesActCustomFields}: ${d.customFields.length}',
        },
    ];
    final colors = context.colors;
    return SectionCard(
      padding: const EdgeInsets.all(Space.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.rulesTestHint, style: context.text.bodySmall),
          const SizedBox(height: Space.xs),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _payee,
                  decoration: InputDecoration(labelText: l.rulesFieldPayee),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _note,
                  decoration: InputDecoration(labelText: l.rulesFieldNote),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(labelText: l.rulesTestAmount),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          if (hasInput) ...[
            const SizedBox(height: Space.sm),
            Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    matched
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    color: matched ? colors.primary : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: Space.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          !matched
                              ? l.rulesTestNoMatch
                              : changes.isEmpty
                              ? l.rulesTestNoChange
                              : l.rulesTestMatch,
                          style: context.text.titleSmall,
                        ),
                        for (final c in changes) Text(c),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
