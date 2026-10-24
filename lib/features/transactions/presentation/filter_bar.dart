import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/transactions/domain/txn_filter.dart';
import 'package:personal_finance/features/transactions/presentation/quick_add_extras.dart';
import 'package:personal_finance/features/transactions/presentation/txn_labels.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// The filter chips row (date, account, category, type, tag, amount,
/// status, custom field). Active chips are tonal and show their value.
class TxnFilterBar extends ConsumerWidget {
  const TxnFilterBar({
    required this.filter,
    required this.onChanged,
    super.key,
    this.wrap = false,
    this.trailing,
  });

  final TxnFilter filter;
  final ValueChanged<TxnFilter> onChanged;

  /// Wrap onto several lines (wide screens) instead of scrolling.
  final bool wrap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    final accounts = ref.watch(accountMapProvider);
    final categories = ref.watch(categoryMapProvider);
    final tags = ref.watch(tagMapProvider);
    final defs = (ref.watch(customFieldDefsProvider).value ?? const [])
        .where((d) => d.appliesTo == 'transaction' && !d.archived)
        .toList();
    final fmt = ref.watch(moneyFormatterProvider);
    final dates = ref.watch(dateFormatsProvider);
    final tagsOn = settings.moduleEnabled(AppModule.tags);
    final cfOn = settings.moduleEnabled(AppModule.customFields);
    final height = wrap ? 36.0 : 32.0;

    String many(String label, Iterable<String?> names) {
      final list = names.nonNulls.toList();
      if (list.length == 1) return list.first;
      return l.txnChipCount(label, list.length);
    }

    final chips = <Widget>[
      if (filter.importBatchId != null)
        Center(
          widthFactor: 1,
          child: InputChip(
            avatar: const Icon(Icons.file_upload_outlined, size: 18),
            label: Text(l.txnImportBatchChip),
            selected: true,
            showCheckmark: false,
            deleteButtonTooltipMessage: l.txnClear,
            onDeleted: () => onChanged(filter.copyWith(importBatchId: null)),
          ),
        ),
      if (filter.hasPayee)
        Center(
          widthFactor: 1,
          child: InputChip(
            avatar: const Icon(Icons.storefront_outlined, size: 18),
            label: Text('${l.fieldPayee}: ${filter.payee!.trim()}'),
            selected: true,
            showCheckmark: false,
            deleteButtonTooltipMessage: l.txnClear,
            onDeleted: () => onChanged(filter.copyWith(payee: null)),
          ),
        ),
      TxnFilterChip(
        icon: Icons.calendar_today_outlined,
        label: filter.hasDate
            ? dateLabel(l, dates, filter)
            : l.txnFilterAllDates,
        active: filter.hasDate,
        height: height,
        onTap: () async {
          final f = await editDateFilter(context, filter);
          if (f != null) onChanged(f);
        },
      ),
      TxnFilterChip(
        label: filter.accountIds.isEmpty
            ? l.fieldAccount
            : many(
                l.fieldAccount,
                filter.accountIds.map((id) => accounts[id]?.name),
              ),
        active: filter.accountIds.isNotEmpty,
        height: height,
        onTap: () async {
          final ids = await showAccountMultiPicker(
            context,
            selected: filter.accountIds,
          );
          if (ids != null) onChanged(filter.copyWith(accountIds: ids));
        },
      ),
      TxnFilterChip(
        label: !filter.hasCategory
            ? l.fieldCategory
            : many(l.fieldCategory, [
                for (final id in filter.categoryIds) categories[id]?.name,
                if (filter.uncategorized) l.txnUncategorized,
              ]),
        active: filter.hasCategory,
        height: height,
        onTap: () async {
          final f = await showAdaptiveSheet<TxnFilter>(
            context,
            builder: (_) => _CategoryFilterSheet(filter: filter),
          );
          if (f != null) onChanged(f);
        },
      ),
      TxnFilterChip(
        label: filter.types.isEmpty
            ? l.txnFilterType
            : many(
                l.txnFilterType,
                filter.types.map((t) => TxnLabels.type(l, t)),
              ),
        active: filter.types.isNotEmpty,
        height: height,
        onTap: () async {
          final v = await showAdaptiveSheet<Set<TxnType>>(
            context,
            builder: (_) => _MultiChoiceSheet<TxnType>(
              values: TxnType.values,
              selected: filter.types,
              label: (t) => TxnLabels.type(l, t),
            ),
          );
          if (v != null) onChanged(filter.copyWith(types: v));
        },
      ),
      if (tagsOn)
        TxnFilterChip(
          label: filter.tagIds.isEmpty
              ? l.txnFilterTag
              : many(
                  l.txnFilterTag,
                  filter.tagIds.map(
                    (id) => tags[id] == null ? null : '#${tags[id]!.name}',
                  ),
                ),
          active: filter.tagIds.isNotEmpty,
          height: height,
          onTap: () async {
            final v = await showTagPicker(context, selected: filter.tagIds);
            if (v != null) onChanged(filter.copyWith(tagIds: v));
          },
        ),
      TxnFilterChip(
        label: !filter.hasAmount
            ? l.fieldAmount
            : amountLabel(l, fmt.minor, filter),
        active: filter.hasAmount,
        height: height,
        onTap: () async {
          final f = await showAdaptiveSheet<TxnFilter>(
            context,
            builder: (_) => _AmountFilterSheet(filter: filter),
          );
          if (f != null) onChanged(f);
        },
      ),
      TxnFilterChip(
        label: filter.statuses.isEmpty
            ? l.fieldStatus
            : many(
                l.fieldStatus,
                filter.statuses.map((s) => TxnLabels.status(l, s)),
              ),
        active: filter.statuses.isNotEmpty,
        height: height,
        onTap: () async {
          final v = await showAdaptiveSheet<Set<TxnStatus>>(
            context,
            builder: (_) => _MultiChoiceSheet<TxnStatus>(
              values: TxnStatus.values,
              selected: filter.statuses,
              label: (s) => TxnLabels.status(l, s),
            ),
          );
          if (v != null) onChanged(filter.copyWith(statuses: v));
        },
      ),
      if (cfOn && defs.isNotEmpty)
        TxnFilterChip(
          label: filter.customFields.isEmpty
              ? l.txnFilterCustomField
              : many(l.txnFilterCustomField, [
                  for (final c in filter.customFields)
                    defs.firstWhereOrNull((d) => d.id == c.fieldId)?.name,
                ]),
          active: filter.customFields.isNotEmpty,
          height: height,
          onTap: () async {
            final f = await showAdaptiveSheet<TxnFilter>(
              context,
              builder: (_) =>
                  _CustomFieldFilterSheet(filter: filter, defs: defs),
            );
            if (f != null) onChanged(f);
          },
        ),
      if (filter.activeCount > 0)
        TextButton.icon(
          onPressed: () => onChanged(TxnFilter(search: filter.search)),
          icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
          label: Text(l.txnClearFilters),
        ),
    ];

