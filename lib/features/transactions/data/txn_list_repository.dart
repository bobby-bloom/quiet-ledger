import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/transactions/data/txn_query.dart';
import 'package:personal_finance/features/transactions/domain/txn_filter.dart';

final txnListRepositoryProvider = Provider<TxnListRepository>(
  (ref) => TxnListRepository(ref.watch(databaseProvider)),
);

/// One row of the transaction list (a transaction leg with what the row
/// needs to render). Names (category, account, tags) are resolved from the
/// shared lookups in the UI.
@immutable
class TxnListItem {
  const TxnListItem({
    required this.id,
    required this.rowId,
    required this.accountId,
    required this.date,
    required this.amountMinor,
    required this.type,
    required this.status,
    required this.cursor,
    this.payee,
    this.note,
    this.categoryId,
    this.transferPeerId,
    this.peerAccountId,
    this.recurringRuleId,
    this.importBatchId,
    this.splitCount = 0,
    this.splitCategoryIds = const [],
    this.tagIds = const [],
    this.attachmentCount = 0,
    this.runningBalance,
  });

  final String id;
  final int rowId;
  final String accountId;
  final DateTime date;

  /// Signed amount on [accountId].
  final int amountMinor;
  final TxnType type;
  final TxnStatus status;
  final String? payee;
  final String? note;
  final String? categoryId;
  final String? transferPeerId;

  /// Account of the other transfer leg.
  final String? peerAccountId;
  final String? recurringRuleId;
  final String? importBatchId;
  final int splitCount;
  final List<String> splitCategoryIds;
  final List<String> tagIds;
  final int attachmentCount;

  /// Account balance after this entry (only when requested).
  final int? runningBalance;

  /// Position in the list's sort order.
  final TxnCursor cursor;

  bool get isTransfer => transferPeerId != null || type == TxnType.transfer;
  bool get isSplit => splitCount > 0;

  /// Id of the outgoing leg for transfers (edits are expressed from it).
  String get editId =>
      transferPeerId != null && amountMinor > 0 ? transferPeerId! : id;

  TxnListItem withStatus(TxnStatus s) => TxnListItem(
    id: id,
    rowId: rowId,
    accountId: accountId,
    date: date,
    amountMinor: amountMinor,
    type: type,
    status: s,
    cursor: cursor,
    payee: payee,
    note: note,
    categoryId: categoryId,
    transferPeerId: transferPeerId,
    peerAccountId: peerAccountId,
    recurringRuleId: recurringRuleId,
    importBatchId: importBatchId,
    splitCount: splitCount,
    splitCategoryIds: splitCategoryIds,
    tagIds: tagIds,
    attachmentCount: attachmentCount,
    runningBalance: runningBalance,
  );

  @override
  bool operator ==(Object other) =>
      other is TxnListItem &&
      other.id == id &&
      other.rowId == rowId &&
      other.accountId == accountId &&
      other.date == date &&
      other.amountMinor == amountMinor &&
      other.type == type &&
      other.status == status &&
      other.payee == payee &&
      other.note == note &&
      other.categoryId == categoryId &&
      other.peerAccountId == peerAccountId &&
      other.splitCount == splitCount &&
      other.attachmentCount == attachmentCount &&
      other.runningBalance == runningBalance &&
      _eq(other.tagIds, tagIds) &&
      _eq(other.splitCategoryIds, splitCategoryIds);

  static bool _eq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    rowId,
    amountMinor,
    date,
    status,
    payee,
    categoryId,
    runningBalance,
    Object.hashAll(tagIds),
  );
}

/// Count and income/expense totals of a filtered list. Transfers only count
/// when the list is filtered to accounts (they move money on them).
@immutable
class TxnTotals {
  const TxnTotals({this.count = 0, this.inMinor = 0, this.outMinor = 0});

  final int count;
  final int inMinor;

  /// Negative or zero.
  final int outMinor;

  @override
  bool operator ==(Object other) =>
      other is TxnTotals &&
      other.count == count &&
      other.inMinor == inMinor &&
      other.outMinor == outMinor;

  @override
  int get hashCode => Object.hash(count, inMinor, outMinor);
}

/// Read side of the transaction list. All queries filter in SQL and load in
/// keyset pages, so 100k+ rows stay fast.
class TxnListRepository {
  TxnListRepository(this.db);

  final AppDatabase db;

  /// Tables whose changes invalidate list rows.
  Set<ResultSetImplementation<dynamic, dynamic>> get readTables => {
    db.transactions,
    db.transactionSplits,
    db.transactionTags,
    db.attachments,
    db.customFieldValues,
    db.categories,
  };

