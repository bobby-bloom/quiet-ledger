import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/features/import/domain/date_parser.dart';
import 'package:personal_finance/features/import/domain/import_config.dart';
import 'package:personal_finance/features/import/domain/number_parser.dart';
import 'package:personal_finance/features/import/domain/raw_sheet.dart';
import 'package:personal_finance/features/import/domain/row_parser.dart';
import 'package:personal_finance/features/import/presentation/import_labels.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_controller.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_screen.dart';
import 'package:personal_finance/features/import/presentation/steps/step_common.dart';

/// Step 5: date and number formats per column, and every unreadable cell.
class FormatsStep extends ConsumerWidget {
  const FormatsStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(importWizardProvider);
    final cur = s.currentSheet;
    final parsed = ref.watch(currentSheetPreviewProvider);
    if (cur == null || parsed == null) return const SizedBox.shrink();
    final (wb, sheet, cfg) = cur;
    final issues = parsed.issues;
    const maxIssues = 60;

    return StepScaffold(
      intro: l.importFormatsIntro,
      children: [
        const SheetSelector(),
        for (final col in cfg.columns.where((c) => c.isDate || c.isNumber))
          _FormatCard(
            column: col,
            header: col.index < parsed.headers.length
                ? parsed.headers[col.index]
                : '',
            config: cfg,
            parsed: parsed,
            sheet: sheet,
            date1904: wb.date1904,
          ),
        StepSection(l.importIssuesTitle),
        if (issues.isEmpty)
          StepBanner(
            message: l.importNoIssues,
            tone: BannerTone.ok,
            icon: Icons.check_circle_outline,
          )
        else
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final i in issues.take(maxIssues))
                  ListTile(
                    dense: true,
                    leading: Icon(
                      i.isError ? Icons.error_outline : Icons.info_outline,
                      color: i.isError
                          ? context.colors.error
                          : context.finance.warning,
                    ),
                    title: Text(l.importIssueLabel(i.kind)),
                    subtitle: Text(
                      l.importIssueAt(i.row + 1, columnLetter(i.col)),
                    ),
                    trailing: Text(
                      i.value,
                      style: context.mono.copyWith(
                        color: i.isError ? context.colors.error : null,
                      ),
                    ),
                  ),
                if (issues.length > maxIssues)
                  Padding(
                    padding: const EdgeInsets.all(Space.sm),
                    child: Text(l.importMoreIssues(issues.length - maxIssues)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FormatCard extends ConsumerWidget {
  const _FormatCard({
    required this.column,
    required this.header,
    required this.config,
    required this.parsed,
    required this.sheet,
    required this.date1904,
  });

  final ColumnConfig column;
  final String header;
  final SheetConfig config;
  final ParsedSheet parsed;
  final RawSheet sheet;
  final bool date1904;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = ref.read(importWizardProvider.notifier);
    final money = ref.watch(moneyFormatterProvider);
    final dates = ref.watch(dateFormatsProvider);
    final col = column.index;
    final samples = <RawCell>[
      for (final r in parsed.rows)
        if (sheet.cell(r.row, col) case final cell when cell.isNotEmpty) cell,
    ].take(4).toList();
    final title =
        '${columnLetter(col)} · ${header.isEmpty ? l.importColumn(columnLetter(col)) : header} → '
        '${l.importTargetLabel(column.target, mode: config.amountMode)}';

    Widget body;
    if (column.isDate) {
      final detected = parsed.formats.dates[col] ?? DateFormatKind.auto;
      final allCells = samples.every((x) => x.kind == RawKind.date);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<DateFormatKind>(
            initialValue: column.dateFormat,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l.importDateFormat,
              helperText: l.importDetected(
                allCells && samples.isNotEmpty
                    ? l.importDateCells
                    : l.importDateFormatLabel(detected),
              ),
            ),
            items: [
              for (final k in DateFormatKind.values)
                DropdownMenuItem(
                  value: k,
                  child: Text(l.importDateFormatLabel(k)),
                ),
            ],
            onChanged: (k) => c.updateSheet(
              config.withColumn(column.copyWith(dateFormat: k)),
            ),
          ),
          const SizedBox(height: Space.xs),
          for (final cell in samples)
            _SampleLine(
              raw: cell.display,
              parsed: () {
                final kind = detected == DateFormatKind.auto
                    ? DateFormatKind.dmy
                    : detected;
                final d =
                    parseDateCell(
                      cell,
                      kind,
                      yearHint: config.year,
                      date1904: date1904,
                    ) ??
                    (cell.kind == RawKind.number
                        ? parseDateCell(
                            cell,
                            DateFormatKind.excelSerial,
                            date1904: date1904,
                          )
                        : null);
                return d == null ? null : dates.medium(d);
              }(),
            ),
        ],
      );
    } else {
      final detected = parsed.formats.numbers[col] ?? NumberFormatKind.de;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<NumberFormatKind>(
            initialValue: column.numberFormat,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l.importNumberFormat,
              helperText: l.importDetected(l.importNumberFormatLabel(detected)),
            ),
            items: [
              for (final k in NumberFormatKind.values)
                DropdownMenuItem(
                  value: k,
                  child: Text(l.importNumberFormatLabel(k)),
                ),
            ],
            onChanged: (k) => c.updateSheet(
              config.withColumn(column.copyWith(numberFormat: k)),
            ),
          ),
          const SizedBox(height: Space.xs),
          for (final cell in samples)
            _SampleLine(
              raw: cell.display,
              parsed: switch (parseAmountCell(cell, detected)) {
                final int v => money.minor(v),
                null => null,
              },
            ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: SectionCard(title: title, child: body),
    );
  }
}

class _SampleLine extends StatelessWidget {
  const _SampleLine({required this.raw, required this.parsed});

  final String raw;
  final String? parsed;

  @override
  Widget build(BuildContext context) {
    final bad = parsed == null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              raw,
              style: context.mono.copyWith(
                color: bad ? context.colors.error : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.arrow_forward, size: 14),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Text(
              parsed ?? context.l10n.importInvalidCell(raw),
              style: context.text.bodyMedium?.copyWith(
                color: bad ? context.colors.error : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
