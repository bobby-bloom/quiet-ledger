import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/reports/data/report_queries.dart';
import 'package:personal_finance/features/reports/domain/report_models.dart';
import 'package:personal_finance/features/reports/presentation/report_format.dart';
import 'package:personal_finance/features/reports/presentation/report_providers.dart';

/// Period (presets, custom range, previous/next), accounts, tags and custom
/// field filters plus the "include excluded" toggle of one report.
class ReportFilterBar extends ConsumerWidget {
  const ReportFilterBar({required this.type, super.key});

  final ReportType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(reportViewProvider(type));
    final ctrl = ref.read(reportViewProvider(type).notifier);
    final fmt = ReportFormat.of(context, ref);
    final settings = ref.watch(settingsProvider);
    final tagsOn = settings.moduleEnabled(AppModule.tags);
    final fieldsOn = settings.moduleEnabled(AppModule.customFields);
    final exclusions = ref.watch(reportExclusionsProvider);
    final f = s.filter;
    final isNetWorth = type == ReportType.netWorth;

    return Wrap(
      spacing: Space.xs,
      runSpacing: Space.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l.reportsPreviousPeriod,
              icon: const Icon(Icons.chevron_left),
              onPressed: () => ctrl.step(-1),
            ),
            Flexible(
              child: _PeriodButton(
                label: fmt.range(s.range),
                selected: s.preset,
                onPreset: ctrl.setPreset,
                onCustom: () async {
                  final r = await _pickRange(context, s.range);
                  if (r != null) ctrl.setRange(r);
                },
              ),
            ),
            IconButton(
              tooltip: l.reportsNextPeriod,
              icon: const Icon(Icons.chevron_right),
              onPressed: () => ctrl.step(1),
            ),
          ],
        ),
        FilterChip(
          avatar: const Icon(Icons.account_balance_outlined, size: 18),
          label: Text(
            f.accountIds.isEmpty
                ? l.reportsAllAccounts
                : l.reportsAccountsCount(f.accountIds.length),
          ),
          selected: f.accountIds.isNotEmpty,
          showCheckmark: false,
          onSelected: (_) async {
            final ids = await showAccountMultiPicker(
              context,
              selected: f.accountIds,
            );
            if (ids != null) ctrl.setAccounts(ids);
          },
        ),
        if (tagsOn && !isNetWorth)
          FilterChip(
            avatar: const Icon(Icons.sell_outlined, size: 18),
            label: Text(
              f.tagIds.isEmpty
                  ? l.reportsAllTags
                  : l.reportsTagsCount(f.tagIds.length),
            ),
            selected: f.tagIds.isNotEmpty,
            showCheckmark: false,
            onSelected: (_) async {
              final ids = await showAdaptiveSheet<Set<String>>(
                context,
                builder: (_) => _TagPicker(selected: f.tagIds),
              );
              if (ids != null) ctrl.setTags(ids);
            },
          ),
        if (fieldsOn && !isNetWorth)
          _CustomFieldChip(
            filter: f.customField,
            onChanged: ctrl.setCustomField,
          ),
        if (!exclusions.isEmpty)
          Tooltip(
            message: l.reportsIncludeExcludedHint,
            child: FilterChip(
              label: Text(l.reportsIncludeExcluded),
              selected: s.includeExcluded,
              onSelected: (v) => ctrl.setIncludeExcluded(value: v),
            ),
          ),
        if (f.hasNarrowing || s.includeExcluded)
          TextButton(
            onPressed: ctrl.clearNarrowing,
            child: Text(l.reportsClearFilters),
          ),
      ],
    );
  }

  static Future<DateRange?> _pickRange(
    BuildContext context,
    DateRange current,
  ) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: current.start, end: current.last),
    );
    if (picked == null) return null;
    final s = picked.start;
    final e = picked.end;
    return DateRange(
      DateTime(s.year, s.month, s.day),
      DateTime(e.year, e.month, e.day + 1),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.label,
    required this.selected,
    required this.onPreset,
    required this.onCustom,
  });

  final String label;
  final ReportPeriod? selected;
  final ValueChanged<ReportPeriod> onPreset;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return MenuAnchor(
      menuChildren: [
        for (final p in ReportPeriod.values)
          MenuItemButton(
            leadingIcon: Icon(p == selected ? Icons.check : null, size: 18),
            onPressed: () => onPreset(p),
            child: Text(reportPeriodLabel(l, p)),
          ),
        const Divider(height: 1),
        MenuItemButton(
          leadingIcon: const Icon(Icons.date_range_outlined, size: 18),
          onPressed: onCustom,
          child: Text(l.reportsCustomRange),
        ),
      ],
      builder: (context, controller, _) => Semantics(
        label: l.reportsPeriod,
        button: true,
        child: OutlinedButton.icon(
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, Space.minTouch),
          ),
        ),
      ),
    );
  }
}

class _TagPicker extends ConsumerStatefulWidget {
  const _TagPicker({required this.selected});

