import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';

/// Editable values of an account, as entered in the account form.
///
/// Money in minor units, rates in basis points (1 % = 100 bp).
@immutable
class AccountDraft {
  const AccountDraft({
    required this.name,
    required this.type,
    required this.openingDate,
    this.openingBalanceMinor = 0,
    this.color,
    this.icon,
    this.groupId,
    this.includeInNetWorth = true,
    this.includeInBudgets = true,
    this.includeInForecast = true,
    this.lowBalanceThresholdMinor,
    this.expectedAnnualReturnBp,
    this.interestRateBp,
    this.note,
    this.archived = false,
  });

  factory AccountDraft.fromAccount(Account a) => AccountDraft(
    name: a.name,
    type: a.type,
    openingDate: a.openingDate,
    openingBalanceMinor: a.openingBalanceMinor,
    color: a.color,
    icon: a.icon,
    groupId: a.groupId,
    includeInNetWorth: a.includeInNetWorth,
    includeInBudgets: a.includeInBudgets,
    includeInForecast: a.includeInForecast,
    lowBalanceThresholdMinor: a.lowBalanceThresholdMinor,
    expectedAnnualReturnBp: a.expectedAnnualReturnBp,
    interestRateBp: a.interestRateBp,
    note: a.note,
    archived: a.archived,
  );

  /// Defaults for a new account of [type].
  factory AccountDraft.empty({
    AccountType type = AccountType.checking,
    DateTime? openingDate,
  }) => AccountDraft(
    name: '',
    type: type,
    openingDate: dateOnly(openingDate ?? DateTime.now()),
    icon: defaultAccountIcon(type),
    includeInBudgets: !type.isLiability && type != AccountType.investment,
  );

  final String name;
  final AccountType type;
  final int openingBalanceMinor;
  final DateTime openingDate;

  /// ARGB colour value, null = default colour for the type.
  final int? color;

  /// AppIcons key, null = default icon for the type.
  final String? icon;
  final String? groupId;
  final bool includeInNetWorth;
  final bool includeInBudgets;
  final bool includeInForecast;
  final int? lowBalanceThresholdMinor;
  final int? expectedAnnualReturnBp;
  final int? interestRateBp;
  final String? note;
  final bool archived;

  /// Problems that prevent saving; empty when valid.
  List<AccountDraftProblem> validate() => [
    if (name.trim().isEmpty) AccountDraftProblem.nameRequired,
    if (name.trim().length > 80) AccountDraftProblem.nameTooLong,
    if (expectedAnnualReturnBp != null &&
        (expectedAnnualReturnBp! < -10000 || expectedAnnualReturnBp! > 10000))
      AccountDraftProblem.returnOutOfRange,
    if (interestRateBp != null &&
        (interestRateBp! < 0 || interestRateBp! > 10000))
      AccountDraftProblem.interestOutOfRange,
  ];

  static const _unset = Object();

  AccountDraft copyWith({
    String? name,
    AccountType? type,
    int? openingBalanceMinor,
    DateTime? openingDate,
    Object? color = _unset,
    Object? icon = _unset,
    Object? groupId = _unset,
    bool? includeInNetWorth,
    bool? includeInBudgets,
    bool? includeInForecast,
    Object? lowBalanceThresholdMinor = _unset,
    Object? expectedAnnualReturnBp = _unset,
    Object? interestRateBp = _unset,
    Object? note = _unset,
    bool? archived,
  }) => AccountDraft(
    name: name ?? this.name,
    type: type ?? this.type,
    openingBalanceMinor: openingBalanceMinor ?? this.openingBalanceMinor,
    openingDate: openingDate ?? this.openingDate,
    color: color == _unset ? this.color : color as int?,
    icon: icon == _unset ? this.icon : icon as String?,
    groupId: groupId == _unset ? this.groupId : groupId as String?,
    includeInNetWorth: includeInNetWorth ?? this.includeInNetWorth,
    includeInBudgets: includeInBudgets ?? this.includeInBudgets,
    includeInForecast: includeInForecast ?? this.includeInForecast,
    lowBalanceThresholdMinor: lowBalanceThresholdMinor == _unset
        ? this.lowBalanceThresholdMinor
        : lowBalanceThresholdMinor as int?,
    expectedAnnualReturnBp: expectedAnnualReturnBp == _unset
        ? this.expectedAnnualReturnBp
        : expectedAnnualReturnBp as int?,
    interestRateBp: interestRateBp == _unset
        ? this.interestRateBp
        : interestRateBp as int?,
    note: note == _unset ? this.note : note as String?,
    archived: archived ?? this.archived,
  );

  @override
  bool operator ==(Object other) =>
      other is AccountDraft &&
      other.name == name &&
      other.type == type &&
      other.openingBalanceMinor == openingBalanceMinor &&
      other.openingDate == openingDate &&
      other.color == color &&
      other.icon == icon &&
      other.groupId == groupId &&
      other.includeInNetWorth == includeInNetWorth &&
      other.includeInBudgets == includeInBudgets &&
      other.includeInForecast == includeInForecast &&
      other.lowBalanceThresholdMinor == lowBalanceThresholdMinor &&
      other.expectedAnnualReturnBp == expectedAnnualReturnBp &&
      other.interestRateBp == interestRateBp &&
      other.note == note &&
      other.archived == archived;

  @override
  int get hashCode => Object.hash(
    name,
    type,
    openingBalanceMinor,
    openingDate,
    color,
    icon,
    groupId,
    includeInNetWorth,
    includeInBudgets,
    includeInForecast,
    lowBalanceThresholdMinor,
    expectedAnnualReturnBp,
    interestRateBp,
    note,
    archived,
  );
}

enum AccountDraftProblem {
  nameRequired,
  nameTooLong,
  returnOutOfRange,
  interestOutOfRange,
}

/// Default AppIcons key for an account type.
String defaultAccountIcon(AccountType type) => switch (type) {
  AccountType.checking => 'bank',
  AccountType.savings => 'savings',
  AccountType.cash => 'cash',
  AccountType.creditCard => 'card',
  AccountType.investment => 'investment',
  AccountType.loan => 'loan',
  AccountType.otherAsset => 'asset',
  AccountType.otherLiability => 'loan',
};

/// Whether an interest rate is meaningful for [type] (loans and credit).
bool typeHasInterest(AccountType type) =>
    type == AccountType.loan ||
    type == AccountType.creditCard ||
    type == AccountType.otherLiability ||
    type == AccountType.savings;

/// Whether an expected annual return is meaningful for [type].
bool typeHasReturn(AccountType type) =>
    type == AccountType.investment ||
    type == AccountType.savings ||
    type == AccountType.otherAsset;
