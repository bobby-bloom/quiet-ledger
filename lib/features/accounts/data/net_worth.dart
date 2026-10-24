import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/accounts/domain/account_grouping.dart';

// Balance aggregations for accounts and net worth. Everything is computed in
// SQL so it stays fast with 100k+ transactions. Balances count cleared and
// pending transactions (like `accountBalancesProvider`); planned entries are
// excluded unless asked for.

/// One point of a balance series: the balance at the end of [date].
@immutable
class BalancePoint {
  const BalancePoint(this.date, this.balanceMinor);

  final DateTime date;
  final int balanceMinor;

  @override
  bool operator ==(Object other) =>
      other is BalancePoint &&
      other.date == date &&
      other.balanceMinor == balanceMinor;

  @override
  int get hashCode => Object.hash(date, balanceMinor);

  @override
  String toString() => 'BalancePoint($date, $balanceMinor)';
}

/// Resolution of a balance series.
enum BalanceBucket { day, month }

/// Parameters of [balanceHistoryProvider].
@immutable
class BalanceHistoryQuery {
  const BalanceHistoryQuery({
    required this.from,
    required this.to,
    this.accountIds,
    this.bucket = BalanceBucket.day,
  });

  /// null = all live accounts included in net worth.
  final Set<String>? accountIds;

  /// Inclusive start (local midnight).
  final DateTime from;

  /// Exclusive end (local midnight).
  final DateTime to;
  final BalanceBucket bucket;

  @override
  bool operator ==(Object other) =>
      other is BalanceHistoryQuery &&
      other.from == from &&
      other.to == to &&
      other.bucket == bucket &&
      _setEq(other.accountIds, accountIds);

  @override
  int get hashCode => Object.hash(
    from,
    to,
    bucket,
    accountIds == null ? null : Object.hashAllUnordered(accountIds!),
  );

  static bool _setEq(Set<String>? a, Set<String>? b) => a == null
      ? b == null
      : b != null && a.length == b.length && a.containsAll(b);
}

List<String> _statuses({required bool pending, required bool planned}) => [
  TxnStatus.cleared.name,
  if (pending) TxnStatus.pending.name,
  if (planned) TxnStatus.planned.name,
];

String _marks(int n) => List.filled(n, '?').join(', ');