  /// Emits whenever a table relevant to the list changes.
  Stream<void> changes() =>
      db.tableUpdates(TableUpdateQuery.onAllTables(readTables)).map((_) {});

  /// Loads rows of [filter] in [sort] order.
  ///
  /// * [after]: keyset cursor; only rows strictly after it.
  /// * [upTo]: only rows at or before this cursor (reloading a page).
  /// * [limit]: maximum number of rows (null = no limit, use with [upTo]).
  /// * [runningBalance]: compute the balance after each row; requires a
  ///   single-account filter and a date sort, otherwise it is ignored.
  Future<List<TxnListItem>> fetch(
    TxnFilter filter, {
    TxnSort sort = TxnSort.dateDesc,
    TxnCursor? after,
    TxnCursor? upTo,
    int? limit = 60,
    bool runningBalance = false,
    DateTime? now,
  }) async {
    final q = _select(
      filter,
      sort: sort,
      after: after,
      upTo: upTo,
      limit: limit,
      runningBalance: runningBalance,
      now: now ?? DateTime.now(),
    );
    final rows = await db
        .customSelect(q.sql, variables: q.vars, readsFrom: readTables)
        .get();
    return [for (final r in rows) _item(r, sort)];
  }

  /// Reactive variant of [fetch] (used for small fixed-size lists such as
  /// the dashboard's recent transactions).
  Stream<List<TxnListItem>> watch(
    TxnFilter filter, {
    TxnSort sort = TxnSort.dateDesc,
    int limit = 10,
    DateTime? now,
  }) {
    final q = _select(
      filter,
      sort: sort,
      limit: limit,
      runningBalance: false,
      now: now ?? DateTime.now(),
    );
    return db
        .customSelect(q.sql, variables: q.vars, readsFrom: readTables)
        .watch()
        .map((rows) => [for (final r in rows) _item(r, sort)]);
  }

  /// Whether running balances can be computed for [filter] / [sort].
  static bool runningBalanceApplies(TxnFilter filter, TxnSort sort) =>
      filter.singleAccountId != null &&
      (sort == TxnSort.dateDesc || sort == TxnSort.dateAsc);

  SqlPart _select(
    TxnFilter filter, {
    required TxnSort sort,
    required bool runningBalance,
    required DateTime now,
    TxnCursor? after,
    TxnCursor? upTo,
    int? limit,
  }) {
    final where = TxnQuery.where(filter, now: now);
    final vars = <Variable<Object>>[];
    final withBalance = runningBalance && runningBalanceApplies(filter, sort);
    var cte = '';
    var balanceCol = '';
    var balanceJoin = '';
    if (withBalance) {
      final account = filter.singleAccountId!;
      cte =
          'WITH bal AS (SELECT b.id AS bid, SUM(b.amount_minor) OVER '
          '(ORDER BY b.date, b.rowid ROWS UNBOUNDED PRECEDING) AS run '
          'FROM transactions b WHERE b.account_id = ? AND '
          'b.deleted_at IS NULL) ';
      vars.add(Variable<Object>(account));
      balanceCol =
          ', bal.run + (SELECT a.opening_balance_minor FROM accounts a '
          'WHERE a.id = t.account_id) AS running_balance';
      balanceJoin = ' LEFT JOIN bal ON bal.bid = t.id';
    }
    final conditions = [where.sql];
    vars.addAll(where.vars);
    if (after != null) {
      final a = TxnQuery.after(sort, after);
      conditions.add(a.sql);
      vars.addAll(a.vars);
    }
    if (upTo != null) {
      final b = TxnQuery.atOrBefore(sort, upTo);
      conditions.add(b.sql);
      vars.addAll(b.vars);
    }
    final limitSql = limit == null ? '' : ' LIMIT $limit';
    final sql =
        '${cte}SELECT t.rowid AS rid, t.id, t.account_id, t.date, '
        't.amount_minor, t.type, t.status, t.payee, t.note, t.category_id, '
        't.transfer_peer_id, t.recurring_rule_id, t.import_batch_id, '
        'p.account_id AS peer_account_id, '
        "(SELECT group_concat(COALESCE(s.category_id, ''), ',') FROM "
        'transaction_splits s WHERE s.transaction_id = t.id AND '
        's.deleted_at IS NULL) AS split_cats, '
        "(SELECT group_concat(tt.tag_id, ',') FROM transaction_tags tt "
        'WHERE tt.transaction_id = t.id AND tt.deleted_at IS NULL) AS tag_ids, '
        '(SELECT COUNT(*) FROM attachments att WHERE att.transaction_id = t.id '
        'AND att.deleted_at IS NULL) AS attachment_count, '
        '${TxnQuery.sortKeyColumns(sort)}$balanceCol '
        '${TxnQuery.from}$balanceJoin '
        'WHERE ${conditions.join(' AND ')} '
        '${TxnQuery.orderBy(sort)}$limitSql';
    return SqlPart(sql, vars);
  }

