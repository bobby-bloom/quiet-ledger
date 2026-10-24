import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/accounts/domain/account_grouping.dart';

final reconciliationServiceProvider = Provider<ReconciliationService>(
  (ref) => ReconciliationService(
    ref.watch(databaseProvider),
    ref.watch(ledgerRepositoryProvider),
  ),
);

/// Recorded balances of an account as of a date, split by status.
class RecordedBalance {
  const RecordedBalance({
    required this.clearedMinor,
    required this.pendingMinor,
    required this.pendingCount,
  });

  /// Opening balance plus all cleared transactions up to the date.
  final int clearedMinor;

  /// Sum of pending transactions up to the date.
  final int pendingMinor;
  final int pendingCount;

  int get totalMinor => clearedMinor + pendingMinor;
}

/// Balance reconciliation (PLAN.md §2.2): compares the real bank balance
/// with the cleared balance in the app. The difference is resolved by
/// clearing pending transactions the bank already booked and, for whatever
/// remains, a correction transaction.
class ReconciliationService {
  ReconciliationService(this.db, this.ledger);

  final AppDatabase db;
  final LedgerRepository ledger;

  /// Watches the recorded balances of [accountId] up to and including
  /// [asOf].
  Stream<RecordedBalance> watchRecorded(String accountId, DateTime asOf) {
    return db
        .customSelect(
          'SELECT a.opening_balance_minor + COALESCE((SELECT SUM(t.amount_minor) '
          'FROM transactions t WHERE t.account_id = a.id AND t.deleted_at IS NULL '
          'AND t.status = ? AND t.date <= ?), 0) AS cleared, '
          'COALESCE((SELECT SUM(t.amount_minor) FROM transactions t '
          'WHERE t.account_id = a.id AND t.deleted_at IS NULL '
          'AND t.status = ? AND t.date <= ?), 0) AS pending, '
          '(SELECT COUNT(*) FROM transactions t WHERE t.account_id = a.id '
          'AND t.deleted_at IS NULL AND t.status = ? AND t.date <= ?) AS n '
          'FROM accounts a WHERE a.id = ?',
          variables: [
            Variable<String>(TxnStatus.cleared.name),
            Variable<DateTime>(dateOnly(asOf)),
            Variable<String>(TxnStatus.pending.name),
            Variable<DateTime>(dateOnly(asOf)),
            Variable<String>(TxnStatus.pending.name),
            Variable<DateTime>(dateOnly(asOf)),
            Variable<String>(accountId),
          ],
          readsFrom: {db.accounts, db.transactions},
        )
        .watch()
        .map((rows) {
          if (rows.isEmpty) {
            return const RecordedBalance(
              clearedMinor: 0,
              pendingMinor: 0,
              pendingCount: 0,
            );
          }
          final r = rows.single;
          return RecordedBalance(
            clearedMinor: r.read<int>('cleared'),
            pendingMinor: r.read<int>('pending'),
            pendingCount: r.read<int>('n'),
          );
        });
  }

  Future<RecordedBalance> recorded(String accountId, DateTime asOf) =>
      watchRecorded(accountId, asOf).first;

  /// Pending transactions of [accountId] up to [asOf], newest first.
  Stream<List<Txn>> watchPending(String accountId, DateTime asOf) {
    return (db.select(db.transactions)
          ..where(
            (t) =>
                t.accountId.equals(accountId) &
                t.deletedAt.isNull() &
                t.status.equalsValue(TxnStatus.pending) &
                t.date.isSmallerOrEqualValue(dateOnly(asOf)),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  /// Marks transactions as cleared (bank booked them).
  Future<void> markCleared(Iterable<String> ids) =>
      ledger.bulkUpdate(ids, status: TxnStatus.cleared);

  /// Difference between [actualMinor] and the cleared balance as of
  /// [asOf]; positive = the bank has more than the app.
  Future<int> difference(
    String accountId,
    int actualMinor,
    DateTime asOf,
  ) async {
    final r = await recorded(accountId, asOf);
    return reconciliationDifference(
      actualMinor: actualMinor,
      clearedMinor: r.clearedMinor,
    );
  }

  /// Creates a cleared correction transaction on [asOf] so that the cleared
  /// balance equals [actualMinor]. Returns its id, or null when there is no
  /// difference.
  Future<String?> createCorrection({
    required String accountId,
    required int actualMinor,
    required DateTime asOf,
    required String payee,
    String? note,
  }) async {
    final diff = await difference(accountId, actualMinor, asOf);
    if (diff == 0) return null;
    return await ledger.create(
      TxnDraft(
        accountId: accountId,
        amountMinor: diff,
        date: asOf,
        type: diff > 0 ? TxnType.income : TxnType.expense,
        payee: payee,
        note: note,
      ),
    );
  }
}
