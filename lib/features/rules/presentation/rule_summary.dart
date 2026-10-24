import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/money/money.dart';
import 'package:personal_finance/core/money/money_format.dart';
import 'package:personal_finance/features/rules/domain/rule_model.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// Labels for rule enums and one-line rule descriptions.
extension RuleLabels on AppLocalizations {
  String rulesFieldLabel(RuleTextField f) => switch (f) {
    RuleTextField.payee => rulesFieldPayee,
    RuleTextField.note => rulesFieldNote,
    RuleTextField.payeeOrNote => rulesFieldPayeeOrNote,
  };

  String rulesOperatorLabel(TextOperator o) => switch (o) {
    TextOperator.contains => rulesOpContains,
    TextOperator.equals => rulesOpEquals,
    TextOperator.startsWith => rulesOpStartsWith,
    TextOperator.endsWith => rulesOpEndsWith,
    TextOperator.regex => rulesOpRegex,
  };

  String statusLabel(TxnStatus s) => switch (s) {
    TxnStatus.cleared => statusCleared,
    TxnStatus.pending => statusPending,
    TxnStatus.planned => statusPlanned,
  };

  String typeLabel(TxnType t) => switch (t) {
    TxnType.expense => typeExpense,
    TxnType.income => typeIncome,
    TxnType.transfer => typeTransfer,
  };
}

/// "Payee contains "REWE" → Food › Groceries".
String describeRule(
  RuleDef rule,
  AppLocalizations l, {
  required Map<String, Category> categories,
  required Map<String, Account> accounts,
  required MoneyFormatter money,
}) {
  final parts = <String>[];
  for (final c in rule.conditions.effective) {
    switch (c) {
      case TextCondition():
        final neg = c.negate ? '¬ ' : '';
        parts.add(
          '$neg${l.rulesFieldLabel(c.field)} ${l.rulesOperatorLabel(c.operator)} “${c.value}”',
        );
      case AmountCondition():
        final min = c.minMinor == null ? '' : money.format(Money(c.minMinor!));
        final max = c.maxMinor == null ? '' : money.format(Money(c.maxMinor!));
        parts.add(l.rulesSummaryAmount('$min … $max'.trim()));
      case AccountCondition():
        parts.add(
          c.accountIds.map((id) => accounts[id]?.name ?? '?').join(' / '),
        );
      case TypeCondition():
        parts.add(c.types.map(l.typeLabel).join(' / '));
    }
  }
  final cond = parts.isEmpty
      ? l.rulesSummaryNoConditions
      : parts.join(
          rule.conditions.mode == MatchMode.all
              ? l.rulesSummaryAnd
              : l.rulesSummaryOr,
        );
  final a = rule.actions;
  final acts = <String>[
    if (a.categoryId != null)
      if (categories[a.categoryId] case final c?)
        categoryPath(c, categories)
      else
        '?',
    if (a.payee != null && a.payee!.isNotEmpty) '“${a.payee}”',
    if (a.addTagIds.isNotEmpty) '#${a.addTagIds.length}',
    if (a.status != null) l.statusLabel(a.status!),
    if (a.note != null && a.note!.isNotEmpty) a.note!,
  ];
  return acts.isEmpty ? cond : '$cond → ${acts.join(', ')}';
}
