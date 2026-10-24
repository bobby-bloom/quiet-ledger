import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/accounts/domain/account_draft.dart';

final accountsRepositoryProvider = Provider<AccountsRepository>(
  (ref) => AccountsRepository(
    ref.watch(databaseProvider),
    ref.watch(syncWriterProvider),
  ),
);

/// Thrown when an account cannot be deleted because data refers to it.
class AccountInUseException implements Exception {
  const AccountInUseException(this.usage);

  final AccountUsage usage;

  @override
  String toString() =>
      'AccountInUseException(${usage.transactions} transactions, '
      '${usage.recurringRules} recurring rules)';
}

/// How much data refers to an account.
class AccountUsage {
  const AccountUsage({
    required this.transactions,
    required this.recurringRules,
  });

  final int transactions;
  final int recurringRules;

  bool get inUse => transactions > 0 || recurringRules > 0;
}

/// Writes for accounts and account groups. All writes go through
/// [SyncWriter]; reads of reference data use the shared lookups
/// (`accountsProvider`, `accountGroupsProvider`).
class AccountsRepository {
  AccountsRepository(this.db, this.writer);

  final AppDatabase db;
  final SyncWriter writer;

  // ----------------------------------------------------------- accounts ---

  /// Creates an account at the end of the list and returns its id.
  Future<String> create(AccountDraft draft) {
    _check(draft);
    return writer.transaction(() async {
      final order = await _nextAccountOrder();
      return await writer.insert(
        db.accounts,
        _companion(draft).copyWith(sortOrder: Value(order)),
      );
    });
  }

  /// Replaces the editable fields of account [id] with [draft].
  Future<void> update(String id, AccountDraft draft) {
    _check(draft);
    return writer.update(db.accounts, id, _companion(draft));
  }

  Future<void> setArchived(String id, {required bool archived}) => writer
      .update(db.accounts, id, AccountsCompanion(archived: Value(archived)));

  /// Assigns account [id] to [groupId] (null = ungrouped).
  Future<void> moveToGroup(String id, String? groupId) => writer.update(
    db.accounts,
    id,
    AccountsCompanion(groupId: Value(groupId)),
  );

