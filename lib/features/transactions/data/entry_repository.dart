import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/settings/setting_def.dart';
import 'package:personal_finance/features/transactions/data/txn_query.dart';

final entryRepositoryProvider = Provider<EntryRepository>(
  (ref) => EntryRepository(ref.watch(databaseProvider)),
);

/// What history says about a payee: the category, account and type of the
/// most recent transaction with that payee.
@immutable
class PayeeSuggestion {
  const PayeeSuggestion({
    required this.payee,
    required this.count,
    required this.type,
    this.categoryId,
    this.accountId,
  });

  final String payee;

  /// Number of transactions with this payee.
  final int count;
  final TxnType type;
  final String? categoryId;
  final String? accountId;

  @override
  bool operator ==(Object other) =>
      other is PayeeSuggestion &&
      other.payee == payee &&
      other.count == count &&
      other.type == type &&
      other.categoryId == categoryId &&
      other.accountId == accountId;

  @override
  int get hashCode => Object.hash(payee, count, type, categoryId, accountId);

  @override
  String toString() =>
      'PayeeSuggestion($payee, $count, $type, $categoryId, $accountId)';
}

/// Hidden settings that remember the last quick-add values ("last used"
/// defaults). Not shown in the settings UI.
abstract final class EntryMemory {
  static final lastType = SettingDef.string(
    key: 'entry.lastUsedType',
    section: SettingSection.entry,
    defaultValue: 'expense',
    label: (l) => l.setOptLastUsed,
    hidden: true,
  );

  /// ISO date (yyyy-MM-dd) of the last saved entry.
  static final lastDate = SettingDef.optionalString(
    key: 'entry.lastUsedDate',
    section: SettingSection.entry,
    label: (l) => l.setOptLastUsed,
    hidden: true,
  );

  static final lastAccountId = SettingDef.optionalString(
    key: 'entry.lastUsedAccountId',
    section: SettingSection.entry,
    label: (l) => l.setOptLastUsed,
    hidden: true,
  );

  static final all = <SettingDef<Object?>>[lastType, lastDate, lastAccountId];
}

/// History lookups for quick add: payee autocomplete with learned category
/// and account, recently used categories.
class EntryRepository {
  EntryRepository(this.db);

  final AppDatabase db;

  /// Payees matching [query] (word-prefix, via the FTS index), most
  /// frequent first, each with the category/account of its latest entry.
  Future<List<PayeeSuggestion>> suggestPayees(
    String query, {
    int limit = 8,
  }) async {
    final words = TxnQuery.ftsQuery(query);
    if (words.isEmpty) return const [];
    // Restrict all terms to the payee column.
    final fts = 'payee : ($words)';
    final rows = await db
        .customSelect(
          'SELECT payee, category_id, account_id, type, cnt FROM ( '
          'SELECT t.payee AS payee, t.category_id AS category_id, '
          't.account_id AS account_id, t.type AS type, '
          'COUNT(*) OVER (PARTITION BY lower(t.payee)) AS cnt, '
          'ROW_NUMBER() OVER (PARTITION BY lower(t.payee) '
          'ORDER BY t.date DESC, t.rowid DESC) AS rn '
          'FROM txn_search s JOIN transactions t ON t.rowid = s.rowid '
          'WHERE txn_search MATCH ? AND t.deleted_at IS NULL '
          'AND t.payee IS NOT NULL AND (t.transfer_peer_id IS NULL OR '
          't.amount_minor < 0) '
          ') WHERE rn = 1 ORDER BY cnt DESC, payee COLLATE NOCASE LIMIT ?',
          variables: [Variable<String>(fts), Variable<int>(limit)],
          readsFrom: {db.transactions},
        )
        .get();
    return [for (final r in rows) _suggestion(r)];
  }

  /// The latest transaction with exactly this payee (case-insensitive), or
  /// null when the payee is new.
  Future<PayeeSuggestion?> lastForPayee(String payee) async {
    final p = payee.trim();
    if (p.isEmpty) return null;
    final row = await db
        .customSelect(
          'SELECT t.payee AS payee, t.category_id AS category_id, '
          't.account_id AS account_id, t.type AS type, '
          '(SELECT COUNT(*) FROM transactions c WHERE c.deleted_at IS NULL '
          'AND c.payee = ?1 COLLATE NOCASE) AS cnt '
          'FROM transactions t WHERE t.deleted_at IS NULL '
          'AND t.payee = ?1 COLLATE NOCASE AND (t.transfer_peer_id IS NULL '
          'OR t.amount_minor < 0) ORDER BY t.date DESC, t.rowid DESC LIMIT 1',
          variables: [Variable<String>(p)],
          readsFrom: {db.transactions},
        )
        .getSingleOrNull();
    return row == null ? null : _suggestion(row);
  }

  PayeeSuggestion _suggestion(QueryRow r) => PayeeSuggestion(
    payee: r.read<String>('payee'),
    count: r.read<int>('cnt'),
    type: TxnType.values.byName(r.read<String>('type')),
    categoryId: r.readNullable<String>('category_id'),
    accountId: r.readNullable<String>('account_id'),
  );

  /// Ids of the most recently used categories (newest first), looking at
  /// the latest 1000 entries only so it stays fast on large ledgers. Split
  /// lines count too.
  Stream<List<String>> watchRecentCategories({required int limit}) {
    if (limit <= 0) return Stream.value(const []);
    return db
        .customSelect(
          'SELECT cid FROM ( '
          'SELECT COALESCE(t.category_id, s.category_id) AS cid, '
          't.r AS r FROM (SELECT rowid AS r, id, category_id FROM transactions '
          'WHERE deleted_at IS NULL ORDER BY rowid DESC LIMIT 1000) t '
          'LEFT JOIN transaction_splits s ON s.transaction_id = t.id '
          'AND s.deleted_at IS NULL AND t.category_id IS NULL '
          ') x JOIN categories c ON c.id = x.cid '
          'WHERE c.deleted_at IS NULL AND c.archived = 0 '
          'GROUP BY cid ORDER BY MAX(r) DESC LIMIT ?',
          variables: [Variable<int>(limit)],
          readsFrom: {db.transactions, db.transactionSplits, db.categories},
        )
        .watch()
        .map((rows) => [for (final r in rows) r.read<String>('cid')]);
  }
}