    if (wrap) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              spacing: Space.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: chips,
            ),
          ),
          ?trailing,
        ],
      );
    }
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
        children: [
          for (final c in chips)
            Padding(
              padding: const EdgeInsets.only(right: Space.xs),
              child: c,
            ),
          ?trailing,
        ],
      ),
    );
  }

  /// Label of the date facet ("October 2026", "Last 30 days", a range).
  static String dateLabel(AppLocalizations l, DateFormats f, TxnFilter filter) {
    final now = DateTime.now();
    switch (filter.datePreset) {
      case DatePreset.thisMonth:
        return f.monthYear(now);
      case DatePreset.lastMonth:
        return f.monthYear(DateTime(now.year, now.month - 1));
      case DatePreset.custom:
        final from = filter.dateFrom;
        final to = filter.dateTo;
        if (from != null && to != null) {
          return '${f.short(from)} – ${f.short(to)}';
        }
        if (from != null) return '≥ ${f.short(from)}';
        if (to != null) return '≤ ${f.short(to)}';
        return l.txnFilterAllDates;
      case null:
        return l.txnFilterAllDates;
      case final DatePreset p:
        return TxnLabels.preset(l, p);
    }
  }

  static String amountLabel(
    AppLocalizations l,
    String Function(int) money,
    TxnFilter f,
  ) {
    final min = f.minAmountMinor;
    final max = f.maxAmountMinor;
    if (min != null && max != null) return '${money(min)} – ${money(max)}';
    if (min != null) return l.txnAmountAtLeast(money(min));
    return l.txnAmountAtMost(money(max!));
  }
}

