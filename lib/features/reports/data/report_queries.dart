import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/budgets/data/budget_period_provider.dart';
import 'package:personal_finance/features/reports/domain/report_models.dart';
import 'package:personal_finance/features/reports/domain/report_periods.dart';

// All report aggregations run in SQL (PLAN.md §4: fast with 100k+ rows).
//
// Semantics shared by every income/expense query:
// * Only live rows (`deleted_at IS NULL`) of transactions and splits.
// * Transfers (type `transfer` or a transfer peer) are excluded.
// * Planned transactions are excluded (they have not happened yet); cleared
//   and pending ones count.
// * Split transactions contribute their split lines (which carry the
//   category); the parent row of a split is skipped.
// * Expense lines count as `-amount` (refunds reduce spending), income
//   lines as `+amount`.
// * Child categories roll up into their parent at the top level. Archived
//   categories are still reported.
// * [ReportExclusions] (Settings › Reports) remove accounts, tags and
//   categories (a parent removes its children); pass
//   [ReportExclusions.none] for "include excluded".

final reportQueriesProvider = Provider<ReportQueries>(
  (ref) => ReportQueries(ref.watch(databaseProvider)),
);

/// The exclusions configured in Settings › Reports.
final reportExclusionsProvider = Provider<ReportExclusions>((ref) {
  final s = ref.watch(settingsProvider);
  return ReportExclusions(
    categoryIds: s.get(ReportSettings.excludedCategories).toSet(),
    accountIds: s.get(ReportSettings.excludedAccounts).toSet(),
    tagIds: s.moduleEnabled(AppModule.tags)
        ? s.get(ReportSettings.excludedTags).toSet()
        : const {},
  );
});

/// The configured budget periods (Settings › Budgets, incl. salary-based
/// starts and business-day shifting), used for the "budget period" interval.
final reportBudgetPeriodsProvider = Provider<BudgetPeriods>(
  (ref) => ref.watch(budgetPeriodsProvider),
);

// ------------------------------------------------- dashboard providers ---

/// Dashboard: income, expenses, net change (`netMinor`) and savings rate
/// (`savingsRateBp`) for a [DateRange], over all accounts, honouring the
/// exclusions of Settings › Reports. Reactive.
///
/// `ref.watch(monthSummaryProvider(DateRange(start, end)))`
final monthSummaryProvider = StreamProvider.family<MonthSummary, DateRange>((
  ref,
  range,
) {
  final q = ref.watch(reportQueriesProvider);
  final ex = ref.watch(reportExclusionsProvider);
  return q.watchSummary(ReportFilter(range: range), ex);
});

/// Arguments of [topCategoriesProvider].
typedef TopCategoriesArgs = ({DateRange range, int limit});

/// Dashboard: the top-level expense categories with the highest net
/// spending in `range` (children rolled up), at most `limit`, honouring the
/// exclusions of Settings › Reports. Reactive.
///
/// `ref.watch(topCategoriesProvider((range: r, limit: 5)))`
final topCategoriesProvider =
    StreamProvider.family<List<CategoryAmount>, TopCategoriesArgs>((ref, args) {
      final q = ref.watch(reportQueriesProvider);
      final ex = ref.watch(reportExclusionsProvider);
      return q
          .watchByCategory(ReportFilter(range: args.range), ex)
          .map(
            (rows) =>
                rows.where((r) => r.amountMinor > 0).take(args.limit).toList(),
          );
    });

/// Dashboard: month-end net worth for the last `months` calendar months
/// (the current month last, its value = balance up to today and any
/// already-booked future-dated entries of this month). Accounts with
/// `includeInNetWorth` only; liabilities count negative. Reactive.
///
/// `ref.watch(netWorthSeriesProvider(12))`
final netWorthSeriesProvider = StreamProvider.family<List<NetWorthPoint>, int>((
  ref,
  months,
) {
  final q = ref.watch(reportQueriesProvider);
  final ex = ref.watch(reportExclusionsProvider);
  return q.watchNetWorth(monthBuckets(lastMonths(DateTime.now(), months)), ex);
});

// ---------------------------------------------------------- SQL helper ---

class _Sql {
  final _b = StringBuffer();
  final vars = <Variable<Object>>[];

