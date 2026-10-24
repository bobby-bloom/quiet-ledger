import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/database.dart';

/// Net worth split into assets and liabilities (minor units).
///
/// [liabilitiesMinor] is the (usually negative) sum of liability-type
/// accounts, so `net = assets + liabilities`.
@immutable
class NetWorthSummary {
  const NetWorthSummary({
    required this.assetsMinor,
    required this.liabilitiesMinor,
  });

  static const zero = NetWorthSummary(assetsMinor: 0, liabilitiesMinor: 0);

  final int assetsMinor;
  final int liabilitiesMinor;

  int get netMinor => assetsMinor + liabilitiesMinor;

  /// Share of assets in `|assets| + |liabilities|` (0..1) for the split bar;
  /// null when both are zero.
  double? get assetShare {
    final total = assetsMinor.abs() + liabilitiesMinor.abs();
    if (total == 0) return null;
    return assetsMinor.abs() / total;
  }

  @override
  bool operator ==(Object other) =>
      other is NetWorthSummary &&
      other.assetsMinor == assetsMinor &&
      other.liabilitiesMinor == liabilitiesMinor;

  @override
  int get hashCode => Object.hash(assetsMinor, liabilitiesMinor);

  @override
  String toString() =>
      'NetWorthSummary(assets: $assetsMinor, liabilities: $liabilitiesMinor)';
}

/// Computes the net worth of the live accounts that are included in net
/// worth. Liability-type accounts (credit card, loan, other liability) count
/// as liabilities, everything else as assets.
NetWorthSummary computeNetWorth(
  Iterable<Account> accounts,
  Map<String, int> balances,
) {
  var assets = 0;
  var liabilities = 0;
  for (final a in accounts) {
    if (a.deletedAt != null || !a.includeInNetWorth) continue;
    final b = balances[a.id] ?? a.openingBalanceMinor;
    if (a.type.isLiability) {
      liabilities += b;
    } else {
      assets += b;
    }
  }
  return NetWorthSummary(assetsMinor: assets, liabilitiesMinor: liabilities);
}

/// One section of the grouped account list: either a user-defined
/// [group] or, for ungrouped accounts, an account [type].
@immutable
class AccountSection {
  const AccountSection({required this.accounts, this.group, this.type});

  final AccountGroup? group;

  /// Set for sections of ungrouped accounts.
  final AccountType? type;
  final List<Account> accounts;

  /// Stable key for widgets.
  String get key => group != null ? 'g:${group!.id}' : 't:${type?.name}';

  int subtotal(Map<String, int> balances) => accounts.fold(
    0,
    (sum, a) => sum + (balances[a.id] ?? a.openingBalanceMinor),
  );
}

/// Groups [accounts] for the account list: user groups first (in their
/// sort order), then ungrouped accounts by type. Archived accounts are left
/// out unless [includeArchived]. Accounts keep their `sortOrder` order.
List<AccountSection> groupAccounts(
  List<Account> accounts,
  List<AccountGroup> groups, {
  bool includeArchived = false,
}) {
  final visible = [
    for (final a in accounts)
      if (a.deletedAt == null && (includeArchived || !a.archived)) a,
  ]..sort(compareAccounts);
  final groupIds = {for (final g in groups) g.id};
  final sortedGroups = [...groups]
    ..sort((a, b) {
      final c = a.sortOrder.compareTo(b.sortOrder);
      return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  final sections = <AccountSection>[];
  for (final g in sortedGroups) {
    final inGroup = [
      for (final a in visible)
        if (a.groupId == g.id) a,
    ];
    if (inGroup.isNotEmpty) {
      sections.add(AccountSection(group: g, accounts: inGroup));
    }
  }
  final ungrouped = [
    for (final a in visible)
      if (a.groupId == null || !groupIds.contains(a.groupId)) a,
  ];
  for (final t in AccountType.values) {
    final ofType = [
      for (final a in ungrouped)
        if (a.type == t) a,
    ];
    if (ofType.isNotEmpty) {
      sections.add(AccountSection(type: t, accounts: ofType));
    }
  }
  return sections;
}

/// Order of accounts in lists: sortOrder, then name.
int compareAccounts(Account a, Account b) {
  final c = a.sortOrder.compareTo(b.sortOrder);
  return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

/// Moves the element at [oldIndex] to [newIndex] with the semantics of
/// `ReorderableListView.onReorder` (newIndex counts the removed element).
List<T> reorderList<T>(List<T> list, int oldIndex, int newIndex) {
  final result = [...list];
  final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
  final item = result.removeAt(oldIndex);
  result.insert(target.clamp(0, result.length), item);
  return result;
}

/// Moves the element at [oldIndex] so that it ends up at [newIndex]
/// (`ReorderableListView.onReorderItem` semantics).
List<T> moveItem<T>(List<T> list, int oldIndex, int newIndex) {
  final result = [...list];
  final item = result.removeAt(oldIndex);
  result.insert(newIndex.clamp(0, result.length), item);
  return result;
}

/// An entry of the flat reorder list: a group header (`groupId`, null for
/// "no group") or an account.
@immutable
class LayoutEntry {
  const LayoutEntry.header(this.groupId) : accountId = null;
  const LayoutEntry.account(String this.accountId) : groupId = null;

  final String? groupId;
  final String? accountId;

  bool get isHeader => accountId == null;

  @override
  bool operator ==(Object other) =>
      other is LayoutEntry &&
      other.groupId == groupId &&
      other.accountId == accountId;

  @override
  int get hashCode => Object.hash(groupId, accountId);
}

/// Resolves a flat reorder list (headers and accounts) into the group and
/// position of every account: an account belongs to the closest header
/// above it (the first header if none).
List<({String accountId, String? groupId})> resolveLayout(
  List<LayoutEntry> entries,
) {
  var current = entries
      .firstWhere(
        (e) => e.isHeader,
        orElse: () => const LayoutEntry.header(null),
      )
      .groupId;
  final result = <({String accountId, String? groupId})>[];
  for (final e in entries) {
    if (e.isHeader) {
      current = e.groupId;
    } else {
      result.add((accountId: e.accountId!, groupId: current));
    }
  }
  return result;
}

/// Difference between the real (bank) balance and the recorded cleared
/// balance; positive = money is missing in the app.
int reconciliationDifference({
  required int actualMinor,
  required int clearedMinor,
}) => actualMinor - clearedMinor;