/// Opens the date facet menu. Returns the new filter or null.
Future<TxnFilter?> editDateFilter(
  BuildContext context,
  TxnFilter filter,
) async {
  final l = context.l10n;
  final choice = await showAdaptiveSheet<Object>(
    context,
    builder: (ctx) => ListView(
      shrinkWrap: true,
      children: [
        _choiceTile(ctx, l.txnFilterAllDates, 'all', filter.datePreset == null),
        for (final p in DatePreset.values)
          _choiceTile(ctx, TxnLabels.preset(l, p), p, filter.datePreset == p),
        const SizedBox(height: Space.xs),
      ],
    ),
  );
  if (choice == null || !context.mounted) return null;
  if (choice == 'all') return filter.withoutDate();
  if (choice == DatePreset.custom) {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 50),
      initialDateRange: filter.dateFrom != null && filter.dateTo != null
          ? DateTimeRange(start: filter.dateFrom!, end: filter.dateTo!)
          : null,
    );
    if (range == null) return null;
    return filter.copyWith(
      datePreset: DatePreset.custom,
      dateFrom: DateTime(range.start.year, range.start.month, range.start.day),
      dateTo: DateTime(range.end.year, range.end.month, range.end.day),
    );
  }
  return filter.copyWith(
    datePreset: choice as DatePreset,
    dateFrom: null,
    dateTo: null,
  );
}

Widget _choiceTile(
  BuildContext ctx,
  String label,
  Object value,
  bool selected,
) => ListTile(
  title: Text(label),
  selected: selected,
  trailing: selected ? const Icon(Icons.check) : null,
  onTap: () => Navigator.pop(ctx, value),
);

/// A filter chip as in the design: tonal when active, outlined otherwise,
/// with a chevron; 44 px touch target around a 32/36 px visual.
class TxnFilterChip extends StatelessWidget {
  const TxnFilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    super.key,
    this.icon,
    this.height = 32,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final fg = active ? cs.onSecondaryContainer : cs.onSurfaceVariant;
    return Semantics(
      button: true,
      toggled: active,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: SizedBox(
          height: 44,
          child: Center(
            widthFactor: 1,
            child: Container(
              height: height,
              padding: EdgeInsets.only(left: icon != null ? 8 : 12, right: 10),
              decoration: BoxDecoration(
                color: active ? cs.secondaryContainer : null,
                border: active ? null : Border.all(color: cs.outline),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 6),
                  ],
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: fg,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more, size: 16, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetActions extends StatelessWidget {
  const _SheetActions({required this.onApply, this.onClear});

  final VoidCallback onApply;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(Space.md),
      child: Row(
        children: [
          if (onClear != null)
            TextButton(onPressed: onClear, child: Text(l.txnClear)),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.commonCancel),
          ),
          const SizedBox(width: Space.xs),
          FilledButton(onPressed: onApply, child: Text(l.txnApply)),
        ],
      ),
    );
  }
}

class _MultiChoiceSheet<T> extends StatefulWidget {
  const _MultiChoiceSheet({
    required this.values,
    required this.selected,
    required this.label,
  });

  final List<T> values;
  final Set<T> selected;
  final String Function(T) label;

  @override
  State<_MultiChoiceSheet<T>> createState() => _MultiChoiceSheetState<T>();
}

class _MultiChoiceSheetState<T> extends State<_MultiChoiceSheet<T>> {
  late final Set<T> _sel = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final v in widget.values)
          CheckboxListTile(
            value: _sel.contains(v),
            title: Text(widget.label(v)),
            onChanged: (b) =>
                setState(() => b ?? false ? _sel.add(v) : _sel.remove(v)),
          ),
        _SheetActions(
          onClear: () => Navigator.pop(context, <T>{}),
          onApply: () => Navigator.pop(context, _sel),
        ),
      ],
    );
  }
}

class _CategoryFilterSheet extends ConsumerStatefulWidget {
  const _CategoryFilterSheet({required this.filter});

  final TxnFilter filter;

  @override
  ConsumerState<_CategoryFilterSheet> createState() =>
      _CategoryFilterSheetState();
}