  final Set<String> selected;

  @override
  ConsumerState<_TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends ConsumerState<_TagPicker> {
  late final Set<String> _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tags = (ref.watch(tagsProvider).value ?? const <Tag>[])
        .where((t) => !t.archived || widget.selected.contains(t.id))
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: tags.isEmpty
              ? EmptyState(message: l.commonEmpty)
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final t in tags)
                      CheckboxListTile(
                        value: _selected.contains(t.id),
                        title: Text(t.name),
                        onChanged: (_) => setState(
                          () => _selected.contains(t.id)
                              ? _selected.remove(t.id)
                              : _selected.add(t.id),
                        ),
                      ),
                  ],
                ),
        ),
        _SheetActions(onDone: () => Navigator.pop(context, _selected)),
      ],
    );
  }
}

class _SheetActions extends StatelessWidget {
  const _SheetActions({required this.onDone, this.onClear});

  final VoidCallback onDone;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(Space.md),
      child: Row(
        children: [
          if (onClear != null)
            TextButton(onPressed: onClear, child: Text(l.commonReset)),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.commonCancel),
          ),
          const SizedBox(width: Space.xs),
          FilledButton(onPressed: onDone, child: Text(l.commonDone)),
        ],
      ),
    );
  }
}

// --------------------------------------------------------- custom field ---

/// Display text of a custom field filter value.
String customFieldValueText(BuildContext context, Object value) =>
    switch (value) {
      final bool b => b ? context.l10n.commonYes : context.l10n.commonNo,
      final DateTime d => MaterialLocalizations.of(context).formatShortDate(d),
      _ => '$value',
    };

class _CustomFieldChip extends ConsumerWidget {
  const _CustomFieldChip({required this.filter, required this.onChanged});

  final CustomFieldFilter? filter;
  final ValueChanged<CustomFieldFilter?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final defs = ref.watch(customFieldDefsProvider).value ?? const [];
    final f = filter;
    final def = f == null
        ? null
        : defs.where((d) => d.id == f.fieldId).firstOrNull;
    return FilterChip(
      avatar: const Icon(Icons.tune_outlined, size: 18),
      label: Text(
        f == null
            ? l.reportsCustomField
            : l.reportsCustomFieldValue(
                def?.name ?? l.reportsCustomField,
                customFieldValueText(context, f.value),
              ),
      ),
      selected: f != null,
      showCheckmark: false,
      onSelected: (_) async {
        final r = await showAdaptiveSheet<_FieldResult>(
          context,
          builder: (_) => _CustomFieldSheet(initial: f),
        );
        if (r != null) onChanged(r.filter);
      },
    );
  }
}

class _FieldResult {
  const _FieldResult(this.filter);

  final CustomFieldFilter? filter;
}

class _CustomFieldSheet extends ConsumerStatefulWidget {
  const _CustomFieldSheet({this.initial});

  final CustomFieldFilter? initial;

  @override
  ConsumerState<_CustomFieldSheet> createState() => _CustomFieldSheetState();
}

