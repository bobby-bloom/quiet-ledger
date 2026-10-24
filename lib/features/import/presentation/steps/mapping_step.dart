import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/features/import/domain/balance_checker.dart';
import 'package:personal_finance/features/import/domain/import_analysis.dart';
import 'package:personal_finance/features/import/domain/import_config.dart';
import 'package:personal_finance/features/import/domain/raw_sheet.dart';
import 'package:personal_finance/features/import/domain/row_parser.dart';
import 'package:personal_finance/features/import/presentation/import_labels.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_controller.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_screen.dart';
import 'package:personal_finance/features/import/presentation/sheet_preview_grid.dart';
import 'package:personal_finance/features/import/presentation/steps/step_common.dart';

/// Step 4: what each column is (design: ImportMapping board).
class MappingStep extends ConsumerWidget {
  const MappingStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(importWizardProvider);
    final c = ref.read(importWizardProvider.notifier);
    final cur = s.currentSheet;
    final parsed = ref.watch(currentSheetPreviewProvider);
    if (cur == null || parsed == null) return const SizedBox.shrink();
    final (wb, sheet, cfg) = cur;
    final fields = s.context?.customFields ?? const <ExistingField>[];
    final headers = parsed.headers;

    final detail = [
      l.importRows(sheet.rowCount),
      if (cfg.headerRow >= 0)
        l.importInfoHeaderRow(cfg.headerRow + 1)
      else
        l.importInfoNoHeader,
      if (parsed.count(RowClass.subtotal) > 0)
        l.importInfoSubtotals(parsed.count(RowClass.subtotal)),
    ].join(' · ');

    final errors = parsed.issues.where((i) => i.isError).toList();
    final balanceCol = cfg.columnFor(ColumnTarget.balance)?.index;
    BalanceReport? balance;
    if (balanceCol != null) {
      balance = checkBalances(cfg.key, [
        for (final r in parsed.validRows)
          BalancePoint(
            ref: '${r.row}',
            amountMinor: r.amountMinor!,
            balanceMinor: r.balanceMinor,
            date: r.date,
          ),
      ]);
    }
    final missing = !c.canLeave(ImportStep.mapping);

