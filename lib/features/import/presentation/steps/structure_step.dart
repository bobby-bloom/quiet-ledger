import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/features/import/domain/row_parser.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_controller.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_screen.dart';
import 'package:personal_finance/features/import/presentation/sheet_preview_grid.dart';
import 'package:personal_finance/features/import/presentation/steps/step_common.dart';

/// Step 3: header row(s), data range and row filters.
class StructureStep extends ConsumerStatefulWidget {
  const StructureStep({super.key});

  @override
  ConsumerState<StructureStep> createState() => _StructureStepState();
}

class _StructureStepState extends ConsumerState<StructureStep> {
  late final TextEditingController _patterns;

  @override
  void initState() {
    super.initState();
    _patterns = TextEditingController(
      text: ref
          .read(importWizardProvider)
          .config
          .filters
          .skipPatterns
          .join(', '),
    );
  }

  @override
  void dispose() {
    _patterns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(importWizardProvider);
    final c = ref.read(importWizardProvider.notifier);
    final cur = s.currentSheet;
    final parsed = ref.watch(currentSheetPreviewProvider);
    if (cur == null) return const SizedBox.shrink();
    final (_, sheet, cfg) = cur;
    final rows = sheet.rowCount;
    final filters = s.config.filters;
    final data = parsed?.validRows.length ?? 0;
    final skipped = parsed == null
        ? 0
        : parsed.classes
              .where(
                (x) =>
                    x == RowClass.subtotal ||
                    x == RowClass.noDate ||
                    x == RowClass.noAmount ||
                    x == RowClass.title,
              )
              .length;

    return StepScaffold(
      intro: l.importStructureIntro,
      children: [
        const SheetSelector(),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            SizedBox(
              width: 200,
              child: RowStepper(
                label: l.importHeaderRow,
                value: cfg.headerRow < 0 ? null : cfg.headerRow + 1,
                max: rows,
                emptyLabel: l.importNoHeader,
                onChanged: (v) {
                  final header = v == null ? -1 : v - 1;
                  final count = v == null
                      ? 0
                      : (cfg.headerRows == 0 ? 1 : cfg.headerRows);
                  c.updateSheet(
                    cfg.copyWith(
                      headerRow: header,
                      headerRows: count,
                      firstDataRow: header < 0
                          ? cfg.firstDataRow
                          : header + count,
                    ),
                  );
                },
              ),
            ),
            if (cfg.headerRow >= 0)
              SizedBox(
                width: 170,
                child: RowStepper(
                  label: l.importHeaderRows,
                  value: cfg.headerRows,
                  max: 3,
                  onChanged: (v) {
                    final n = v ?? 1;
                    c.updateSheet(
                      cfg.copyWith(
                        headerRows: n,
                        firstDataRow: cfg.headerRow + n,
                      ),
                    );
                  },
                ),
              ),
            SizedBox(
              width: 200,
              child: RowStepper(
                label: l.importFirstDataRow,
                value: cfg.firstDataRow + 1,
                max: rows,
                onChanged: (v) =>
                    c.updateSheet(cfg.copyWith(firstDataRow: (v ?? 1) - 1)),
              ),
            ),
            SizedBox(
              width: 200,
              child: RowStepper(
                label: l.importLastDataRow,
                value: cfg.lastDataRow == null ? null : cfg.lastDataRow! + 1,
                max: rows,
                min: cfg.firstDataRow + 1,
                emptyLabel: l.importUntilEnd,
                onChanged: (v) => c.updateSheet(
                  cfg.copyWith(lastDataRow: v == null ? null : v - 1),
                ),
              ),
            ),
          ],
        ),
        StepSection(l.importRowFilters),
        SectionCard(
          padding: const EdgeInsets.all(Space.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _patterns,
                decoration: InputDecoration(
                  labelText: l.importSkipPatterns,
                  helperText: l.importSkipPatternsHint,
                ),
                onChanged: (v) => c.updateConfig(
                  s.config.copyWith(
                    filters: filters.copyWith(
                      skipPatterns: [
                        for (final p in v.split(','))
                          if (p.trim().isNotEmpty) p.trim(),
                      ],
                    ),
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.importSkipWithoutDate),
                value: filters.skipWithoutDate,
                onChanged: (v) => c.updateConfig(
                  s.config.copyWith(
                    filters: filters.copyWith(skipWithoutDate: v),
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.importSkipZero),
                value: filters.skipZeroAmount,
                onChanged: (v) => c.updateConfig(
                  s.config.copyWith(
                    filters: filters.copyWith(skipZeroAmount: v),
                  ),
                ),
              ),
            ],
          ),
        ),
        StepSection('${sheet.name} · ${l.importRowStats(data, skipped)}'),
        SheetPreviewGrid(
          sheet: sheet,
          config: cfg,
          parsed: parsed,
          mode: PreviewMode.structure,
          maxRows: 80,
        ),
      ],
    );
  }
}