  void add(String s, [Iterable<Variable<Object>> v = const []]) {
    _b.write(s);
    vars.addAll(v);
  }

  /// Appends `(?, ?, ...)` for [ids].
  void inList(Iterable<String> ids) {
    final list = ids.toList();
    add('(${List.filled(list.length, '?').join(', ')})', [
      for (final id in list) Variable<String>(id),
    ]);
  }

  String get text => _b.toString();
}

Variable<Object> _date(DateTime d) => Variable<DateTime>(d);

/// Read access to the report aggregations. Every method returns a reactive
/// stream (drift `watch`).
class ReportQueries {
  ReportQueries(this.db);

  final AppDatabase db;

  Set<ResultSetImplementation<dynamic, dynamic>> get _reads => {
    db.transactions,
    db.transactionSplits,
    db.categories,
    db.transactionTags,
    db.customFieldValues,
  };

  // ------------------------------------------------------- base CTEs ---

  /// Conditions on `transactions t` (filters, exclusions, live, no
  /// transfers, no planned).
  void _txnWhere(
    _Sql q,
    ReportFilter f,
    ReportExclusions ex, {
    required List<DateRange> ranges,
    CategoryKind? kind,
  }) {
    q.add(
      "t.deleted_at IS NULL AND t.transfer_peer_id IS NULL AND t.status <> 'planned'",
    );
    if (kind != null) {
      q.add(' AND t.type = ?', [Variable<String>(kind.name)]);
    } else {
      q.add(" AND t.type IN ('expense', 'income')");
    }
    if (ranges.isNotEmpty) {
      q.add(' AND (');
      for (var i = 0; i < ranges.length; i++) {
        if (i > 0) q.add(' OR ');
        q.add('(t.date >= ? AND t.date < ?)', [
          _date(ranges[i].start),
          _date(ranges[i].end),
        ]);
      }
      q.add(')');
    }
    if (f.accountIds.isNotEmpty) {
      q
        ..add(' AND t.account_id IN ')
        ..inList(f.accountIds);
    }
    if (ex.accountIds.isNotEmpty) {
      q
        ..add(' AND t.account_id NOT IN ')
        ..inList(ex.accountIds);
    }
    if (f.tagIds.isNotEmpty) {
      q
        ..add(
          ' AND t.id IN (SELECT tt.transaction_id FROM transaction_tags tt '
          'WHERE tt.deleted_at IS NULL AND tt.tag_id IN ',
        )
        ..inList(f.tagIds)
        ..add(')');
    }
    if (ex.tagIds.isNotEmpty) {
      q
        ..add(
          ' AND t.id NOT IN (SELECT tx.transaction_id FROM transaction_tags tx '
          'WHERE tx.deleted_at IS NULL AND tx.tag_id IN ',
        )
        ..inList(ex.tagIds)
        ..add(')');
    }
    // Tag and custom field conditions are uncorrelated `IN` subqueries so
    // SQLite evaluates them once instead of per transaction.
    final cf = f.customField;
    if (cf != null) {
      // json_each handles scalars (one row) and multiselect lists alike.
      final (match, value) = switch (cf.value) {
        final bool b => ('j.value = ?', Variable<int>(b ? 1 : 0)),
        final int n => ('j.value = ?', Variable<int>(n)),
        final num n => ('j.value = ?', Variable<double>(n.toDouble())),
        final DateTime d => (
          'substr(j.value, 1, 10) = ?',
          Variable<String>(_isoDay(d)),
        ),
        final Object o => (
          'j.value = ? COLLATE NOCASE',
          Variable<String>(o.toString()),
        ),
      };
      q.add(
        ' AND t.id IN (SELECT v.entity_id FROM custom_field_values v '
        'WHERE v.deleted_at IS NULL AND v.field_id = ? '
        'AND CASE WHEN json_valid(v.value) THEN '
        'EXISTS (SELECT 1 FROM json_each(v.value) j WHERE $match) '
        'ELSE 0 END)',
        [Variable<String>(cf.fieldId), value],
      );
    }
  }