class _CategoryFilterSheetState extends ConsumerState<_CategoryFilterSheet> {
  late Set<String> _ids = {...widget.filter.categoryIds};
  late bool _uncategorized = widget.filter.uncategorized;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final categories = ref.watch(categoryMapProvider);
    final names = [
      for (final id in _ids)
        if (categories[id] != null)
          (id, categoryPath(categories[id]!, categories)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          value: _uncategorized,
          title: Text(l.txnUncategorized),
          onChanged: (v) => setState(() => _uncategorized = v ?? false),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          child: Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              for (final (id, name) in names)
                InputChip(
                  label: Text(name),
                  onDeleted: () => setState(() => _ids.remove(id)),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: Text(l.txnChooseCategories),
                onPressed: () async {
                  final v = await showCategoryMultiPicker(
                    context,
                    selected: _ids,
                  );
                  if (v != null) setState(() => _ids = {...v});
                },
              ),
            ],
          ),
        ),
        _SheetActions(
          onClear: () => Navigator.pop(
            context,
            widget.filter.copyWith(categoryIds: {}, uncategorized: false),
          ),
          onApply: () => Navigator.pop(
            context,
            widget.filter.copyWith(
              categoryIds: _ids,
              uncategorized: _uncategorized,
            ),
          ),
        ),
      ],
    );
  }
}

class _AmountFilterSheet extends StatefulWidget {
  const _AmountFilterSheet({required this.filter});

  final TxnFilter filter;

  @override
  State<_AmountFilterSheet> createState() => _AmountFilterSheetState();
}

