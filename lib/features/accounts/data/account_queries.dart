import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';

/// A row of the compact transaction list on the account detail screen.
@immutable
class RecentTxn {
  const RecentTxn({
    required this.id,
    required this.date,
    required this.amountMinor,
    required this.type,
    required this.status,
    this.payee,
    this.note,
    this.categoryName,
    this.parentCategoryName,
    this.categoryIcon,
    this.categoryColor,
    this.peerAccountName,
    this.isSplit = false,
  });

  final String id;
  final DateTime date;
  final int amountMinor;
  final TxnType type;
  final TxnStatus status;
  final String? payee;
  final String? note;
  final String? categoryName;
  final String? parentCategoryName;
  final String? categoryIcon;
  final int? categoryColor;

  /// Other account of a transfer.
  final String? peerAccountName;
  final bool isSplit;
}

/// Watches the newest [limit] transactions of [accountId] (planned
/// entries included, so upcoming items are visible).
Stream<List<RecentTxn>> watchRecentTransactions(
  AppDatabase db,
  String accountId, {
  int limit = 20,
}) {
  return db
      .customSelect(
        'SELECT t.id, t.date, t.amount_minor, t.type, t.status, t.payee, '
        't.note, c.name AS cat_name, p.name AS parent_name, '
        'c.icon AS cat_icon, COALESCE(c.color, p.color) AS cat_color, '
        'pa.name AS peer_name, '
        'EXISTS (SELECT 1 FROM transaction_splits s WHERE s.transaction_id = '
        't.id AND s.deleted_at IS NULL) AS is_split '
        'FROM transactions t '
        'LEFT JOIN categories c ON c.id = t.category_id '
        'LEFT JOIN categories p ON p.id = c.parent_id '
        'LEFT JOIN transactions peer ON peer.id = t.transfer_peer_id '
        'LEFT JOIN accounts pa ON pa.id = peer.account_id '
        'WHERE t.account_id = ? AND t.deleted_at IS NULL '
        'ORDER BY t.date DESC, t.created_at DESC LIMIT ?',
        variables: [Variable<String>(accountId), Variable<int>(limit)],
        readsFrom: {
          db.transactions,
          db.categories,
          db.accounts,
          db.transactionSplits,
        },
      )
      .watch()
      .map(
        (rows) => [
          for (final r in rows)
            RecentTxn(
              id: r.read<String>('id'),
              date: r.read<DateTime>('date'),
              amountMinor: r.read<int>('amount_minor'),
              type: _byName(TxnType.values, r.read<String>('type')),
              status: _byName(TxnStatus.values, r.read<String>('status')),
              payee: r.readNullable<String>('payee'),
              note: r.readNullable<String>('note'),
              categoryName: r.readNullable<String>('cat_name'),
              parentCategoryName: r.readNullable<String>('parent_name'),
              categoryIcon: r.readNullable<String>('cat_icon'),
              categoryColor: r.readNullable<int>('cat_color'),
              peerAccountName: r.readNullable<String>('peer_name'),
              isSplit: r.read<bool>('is_split'),
            ),
        ],
      );
}

T _byName<T extends Enum>(List<T> values, String name) =>
    values.firstWhere((v) => v.name == name, orElse: () => values.first);

final recentTransactionsProvider = StreamProvider.autoDispose
    .family<List<RecentTxn>, String>(
      (ref, accountId) =>
          watchRecentTransactions(ref.watch(databaseProvider), accountId),
    );

/// Number of live transactions per account id.
final accountTxnCountsProvider = StreamProvider<Map<String, int>>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT account_id AS id, COUNT(*) AS c FROM transactions '
        'WHERE deleted_at IS NULL GROUP BY account_id',
        readsFrom: {db.transactions},
      )
      .watch()
      .map(
        (rows) => {
          for (final r in rows) r.read<String>('id'): r.read<int>('c'),
        },
      );
});