class _CustomFieldSheetState extends ConsumerState<_CustomFieldSheet> {
  late String? _fieldId = widget.initial?.fieldId;
  late Object? _value = widget.initial?.value;
  late final _text = TextEditingController(
    text: widget.initial?.value is String || widget.initial?.value is num
        ? '${widget.initial!.value}'
        : '',
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  List<String> _options(CustomFieldDef d) {
    try {
      return [for (final o in jsonDecode(d.options) as List) '$o'];
    } on Object {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final defs = (ref.watch(customFieldDefsProvider).value ?? const [])
        .where(
          (d) =>
              d.appliesTo == 'transaction' &&
              (!d.archived || d.id == widget.initial?.fieldId),
        )
        .toList();
    final def = defs.where((d) => d.id == _fieldId).firstOrNull;

    Widget valueEditor(CustomFieldDef d) {
      switch (d.type) {
        case CustomFieldType.select:
        case CustomFieldType.multiselect:
          final options = _options(d);
          return DropdownButtonFormField<String>(
            initialValue: options.contains(_value) ? _value! as String : null,
            decoration: InputDecoration(labelText: l.reportsFieldValue),
            items: [
              for (final o in options)
                DropdownMenuItem(value: o, child: Text(o)),
            ],
            onChanged: (v) => setState(() => _value = v),
          );
        case CustomFieldType.boolean:
          return SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(l.commonYes)),
              ButtonSegment(value: false, label: Text(l.commonNo)),
            ],
            emptySelectionAllowed: true,
            selected: {if (_value is bool) _value! as bool},
            onSelectionChanged: (v) =>
                setState(() => _value = v.isEmpty ? null : v.first),
          );
        case CustomFieldType.date:
          final current = _value is DateTime ? _value! as DateTime : null;
          return OutlinedButton.icon(
            icon: const Icon(Icons.event_outlined),
            label: Text(
              current == null
                  ? l.reportsFieldValue
                  : customFieldValueText(context, current),
            ),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                firstDate: DateTime(1970),
                lastDate: DateTime(2100),
                initialDate: current ?? DateTime.now(),
              );
              if (d != null) setState(() => _value = d);
            },
          );
        case CustomFieldType.number:
        case CustomFieldType.text:
          final number = d.type == CustomFieldType.number;
          return TextField(
            controller: _text,
            keyboardType: number
                ? const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  )
                : TextInputType.text,
            decoration: InputDecoration(labelText: l.reportsFieldValue),
            onChanged: (v) => setState(() {
              final t = v.trim();
              if (t.isEmpty) {
                _value = null;
              } else if (number) {
                _value = num.tryParse(t.replaceAll(',', '.'));
              } else {
                _value = t;
              }
            }),
          );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.lg,
            Space.lg,
            Space.xs,
          ),
          child: Text(l.reportsCustomField, style: context.text.titleMedium),
        ),
        if (defs.isEmpty)
          EmptyState(message: l.reportsNoFields)
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: def?.id,
                  decoration: InputDecoration(labelText: l.reportsChooseField),
                  items: [
                    for (final d in defs)
                      DropdownMenuItem(value: d.id, child: Text(d.name)),
                  ],
                  onChanged: (v) => setState(() {
                    _fieldId = v;
                    _value = null;
                    _text.clear();
                  }),
                ),
                const SizedBox(height: Space.md),
                if (def != null) valueEditor(def),
              ],
            ),
          ),
        _SheetActions(
          onClear: () => Navigator.pop(context, const _FieldResult(null)),
          onDone: () {
            final id = _fieldId;
            final v = _value;
            Navigator.pop(
              context,
              _FieldResult(
                id == null || v == null
                    ? null
                    : CustomFieldFilter(fieldId: id, value: v),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Report-specific options (expense/income, interval, sorting, trend
/// categories).
class ReportOptionsBar extends ConsumerWidget {
  const ReportOptionsBar({required this.type, super.key});

  final ReportType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(reportViewProvider(type));
    final ctrl = ref.read(reportViewProvider(type).notifier);

    Widget kind() => SegmentedButton<CategoryKind>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: CategoryKind.expense, label: Text(l.typeExpense)),
        ButtonSegment(value: CategoryKind.income, label: Text(l.typeIncome)),
      ],
      selected: {s.kind},
      onSelectionChanged: (v) => ctrl.setKind(v.first),
    );

    Widget interval() {
      final budgetsOn = ref.watch(
        settingsProvider.select((x) => x.moduleEnabled(AppModule.budgets)),
      );
      return SegmentedButton<ReportInterval>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: ReportInterval.month,
            label: Text(l.reportsIntervalMonth),
          ),
          ButtonSegment(
            value: ReportInterval.quarter,
            label: Text(l.reportsIntervalQuarter),
          ),
          ButtonSegment(
            value: ReportInterval.year,
            label: Text(l.reportsIntervalYear),
          ),
          if (budgetsOn)
            ButtonSegment(
              value: ReportInterval.budgetPeriod,
              label: Text(l.reportsIntervalBudgetPeriod),
            ),
        ],
        selected: {s.interval},
        onSelectionChanged: (v) => ctrl.setInterval(v.first),
      );
    }

    final children = <Widget>[
      switch (type) {
        ReportType.spending || ReportType.comparison => kind(),
        ReportType.incomeExpense || ReportType.categoryTrend => interval(),
        ReportType.topPayees => SegmentedButton<PayeeSort>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: PayeeSort.total,
              label: Text(l.reportsSortTotal),
            ),
            ButtonSegment(
              value: PayeeSort.count,
              label: Text(l.reportsSortCount),
            ),
            ButtonSegment(
              value: PayeeSort.average,
              label: Text(l.reportsSortAverage),
            ),
          ],
          selected: {s.payeeSort},
          onSelectionChanged: (v) => ctrl.setPayeeSort(v.first),
        ),
        ReportType.netWorth => const SizedBox.shrink(),
      },
      if (type == ReportType.categoryTrend)
        OutlinedButton.icon(
          icon: const Icon(Icons.category_outlined, size: 18),
          label: Text(
            s.trendCategoryIds.isEmpty
                ? l.reportsTopCategoriesAuto
                : '${l.reportsChooseCategories} (${s.trendCategoryIds.length})',
          ),
          onPressed: () async {
            final ids = await showCategoryMultiPicker(
              context,
              selected: s.trendCategoryIds.toSet(),
            );
            if (ids != null) {
              // Keep the existing order (series colours follow it).
              final kept = s.trendCategoryIds.where(ids.contains).toList();
              ctrl.setTrendCategories([
                ...kept,
                ...ids.where((x) => !kept.contains(x)),
              ]);
            }
          },
        ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final c in children) ...[c, const SizedBox(width: Space.xs)],
        ],
      ),
    );
  }
}
