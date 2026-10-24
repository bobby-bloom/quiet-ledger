import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/recurring/data/recurring_providers.dart';
import 'package:personal_finance/features/recurring/domain/recurring_logic.dart';
import 'package:personal_finance/features/recurring/domain/schedule_text.dart';

/// Picks a recurring rule (e.g. the salary rule for salary-based budget
/// periods). Returns the rule id, '' for "None" when [allowNone], or null
/// when dismissed.
Future<String?> showRecurringRulePicker(
  BuildContext context, {
  bool incomeOnly = false,
  bool allowNone = false,
  String? selectedId,
}) => showAdaptiveSheet<String>(
  context,
  builder: (_) => RecurringRulePicker(
    incomeOnly: incomeOnly,
    allowNone: allowNone,
    selectedId: selectedId,
  ),
);

class RecurringRulePicker extends ConsumerWidget {
  const RecurringRulePicker({
    super.key,
    this.incomeOnly = false,
    this.allowNone = false,
    this.selectedId,
    this.onPicked,
  });

  final bool incomeOnly;
  final bool allowNone;
  final String? selectedId;

  /// Called instead of popping with the id (used by the picker route).
  final ValueChanged<String>? onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final plans = ref.watch(recurringPlansProvider).value;
    final lang = ref.watch(languageCodeProvider);
    void pick(String id) =>
        onPicked != null ? onPicked!(id) : Navigator.pop(context, id);
    final rules = (plans ?? const <RecurringPlan>[])
        .where((p) => !incomeOnly || p.isIncome)
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.xl,
            Space.lg,
            Space.xl,
            Space.xs,
          ),
          child: Text(
            incomeOnly ? l.recurringPickIncome : l.recurringPickRule,
            style: context.text.titleLarge,
          ),
        ),
        Flexible(
          child: plans == null
              ? const Padding(
                  padding: EdgeInsets.all(Space.xxl),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    if (allowNone)
                      ListTile(
                        leading: const Icon(Icons.block),
                        title: Text(l.commonNone),
                        selected: selectedId == null || selectedId!.isEmpty,
                        onTap: () => pick(''),
                      ),
                    if (rules.isEmpty)
                      EmptyState(
                        icon: Icons.event_repeat_outlined,
                        message: incomeOnly
                            ? l.recurringNoIncomeRules
                            : l.recurringEmpty,
                        actionLabel: l.recurringNew,
                        onAction: () {
                          Navigator.maybePop(context);
                          unawaited(
                            context.push(
                              incomeOnly
                                  ? '/plan/recurring/new?type=income'
                                  : '/plan/recurring/new',
                            ),
                          );
                        },
                      ),
                    for (final p in rules)
                      ListTile(
                        leading: Icon(
                          p.isIncome
                              ? Icons.south_west
                              : Icons.event_repeat_outlined,
                        ),
                        title: Text(p.name),
                        subtitle: Text(describeSchedule(p.rrule, lang)),
                        trailing: AmountText(
                          p.template.amountMinor,
                          type: p.type,
                        ),
                        selected: p.id == selectedId,
                        onTap: () => pick(p.id),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: Space.md),
      ],
    );
  }
}

/// '/plan/recurring/pick' — picks the salary rule for salary-based budget
/// periods (Settings › Budgets), stores it and pops with the id.
class SalaryRulePickScreen extends ConsumerWidget {
  const SalaryRulePickScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final current = ref.watch(
      settingsProvider.select((s) => s.get(BudgetSettings.salaryRuleId)),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.recurringPickIncome)),
      body: RecurringRulePicker(
        incomeOnly: true,
        allowNone: true,
        selectedId: current,
        onPicked: (id) async {
          final notifier = ref.read(settingsProvider.notifier);
          if (id.isEmpty) {
            await notifier.reset(BudgetSettings.salaryRuleId);
          } else {
            await notifier.set(BudgetSettings.salaryRuleId, id);
          }
          if (context.mounted && context.canPop()) context.pop(id);
        },
      ),
    );
  }
}
