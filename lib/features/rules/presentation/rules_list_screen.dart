import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/features/rules/data/rule_repository.dart';
import 'package:personal_finance/features/rules/domain/rule_model.dart';
import 'package:personal_finance/features/rules/presentation/rerun_rules_dialog.dart';
import 'package:personal_finance/features/rules/presentation/rule_summary.dart';

/// `/more/rules`: rules in priority order (drag to reorder), enable toggle.
class RulesListScreen extends ConsumerStatefulWidget {
  const RulesListScreen({super.key});

  @override
  ConsumerState<RulesListScreen> createState() => _RulesListScreenState();
}

class _RulesListScreenState extends ConsumerState<RulesListScreen> {
  /// Optimistic order while the reorder is written.
  List<RuleDef>? _pending;

  Future<void> _reorder(List<RuleDef> rules, int from, int to) async {
    final list = [...rules];
    list.insert(to, list.removeAt(from));
    setState(() => _pending = list);
    await ref.read(ruleRepositoryProvider).reorder([
      for (final r in list) r.id!,
    ]);
    if (mounted) setState(() => _pending = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rules = ref.watch(rulesProvider);
    final categories = ref.watch(categoryMapProvider);
    final accounts = ref.watch(accountMapProvider);
    final money = ref.watch(moneyFormatterProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.rulesTitle),
        actions: [
          IconButton(
            tooltip: l.rulesRerun,
            icon: const Icon(Icons.replay),
            onPressed: () => unawaited(showRerunRulesDialog(context)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/more/rules/new'),
        icon: const Icon(Icons.add),
        label: Text(l.rulesAdd),
      ),
      body: AsyncView(
        value: rules,
        data: (loaded) {
          final list = _pending ?? loaded;
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.auto_fix_high_outlined,
              message: l.rulesEmpty,
              actionLabel: l.rulesAdd,
              onAction: () => context.push('/more/rules/new'),
            );
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  Space.md,
                  Space.xs,
                  Space.md,
                  96,
                ),
                header: Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: Text(
                    l.rulesOrderHint,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
                buildDefaultDragHandles: false,
                itemCount: list.length,
                onReorderItem: (from, to) =>
                    unawaited(_reorder(list, from, to)),
                itemBuilder: (context, i) {
                  final r = list[i];
                  return Card(
                    key: ValueKey(r.id),
                    margin: const EdgeInsets.only(bottom: Space.cardGap),
                    child: ListTile(
                      leading: ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.all(Space.xs),
                          child: Icon(Icons.drag_indicator),
                        ),
                      ),
                      title: Text(
                        r.name,
                        style: r.enabled
                            ? null
                            : TextStyle(color: context.colors.onSurfaceVariant),
                      ),
                      subtitle: Text(
                        describeRule(
                          r,
                          l,
                          categories: categories,
                          accounts: accounts,
                          money: money,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Switch(
                        value: r.enabled,
                        onChanged: (v) => unawaited(
                          ref
                              .read(ruleRepositoryProvider)
                              .setEnabled(r.id!, enabled: v),
                        ),
                      ),
                      onTap: () => context.push('/more/rules/${r.id}'),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