    return StepScaffold(
      children: [
        const SheetSelector(),
        Row(
          children: [
            IconTile(
              icon: Icons.table_chart_outlined,
              color: context.colors.primary,
              size: 32,
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.importSheetInfo(wb.fileName, sheet.name),
                    style: context.text.titleSmall,
                  ),
                  Text(
                    detail,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        SheetPreviewGrid(
          sheet: sheet,
          config: cfg,
          parsed: parsed,
          headers: headers,
          maxRows: WindowSize.of(context).isCompact ? 8 : 14,
        ),
        const SizedBox(height: Space.sm),
        if (balance != null || errors.isNotEmpty)
          _CheckCard(
            balance: balance,
            balanceColumn: balanceCol == null ? '' : columnLetter(balanceCol),
            errors: errors,
          ),
        if (missing)
          StepBanner(
            message: l.importNeedDateAmount,
            tone: BannerTone.warning,
            icon: Icons.warning_amber_outlined,
          ),
        StepSection(l.importAmountMode),
        SegmentedButton<AmountMode>(
          segments: [
            ButtonSegment(
              value: AmountMode.signed,
              label: Text(l.importAmountSigned),
            ),
            ButtonSegment(
              value: AmountMode.debitCredit,
              label: Text(l.importAmountDebitCredit),
            ),
            ButtonSegment(
              value: AmountMode.amountWithType,
              label: Text(l.importAmountWithType),
            ),
          ],
          selected: {cfg.amountMode},
          onSelectionChanged: (v) =>
              c.updateSheet(cfg.copyWith(amountMode: v.first)),
        ),
        if (cfg.amountMode == AmountMode.signed)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.importInvertSign),
            value: cfg.invertSign,
            onChanged: (v) => c.updateSheet(cfg.copyWith(invertSign: v)),
          ),
        if (cfg.amountMode == AmountMode.amountWithType)
          _TypeTokens(config: cfg),
        const SizedBox(height: Space.sm),
        SectionCard(
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.xxs,
            Space.md,
            Space.xs,
          ),
          child: Column(
            children: [
              for (var col = 0; col < headers.length; col++)
                _ColumnRow(
                  index: col,
                  header: headers[col],
                  sample: _sample(sheet, parsed, col),
                  config: cfg,
                  fields: fields,
                  divider: col > 0,
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            if (cfg.columnFor(ColumnTarget.category) != null &&
                cfg.columnFor(ColumnTarget.subcategory) == null)
              SizedBox(
                width: 220,
                child: _SeparatorField(
                  label: l.importCategorySeparator,
                  value: cfg.categorySeparator,
                  options: const ['', '>', '›', ':', '/', ' - ', '|', r'\'],
                  onChanged: (v) =>
                      c.updateSheet(cfg.copyWith(categorySeparator: v)),
                ),
              ),
            if (cfg.columnFor(ColumnTarget.tags) != null)
              SizedBox(
                width: 220,
                child: _SeparatorField(
                  label: l.importTagSeparator,
                  value: cfg.tagSeparator,
                  options: const [',', ';', '|', ' '],
                  onChanged: (v) =>
                      c.updateSheet(cfg.copyWith(tagSeparator: v)),
                ),
              ),
          ],
        ),
        if (s.includedSheets.length > 1)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.copy_all_outlined),
              label: Text(l.importApplyToSimilar),
              onPressed: () {
                final n = c.applyMappingToSimilar(cfg);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.importAppliedToSimilar(n))),
                );
              },
            ),
          ),
      ],
    );
  }

  static String _sample(RawSheet sheet, ParsedSheet parsed, int col) {
    for (final r in parsed.rows.take(20)) {
      final v = sheet.cell(r.row, col).display.trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }
}

class _CheckCard extends StatelessWidget {
  const _CheckCard({
    required this.balance,
    required this.balanceColumn,
    required this.errors,
  });