  static String _isoDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Appends the `lines` and `cl` CTE bodies (without `WITH`).
  ///
  /// `cl` columns: txn_id, date, account_id, payee, type, category_id,
  /// amount, top_id (category rolled up to its live parent).
  void _linesCte(
    _Sql q,
    ReportFilter f,
    ReportExclusions ex, {
    required List<DateRange> ranges,
    CategoryKind? kind,
  }) {
    q.add(
      'lines AS ( '
      'SELECT t.id AS txn_id, t.date AS date, t.account_id AS account_id, '
      't.payee AS payee, t.type AS type, t.category_id AS category_id, '
      't.amount_minor AS amount FROM transactions t WHERE ',
    );
    _txnWhere(q, f, ex, ranges: ranges, kind: kind);
    q.add(
      ' AND NOT EXISTS (SELECT 1 FROM transaction_splits s0 '
      'WHERE s0.transaction_id = t.id AND s0.deleted_at IS NULL) '
      'UNION ALL '
      'SELECT t.id, t.date, t.account_id, t.payee, t.type, s.category_id, '
      's.amount_minor FROM transaction_splits s '
      'JOIN transactions t ON t.id = s.transaction_id '
      'WHERE s.deleted_at IS NULL AND ',
    );
    _txnWhere(q, f, ex, ranges: ranges, kind: kind);
    q.add(
      '), cl AS ( '
      'SELECT l.txn_id AS txn_id, l.date AS date, l.account_id AS account_id, '
      'l.payee AS payee, l.type AS type, l.category_id AS category_id, '
      'l.amount AS amount, '
      'CASE WHEN p.id IS NULL THEN l.category_id ELSE p.id END AS top_id '
      'FROM lines l '
      'LEFT JOIN categories c ON c.id = l.category_id '
      'LEFT JOIN categories p ON p.id = c.parent_id AND p.deleted_at IS NULL',
    );
    if (ex.categoryIds.isNotEmpty) {
      q
        ..add(' WHERE (l.category_id IS NULL OR (l.category_id NOT IN ')
        ..inList(ex.categoryIds)
        ..add(" AND COALESCE(c.parent_id, '') NOT IN ")
        ..inList(ex.categoryIds)
        ..add('))');
    }
    q.add(')');
  }

  /// Appends `b(idx, s, e) AS (VALUES ...)`.
  void _bucketsCte(_Sql q, List<DateRange> buckets) {
    q.add('b(idx, s, e) AS (VALUES ');
    for (var i = 0; i < buckets.length; i++) {
      if (i > 0) q.add(', ');
      q.add('(?, ?, ?)', [
        Variable<int>(i),
        _date(buckets[i].start),
        _date(buckets[i].end),
      ]);
    }
    q.add(')');
  }

  static const _signed =
      "CASE WHEN cl.type = 'income' THEN cl.amount ELSE -cl.amount END";

  // ------------------------------------------------ spending / income ---

  /// Totals per category. Without [parentId]: top-level categories with
  /// children rolled up. With [parentId]: the parent's own lines and each
  /// child separately. [kind] selects expense (spending) or income lines.
  /// Sorted by amount, descending; zero totals are omitted.
  Stream<List<CategoryAmount>> watchByCategory(
    ReportFilter f,
    ReportExclusions ex, {
    CategoryKind kind = CategoryKind.expense,
    String? parentId,
  }) {
    final q = _Sql()..add('WITH ');
    _linesCte(q, f, ex, ranges: [f.range], kind: kind);
    final key = parentId == null ? 'cl.top_id' : 'cl.category_id';
    q.add(
      ' SELECT g.id AS id, c.name AS name, c.icon AS icon, c.color AS color, '
      'c.archived AS archived, g.total AS total, g.n AS n, g.drill AS drill '
      'FROM (SELECT $key AS id, SUM($_signed) AS total, '
      'COUNT(DISTINCT cl.txn_id) AS n, '
      'MAX(CASE WHEN cl.category_id IS NOT cl.top_id THEN 1 ELSE 0 END) '
      'AS drill FROM cl',
    );
    if (parentId != null) {
      q.add(' WHERE cl.top_id = ?', [Variable<String>(parentId)]);
    }
    q.add(
      ' GROUP BY $key) g LEFT JOIN categories c ON c.id = g.id '
      'WHERE g.total <> 0 ORDER BY g.total DESC, c.name',
    );
    return db
        .customSelect(q.text, variables: q.vars, readsFrom: _reads)
        .watch()
        .map(
          (rows) => [
            for (final r in rows)
              CategoryAmount(
                categoryId: r.readNullable<String>('id'),
                name: r.readNullable<String>('name'),
                icon: r.readNullable<String>('icon'),
                color: r.readNullable<int>('color'),
                archived: r.readNullable<bool>('archived') ?? false,
                amountMinor: r.read<int>('total'),
                count: r.read<int>('n'),
                hasChildren: parentId == null && r.read<int>('drill') == 1,
              ),
          ],
        );
  }