  TxnListItem _item(QueryRow r, TxnSort sort) {
    final splitCats = r.readNullable<String>('split_cats');
    final splits = splitCats == null ? const <String>[] : splitCats.split(',');
    final tags = r.readNullable<String>('tag_ids');
    final terms = TxnQuery.sortTerms(sort).length;
    return TxnListItem(
      id: r.read<String>('id'),
      rowId: r.read<int>('rid'),
      accountId: r.read<String>('account_id'),
      date: r.read<DateTime>('date'),
      amountMinor: r.read<int>('amount_minor'),
      type: TxnType.values.byName(r.read<String>('type')),
      status: TxnStatus.values.byName(r.read<String>('status')),
      payee: r.readNullable<String>('payee'),
      note: r.readNullable<String>('note'),
      categoryId: r.readNullable<String>('category_id'),
      transferPeerId: r.readNullable<String>('transfer_peer_id'),
      peerAccountId: r.readNullable<String>('peer_account_id'),
      recurringRuleId: r.readNullable<String>('recurring_rule_id'),
      importBatchId: r.readNullable<String>('import_batch_id'),
      splitCount: splits.length,
      splitCategoryIds: [
        for (final s in splits)
          if (s.isNotEmpty) s,
      ],
      tagIds: tags == null || tags.isEmpty ? const [] : tags.split(','),
      attachmentCount: r.read<int>('attachment_count'),
      runningBalance: r.data.containsKey('running_balance')
          ? r.readNullable<int>('running_balance')
          : null,
      cursor: TxnCursor([
        for (var i = 0; i < terms; i++) r.data['k$i']! as Object,
      ]),
    );
  }

  /// Count and in/out totals for [filter], updated live.
  Stream<TxnTotals> watchTotals(TxnFilter filter, {DateTime? now}) {
    final where = TxnQuery.where(filter, now: now ?? DateTime.now());
    final includeTransfers = filter.accountIds.isNotEmpty;
    final cond = includeTransfers ? '' : "AND t.type <> 'transfer'";
    return db
        .customSelect(
          'SELECT COUNT(*) AS c, '
          'COALESCE(SUM(CASE WHEN t.amount_minor > 0 $cond '
          'THEN t.amount_minor END), 0) AS i, '
          'COALESCE(SUM(CASE WHEN t.amount_minor < 0 $cond '
          'THEN t.amount_minor END), 0) AS o '
          '${TxnQuery.from} WHERE ${where.sql}',
          variables: where.vars,
          readsFrom: readTables,
        )
        .watch()
        .map(
          (rows) => TxnTotals(
            count: rows.single.read<int>('c'),
            inMinor: rows.single.read<int>('i'),
            outMinor: rows.single.read<int>('o'),
          ),
        );
  }

  /// Net amount per day in `[start, end)` for [filter] (group headers).
  /// Transfers are excluded unless the list is filtered to accounts.
  Future<Map<DateTime, int>> daySums(
    TxnFilter filter,
    DateTime start,
    DateTime end, {
    DateTime? now,
  }) async {
    final where = TxnQuery.where(filter, now: now ?? DateTime.now());
    final cond = filter.accountIds.isNotEmpty ? '' : "AND t.type <> 'transfer'";
    final rows = await db
        .customSelect(
          'SELECT t.date AS d, SUM(t.amount_minor) AS s ${TxnQuery.from} '
          'WHERE ${where.sql} AND t.date >= ? AND t.date < ? $cond '
          'GROUP BY t.date',
          variables: [
            ...where.vars,
            Variable<DateTime>(start),
            Variable<DateTime>(end),
          ],
          readsFrom: readTables,
        )
        .get();
    return {for (final r in rows) r.read<DateTime>('d'): r.read<int>('s')};
  }

  /// Ids of all rows matching [filter] (bulk "select all"), capped.
  Future<List<String>> ids(
    TxnFilter filter, {
    int cap = 10000,
    DateTime? now,
  }) async {
    final where = TxnQuery.where(filter, now: now ?? DateTime.now());
    final rows = await db
        .customSelect(
          'SELECT t.id AS id ${TxnQuery.from} WHERE ${where.sql} LIMIT $cap',
          variables: where.vars,
          readsFrom: readTables,
        )
        .get();
    return [for (final r in rows) r.read<String>('id')];
  }

  /// Number of rows matching [filter] (saved filter badges).
  Stream<int> watchCount(TxnFilter filter, {DateTime? now}) =>
      watchTotals(filter, now: now).map((t) => t.count);
}