/// Watches the balance series over `[from, to)`.
///
/// The first point is the balance at the start of [from] (opening balances
/// plus everything before), then one point per day (or month end) with
/// movements, and a final point on the last day of the range so the line
/// reaches the end. With [accountIds] null the series is the net worth of
/// all live accounts that are included in net worth.
Stream<List<BalancePoint>> watchBalanceHistory(
  AppDatabase db, {
  required DateTime from,
  required DateTime to,
  Set<String>? accountIds,
  BalanceBucket bucket = BalanceBucket.day,
  bool includePending = true,
  bool includePlanned = false,
}) {
  final start = dateOnly(from);
  final end = dateOnly(to);
  final statuses = _statuses(pending: includePending, planned: includePlanned);
  final ids = accountIds?.toList();
  final accFilter = ids == null
      ? 'include_in_net_worth = 1'
      : (ids.isEmpty ? '0' : 'id IN (${_marks(ids.length)})');
  final key = bucket == BalanceBucket.day
      ? 't.date'
      : "strftime('%Y-%m', t.date, 'unixepoch', 'localtime')";
  final statusMarks = _marks(statuses.length);
  final sql =
      'WITH acc AS (SELECT id, opening_balance_minor FROM accounts '
      'WHERE deleted_at IS NULL AND $accFilter), '
      'base AS (SELECT (SELECT COALESCE(SUM(opening_balance_minor), 0) FROM acc)'
      ' + COALESCE((SELECT SUM(t.amount_minor) FROM transactions t '
      'WHERE t.account_id IN (SELECT id FROM acc) AND t.deleted_at IS NULL '
      'AND t.status IN ($statusMarks) AND t.date < ?), 0) AS b), '
      'buckets AS (SELECT $key AS k, SUM(t.amount_minor) AS s '
      'FROM transactions t WHERE t.account_id IN (SELECT id FROM acc) '
      'AND t.deleted_at IS NULL AND t.status IN ($statusMarks) '
      'AND t.date >= ? AND t.date < ? GROUP BY k) '
      'SELECT 0 AS ord, NULL AS k, b AS bal FROM base '
      'UNION ALL '
      'SELECT 1 AS ord, k, (SELECT b FROM base) + SUM(s) OVER '
      '(ORDER BY k ROWS UNBOUNDED PRECEDING) AS bal FROM buckets '
      'ORDER BY ord, k';
  final vars = <Variable>[
    if (ids != null)
      for (final id in ids) Variable<String>(id),
    for (final s in statuses) Variable<String>(s),
    Variable<DateTime>(start),
    for (final s in statuses) Variable<String>(s),
    Variable<DateTime>(start),
    Variable<DateTime>(end),
  ];
  return db
      .customSelect(
        sql,
        variables: vars,
        readsFrom: {db.accounts, db.transactions},
      )
      .watch()
      .map((rows) {
        final points = <BalancePoint>[];
        for (final r in rows) {
          final bal = r.read<int>('bal');
          if (r.read<int>('ord') == 0) {
            points.add(BalancePoint(start, bal));
            continue;
          }
          final k = r.data['k'];
          final DateTime date;
          if (bucket == BalanceBucket.day) {
            date = dateOnly(
              DateTime.fromMillisecondsSinceEpoch((k! as int) * 1000),
            );
          } else {
            final parts = (k! as String).split('-');
            final monthEnd = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]) + 1,
              0,
            );
            final last = end.subtract(const Duration(days: 1));
            date = monthEnd.isAfter(last) ? dateOnly(last) : monthEnd;
          }
          if (points.isNotEmpty && points.last.date == date) {
            points[points.length - 1] = BalancePoint(date, bal);
          } else {
            points.add(BalancePoint(date, bal));
          }
        }
        final lastDay = dateOnly(end.subtract(const Duration(hours: 12)));
        if (points.isNotEmpty && points.last.date.isBefore(lastDay)) {
          points.add(BalancePoint(lastDay, points.last.balanceMinor));
        }
        return points;
      });
}

/// Balance series of one account over `[from, to)` (see
/// [watchBalanceHistory]).
Future<List<BalancePoint>> accountBalanceHistory(
  AppDatabase db,
  String accountId,
  DateTime from,
  DateTime to, {
  BalanceBucket bucket = BalanceBucket.day,
}) => watchBalanceHistory(
  db,
  accountIds: {accountId},
  from: from,
  to: to,
  bucket: bucket,
).first;

/// Reactive balance series, e.g. for charts.
final balanceHistoryProvider = StreamProvider.autoDispose
    .family<List<BalancePoint>, BalanceHistoryQuery>(
      (ref, q) => watchBalanceHistory(
        ref.watch(databaseProvider),
        from: q.from,
        to: q.to,
        accountIds: q.accountIds,
        bucket: q.bucket,
      ),
    );

/// Watches assets/liabilities of live accounts included in net worth.
Stream<NetWorthSummary> watchNetWorthSummary(AppDatabase db) {
  return db
      .customSelect(
        'SELECT a.type AS type, SUM(a.opening_balance_minor + COALESCE(( '
        'SELECT SUM(t.amount_minor) FROM transactions t '
        'WHERE t.account_id = a.id AND t.deleted_at IS NULL '
        'AND t.status IN (?, ?)), 0)) AS bal '
        'FROM accounts a WHERE a.deleted_at IS NULL '
        'AND a.include_in_net_worth = 1 GROUP BY a.type',
        variables: [
          Variable<String>(TxnStatus.cleared.name),
          Variable<String>(TxnStatus.pending.name),
        ],
        readsFrom: {db.accounts, db.transactions},
      )
      .watch()
      .map((rows) {
        var assets = 0;
        var liabilities = 0;
        for (final r in rows) {
          final type = AccountType.values
              .where((t) => t.name == r.read<String>('type'))
              .firstOrNull;
          final bal = r.read<int>('bal');
          if (type != null && type.isLiability) {
            liabilities += bal;
          } else {
            assets += bal;
          }
        }
        return NetWorthSummary(
          assetsMinor: assets,
          liabilitiesMinor: liabilities,
        );
      });
}

