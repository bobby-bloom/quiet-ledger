import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/features/import/domain/import_analysis.dart';
import 'package:personal_finance/features/import/domain/import_config.dart';
import 'package:personal_finance/features/import/domain/import_drafts.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_controller.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_screen.dart';

/// Step 8: duplicates of existing transactions, within the batch, and rows
/// imported before (incremental re-import).
class DuplicatesStep extends ConsumerWidget {
  const DuplicatesStep({super.key});

  static const _maxShown = 300;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(importWizardProvider);
    final c = ref.read(importWizardProvider.notifier);
    final set = ref.watch(plannedDraftsProvider);
    if (set == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    final dups = [
      for (final t in set.txns)
        if (t.dup != DupStatus.unique) t,
    ];
    final already = dups
        .where((t) => t.dup == DupStatus.alreadyImported)
        .length;
    final included = dups.where((t) => t.included).length;

    return StepScaffold(
      intro: l.importDuplicatesIntro,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.importIncremental),
          value: s.config.incremental,
          onChanged: (v) => c.setIncremental(value: v),
        ),
        if (already > 0) StepBanner(message: l.importAlreadyCount(already)),
        if (dups.isEmpty)
          StepBanner(
            message: l.importDupNone,
            tone: BannerTone.ok,
            icon: Icons.check_circle_outline,
          )
        else ...[
          StepSection(
            l.importDupIncluded(included, dups.length),
            trailing: SegmentedButton<DuplicatePolicy>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: DuplicatePolicy.skip,
                  label: Text(l.importDupSkipAll),
                ),
                ButtonSegment(
                  value: DuplicatePolicy.import,
                  label: Text(l.importDupImportAll),
                ),
              ],
              selected: {s.config.duplicates},
              onSelectionChanged: (v) => c.setAllDuplicates(
                include: v.first == DuplicatePolicy.import,
              ),
            ),
          ),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final t in dups.take(_maxShown))
                  _DupTile(
                    txn: t,
                    onChanged: (v) => c.setInclude(t.ref, include: v),
                  ),
                if (dups.length > _maxShown)
                  Padding(
                    padding: const EdgeInsets.all(Space.sm),
                    child: Text(l.importMoreIssues(dups.length - _maxShown)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DupTile extends ConsumerWidget {
  const _DupTile({required this.txn, required this.onChanged});

  final PlannedTxn txn;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final dates = ref.watch(dateFormatsProvider);
    final d = txn.draft;
    final label = switch (txn.dup) {
      DupStatus.existing => l.importDupExisting,
      DupStatus.batch => l.importDupBatch,
      DupStatus.alreadyImported => l.importDupAlready,
      DupStatus.unique => '',
    };
    final text = {?d.payee, ?d.note}.join(' · ');
    return CheckboxListTile(
      value: txn.included,
      onChanged: (v) => onChanged(v ?? false),
      title: Row(
        children: [
          Expanded(
            child: Text(
              text.isEmpty ? dates.short(d.date) : text,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AmountText(d.amountMinor, type: d.type),
        ],
      ),
      subtitle: Wrap(
        spacing: Space.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(dates.short(d.date)),
          StatusBadge(
            label,
            background: txn.dup == DupStatus.alreadyImported
                ? context.colors.surfaceContainerHigh
                : context.finance.warningContainer,
            foreground: txn.dup == DupStatus.alreadyImported
                ? context.colors.onSurfaceVariant
                : context.finance.onWarningContainer,
          ),
        ],
      ),
    );
  }
}
