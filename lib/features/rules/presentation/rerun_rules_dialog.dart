import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/features/rules/domain/rule_service.dart';

/// Settings › Data › Re-run rules: previews how many transactions change,
/// then applies. Returns the number of updated transactions (null when
/// cancelled).
Future<int?> showRerunRulesDialog(BuildContext context) =>
    showDialog<int>(context: context, builder: (_) => const _RerunDialog());

class _RerunDialog extends ConsumerStatefulWidget {
  const _RerunDialog();

  @override
  ConsumerState<_RerunDialog> createState() => _RerunDialogState();
}

class _RerunDialogState extends ConsumerState<_RerunDialog> {
  bool _onlyUncategorised = true;
  late Future<RerunPreview> _preview = _load();
  bool _applying = false;

  Future<RerunPreview> _load() => ref
      .read(ruleServiceProvider)
      .previewRerun(onlyUncategorised: _onlyUncategorised);

  Future<void> _apply() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _applying = true);
    final n = await ref
        .read(ruleServiceProvider)
        .rerunRules(onlyUncategorised: _onlyUncategorised);
    messenger.showSnackBar(SnackBar(content: Text(l.rulesRerunDone(n))));
    navigator.pop(n);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.rulesRerunTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.rulesRerunOnlyUncategorised),
              value: _onlyUncategorised,
              onChanged: _applying
                  ? null
                  : (v) => setState(() {
                      _onlyUncategorised = v;
                      _preview = _load();
                    }),
            ),
            if (!_onlyUncategorised)
              Text(
                l.rulesRerunAllHint,
                style: context.text.bodySmall?.copyWith(
                  color: context.finance.warning,
                ),
              ),
            const SizedBox(height: Space.sm),
            FutureBuilder<RerunPreview>(
              future: _preview,
              builder: (context, snap) {
                final p = snap.data;
                if (p == null) return const LinearProgressIndicator();
                return Text(
                  p.ruleCount == 0
                      ? l.rulesNoRules
                      : l.rulesRerunPreview(p.changedCount, p.scanned),
                  style: context.text.titleSmall,
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _applying ? null : () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FutureBuilder<RerunPreview>(
          future: _preview,
          builder: (context, snap) => FilledButton(
            onPressed: _applying || (snap.data?.changedCount ?? 0) == 0
                ? null
                : _apply,
            child: Text(l.rulesRerunApply),
          ),
        ),
      ],
    );
  }
}