/// Assets, liabilities and net worth (live accounts with
/// `includeInNetWorth`, archived ones included).
final netWorthSummaryProvider = StreamProvider<NetWorthSummary>(
  (ref) => watchNetWorthSummary(ref.watch(databaseProvider)),
);

/// Net worth in minor units: the sum of the balances of all live accounts
/// with `includeInNetWorth` (liabilities count negative).
final netWorthProvider = StreamProvider<int>(
  (ref) =>
      watchNetWorthSummary(ref.watch(databaseProvider)).map((s) => s.netMinor),
);

/// Number of months shown in the account list sparklines.
const sparklineMonths = 6;

/// Monthly movement sums per account for the sparkline window:
/// accountId -> 'yyyy-MM' -> sum.
final _monthlySumsProvider = StreamProvider<Map<String, Map<String, int>>>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final from = DateTime(now.year, now.month - (sparklineMonths - 1));
  return db
      .customSelect(
        'SELECT t.account_id AS id, '
        "strftime('%Y-%m', t.date, 'unixepoch', 'localtime') AS k, "
        'SUM(t.amount_minor) AS s FROM transactions t '
        'WHERE t.deleted_at IS NULL AND t.status IN (?, ?) AND t.date >= ? '
        'GROUP BY t.account_id, k',
        variables: [
          Variable<String>(TxnStatus.cleared.name),
          Variable<String>(TxnStatus.pending.name),
          Variable<DateTime>(from),
        ],
        readsFrom: {db.transactions},
      )
      .watch()
      .map((rows) {
        final out = <String, Map<String, int>>{};
        for (final r in rows) {
          (out[r.read<String>('id')] ??= {})[r.read<String>('k')] = r.read<int>(
            's',
          );
        }
        return out;
      });
});

/// Month-end balances for the account list sparklines: accountId -> the
/// balance before the window followed by [sparklineMonths] month-end
/// balances (the last one is the current balance).
final accountSparklinesProvider = Provider<Map<String, List<int>>>((ref) {
  final balances = ref.watch(accountBalancesProvider).value;
  final sums = ref.watch(_monthlySumsProvider).value;
  if (balances == null || sums == null) return const {};
  final now = DateTime.now();
  final keys = [
    for (var i = sparklineMonths - 1; i >= 0; i--)
      _monthKey(DateTime(now.year, now.month - i)),
  ];
  return {
    for (final e in balances.entries)
      e.key: sparklineSeries(e.value, sums[e.key] ?? const {}, keys),
  };
});

String _monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// Walks back from [current] through the monthly sums. [monthKeys] are the
/// window's months, oldest first; sums of later months (future-dated
/// entries) belong to the last point.
@visibleForTesting
List<int> sparklineSeries(
  int current,
  Map<String, int> sums,
  List<String> monthKeys,
) {
  final lastKey = monthKeys.last;
  var endOfWindow = current;
  for (final e in sums.entries) {
    if (e.key.compareTo(lastKey) > 0) endOfWindow -= e.value;
  }
  var b = endOfWindow;
  for (final k in monthKeys) {
    b -= sums[k] ?? 0;
  }
  final ends = <int>[b];
  for (final k in monthKeys) {
    b += sums[k] ?? 0;
    ends.add(b);
  }
  ends[ends.length - 1] = current;
  return ends;
}
