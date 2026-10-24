import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/features/import/domain/import_analysis.dart';
import 'package:personal_finance/features/import/domain/import_drafts.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_controller.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_screen.dart';
import 'package:personal_finance/features/import/presentation/steps/step_common.dart';

/// Step 7: merge debit/credit pairs between accounts into transfers.
class TransfersStep extends ConsumerWidget {
  const TransfersStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(importWizardProvider);
    final c = ref.read(importWizardProvider.notifier);
    final a = s.analysis;
    final cfg = s.config.transfers;
    final dates = ref.watch(dateFormatsProvider);
    if (a == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    bool merged(String key, int i) =>
        s.decisions.transfers[key] ??
        defaultTransferAccepted(a.transfers[i], a);
    final selected = [
      for (var i = 0; i < a.transfers.length; i++)
        if (merged(a.transfers[i].key, i)) i,
    ].length;
    String accountName(String key) {
      final t = a.accountTargets[key];
      if (t?.existingId != null) {
        return s.context?.account(t!.existingId!)?.name ?? key;
      }
      return t?.name ?? key;
    }

    return StepScaffold(
      intro: l.importTransfersIntro,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.importDetectTransfers),
          value: cfg.detect,
          onChanged: (v) => c.setTransferConfig(cfg.copyWith(detect: v)),
        ),
        if (cfg.detect)
          SizedBox(
            width: 240,
            child: RowStepper(
              label: l.importTransferWindow,
              value: cfg.windowDays,
              min: 0,
              max: 14,
              onChanged: (v) =>
                  c.setTransferConfig(cfg.copyWith(windowDays: v ?? 0)),
            ),
          ),
        if (cfg.detect) ...[
          StepSection(
            l.importTransfersCount(selected, a.transfers.length),
            trailing: a.transfers.isEmpty
                ? null
                : Wrap(
                    spacing: Space.xs,
                    children: [
                      TextButton(
                        onPressed: () => c.setAllTransfers(merge: true),
                        child: Text(l.importMergeAll),
                      ),
                      TextButton(
                        onPressed: () => c.setAllTransfers(merge: false),
                        child: Text(l.importMergeNone),
                      ),
                    ],
                  ),
          ),
          if (a.transfers.isEmpty)
            StepBanner(message: l.importTransfersNone)
          else
            SectionCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < a.transfers.length; i++)
                    _PairTile(
                      out: a.rows[a.transfers[i].outIndex],
                      inc: a.rows[a.transfers[i].inIndex],
                      dayDiff: a.transfers[i].dayDiff,
                      value: merged(a.transfers[i].key, i),
                      from: accountName(
                        a.rows[a.transfers[i].outIndex].row.accountKey,
                      ),
                      to: accountName(
                        a.rows[a.transfers[i].inIndex].row.accountKey,
                      ),
                      date: dates.short(a.rows[a.transfers[i].outIndex].date),
                      onChanged: (v) =>
                          c.setTransfer(a.transfers[i].key, merge: v),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _PairTile extends StatelessWidget {
  const _PairTile({
    required this.out,
    required this.inc,
    required this.dayDiff,
    required this.value,
    required this.from,
    required this.to,
    required this.date,
    required this.onChanged,
  });

  final AnalysedRow out;
  final AnalysedRow inc;
  final int dayDiff;
  final bool value;
  final String from;
  final String to;
  final String date;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = {?out.row.payee, ?out.row.note}.join(' · ');
    return CheckboxListTile(
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      title: Row(
        children: [
          Expanded(child: Text('$from → $to', overflow: TextOverflow.ellipsis)),
          AmountText(-out.amountMinor, type: TxnType.transfer),
        ],
      ),
      subtitle: Text(
        [
          date,
          l.importDaysApart(dayDiff),
          if (text.isNotEmpty) text,
        ].join(' · '),
        style: context.text.bodySmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