  final BalanceReport? balance;
  final String balanceColumn;
  final List<CellIssue> errors;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final b = balance;
    final mismatchRows = b == null
        ? const <int>[]
        : [for (final m in b.mismatches) int.tryParse(m.ref) ?? 0];
    final lines = [
      if (errors.isNotEmpty)
        l.importBadValues(errors.length, rowList(errors.map((e) => e.row))),
      if (mismatchRows.isNotEmpty)
        l.importMismatches(mismatchRows.length, rowList(mismatchRows)),
    ];
    final ok = b != null && b.ok && errors.isEmpty;
    return SectionCard(
      padding: const EdgeInsets.all(Space.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (b != null && b.checked > 0) ...[
            Row(
              children: [
                Icon(
                  ok ? Icons.check_circle_outline : Icons.rule,
                  size: 20,
                  color: ok ? context.colors.primary : context.finance.warning,
                ),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Text(
                    l.importBalanceCheck(b.matched, b.checked, balanceColumn),
                    style: context.text.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            ProgressBar(
              value: b.checked == 0 ? 0 : b.matched / b.checked,
              state: b.ok ? ProgressState.onTrack : ProgressState.warning,
            ),
          ],
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(
                line,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ColumnRow extends ConsumerWidget {
  const _ColumnRow({
    required this.index,
    required this.header,
    required this.sample,
    required this.config,
    required this.fields,
    required this.divider,
  });

  final int index;
  final String header;
  final String sample;
  final SheetConfig config;
  final List<ExistingField> fields;
  final bool divider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = ref.read(importWizardProvider.notifier);
    final col = config.column(index);
    final target = col?.target ?? ColumnTarget.ignore;
    final selected = target == ColumnTarget.customField
        ? 'cf:${col!.customFieldId}'
        : target.name;
    final compact = WindowSize.of(context).isCompact;

    final items = <DropdownMenuItem<String>>[
      for (final t in ColumnTarget.values)
        if (t != ColumnTarget.customField)
          DropdownMenuItem(
            value: t.name,
            child: Text(
              l.importTargetLabel(
                t,
                separator: config.categorySeparator,
                mode: config.amountMode,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      for (final f in fields)
        DropdownMenuItem(
          value: 'cf:${f.id}',
          child: Text(
            l.importTargetCustom(f.name),
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
    final dropdown = DropdownButtonFormField<String>(
      key: ValueKey('$index-$selected'),
      initialValue: items.any((i) => i.value == selected)
          ? selected
          : ColumnTarget.ignore.name,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: Space.sm,
          vertical: Space.xs,
        ),
      ),
      items: items,
      onChanged: (v) {
        if (v == null) return;
        if (v.startsWith('cf:')) {
          c.updateSheet(
            config.withTarget(
              index,
              ColumnTarget.customField,
              fieldId: v.substring(3),
            ),
          );
        } else {
          c.updateSheet(
            config.withTarget(index, ColumnTarget.values.byName(v)),
          );
        }
      },
    );

    final label = Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.colors.surfaceContainer,
            borderRadius: BorderRadius.circular(Radii.xs),
          ),
          child: Text(columnLetter(index), style: context.mono),
        ),
        const SizedBox(width: Space.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                header.isEmpty ? l.importColumn(columnLetter(index)) : header,
                style: context.text.labelLarge,
                overflow: TextOverflow.ellipsis,
              ),
              if (sample.isNotEmpty)
                Text(
                  sample,
                  style: context.mono.copyWith(
                    color: context.colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
            ],
          ),
        ),
      ],
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        border: divider
            ? Border(top: BorderSide(color: context.colors.surfaceContainer))
            : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: Space.xxs),
      child: compact
          ? Row(
              children: [
                Expanded(child: label),
                const SizedBox(width: Space.xs),
                SizedBox(width: 176, child: dropdown),
              ],
            )
          : Row(
              children: [
                Expanded(child: label),
                const SizedBox(width: Space.sm),
                SizedBox(width: 280, child: dropdown),
              ],
            ),
    );
  }
}

class _SeparatorField extends StatelessWidget {
  const _SeparatorField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final all = {...options, value}.toList();
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final o in all)
          DropdownMenuItem(
            value: o,
            child: Text(
              o.isEmpty || o == ' ' ? l.importDelimiterLabel(o) : '“$o”',
            ),
          ),
      ],
      onChanged: (v) => onChanged(v ?? ''),
    );
  }
}

class _TypeTokens extends ConsumerStatefulWidget {
  const _TypeTokens({required this.config});

  final SheetConfig config;

  @override
  ConsumerState<_TypeTokens> createState() => _TypeTokensState();
}

class _TypeTokensState extends ConsumerState<_TypeTokens> {
  late final _neg = TextEditingController(
    text: widget.config.typeTokens.negative.join(', '),
  );
  late final _pos = TextEditingController(
    text: widget.config.typeTokens.positive.join(', '),
  );

  @override
  void dispose() {
    _neg.dispose();
    _pos.dispose();
    super.dispose();
  }

  List<String> _split(String v) => [
    for (final p in v.split(','))
      if (p.trim().isNotEmpty) p.trim(),
  ];

  void _save() {
    final latest = ref
        .read(importWizardProvider)
        .config
        .sheet(widget.config.key);
    if (latest == null) return;
    ref
        .read(importWizardProvider.notifier)
        .updateSheet(
          latest.copyWith(
            typeTokens: TypeTokens(
              negative: _split(_neg.text),
              positive: _split(_pos.text),
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: Column(
        children: [
          TextField(
            controller: _neg,
            decoration: InputDecoration(labelText: l.importTypeNegative),
            onChanged: (_) => _save(),
          ),
          const SizedBox(height: Space.xs),
          TextField(
            controller: _pos,
            decoration: InputDecoration(labelText: l.importTypePositive),
            onChanged: (_) => _save(),
          ),
        ],
      ),
    );
  }
}
