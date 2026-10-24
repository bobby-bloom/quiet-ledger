import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/features/import/domain/date_parser.dart';
import 'package:personal_finance/features/import/domain/import_config.dart';
import 'package:personal_finance/features/import/domain/raw_sheet.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_controller.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_screen.dart';

/// Step 2: which sheets, and where each sheet's account comes from.
class SheetsStep extends ConsumerWidget {
  const SheetsStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(importWizardProvider);
    return StepScaffold(
      intro: l.importSheetsIntro,
      children: [
        for (final (wb, sheet, cfg) in s.allSheets)
          _SheetCard(
            key: ValueKey(cfg.key),
            workbook: wb,
            sheet: sheet,
            config: cfg,
          ),
      ],
    );
  }
}

class _SheetCard extends ConsumerWidget {
  const _SheetCard({
    required this.workbook,
    required this.sheet,
    required this.config,
    super.key,
  });

  final RawWorkbook workbook;
  final RawSheet sheet;
  final SheetConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = ref.read(importWizardProvider.notifier);
    final hasData =
        config.columnFor(ColumnTarget.date) != null && sheet.rowCount > 1;
    final subtitle = [
      workbook.fileName,
      l.importRows(sheet.rowCount),
      if (sheet.hidden) l.importSheetHidden,
      if (!hasData) l.importSheetNoData,
    ].join(' · ');
    final hasAccountColumn = config.columnFor(ColumnTarget.account) != null;
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            value: config.include,
            title: Text(sheet.name, style: context.text.titleSmall),
            subtitle: Text(subtitle),
            onChanged: (v) => c.updateSheet(config.copyWith(include: v)),
          ),
          if (config.include)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.importAccountSource, style: context.text.labelLarge),
                  const SizedBox(height: Space.xs),
                  SegmentedButton<AccountSource>(
                    segments: [
                      ButtonSegment(
                        value: AccountSource.fixed,
                        label: Text(l.importAccountFixed),
                      ),
                      ButtonSegment(
                        value: AccountSource.column,
                        label: Text(l.importAccountColumn),
                        enabled: hasAccountColumn,
                      ),
                      ButtonSegment(
                        value: AccountSource.sheetName,
                        label: Text(l.importAccountSheetName),
                      ),
                    ],
                    selected: {config.accountSource},
                    onSelectionChanged: (v) =>
                        c.updateSheet(config.copyWith(accountSource: v.first)),
                  ),
                  const SizedBox(height: Space.sm),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      if (config.accountSource != AccountSource.sheetName)
                        SizedBox(
                          width: 320,
                          child: AccountNameField(
                            value: config.fixedAccount,
                            onChanged: (v) =>
                                c.updateSheet(config.copyWith(fixedAccount: v)),
                          ),
                        ),
                      SizedBox(
                        width: 220,
                        child: _YearField(
                          value: config.year,
                          suggested: yearFromName(sheet.name),
                          onChanged: (y) =>
                              c.updateSheet(config.copyWith(year: y)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Account name with suggestions from the existing accounts.
class AccountNameField extends ConsumerStatefulWidget {
  const AccountNameField({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  ConsumerState<AccountNameField> createState() => _AccountNameFieldState();
}

class _AccountNameFieldState extends ConsumerState<AccountNameField> {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final names = <String>[
      for (final a in ref.watch(accountsProvider).value ?? const <Account>[])
        if (!a.archived) a.name,
    ];
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: widget.value),
      optionsBuilder: (v) {
        final q = v.text.toLowerCase();
        return names.where((n) => q.isEmpty || n.toLowerCase().contains(q));
      },
      onSelected: widget.onChanged,
      fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
        controller: controller,
        focusNode: focus,
        decoration: InputDecoration(
          labelText: l.importAccountName,
          helperText: l.importAccountNameHint,
          prefixIcon: const Icon(Icons.account_balance_outlined),
        ),
        onChanged: widget.onChanged,
        onSubmitted: (_) => onSubmit(),
      ),
    );
  }
}

class _YearField extends StatelessWidget {
  const _YearField({
    required this.value,
    required this.suggested,
    required this.onChanged,
  });

  final int? value;
  final int? suggested;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final now = DateTime.now().year;
    final years = <int>{
      for (var y = now + 1; y >= 1990; y--) y,
      ?value,
      ?suggested,
    }.toList()..sort((a, b) => b.compareTo(a));
    return DropdownButtonFormField<int?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: l.importYear),
      items: [
        DropdownMenuItem(child: Text(l.importYearNone)),
        for (final y in years) DropdownMenuItem(value: y, child: Text('$y')),
      ],
      onChanged: onChanged,
    );
  }
}
