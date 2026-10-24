import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_controller.dart';

/// Chooses the sheet shown in the structure/mapping/formats steps.
class SheetSelector extends ConsumerWidget {
  const SheetSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(importWizardProvider);
    final c = ref.read(importWizardProvider.notifier);
    final sheets = s.includedSheets;
    final current = s.currentSheet;
    if (sheets.length <= 1 || current == null) return const SizedBox.shrink();
    final multiFile = s.workbooks.length > 1;
    String label(String file, String sheet) =>
        multiFile ? '$file › $sheet' : sheet;
    if (sheets.length > 6) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.sm),
        child: DropdownButtonFormField<String>(
          initialValue: current.$3.key,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.l10n.importSheetPicker,
          ),
          items: [
            for (final sh in sheets)
              DropdownMenuItem(
                value: sh.$3.key,
                child: Text(label(sh.$1.fileName, sh.$2.name)),
              ),
          ],
          onChanged: (k) {
            if (k != null) c.selectSheet(k);
          },
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Wrap(
        spacing: Space.xs,
        runSpacing: Space.xs,
        children: [
          for (final sh in sheets)
            ChoiceChip(
              label: Text(label(sh.$1.fileName, sh.$2.name)),
              selected: sh.$3.key == current.$3.key,
              onSelected: (_) => c.selectSheet(sh.$3.key),
            ),
        ],
      ),
    );
  }
}

/// A labelled 1-based row number with − / + buttons.
class RowStepper extends StatelessWidget {
  const RowStepper({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
    this.min = 1,
    this.max = 9999,
    this.emptyLabel,
  });

  final String label;

  /// Null = [emptyLabel] (e.g. "No header", "Until the end").
  final int? value;
  final int min;
  final int max;
  final String? emptyLabel;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final text = v == null ? (emptyLabel ?? '–') : '$v';
    return Semantics(
      label: label,
      value: text,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: Space.xs),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: '−',
              icon: const Icon(Icons.remove),
              onPressed: v == null
                  ? null
                  : () => onChanged(
                      v <= min ? (emptyLabel == null ? min : null) : v - 1,
                    ),
            ),
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: context.text.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            IconButton(
              tooltip: '+',
              icon: const Icon(Icons.add),
              onPressed: v != null && v >= max
                  ? null
                  : () => onChanged(v == null ? min : v + 1),
            ),
          ],
        ),
      ),
    );
  }
}