class _AmountFilterSheetState extends State<_AmountFilterSheet> {
  late int? _min = widget.filter.minAmountMinor;
  late int? _max = widget.filter.maxAmountMinor;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, 0),
          child: Row(
            children: [
              Expanded(
                child: MoneyField(
                  label: l.txnAmountMin,
                  initialMinor: _min,
                  autofocus: true,
                  onChanged: (v) => _min = v,
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: MoneyField(
                  label: l.txnAmountMax,
                  initialMinor: _max,
                  onChanged: (v) => _max = v,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, 0),
          child: Text(
            l.txnAmountHint,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        _SheetActions(
          onClear: () => Navigator.pop(
            context,
            widget.filter.copyWith(minAmountMinor: null, maxAmountMinor: null),
          ),
          onApply: () {
            var min = _min;
            var max = _max;
            if (min != null && max != null && min > max) {
              (min, max) = (max, min);
            }
            Navigator.pop(
              context,
              widget.filter.copyWith(minAmountMinor: min, maxAmountMinor: max),
            );
          },
        ),
      ],
    );
  }
}

class _CustomFieldFilterSheet extends StatefulWidget {
  const _CustomFieldFilterSheet({required this.filter, required this.defs});

  final TxnFilter filter;
  final List<CustomFieldDef> defs;

  @override
  State<_CustomFieldFilterSheet> createState() =>
      _CustomFieldFilterSheetState();
}

class _CustomFieldFilterSheetState extends State<_CustomFieldFilterSheet> {
  late final List<CustomFieldFilter> _conds = [...widget.filter.customFields];
  late String _fieldId = widget.defs.first.id;
  CustomFieldOp _op = CustomFieldOp.isSet;
  Object? _value;
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  CustomFieldDef get _def => widget.defs.firstWhere(
    (d) => d.id == _fieldId,
    orElse: () => widget.defs.first,
  );

  List<CustomFieldOp> _opsFor(CustomFieldType t) => switch (t) {
    CustomFieldType.text => const [CustomFieldOp.isSet, CustomFieldOp.contains],
    CustomFieldType.multiselect => const [
      CustomFieldOp.isSet,
      CustomFieldOp.includes,
    ],
    _ => const [CustomFieldOp.isSet, CustomFieldOp.equals],
  };

  String _opLabel(AppLocalizations l, CustomFieldOp op) => switch (op) {
    CustomFieldOp.isSet => l.txnCustomFieldAny,
    CustomFieldOp.equals || CustomFieldOp.matches => l.txnCustomFieldEquals,
    CustomFieldOp.contains => l.txnCustomFieldContains,
    CustomFieldOp.includes => l.txnCustomFieldIncludes,
  };

  String _condLabel(AppLocalizations l, CustomFieldFilter c) {
    final d = widget.defs.firstWhereOrNull((x) => x.id == c.fieldId);
    final name = d?.name ?? '?';
    if (c.op == CustomFieldOp.isSet) return '$name: ${l.txnCustomFieldAny}';
    final v = switch (c.value) {
      true => l.commonYes,
      false => l.commonNo,
      final Object? o => '$o',
    };
    return '$name ${_opLabel(l, c.op).toLowerCase()} $v';
  }

  Widget _valueInput(AppLocalizations l) {
    final d = _def;
    if (_op == CustomFieldOp.isSet) return const SizedBox.shrink();
    switch (d.type) {
      case CustomFieldType.select:
      case CustomFieldType.multiselect:
        final options = customFieldOptions(d);
        return DropdownButtonFormField<String>(
          initialValue: options.contains(_value) ? _value! as String : null,
          decoration: InputDecoration(labelText: l.txnCustomFieldValue),
          items: [
            for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: (v) => setState(() => _value = v),
        );
      case CustomFieldType.boolean:
        return SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: true, label: Text(l.commonYes)),
            ButtonSegment(value: false, label: Text(l.commonNo)),
          ],
          selected: {_value == true},
          onSelectionChanged: (v) => setState(() => _value = v.first),
        );
      case CustomFieldType.date:
        final parsed = _value is String
            ? DateTime.tryParse(_value! as String)
            : null;
        return OutlinedButton.icon(
          icon: const Icon(Icons.event_outlined),
          label: Text(
            parsed == null
                ? l.txnPickDate
                : MaterialLocalizations.of(context).formatMediumDate(parsed),
          ),
          onPressed: () async {
            final p = await showDatePicker(
              context: context,
              initialDate: parsed ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2200),
            );
            if (p != null) {
              setState(
                () => _value =
                    '${p.year.toString().padLeft(4, '0')}-'
                    '${p.month.toString().padLeft(2, '0')}-'
                    '${p.day.toString().padLeft(2, '0')}',
              );
            }
          },
        );
      case CustomFieldType.number:
      case CustomFieldType.text:
        return TextField(
          controller: _text,
          keyboardType: d.type == CustomFieldType.number
              ? const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                )
              : TextInputType.text,
          decoration: InputDecoration(labelText: l.txnCustomFieldValue),
          onChanged: (v) => setState(() {
            _value = d.type == CustomFieldType.number
                ? num.tryParse(v.trim().replaceAll(',', '.'))
                : (v.trim().isEmpty ? null : v.trim());
          }),
        );
    }
  }

  bool get _canAdd => _op == CustomFieldOp.isSet || _value != null;

  void _add() {
    setState(() {
      _conds.add(
        CustomFieldFilter(
          fieldId: _fieldId,
          op: _op,
          value: _op == CustomFieldOp.isSet ? null : _value,
        ),
      );
      _op = CustomFieldOp.isSet;
      _value = null;
      _text.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ops = _opsFor(_def.type);
    if (!ops.contains(_op)) _op = ops.first;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_conds.isNotEmpty)
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                for (var i = 0; i < _conds.length; i++)
                  InputChip(
                    label: Text(_condLabel(l, _conds[i])),
                    onDeleted: () => setState(() => _conds.removeAt(i)),
                  ),
              ],
            ),
          const SizedBox(height: Space.sm),
          DropdownButtonFormField<String>(
            initialValue: _fieldId,
            decoration: InputDecoration(labelText: l.txnCustomFieldChoose),
            items: [
              for (final d in widget.defs)
                DropdownMenuItem(value: d.id, child: Text(d.name)),
            ],
            onChanged: (v) => setState(() {
              _fieldId = v ?? _fieldId;
              _value = null;
              _text.clear();
            }),
          ),
          const SizedBox(height: Space.sm),
          SegmentedButton<CustomFieldOp>(
            showSelectedIcon: false,
            segments: [
              for (final op in ops)
                ButtonSegment(value: op, label: Text(_opLabel(l, op))),
            ],
            selected: {_op},
            onSelectionChanged: (v) => setState(() {
              _op = v.first;
              _value = null;
              _text.clear();
            }),
          ),
          const SizedBox(height: Space.sm),
          _valueInput(l),
          const SizedBox(height: Space.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _canAdd ? _add : null,
              icon: const Icon(Icons.add),
              label: Text(l.txnCustomFieldAdd),
            ),
          ),
          _SheetActions(
            onClear: () => Navigator.pop(
              context,
              widget.filter.copyWith(customFields: const []),
            ),
            onApply: () {
              final all = [..._conds];
              if (_op != CustomFieldOp.isSet && _value != null) {
                all.add(
                  CustomFieldFilter(fieldId: _fieldId, op: _op, value: _value),
                );
              }
              Navigator.pop(context, widget.filter.copyWith(customFields: all));
            },
          ),
        ],
      ),
    );
  }
}
