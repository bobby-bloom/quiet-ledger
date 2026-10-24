import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/money/money_input.dart';
import 'package:personal_finance/features/forecast/domain/forecast_dates.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_format.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_providers.dart';
import 'package:personal_finance/features/scenarios/data/scenario_repository.dart';
import 'package:personal_finance/features/scenarios/domain/scenario.dart';
import 'package:personal_finance/features/scenarios/presentation/scenario_labels.dart';

/// Edits one adjustment in a sheet (phone) or dialog (larger screens).
/// Returns the new adjustment, or null when cancelled.
Future<ScenarioAdjustment?> showAdjustmentForm(
  BuildContext context, {
  required AdjustmentKind kind,
  ScenarioAdjustment? initial,
}) => showAdaptiveSheet<ScenarioAdjustment>(
  context,
  builder: (_) => AdjustmentForm(kind: kind, initial: initial),
);

class AdjustmentForm extends ConsumerStatefulWidget {
  const AdjustmentForm({required this.kind, super.key, this.initial});

  final AdjustmentKind kind;
  final ScenarioAdjustment? initial;

  @override
  ConsumerState<AdjustmentForm> createState() => _AdjustmentFormState();
}

class _AdjustmentFormState extends ConsumerState<AdjustmentForm> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _percent = TextEditingController();
  late DateTime _date;
  DateTime? _end;
  int? _amount;
  bool _income = false;
  String? _accountId;
  String? _transferTo;
  String? _categoryId;
  String? _ruleId;
  ChangeMode _mode = ChangeMode.percent;
  ScenarioFrequency _frequency = ScenarioFrequency.monthly;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final today = ref.read(forecastTodayProvider);
    _date = DateTime(today.year, today.month + 1);
    final locale = ref.read(formatLocaleProvider);
    switch (widget.initial) {
      case final OneOffAdjustment a:
        _label.text = a.label;
        _date = a.date;
        _amount = a.amountMinor.abs();
        _income = a.amountMinor > 0;
        _accountId = a.accountId;
      case final CategoryChangeAdjustment a:
        _categoryId = a.categoryId;
        _date = a.from;
        _mode = a.mode;
        _setValue(a.mode, a.value, locale);
      case final RecurringChangeAdjustment a:
        _ruleId = a.ruleId;
        _date = a.from;
        _mode = a.mode;
        _setValue(a.mode, a.value, locale);
      case final AddRecurringAdjustment a:
        _label.text = a.label;
        _date = a.start;
        _end = a.end;
        _amount = a.amountMinor.abs();
        _income = a.amountMinor > 0;
        _accountId = a.accountId;
        _transferTo = a.transferAccountId;
        _categoryId = a.categoryId;
        _frequency = frequencyOf(a.rrule) ?? ScenarioFrequency.monthly;
      case final EndRecurringAdjustment a:
        _ruleId = a.ruleId;
        _date = a.from;
      case final ReturnAdjustment a:
        _accountId = a.accountId;
        _percent.text = bpInput(a.returnBp, locale);
      case final InflationAdjustment a:
        _percent.text = bpInput(a.inflationBp, locale);
      case UnknownAdjustment() || null:
        break;
    }
  }

  void _setValue(ChangeMode mode, int value, String locale) {
    if (mode == ChangeMode.percent) {
      _percent.text = bpInput(value, locale);
    } else {
      _amount = value;
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _percent.dispose();
    super.dispose();
  }

  int? get _bp => parseAmountInput(_percent.text);

  ScenarioAdjustment? _build() {
    int signed(int v) => _income ? v.abs() : -v.abs();
    switch (widget.kind) {
      case AdjustmentKind.oneOff:
        if (_amount == null || _amount == 0 || _accountId == null) return null;
        return OneOffAdjustment(
          date: _date,
          amountMinor: signed(_amount!),
          accountId: _accountId!,
          label: _label.text.trim(),
        );
      case AdjustmentKind.category:
        final v = _mode == ChangeMode.percent ? _bp : _amount;
        if (_categoryId == null || v == null || v == 0) return null;
        return CategoryChangeAdjustment(
          categoryId: _categoryId!,
          from: _date,
          mode: _mode,
          value: v,
        );
      case AdjustmentKind.recurringChange:
        final v = _mode == ChangeMode.percent ? _bp : _amount;
        if (_ruleId == null || v == null || v == 0) return null;
        return RecurringChangeAdjustment(
          ruleId: _ruleId!,
          from: _date,
          mode: _mode,
          value: v,
        );
      case AdjustmentKind.addRecurring:
        if (_amount == null || _amount == 0 || _accountId == null) return null;
        final transfer = _transferTo != null && _transferTo != _accountId;
        return AddRecurringAdjustment(
          label: _label.text.trim(),
          rrule: rruleFor(_frequency, _date),
          start: _date,
          end: _end,
          amountMinor: transfer ? -_amount!.abs() : signed(_amount!),
          accountId: _accountId!,
          transferAccountId: transfer ? _transferTo : null,
          categoryId: transfer ? null : _categoryId,
        );
      case AdjustmentKind.endRecurring:
        if (_ruleId == null) return null;
        return EndRecurringAdjustment(ruleId: _ruleId!, from: _date);
      case AdjustmentKind.returnRate:
        final v = _bp;
        if (v == null) return null;
        return ReturnAdjustment(returnBp: v, accountId: _accountId);
      case AdjustmentKind.inflation:
        final v = _bp;
        if (v == null) return null;
        return InflationAdjustment(inflationBp: v);
    }
  }

  void _submit() {
    setState(() => _submitted = true);
    if (!(_form.currentState?.validate() ?? false)) return;
    final a = _build();
    if (a != null) Navigator.pop(context, a);
  }

  Future<void> _pickDate({bool end = false}) async {
    final today = ref.read(forecastTodayProvider);
    final initial = end ? (_end ?? addMonthsClamped(_date, 12)) : _date;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(today.year - 5),
      lastDate: DateTime(today.year + 40, 12, 31),
    );
    if (d == null) return;
    setState(() => end ? _end = dayOf(d) : _date = dayOf(d));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = widget.kind;
    final fields = <Widget>[
      if (k == AdjustmentKind.oneOff || k == AdjustmentKind.addRecurring)
        TextFormField(
          controller: _label,
          decoration: InputDecoration(labelText: l.scenariosFieldLabel),
          textCapitalization: TextCapitalization.sentences,
        ),
      if (k == AdjustmentKind.oneOff ||
          (k == AdjustmentKind.addRecurring && _transferTo == null))
        _incomeToggle(),
      if (k == AdjustmentKind.oneOff || k == AdjustmentKind.addRecurring)
        MoneyField(
          key: const ValueKey('amount'),
          label: l.scenariosFieldAmount,
          initialMinor: _amount,
          onChanged: (v) => _amount = v,
          validator: (v) =>
              v == null || v == 0 ? l.forecastWhatIfEnterAmount : null,
        ),
      if (k == AdjustmentKind.category) _categoryField(),
      if (k == AdjustmentKind.recurringChange ||
          k == AdjustmentKind.endRecurring)
        _ruleField(),
      if (k == AdjustmentKind.category || k == AdjustmentKind.recurringChange)
        ..._changeFields(perMonth: k == AdjustmentKind.category),
      if (k == AdjustmentKind.addRecurring)
        DropdownButtonFormField<ScenarioFrequency>(
          initialValue: _frequency,
          decoration: InputDecoration(labelText: l.scenariosFieldRepeats),
          items: [
            for (final f in ScenarioFrequency.values)
              DropdownMenuItem(value: f, child: Text(frequencyLabel(l, f))),
          ],
          onChanged: (f) => setState(() => _frequency = f ?? _frequency),
        ),
      if (k != AdjustmentKind.returnRate && k != AdjustmentKind.inflation)
        _dateField(
          k == AdjustmentKind.oneOff
              ? l.scenariosFieldDate
              : l.scenariosFieldFrom,
          _date,
          _pickDate,
        ),
      if (k == AdjustmentKind.addRecurring)
        _dateField(
          l.scenariosFieldUntil,
          _end,
          () => _pickDate(end: true),
          onClear: _end == null ? null : () => setState(() => _end = null),
        ),
      if (k == AdjustmentKind.oneOff || k == AdjustmentKind.addRecurring)
        _accountField(
          l.scenariosFieldAccount,
          _accountId,
          (id) => setState(() => _accountId = id),
          required: true,
        ),
      if (k == AdjustmentKind.addRecurring)
        _accountField(
          l.scenariosFieldTransferTo,
          _transferTo,
          (id) => setState(() => _transferTo = id),
          onClear: _transferTo == null
              ? null
              : () => setState(() => _transferTo = null),
        ),
      if (k == AdjustmentKind.addRecurring && _transferTo == null)
        _categoryField(required: false),
      if (k == AdjustmentKind.returnRate) _returnAccountField(),
      if (k == AdjustmentKind.returnRate || k == AdjustmentKind.inflation)
        _percentField(
          k == AdjustmentKind.returnRate
              ? l.scenariosFieldReturn
              : l.scenariosFieldInflation,
          allowZero: true,
        ),
    ];
    return Form(
      key: _form,
      autovalidateMode: _submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              children: [
                Icon(kindIcon(k), color: context.colors.primary),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(kindLabel(l, k), style: context.text.titleLarge),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final f in fields) ...[
                    f,
                    const SizedBox(height: Space.sm),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.commonCancel),
                ),
                const SizedBox(width: Space.xs),
                FilledButton(onPressed: _submit, child: Text(l.commonDone)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _incomeToggle() => SegmentedButton<bool>(
    segments: [
      ButtonSegment(value: false, label: Text(context.l10n.typeExpense)),
      ButtonSegment(value: true, label: Text(context.l10n.typeIncome)),
    ],
    selected: {_income},
    onSelectionChanged: (v) => setState(() => _income = v.first),
  );

  List<Widget> _changeFields({required bool perMonth}) {
    final t = context.l10n;
    return [
      Text(t.scenariosFieldChangeBy, style: context.text.labelLarge),
      SegmentedButton<ChangeMode>(
        segments: [
          ButtonSegment(
            value: ChangeMode.percent,
            label: Text(t.scenariosModePercent),
          ),
          ButtonSegment(
            value: ChangeMode.absolute,
            label: Text(t.scenariosModeAmount),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: (v) => setState(() => _mode = v.first),
      ),
      if (_mode == ChangeMode.percent)
        _percentField(t.scenariosFieldPercent)
      else
        MoneyField(
          key: const ValueKey('delta'),
          label: perMonth
              ? t.scenariosFieldDeltaMonthly
              : t.scenariosFieldDeltaEach,
          initialMinor: _amount,
          allowNegative: true,
          onChanged: (v) => _amount = v,
          validator: (v) =>
              v == null || v == 0 ? t.scenariosInvalidNumber : null,
        ),
    ];
  }

  Widget _percentField(String label, {bool allowZero = false}) {
    final l = context.l10n;
    return TextFormField(
      controller: _percent,
      decoration: InputDecoration(labelText: label, suffixText: '%'),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-−+]')),
      ],
      textAlign: TextAlign.end,
      validator: (v) {
        final bp = parseAmountInput(v ?? '');
        if (bp == null) return l.scenariosInvalidNumber;
        if (!allowZero && bp == 0) return l.scenariosInvalidNumber;
        if (bp.abs() > 100000) return l.scenariosInvalidNumber;
        return null;
      },
    );
  }

  Widget _dateField(
    String label,
    DateTime? value,
    VoidCallback onTap, {
    VoidCallback? onClear,
  }) {
    final dates = ref.watch(dateFormatsProvider);
    return _PickerField(
      label: label,
      value: value == null ? null : dates.medium(value),
      icon: Icons.event_outlined,
      onTap: onTap,
      onClear: onClear,
    );
  }

  Widget _accountField(
    String label,
    String? value,
    ValueChanged<String> onPicked, {
    bool required = false,
    VoidCallback? onClear,
  }) {
    final l = context.l10n;
    final accounts = ref.watch(accountMapProvider);
    return FormField<String>(
      validator: (_) => required && value == null ? l.scenariosRequired : null,
      builder: (state) => _PickerField(
        label: label,
        value: value == null ? null : accounts[value]?.name,
        icon: Icons.account_balance_outlined,
        error: state.errorText,
        onClear: onClear,
        onTap: () async {
          final id = await showAccountPicker(context, selectedId: value);
          if (id != null) {
            onPicked(id);
            state.didChange(id);
          }
        },
      ),
    );
  }

  Widget _returnAccountField() {
    final t = context.l10n;
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    return DropdownButtonFormField<String?>(
      initialValue: _accountId,
      isExpanded: true,
      decoration: InputDecoration(labelText: t.scenariosFieldAccount),
      items: [
        DropdownMenuItem<String?>(child: Text(t.scenariosAllInvestments)),
        for (final a in accounts)
          if (!a.archived && !a.type.isLiability)
            DropdownMenuItem<String?>(value: a.id, child: Text(a.name)),
      ],
      onChanged: (v) => setState(() => _accountId = v),
    );
  }

  Widget _categoryField({bool required = true}) {
    final t = context.l10n;
    final categories = ref.watch(categoryMapProvider);
    return FormField<String>(
      validator: (_) =>
          required && _categoryId == null ? t.scenariosRequired : null,
      builder: (state) => _PickerField(
        label: t.scenariosFieldCategory,
        value: _categoryId == null
            ? null
            : (categories[_categoryId] == null
                  ? null
                  : categoryPath(categories[_categoryId]!, categories)),
        icon: Icons.category_outlined,
        error: state.errorText,
        onClear: !required && _categoryId != null
            ? () => setState(() => _categoryId = null)
            : null,
        onTap: () async {
          final id = await showCategoryPicker(context, selectedId: _categoryId);
          if (id != null && id.isNotEmpty) {
            setState(() => _categoryId = id);
            state.didChange(id);
          }
        },
      ),
    );
  }

  Widget _ruleField() {
    final t = context.l10n;
    final rules =
        ref.watch(recurringRuleOptionsProvider).value ?? const <RuleOption>[];
    if (rules.isEmpty) {
      return Text(
        t.scenariosNoRules,
        style: context.text.bodyMedium?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      );
    }
    final fmt = ref.watch(moneyFormatterProvider);
    return DropdownButtonFormField<String>(
      initialValue: rules.any((r) => r.id == _ruleId) ? _ruleId : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: t.scenariosFieldRule),
      validator: (v) => v == null ? t.scenariosRequired : null,
      items: [
        for (final r in rules)
          DropdownMenuItem(
            value: r.id,
            child: Text(
              r.amountMinor == 0
                  ? r.name
                  : '${r.name} · ${fmt.minor(r.amountMinor)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (v) => setState(() => _ruleId = v),
    );
  }
}

/// A tappable field that opens a picker.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
    this.error,
  });

  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      button: true,
      label: '$label: ${value ?? l.scenariosChoose}',
      excludeSemantics: onClear == null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InputDecorator(
          isEmpty: value == null,
          decoration: InputDecoration(
            labelText: label,
            errorText: error,
            hintText: l.scenariosChoose,
            suffixIcon: onClear != null
                ? IconButton(
                    tooltip: l.commonReset,
                    icon: const Icon(Icons.close),
                    onPressed: onClear,
                  )
                : Icon(icon, size: 20),
          ),
          child: value == null
              ? null
              : Text(value!, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