  // ------------------------------------------------ income vs expense ---

  /// Income and expenses per bucket (see `bucketsFor`). Buckets without
  /// data are returned with zeros.
  Stream<List<PeriodTotals>> watchIncomeExpense(
    ReportFilter f,
    ReportExclusions ex,
    List<DateRange> buckets,
  ) {
    if (buckets.isEmpty) return Stream.value(const []);
    final span = DateRange(buckets.first.start, buckets.last.end);
    final q = _Sql()..add('WITH ');
    _linesCte(q, f, ex, ranges: [span]);
    q.add(', ');
    _bucketsCte(q, buckets);
    q.add(
      ' SELECT b.idx AS idx, '
      "SUM(CASE WHEN cl.type = 'income' THEN cl.amount ELSE 0 END) AS income, "
      "SUM(CASE WHEN cl.type = 'expense' THEN -cl.amount ELSE 0 END) "
      'AS expense FROM cl JOIN b ON cl.date >= b.s AND cl.date < b.e '
      'GROUP BY b.idx',
    );
    return db
        .customSelect(q.text, variables: q.vars, readsFrom: _reads)
        .watch()
        .map((rows) {
          final byIdx = {for (final r in rows) r.read<int>('idx'): r};
          return [
            for (var i = 0; i < buckets.length; i++)
              PeriodTotals(
                range: buckets[i],
                incomeMinor: byIdx[i]?.read<int>('income') ?? 0,
                expenseMinor: byIdx[i]?.read<int>('expense') ?? 0,
              ),
          ];
        });
  }

  /// Income, expenses, net and savings rate of `f.range`.
  Stream<PeriodTotals> watchSummary(ReportFilter f, ReportExclusions ex) =>
      watchIncomeExpense(f, ex, [f.range]).map((l) => l.single);

  // -------------------------------------------------------- net worth ---

  /// Net worth at the end of each bucket: opening balances (from their
  /// opening date) plus all live, non-planned transactions dated before the
  /// bucket end, for accounts with `includeInNetWorth` (archived ones
  /// included). Liability accounts are reported separately and count with
  /// their (normally negative) balance. Only [accountIds] when non-empty;
  /// tag and custom field filters do not apply to balances.
  Stream<List<NetWorthPoint>> watchNetWorth(
    List<DateRange> buckets,
    ReportExclusions ex, {
    Set<String> accountIds = const {},
  }) {
    if (buckets.isEmpty) return Stream.value(const []);
    final q = _Sql()
      ..add('WITH b(idx, s, e) AS (VALUES (?, ?, ?)', [
        const Variable<int>(-1),
        const Variable<int>(-(1 << 52)),
        _date(buckets.first.end),
      ]);
    for (var i = 1; i < buckets.length; i++) {
      q.add(', (?, ?, ?)', [
        Variable<int>(i),
        _date(buckets[i - 1].end),
        _date(buckets[i].end),
      ]);
    }
    q.add(
      ') SELECT t.account_id AS account_id, b.idx AS idx, '
      'SUM(t.amount_minor) AS total FROM transactions t '
      'JOIN b ON t.date >= b.s AND t.date < b.e '
      "WHERE t.deleted_at IS NULL AND t.status <> 'planned' AND t.date < ? "
      'AND t.account_id IN (SELECT a.id FROM accounts a '
      'WHERE a.deleted_at IS NULL AND a.include_in_net_worth = 1',
      [_date(buckets.last.end)],
    );
    if (accountIds.isNotEmpty) {
      q
        ..add(' AND a.id IN ')
        ..inList(accountIds);
    }
    if (ex.accountIds.isNotEmpty) {
      q
        ..add(' AND a.id NOT IN ')
        ..inList(ex.accountIds);
    }
    q.add(') GROUP BY t.account_id, b.idx');

    return db
        .customSelect(
          q.text,
          variables: q.vars,
          readsFrom: {db.transactions, db.accounts},
        )
        .watch()
        .asyncMap((rows) async {
          final accounts =
              await (db.select(db.accounts)..where(
                    (a) =>
                        a.deletedAt.isNull() & a.includeInNetWorth.equals(true),
                  ))
                  .get();
          final included = accounts.where(
            (a) =>
                (accountIds.isEmpty || accountIds.contains(a.id)) &&
                !ex.accountIds.contains(a.id),
          );
          // account -> bucket index (-1 = before first end) -> sum
          final sums = <String, Map<int, int>>{};
          for (final r in rows) {
            (sums[r.read<String>('account_id')] ??= {})[r.read<int>('idx')] = r
                .read<int>('total');
          }
          final assets = List.filled(buckets.length, 0);
          final liabilities = List.filled(buckets.length, 0);
          for (final a in included) {
            final s = sums[a.id] ?? const {};
            var running = s[-1] ?? 0;
            for (var i = 0; i < buckets.length; i++) {
              if (i > 0) running += s[i] ?? 0;
              final opening = a.openingDate.isBefore(buckets[i].end)
                  ? a.openingBalanceMinor
                  : 0;
              final balance = running + opening;
              if (a.type.isLiability) {
                liabilities[i] += balance;
              } else {
                assets[i] += balance;
              }
            }
          }
          return [
            for (var i = 0; i < buckets.length; i++)
              NetWorthPoint(
                range: buckets[i],
                assetsMinor: assets[i],
                liabilitiesMinor: liabilities[i],
              ),
          ];
        });
  }

