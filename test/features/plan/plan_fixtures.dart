import 'package:drift/drift.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';

import '../../helpers/test_app.dart';

/// Small fixture builder for Plan feature tests.
class PlanFixture {
  PlanFixture(this.db)
    : writer = SyncWriter(db, testClock(node: 'fixture'), 'fixture'),
      ledger = LedgerRepository(
        db,
        SyncWriter(db, testClock(node: 'fixture'), 'fixture'),
      );

  final AppDatabase db;
  final SyncWriter writer;
  final LedgerRepository ledger;

  Future<String> account(
    String name, {
    int opening = 0,
    bool includeInBudgets = true,
    AccountType type = AccountType.checking,
    DateTime? openingDate,
  }) => writer.insert(
    db.accounts,
    AccountsCompanion(
      name: Value(name),
      type: Value(type),
      openingBalanceMinor: Value(opening),
      openingDate: Value(openingDate ?? DateTime(2025)),
      includeInBudgets: Value(includeInBudgets),
    ),
  );

  Future<String> category(
    String name, {
    CategoryKind kind = CategoryKind.expense,
    String? parentId,
    String? rolloverOverride,
    int? warnThresholdOverride,
  }) => writer.insert(
    db.categories,
    CategoriesCompanion(
      name: Value(name),
      kind: Value(kind),
      parentId: Value(parentId),
      rolloverOverride: Value(rolloverOverride),
      warnThresholdOverride: Value(warnThresholdOverride),
    ),
  );

  Future<String> expense(
    String account,
    String? category,
    int amountMinor,
    DateTime date, {
    TxnStatus status = TxnStatus.cleared,
  }) => ledger.create(
    TxnDraft(
      accountId: account,
      amountMinor: -amountMinor.abs(),
      date: date,
      categoryId: category,
      status: status,
    ),
  );

  Future<String> income(
    String account,
    String? category,
    int amountMinor,
    DateTime date,
  ) => ledger.create(
    TxnDraft(
      accountId: account,
      amountMinor: amountMinor.abs(),
      date: date,
      type: TxnType.income,
      categoryId: category,
    ),
  );
}
