import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/app_icons.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/money/money_input.dart';
import 'package:personal_finance/features/accounts/domain/account_draft.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

String accountTypeLabel(AppLocalizations l, AccountType t) => switch (t) {
  AccountType.checking => l.accountsTypeChecking,
  AccountType.savings => l.accountsTypeSavings,
  AccountType.cash => l.accountsTypeCash,
  AccountType.creditCard => l.accountsTypeCreditCard,
  AccountType.investment => l.accountsTypeInvestment,
  AccountType.loan => l.accountsTypeLoan,
  AccountType.otherAsset => l.accountsTypeOtherAsset,
  AccountType.otherLiability => l.accountsTypeOtherLiability,
};

/// Default colour of an account type, from theme roles.
Color accountTypeColor(BuildContext context, AccountType t) => switch (t) {
  AccountType.checking => context.colors.primary,
  AccountType.savings => context.colors.tertiary,
  AccountType.cash => context.finance.warning,
  AccountType.creditCard => context.finance.chartAt(1),
  AccountType.investment => context.finance.income,
  AccountType.loan => context.finance.chartAt(4),
  AccountType.otherAsset => context.finance.chartAt(5),
  AccountType.otherLiability => context.colors.error,
};

Color accountColor(BuildContext context, Account a) =>
    a.color != null ? Color(a.color!) : accountTypeColor(context, a.type);

IconData accountIcon(Account a) =>
    AppIcons.of(a.icon ?? defaultAccountIcon(a.type));

/// Formats basis points as a percentage, e.g. 450 -> "4.5%" / "4,5 %".
String formatBp(int bp, String locale) {
  final sym = NumberFormat.decimalPattern(locale).symbols;
  final neg = bp < 0;
  final a = bp.abs();
  final whole = a ~/ 100;
  final frac = (a % 100)
      .toString()
      .padLeft(2, '0')
      .replaceAll(RegExp(r'0+$'), '');
  final number = frac.isEmpty ? '$whole' : '$whole${sym.DECIMAL_SEP}$frac';
  final sign = neg ? '−' : '';
  return locale.startsWith('de') ? '$sign$number %' : '$sign$number%';
}

/// Text for a basis-point input field, e.g. 450 -> "4,5".
String bpInputText(int? bp, String locale) {
  if (bp == null) return '';
  return formatBp(bp, locale).replaceAll('%', '').replaceAll('−', '-').trim();
}

/// Parses a percentage typed by the user ("4,5", "4.5 %") into basis
/// points; null when empty or invalid.
int? parseBp(String input) {
  final t = input.replaceAll('%', '').trim();
  if (t.isEmpty) return null;
  return parseAmountInput(t);
}