  // --------------------------------------------------- category trend ---

  /// Totals per bucket for each of [categoryIds] (a parent includes its
  /// children). Values are positive spending for expense categories and
  /// positive income for income categories. Series keep the order of
  /// [categoryIds]; unknown ids are dropped.
  Stream<TrendReport> watchCategoryTrend(
    ReportFilter f,
    ReportExclusions ex,
    List<String> categoryIds,
    List<DateRange> buckets,
  ) {
    final ids = categoryIds.toSet().toList();
    if (buckets.isEmpty || ids.isEmpty) {
      return Stream.value(TrendReport(buckets: buckets, series: const []));
    }
    final span = DateRange(buckets.first.start, buckets.last.end);
    final q = _Sql()..add('WITH ');
    _linesCte(q, f, ex, ranges: [span]);
    q.add(', ');
    _bucketsCte(q, buckets);
    q.add(', sel(id) AS (VALUES ');
    for (var i = 0; i < ids.length; i++) {
      q.add(i == 0 ? '(?)' : ', (?)', [Variable<String>(ids[i])]);
    }
    q.add(
      ') SELECT sel.id AS id, b.idx AS idx, '
      'SUM(CASE WHEN cl.type = sc.kind THEN $_signed ELSE 0 END) AS total '
      'FROM cl JOIN sel ON sel.id = cl.top_id OR sel.id = cl.category_id '
      'JOIN categories sc ON sc.id = sel.id '
      'JOIN b ON cl.date >= b.s AND cl.date < b.e '
      'GROUP BY sel.id, b.idx',
    );
    return db
        .customSelect(q.text, variables: q.vars, readsFrom: _reads)
        .watch()
        .asyncMap((rows) async {
          final cats = await (db.select(
            db.categories,
          )..where((c) => c.id.isIn(ids))).get();
          final byId = {for (final c in cats) c.id: c};
          final values = <String, List<int>>{
            for (final id in ids) id: List.filled(buckets.length, 0),
          };
          for (final r in rows) {
            values[r.read<String>('id')]![r.read<int>('idx')] = r.read<int>(
              'total',
            );
          }
          return TrendReport(
            buckets: buckets,
            series: [
              for (final id in ids)
                if (byId[id] case final c?)
                  TrendSeries(
                    categoryId: id,
                    name: c.name,
                    kind: c.kind,
                    values: values[id]!,
                  ),
            ],
          );
        });
  }

  // ------------------------------------------------------- top payees ---