  Future<AccountUsage> usage(String id) async {
    final txns = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM transactions '
          'WHERE account_id = ? AND deleted_at IS NULL',
          variables: [Variable<String>(id)],
          readsFrom: {db.transactions},
        )
        .getSingle();
    final rules = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM recurring_rules '
          "WHERE deleted_at IS NULL AND template LIKE '%' || ? || '%'",
          variables: [Variable<String>(id)],
          readsFrom: {db.recurringRules},
        )
        .getSingle();
    return AccountUsage(
      transactions: txns.read<int>('c'),
      recurringRules: rules.read<int>('c'),
    );
  }

  /// Soft-deletes account [id]. Only allowed when no transactions or
  /// recurring rules refer to it (archive it otherwise); throws
  /// [AccountInUseException]. Goals linked to the account are unlinked and
  /// its account-scoped custom field values are removed.
  Future<void> delete(String id) => writer.transaction(() async {
    final u = await usage(id);
    if (u.inUse) throw AccountInUseException(u);
    final goals = await (db.select(
      db.goals,
    )..where((g) => g.accountId.equals(id) & g.deletedAt.isNull())).get();
    for (final g in goals) {
      await writer.update(
        db.goals,
        g.id,
        const GoalsCompanion(accountId: Value(null)),
      );
    }
    await writer.deleteWhere(db.customFieldValues, 'entity_id', id);
    await writer.delete(db.accounts, id);
  });

  /// Restores a deleted account (undo).
  Future<void> restore(String id) => writer.undelete(db.accounts, id);

  /// Sets `sortOrder` to the position in [orderedIds] (only rows whose
  /// order changes are written).
  Future<void> reorder(List<String> orderedIds) => writer.transaction(() async {
    final current = await _accountOrders();
    for (var i = 0; i < orderedIds.length; i++) {
      if (current[orderedIds[i]] != i) {
        await writer.update(
          db.accounts,
          orderedIds[i],
          AccountsCompanion(sortOrder: Value(i)),
        );
      }
    }
  });

  /// Applies the result of the reorder mode: the order and group of every
  /// listed account.
  Future<void> applyLayout(
    List<({String accountId, String? groupId})> layout,
  ) => writer.transaction(() async {
    final rows = await (db.select(
      db.accounts,
    )..where((a) => a.deletedAt.isNull())).get();
    final byId = {for (final r in rows) r.id: r};
    for (var i = 0; i < layout.length; i++) {
      final e = layout[i];
      final a = byId[e.accountId];
      if (a == null) continue;
      if (a.sortOrder == i && a.groupId == e.groupId) continue;
      await writer.update(
        db.accounts,
        a.id,
        AccountsCompanion(sortOrder: Value(i), groupId: Value(e.groupId)),
      );
    }
  });

  // ------------------------------------------------------------- groups ---

  /// Creates a group at the end and returns its id.
  Future<String> createGroup(String name) {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError.value(name, 'name', 'empty');
    return writer.transaction(() async {
      final max = db.accountGroups.sortOrder.max();
      final row =
          await (db.selectOnly(db.accountGroups)
                ..addColumns([max])
                ..where(db.accountGroups.deletedAt.isNull()))
              .getSingle();
      return await writer.insert(
        db.accountGroups,
        AccountGroupsCompanion(
          name: Value(n),
          sortOrder: Value((row.read(max) ?? -1) + 1),
        ),
      );
    });
  }

  Future<void> renameGroup(String id, String name) {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError.value(name, 'name', 'empty');
    return writer.update(
      db.accountGroups,
      id,
      AccountGroupsCompanion(name: Value(n)),
    );
  }

  Future<void> reorderGroups(List<String> orderedIds) =>
      writer.transaction(() async {
        for (var i = 0; i < orderedIds.length; i++) {
          await writer.update(
            db.accountGroups,
            orderedIds[i],
            AccountGroupsCompanion(sortOrder: Value(i)),
          );
        }
      });

  /// Soft-deletes group [id]; its accounts become ungrouped.
  Future<void> deleteGroup(String id) => writer.transaction(() async {
    final members = await (db.select(
      db.accounts,
    )..where((a) => a.groupId.equals(id) & a.deletedAt.isNull())).get();
    for (final a in members) {
      await writer.update(
        db.accounts,
        a.id,
        const AccountsCompanion(groupId: Value(null)),
      );
    }
    await writer.delete(db.accountGroups, id);
  });

  // ------------------------------------------------------------ helpers ---

  void _check(AccountDraft d) {
    final problems = d.validate();
    if (problems.isNotEmpty) {
      throw ArgumentError('Invalid account: ${problems.join(', ')}');
    }
  }

  Future<int> _nextAccountOrder() async {
    final max = db.accounts.sortOrder.max();
    final row =
        await (db.selectOnly(db.accounts)
              ..addColumns([max])
              ..where(db.accounts.deletedAt.isNull()))
            .getSingle();
    return (row.read(max) ?? -1) + 1;
  }

  Future<Map<String, int>> _accountOrders() async {
    final rows = await (db.select(
      db.accounts,
    )..where((a) => a.deletedAt.isNull())).get();
    return {for (final r in rows) r.id: r.sortOrder};
  }

  AccountsCompanion _companion(AccountDraft d) => AccountsCompanion(
    name: Value(d.name.trim()),
    type: Value(d.type),
    openingBalanceMinor: Value(d.openingBalanceMinor),
    openingDate: Value(dateOnly(d.openingDate)),
    color: Value(d.color),
    icon: Value(d.icon),
    groupId: Value(d.groupId),
    includeInNetWorth: Value(d.includeInNetWorth),
    includeInBudgets: Value(d.includeInBudgets),
    includeInForecast: Value(d.includeInForecast),
    lowBalanceThresholdMinor: Value(d.lowBalanceThresholdMinor),
    expectedAnnualReturnBp: Value(d.expectedAnnualReturnBp),
    interestRateBp: Value(d.interestRateBp),
    note: Value(
      d.note == null || d.note!.trim().isEmpty ? null : d.note!.trim(),
    ),
    archived: Value(d.archived),
  );
}