  /// Payees ranked by net spending, number of transactions or average
  /// spend. Payees are grouped case-insensitively; empty payees are
  /// skipped.
  Stream<List<PayeeStat>> watchTopPayees(
    ReportFilter f,
    ReportExclusions ex, {
    PayeeSort sort = PayeeSort.total,
    int limit = 20,
    CategoryKind kind = CategoryKind.expense,
  }) {
    final q = _Sql()..add('WITH ');
    _linesCte(q, f, ex, ranges: [f.range], kind: kind);
    final order = switch (sort) {
      PayeeSort.total => 'total DESC, n DESC',
      PayeeSort.count => 'n DESC, total DESC',
      PayeeSort.average => 'total * 1.0 / n DESC, total DESC',
    };
    q.add(
      ' SELECT MIN(TRIM(cl.payee)) AS payee, SUM($_signed) AS total, '
      'COUNT(DISTINCT cl.txn_id) AS n FROM cl '
      "WHERE cl.payee IS NOT NULL AND TRIM(cl.payee) <> '' "
      'GROUP BY LOWER(TRIM(cl.payee)) HAVING total <> 0 '
      'ORDER BY $order, payee LIMIT ?',
      [Variable<int>(limit)],
    );
    return db
        .customSelect(q.text, variables: q.vars, readsFrom: _reads)
        .watch()
        .map(
          (rows) => [
            for (final r in rows)
              PayeeStat(
                payee: r.read<String>('payee'),
                totalMinor: r.read<int>('total'),
                count: r.read<int>('n'),
              ),
          ],
        );
  }

  // ------------------------------------------------ period comparison ---

  /// Top-level category totals for `f.range`, the previous period of the
  /// same length and the same period one year earlier.
  Stream<ComparisonReport> watchComparison(
    ReportFilter f,
    ReportExclusions ex, {
    CategoryKind kind = CategoryKind.expense,
  }) {
    final (cur, prev, ly) = comparisonRanges(f.range);
    final buckets = [cur, prev, ly];
    final q = _Sql()..add('WITH ');
    _linesCte(q, f, ex, ranges: buckets, kind: kind);
    q.add(', ');
    _bucketsCte(q, buckets);
    q.add(
      ' SELECT g.id AS id, c.name AS name, g.cur AS cur, g.prev AS prev, '
      'g.ly AS ly FROM (SELECT cl.top_id AS id, '
      'SUM(CASE WHEN b.idx = 0 THEN $_signed ELSE 0 END) AS cur, '
      'SUM(CASE WHEN b.idx = 1 THEN $_signed ELSE 0 END) AS prev, '
      'SUM(CASE WHEN b.idx = 2 THEN $_signed ELSE 0 END) AS ly '
      'FROM cl JOIN b ON cl.date >= b.s AND cl.date < b.e '
      'GROUP BY cl.top_id) g LEFT JOIN categories c ON c.id = g.id '
      'WHERE g.cur <> 0 OR g.prev <> 0 OR g.ly <> 0 '
      'ORDER BY g.cur DESC, g.prev DESC, c.name',
    );
    return db
        .customSelect(q.text, variables: q.vars, readsFrom: _reads)
        .watch()
        .map(
          (rows) => ComparisonReport(
            current: cur,
            previous: prev,
            lastYear: ly,
            rows: [
              for (final r in rows)
                ComparisonRow(
                  categoryId: r.readNullable<String>('id'),
                  name: r.readNullable<String>('name'),
                  currentMinor: r.read<int>('cur'),
                  previousMinor: r.read<int>('prev'),
                  lastYearMinor: r.read<int>('ly'),
                ),
            ],
          ),
        );
  }

  /// The top-level expense categories by spending in [f], used as the
  /// default selection of the category trend.
  Future<List<String>> topCategoryIds(
    ReportFilter f,
    ReportExclusions ex, {
    int limit = 3,
  }) async {
    final rows = await watchByCategory(f, ex).first;
    return rows
        .where((r) => r.categoryId != null && r.amountMinor > 0)
        .map((r) => r.categoryId!)
        .take(limit)
        .toList();
  }
}

/// Sum of [rows] amounts (helper for donut centre totals).
int sumAmounts(Iterable<CategoryAmount> rows) =>
    rows.map((r) => r.amountMinor).sum;
