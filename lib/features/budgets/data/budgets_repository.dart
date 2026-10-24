import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/sync/hlc.dart';
import 'package:personal_finance/features/budgets/domain/budget_math.dart';
import 'package:personal_finance/features/budgets/domain/budget_rules.dart';
import 'package:personal_finance/features/budgets/domain/outstanding.dart';

final budgetsRepositoryProvider = Provider<BudgetsRepository>(
  (ref) => BudgetsRepository(
    ref.watch(databaseProvider),
    ref.watch(syncWriterProvider),
  ),
);

/// Actual money movements of a period that count toward budgets: live
/// transactions and split lines on accounts with `includeInBudgets`,
/// excluding transfers and planned entries.
@immutable
class PeriodActuals {
  const PeriodActuals({
    this.netByCategory = const {},
    this.incomeMinor = 0,
    this.uncategorizedSpentMinor = 0,
  });

  /// Signed net amount per category id (expenses negative, refunds
  /// positive), both expense and income categories, children separate.
  final Map<String, int> netByCategory;

  /// Total income: income categories plus uncategorised income.
  final int incomeMinor;

  /// Spending without a category (positive = spent).
  final int uncategorizedSpentMinor;

  /// Net spending (positive = spent) of [categoryId] including its
  /// [children].
  int spentOf(String categoryId, [Iterable<String> children = const []]) {
    var net = netByCategory[categoryId] ?? 0;
    for (final c in children) {
      net += netByCategory[c] ?? 0;
    }
    return -net;
  }

  @override
  bool operator ==(Object other) =>
      other is PeriodActuals &&
      other.incomeMinor == incomeMinor &&
      other.uncategorizedSpentMinor == uncategorizedSpentMinor &&
      const MapEquality<String, int>().equals(
        other.netByCategory,
        netByCategory,
      );

  @override
  int get hashCode => Object.hash(
    incomeMinor,
    uncategorizedSpentMinor,
    Object.hashAllUnordered(netByCategory.entries.map((e) => e.key)),
  );
}

/// Result of [BudgetsRepository.syncChain] for the target period.
@immutable
class BudgetChain {
  const BudgetChain({this.rolloverByCategory = const {}, this.carryMinor = 0});

  /// Rollover carried into the target period per category.
  final Map<String, int> rolloverByCategory;

  /// Unassigned money carried into the target period (envelope mode).
  final int carryMinor;
}

/// A transaction (or split line) booked on a budget category.
@immutable
class BudgetTxnLine {
  const BudgetTxnLine({
    required this.transactionId,
    required this.date,
    required this.accountId,
    required this.categoryId,
    required this.amountMinor,
    required this.isSplit,
    this.payee,
    this.note,
  });

  final String transactionId;
  final DateTime date;
  final String accountId;
  final String categoryId;
  final int amountMinor;
  final bool isSplit;
  final String? payee;
  final String? note;
}

/// One item of a budget template.
@immutable
class BudgetTemplateItem {
  const BudgetTemplateItem(this.categoryId, this.amountMinor);

  final String categoryId;
  final int amountMinor;

  Map<String, Object?> toJson() => {
    'categoryId': categoryId,
    'amountMinor': amountMinor,
  };

  static List<BudgetTemplateItem> decodeList(String json) {
    try {
      final list = jsonDecode(json);
      if (list is! List) return const [];
      return [
        for (final e in list)
          if (e is Map && e['categoryId'] is String && e['amountMinor'] is num)
            BudgetTemplateItem(
              e['categoryId'] as String,
              (e['amountMinor'] as num).toInt(),
            ),
      ];
    } on FormatException {
      return const [];
    }
  }
}

/// Budgets per category and period, templates and the spending queries
/// behind them. All writes go through [SyncWriter].
class BudgetsRepository {
  BudgetsRepository(this.db, this.writer);

  final AppDatabase db;
  final SyncWriter writer;

  // ----------------------------------------------------------- actuals ---

  // Rows counting toward budgets. Variables: start, end, start, end.
  static const _actualRows =
      'SELECT t.category_id AS category_id, t.amount_minor AS amount, '
      't.type AS txn_type '
      'FROM transactions t JOIN accounts a ON a.id = t.account_id '
      'WHERE t.deleted_at IS NULL AND a.deleted_at IS NULL '
      "AND a.include_in_budgets = 1 AND t.type <> 'transfer' "
      "AND t.transfer_peer_id IS NULL AND t.status <> 'planned' "
      'AND t.date >= ? AND t.date < ? '
      'AND NOT EXISTS (SELECT 1 FROM transaction_splits s0 '
      'WHERE s0.transaction_id = t.id AND s0.deleted_at IS NULL) '
      'UNION ALL '
      'SELECT s.category_id AS category_id, s.amount_minor AS amount, '
      't.type AS txn_type '
      'FROM transaction_splits s '
      'JOIN transactions t ON t.id = s.transaction_id '
      'JOIN accounts a ON a.id = t.account_id '
      'WHERE s.deleted_at IS NULL AND t.deleted_at IS NULL '
      'AND a.deleted_at IS NULL AND a.include_in_budgets = 1 '
      "AND t.type <> 'transfer' AND t.transfer_peer_id IS NULL "
      "AND t.status <> 'planned' AND t.date >= ? AND t.date < ?";

  Selectable<QueryRow> _actualsQuery(DateRange range) => db.customSelect(
    'SELECT x.category_id AS category_id, c.kind AS kind, '
    'x.txn_type AS txn_type, SUM(x.amount) AS total '
    'FROM ($_actualRows) x '
    'LEFT JOIN categories c ON c.id = x.category_id AND c.deleted_at IS NULL '
    'GROUP BY x.category_id, c.kind, x.txn_type',
    variables: [
      Variable<DateTime>(range.start),
      Variable<DateTime>(range.end),
      Variable<DateTime>(range.start),
      Variable<DateTime>(range.end),
    ],
    readsFrom: {
      db.transactions,
      db.transactionSplits,
      db.accounts,
      db.categories,
    },
  );

  static PeriodActuals _toActuals(List<QueryRow> rows) {
    final net = <String, int>{};
    var income = 0;
    var uncategorized = 0;
    for (final r in rows) {
      final cat = r.readNullable<String>('category_id');
      final kind = r.readNullable<String>('kind');
      final type = r.read<String>('txn_type');
      final total = r.read<int>('total');
      if (cat != null && kind != null) {
        net[cat] = (net[cat] ?? 0) + total;
        if (kind == CategoryKind.income.name) income += total;
      } else if (type == TxnType.income.name) {
        income += total;
      } else {
        uncategorized -= total;
      }
    }
    return PeriodActuals(
      netByCategory: net,
      incomeMinor: income,
      uncategorizedSpentMinor: uncategorized,
    );
  }

  Stream<PeriodActuals> watchActuals(DateRange range) =>
      _actualsQuery(range).watch().map(_toActuals);

  Future<PeriodActuals> actuals(DateRange range) async =>
      _toActuals(await _actualsQuery(range).get());

  /// Transactions and split lines of [categoryIds] in [range], newest first.
  Stream<List<BudgetTxnLine>> watchCategoryLines(
    Set<String> categoryIds,
    DateRange range,
  ) {
    if (categoryIds.isEmpty) return Stream.value(const []);
    final ph = List.filled(categoryIds.length, '?').join(', ');
    return db
        .customSelect(
          'SELECT * FROM ( '
          'SELECT t.id AS id, t.date AS date, t.account_id AS account_id, '
          't.category_id AS category_id, t.amount_minor AS amount, '
          't.payee AS payee, t.note AS note, 0 AS is_split '
          'FROM transactions t JOIN accounts a ON a.id = t.account_id '
          'WHERE t.deleted_at IS NULL AND a.deleted_at IS NULL '
          "AND a.include_in_budgets = 1 AND t.type <> 'transfer' "
          "AND t.transfer_peer_id IS NULL AND t.status <> 'planned' "
          'AND t.date >= ? AND t.date < ? AND t.category_id IN ($ph) '
          'AND NOT EXISTS (SELECT 1 FROM transaction_splits s0 '
          'WHERE s0.transaction_id = t.id AND s0.deleted_at IS NULL) '
          'UNION ALL '
          'SELECT t.id, t.date, t.account_id, s.category_id, s.amount_minor, '
          't.payee, COALESCE(s.note, t.note), 1 '
          'FROM transaction_splits s '
          'JOIN transactions t ON t.id = s.transaction_id '
          'JOIN accounts a ON a.id = t.account_id '
          'WHERE s.deleted_at IS NULL AND t.deleted_at IS NULL '
          'AND a.deleted_at IS NULL AND a.include_in_budgets = 1 '
          "AND t.type <> 'transfer' AND t.transfer_peer_id IS NULL "
          "AND t.status <> 'planned' AND t.date >= ? AND t.date < ? "
          'AND s.category_id IN ($ph) '
          ') ORDER BY date DESC, id DESC',
          variables: [
            Variable<DateTime>(range.start),
            Variable<DateTime>(range.end),
            for (final c in categoryIds) Variable<String>(c),
            Variable<DateTime>(range.start),
            Variable<DateTime>(range.end),
            for (final c in categoryIds) Variable<String>(c),
          ],
          readsFrom: {db.transactions, db.transactionSplits, db.accounts},
        )
        .watch()
        .map(
          (rows) => [
            for (final r in rows)
              BudgetTxnLine(
                transactionId: r.read<String>('id'),
                date: r.read<DateTime>('date'),
                accountId: r.read<String>('account_id'),
                categoryId: r.read<String>('category_id'),
                amountMinor: r.read<int>('amount'),
                isSplit: r.read<int>('is_split') == 1,
                payee: r.readNullable<String>('payee'),
                note: r.readNullable<String>('note'),
              ),
          ],
        );
  }

  // ----------------------------------------------------------- planned ---

  /// Planned ledger entries (`status = 'planned'`) of [range] that count
  /// toward budgets, one item per transaction or split line. Entries dated
  /// before [today] are overdue.
  Stream<List<OutstandingItem>> watchPlannedItems(
    DateRange range,
    DateTime today,
  ) => db
      .customSelect(
        'SELECT t.id AS id, t.date AS date, t.account_id AS account_id, '
        't.category_id AS category_id, t.amount_minor AS amount, '
        't.type AS txn_type, t.payee AS payee, t.note AS note, 0 AS is_split '
        'FROM transactions t JOIN accounts a ON a.id = t.account_id '
        'WHERE t.deleted_at IS NULL AND a.deleted_at IS NULL '
        "AND a.include_in_budgets = 1 AND t.type <> 'transfer' "
        "AND t.transfer_peer_id IS NULL AND t.status = 'planned' "
        'AND t.date >= ? AND t.date < ? '
        'AND NOT EXISTS (SELECT 1 FROM transaction_splits s0 '
        'WHERE s0.transaction_id = t.id AND s0.deleted_at IS NULL) '
        'UNION ALL '
        'SELECT t.id, t.date, t.account_id, s.category_id, s.amount_minor, '
        't.type, t.payee, COALESCE(s.note, t.note), 1 '
        'FROM transaction_splits s '
        'JOIN transactions t ON t.id = s.transaction_id '
        'JOIN accounts a ON a.id = t.account_id '
        'WHERE s.deleted_at IS NULL AND t.deleted_at IS NULL '
        'AND a.deleted_at IS NULL AND a.include_in_budgets = 1 '
        "AND t.type <> 'transfer' AND t.transfer_peer_id IS NULL "
        "AND t.status = 'planned' AND t.date >= ? AND t.date < ?",
        variables: [
          Variable<DateTime>(range.start),
          Variable<DateTime>(range.end),
          Variable<DateTime>(range.start),
          Variable<DateTime>(range.end),
        ],
        readsFrom: {db.transactions, db.transactionSplits, db.accounts},
      )
      .watch()
      .map((rows) {
        final day = dateOnly(today);
        return [
          for (final r in rows)
            OutstandingItem(
              source: OutstandingSource.planned,
              date: r.read<DateTime>('date'),
              amountMinor: r.read<int>('amount'),
              type: TxnType.values.byName(r.read<String>('txn_type')),
              accountId: r.read<String>('account_id'),
              categoryId: r.readNullable<String>('category_id'),
              isSplit: r.read<int>('is_split') == 1,
              overdue: r.read<DateTime>('date').isBefore(day),
              title: _titleOf(
                r.readNullable<String>('payee'),
                r.readNullable<String>('note'),
              ),
              transactionId: r.read<String>('id'),
            ),
        ];
      });

  static String? _titleOf(String? payee, String? note) =>
      (payee?.isNotEmpty ?? false) ? payee : note;

  /// `(recurringRuleId, date)` of live ledger rows created for a recurring
  /// rule in [range], whatever their status.
  Stream<Set<(String, DateTime)>> watchRuleBookings(DateRange range) => db
      .customSelect(
        'SELECT DISTINCT recurring_rule_id AS rule_id, date FROM transactions '
        'WHERE deleted_at IS NULL AND recurring_rule_id IS NOT NULL '
        'AND date >= ? AND date < ?',
        variables: [
          Variable<DateTime>(range.start),
          Variable<DateTime>(range.end),
        ],
        readsFrom: {db.transactions},
      )
      .watch()
      .map(
        (rows) => {
          for (final r in rows)
            (r.read<String>('rule_id'), dateOnly(r.read<DateTime>('date'))),
        },
      );

  // ----------------------------------------------------------- budgets ---

  /// Budgets of the budget period starting [start] (not budgets with their
  /// own length that happen to start that day).
  SimpleSelectStatement<$BudgetsTable, Budget> _periodQuery(DateTime start) =>
      db.select(db.budgets)..where(
        (b) =>
            b.periodStart.equals(dateOnly(start)) &
            b.periodEnd.isNull() &
            b.deletedAt.isNull(),
      );

  Stream<List<Budget>> watchPeriod(DateTime periodStart) =>
      _periodQuery(periodStart).watch().map(_dedupe);

  Future<List<Budget>> period(DateTime periodStart) async =>
      _dedupe(await _periodQuery(periodStart).get());

  /// One row per category (sync could create duplicates; the newest wins).
  static List<Budget> _dedupe(List<Budget> rows) {
    final byCat = <String, Budget>{};
    for (final r in rows) {
      final e = byCat[r.categoryId];
      if (e == null || r.updatedAt.compareTo(e.updatedAt) > 0) {
        byCat[r.categoryId] = r;
      }
    }
    return byCat.values.toList();
  }

  /// Sets the budget of [categoryId] in the period starting [periodStart];
  /// null removes it.
  Future<void> setAmount(
    String categoryId,
    DateTime periodStart,
    int? amountMinor,
  ) => setAmounts(periodStart, {categoryId: amountMinor});

  /// Bulk edit: category id -> amount (null removes the budget).
  Future<void> setAmounts(DateTime periodStart, Map<String, int?> amounts) =>
      writer.transaction(() async {
        final start = dateOnly(periodStart);
        final all = await _periodQuery(start).get();
        final byCat = <String, List<Budget>>{};
        for (final b in all) {
          byCat.putIfAbsent(b.categoryId, () => []).add(b);
        }
        for (final e in amounts.entries) {
          final rows = byCat[e.key] ?? const <Budget>[];
          final amount = e.value;
          if (amount == null) {
            for (final r in rows) {
              await writer.delete(db.budgets, r.id);
            }
            continue;
          }
          if (amount < 0) throw ArgumentError.value(amount, 'amountMinor');
          if (rows.isEmpty) {
            await writer.insert(
              db.budgets,
              BudgetsCompanion(
                categoryId: Value(e.key),
                periodStart: Value(start),
                amountMinor: Value(amount),
              ),
            );
          } else {
            // Written explicitly: set by hand, the rule leaves it alone.
            if (rows.first.amountMinor != amount || rows.first.ruleId != null) {
              await writer.update(
                db.budgets,
                rows.first.id,
                BudgetsCompanion(
                  amountMinor: Value(amount),
                  ruleId: const Value(null),
                ),
              );
            }
            for (final dup in rows.skip(1)) {
              await writer.delete(db.budgets, dup.id);
            }
          }
        }
      });

  // ------------------------------------------------------------- rules ---

  SimpleSelectStatement<$BudgetRulesTable, BudgetRule> _rulesQuery() =>
      db.select(db.budgetRules)..where((r) => r.deletedAt.isNull());

  static List<BudgetRulePlan> _plans(List<BudgetRule> rows) => [
    for (final r in rows) BudgetRulePlan.fromRow(r),
  ];

  /// Live repeating budgets.
  Stream<List<BudgetRulePlan>> watchRules() =>
      _rulesQuery().watch().map(_plans);

  Future<List<BudgetRulePlan>> rules() async =>
      _plans(await _rulesQuery().get());

  /// Generates the budget rows of every rule for its covered periods after
  /// its watermark (`generatedUntil`) that start on or before [upTo], then
  /// moves the watermark. A period that already has a live budget of the
  /// category (set by hand or by another rule; for a budget with its own
  /// length any overlapping window) is left alone, as is one whose
  /// generated row was removed. Where two rules cover the same category and
  /// period, the newest one generates.
  ///
  /// Generated rows get a deterministic id and a fixed sync timestamp from
  /// the rule's creation, so two devices create the same row and any edit
  /// or removal by the user wins over it when syncing. Rows a rule
  /// generated before the budget period type changed are turned into (or
  /// back from) budgets with their own length. Idempotent; returns the
  /// number of rows created.
  Future<int> ensureFromRules(BudgetPeriods periods, DateTime upTo) =>
      writer.transaction(() async {
        final all = await rules();
        var created = 0;
        for (final r in all) {
          final windowed = r.windowedOn(periods);
          await _normaliseRows(r, periods, windowed: windowed);
          final due = r.due(periods, upTo);
          if (due.isEmpty) continue;
          for (final p in due) {
            final winner = ruleFor(
              all,
              periods,
              r.categoryId,
              p.start,
              windowed: windowed,
            );
            if (winner?.id != r.id) continue;
            final live =
                await (db.select(db.budgets)..where(
                      (b) =>
                          b.categoryId.equals(r.categoryId) &
                          (windowed
                              ? b.periodEnd.isNotNull() &
                                    b.periodStart.isSmallerThanValue(p.end) &
                                    b.periodEnd.isBiggerThanValue(p.start)
                              : b.periodStart.equals(p.start) &
                                    b.periodEnd.isNull()) &
                          b.deletedAt.isNull(),
                    ))
                    .get();
            if (live.isNotEmpty) continue;
            final id = generatedBudgetId(r.id, p.start);
            final existing = await (db.select(
              db.budgets,
            )..where((b) => b.id.equals(id))).getSingleOrNull();
            if (existing != null) continue; // removed by the user
            await writer.insert(
              db.budgets,
              BudgetsCompanion(
                categoryId: Value(r.categoryId),
                periodStart: Value(p.start),
                amountMinor: Value(r.amountMinor),
                ruleId: Value(r.id),
                periodEnd: Value(windowed ? p.end : null),
              ),
              id: id,
              hlc: Hlc(r.createdAtMillis, 0, ''),
            );
            created++;
          }
          await writer.update(
            db.budgetRules,
            r.id,
            BudgetRulesCompanion(generatedUntil: Value(due.last.start)),
          );
        }
        return created;
      });

  /// Gives the unedited rows [r] generated the kind it has on [periods]
  /// now: a window (`periodEnd`) after the period type changed away from
  /// the one the rule was made for, a budget of the period after it changed
  /// back.
  Future<void> _normaliseRows(
    BudgetRulePlan r,
    BudgetPeriods periods, {
    required bool windowed,
  }) async {
    if (r.cadence != BudgetCadence.period) return;
    final rows =
        await (db.select(db.budgets)..where(
              (b) =>
                  b.ruleId.equals(r.id) &
                  (windowed ? b.periodEnd.isNull() : b.periodEnd.isNotNull()) &
                  b.deletedAt.isNull(),
            ))
            .get();
    if (rows.isEmpty) return;
    final own = windowPeriods(periods, r.lengthOn(periods));
    for (final b in rows) {
      final w = own.periodOf(b.periodStart);
      if (w.start != b.periodStart) continue;
      if (!windowed && b.periodEnd != w.end) continue;
      await writer.update(
        db.budgets,
        b.id,
        BudgetsCompanion(periodEnd: Value(windowed ? w.end : null)),
      );
    }
  }

  /// Makes [categoryId] repeat with [amountMinor] as set in [repeat] (which
  /// must repeat), from [from] on: a budget period, or for a budget with its
  /// own length ([BudgetRepeat.cadence]) one of its windows.
  ///
  /// [replace] is the budget being changed (the period or window shown;
  /// defaults to [from]); budgets starting before it are history and stay
  /// untouched. The category's existing rules end the day before it (rules
  /// starting at or after it are removed). Any budget overlapping [replace]
  /// goes (it is replaced). Later rows the old rules generated move to the
  /// new rule with the new amount where it covers them and are removed
  /// otherwise; later budgets set by hand stay. The new rule takes over the
  /// watermark as far as the old rules of the same length had handled the
  /// periods it covers, so periods the user removed stay removed. Returns
  /// the new rule's id.
  Future<String> repeatFrom({
    required BudgetPeriods periods,
    required String categoryId,
    required DateRange from,
    required int amountMinor,
    required BudgetRepeat repeat,
    DateRange? replace,
  }) {
    if (!repeat.repeats) throw ArgumentError.value(repeat, 'repeat');
    if (amountMinor < 0) throw ArgumentError.value(amountMinor, 'amountMinor');
    return writer.transaction(() async {
      final start = dateOnly(from.start);
      final cut = dateOnly((replace ?? from).start);
      final replaceEnd = dateOnly((replace ?? from).end);
      final every = repeat.every < 1 ? 1 : repeat.every;
      final old = [
        for (final r in await rules())
          if (r.categoryId == categoryId) r,
      ];
      await _endRules(old, cut);
      final rule = BudgetRulePlan(
        id: '',
        categoryId: categoryId,
        amountMinor: amountMinor,
        start: start,
        every: every,
        end: repeat.until,
        count: repeat.count,
        cadence: repeat.cadence,
        periodType: repeat.windowed ? null : periods.config.type,
      );
      // Watermark: as far as old rules of the same length had handled every
      // period the new rule covers.
      var watermark = start;
      final sameLength = [
        for (final r in old)
          if (r.lengthOn(periods) == repeat.cadence && r.generatedUntil != null)
            r,
      ];
      if (sameLength.isNotEmpty) {
        final g = sameLength
            .map((r) => r.generatedUntil!)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        for (final p in rule.periodsUpTo(periods, g)) {
          if (!p.start.isAfter(start)) continue;
          final handled = sameLength.any(
            (r) =>
                r.covers(periods, p.start) &&
                !p.start.isAfter(r.generatedUntil!),
          );
          if (!handled) break;
          watermark = p.start;
        }
      }
      final ruleId = await writer.insert(
        db.budgetRules,
        BudgetRulesCompanion(
          categoryId: Value(categoryId),
          amountMinor: Value(amountMinor),
          cadence: Value(repeat.cadence),
          every: Value(every),
          startDate: Value(start),
          endDate: Value(repeat.until == null ? null : dateOnly(repeat.until!)),
          count: Value(repeat.count),
          generatedUntil: Value(watermark),
          periodType: Value(rule.periodType?.name),
        ),
      );
      final oldIds = {for (final r in old) r.id};
      final windowEnd = repeat.windowed ? from.end : null;
      Budget? here;
      final rows =
          await (db.select(db.budgets)..where(
                (b) =>
                    b.categoryId.equals(categoryId) &
                    b.periodStart.isBiggerOrEqualValue(
                      DateTime(start.year - 2, start.month, start.day),
                    ) &
                    b.deletedAt.isNull(),
              ))
              .get();
      final newKind = windowPeriods(periods, repeat.cadence);
      for (final b in rows) {
        final range = DateRange(
          b.periodStart,
          b.periodEnd ?? periods.periodOf(b.periodStart).end,
        );
        final sameKind =
            (b.periodEnd == null) == !repeat.windowed &&
            (!repeat.windowed || newKind.periodOf(b.periodStart) == range);
        if (sameKind && b.periodStart == start && here == null) {
          here = b;
          continue;
        }
        if (b.periodStart.isBefore(cut)) continue; // history
        final replaced = b.periodStart.isBefore(replaceEnd);
        if (!replaced && !oldIds.contains(b.ruleId)) continue; // set by hand
        if (!replaced && sameKind && rule.covers(periods, b.periodStart)) {
          await writer.update(
            db.budgets,
            b.id,
            BudgetsCompanion(
              amountMinor: Value(amountMinor),
              ruleId: Value(ruleId),
            ),
          );
        } else {
          await writer.delete(db.budgets, b.id);
        }
      }
      if (here == null) {
        await writer.insert(
          db.budgets,
          BudgetsCompanion(
            categoryId: Value(categoryId),
            periodStart: Value(start),
            amountMinor: Value(amountMinor),
            ruleId: Value(ruleId),
            periodEnd: Value(windowEnd),
          ),
          id: generatedBudgetId(ruleId, start),
        );
      } else {
        await writer.update(
          db.budgets,
          here.id,
          BudgetsCompanion(
            amountMinor: Value(amountMinor),
            ruleId: Value(ruleId),
          ),
        );
      }
      return ruleId;
    });
  }

  /// Stops [categoryId] repeating from the period starting [from] on: its
  /// rules end before it (rules starting at or after it are removed) and
  /// their generated, unedited rows from [from] on are removed. Budgets set
  /// by hand stay. Returns the ids of the removed rows (for undo).
  Future<List<String>> stopRepeating(String categoryId, DateTime from) =>
      writer.transaction(() async {
        final start = dateOnly(from);
        final old = (await rules()).where((r) => r.categoryId == categoryId);
        if (old.isEmpty) return const <String>[];
        await _endRules(old, start);
        final rows =
            await (db.select(db.budgets)..where(
                  (b) =>
                      b.categoryId.equals(categoryId) &
                      b.periodStart.isBiggerOrEqualValue(start) &
                      b.ruleId.isIn([for (final r in old) r.id]) &
                      b.deletedAt.isNull(),
                ))
                .get();
        for (final b in rows) {
          await writer.delete(db.budgets, b.id);
        }
        return [for (final b in rows) b.id];
      });

  /// Removes the budget of [categoryId] in [period] only. Rules generate up
  /// to [period] first, so their watermark passes it and the removed row
  /// is not generated again. Returns the removed row ids (for undo).
  Future<List<String>> removeFromPeriod(
    BudgetPeriods periods,
    String categoryId,
    DateRange period,
  ) => writer.transaction(() async {
    await ensureFromRules(periods, period.start);
    final rows = (await _periodQuery(
      period.start,
    ).get()).where((b) => b.categoryId == categoryId).toList();
    for (final b in rows) {
      await writer.delete(db.budgets, b.id);
    }
    return [for (final b in rows) b.id];
  });

  /// Undoes [removeFromPeriod] or [stopRepeating] for the rows [ids].
  Future<void> restoreBudgets(List<String> ids) => writer.transaction(() async {
    for (final id in ids) {
      await writer.undelete(db.budgets, id);
    }
  });

  /// Removes the budget of [categoryId] with its own length in [window]
  /// only (see [removeFromPeriod]). Returns the removed row ids.
  Future<List<String>> removeWindow(
    BudgetPeriods periods,
    String categoryId,
    DateRange window,
  ) => writer.transaction(() async {
    await ensureFromRules(periods, window.start);
    final rows = await _windowQuery(categoryId, window).get();
    for (final b in rows) {
      await writer.delete(db.budgets, b.id);
    }
    return [for (final b in rows) b.id];
  });

  /// Sets the budget of [categoryId] with its own length for [window] by
  /// hand (a one-off window, or an override of a repeating one).
  Future<void> setWindowAmount(
    String categoryId,
    DateRange window,
    int amountMinor,
  ) {
    if (amountMinor < 0) throw ArgumentError.value(amountMinor, 'amountMinor');
    return writer.transaction(() async {
      final rows = await _windowQuery(categoryId, window).get();
      if (rows.isEmpty) {
        await writer.insert(
          db.budgets,
          BudgetsCompanion(
            categoryId: Value(categoryId),
            periodStart: Value(dateOnly(window.start)),
            periodEnd: Value(dateOnly(window.end)),
            amountMinor: Value(amountMinor),
          ),
        );
        return;
      }
      if (rows.first.amountMinor != amountMinor || rows.first.ruleId != null) {
        await writer.update(
          db.budgets,
          rows.first.id,
          BudgetsCompanion(
            amountMinor: Value(amountMinor),
            ruleId: const Value(null),
          ),
        );
      }
      for (final dup in rows.skip(1)) {
        await writer.delete(db.budgets, dup.id);
      }
    });
  }

  /// The budget of [categoryId] for exactly [window], if any.
  Future<Budget?> windowBudget(String categoryId, DateRange window) async =>
      (await _windowQuery(categoryId, window).get()).firstOrNull;

  SimpleSelectStatement<$BudgetsTable, Budget> _windowQuery(
    String categoryId,
    DateRange window,
  ) => db.select(db.budgets)
    ..where(
      (b) =>
          b.categoryId.equals(categoryId) &
          b.periodStart.equals(dateOnly(window.start)) &
          b.periodEnd.equals(dateOnly(window.end)) &
          b.deletedAt.isNull(),
    );

  /// Budgets with their own length overlapping [range] (one per category
  /// and window; the newest wins after sync).
  Selectable<Budget> _windowsQuery(DateRange range) =>
      (db.select(db.budgets)..where(
            (b) =>
                b.periodEnd.isNotNull() &
                b.periodStart.isSmallerThanValue(range.end) &
                b.periodEnd.isBiggerThanValue(range.start) &
                b.deletedAt.isNull(),
          ))
          .map((b) => b);

  static List<Budget> _dedupeWindows(List<Budget> rows) {
    final byKey = <(String, DateTime, DateTime?), Budget>{};
    for (final r in rows) {
      final k = (r.categoryId, r.periodStart, r.periodEnd);
      final e = byKey[k];
      if (e == null || r.updatedAt.compareTo(e.updatedAt) > 0) byKey[k] = r;
    }
    return byKey.values.toList()
      ..sort((a, b) => a.periodStart.compareTo(b.periodStart));
  }

  Stream<List<Budget>> watchWindows(DateRange range) =>
      _windowsQuery(range).watch().map(_dedupeWindows);

  Future<List<Budget>> windows(DateRange range) async =>
      _dedupeWindows(await _windowsQuery(range).get());

  /// Envelope mode: the shares of budgets with their own length assigned to
  /// [period] (see [windowShare]), without [skip] categories (those with a
  /// budget of the period itself).
  Future<int> windowAssigned(
    BudgetPeriods periods,
    DateRange period, {
    Set<String> skip = const {},
  }) async {
    var sum = 0;
    for (final b in await windows(period)) {
      if (skip.contains(b.categoryId)) continue;
      sum += windowShare(
        periods,
        DateRange(b.periodStart, b.periodEnd!),
        b.amountMinor,
        period,
      );
    }
    return sum;
  }

  /// Rollover carried into the window budget [row] (its category with
  /// [children]): along the chain of directly preceding windows of the
  /// category (at most [maxBack]), like [syncChain] does for periods. Not
  /// stored.
  Future<int> windowRollover(
    Budget row,
    RolloverMode mode, {
    Iterable<String> children = const [],
    int maxBack = 12,
  }) async {
    if (mode == RolloverMode.none) return 0;
    final chain = <Budget>[];
    var start = row.periodStart;
    for (var i = 0; i < maxBack; i++) {
      final prev =
          await (db.select(db.budgets)..where(
                (b) =>
                    b.categoryId.equals(row.categoryId) &
                    b.periodEnd.equals(start) &
                    b.deletedAt.isNull(),
              ))
              .get();
      if (prev.isEmpty) break;
      chain.insert(0, prev.first);
      start = prev.first.periodStart;
    }
    var rollover = 0;
    for (final b in chain) {
      final spent = (await actuals(DateRange(b.periodStart, b.periodEnd!)))
          .spentOf(b.categoryId, children);
      rollover = rolloverFor(mode, b.amountMinor + rollover - spent);
    }
    return rollover;
  }

  /// Turns the budgets of [period] that do not repeat yet into rules
  /// repeating every period from it on (Fill menu). Budgets a rule covers
  /// keep their rule. Returns the number of budgets converted.
  Future<int> repeatPeriod(BudgetPeriods periods, DateRange period) =>
      writer.transaction(() async {
        final all = await rules();
        final rows = [
          for (final b in await this.period(period.start))
            if (ruleFor(all, periods, b.categoryId, period.start) == null) b,
        ];
        for (final b in rows) {
          await repeatFrom(
            periods: periods,
            categoryId: b.categoryId,
            from: period,
            amountMinor: b.amountMinor,
            repeat: const BudgetRepeat.everyPeriod(),
          );
        }
        return rows.length;
      });

  /// Ends [old] before [start]; rules starting at or after it are removed.
  Future<void> _endRules(Iterable<BudgetRulePlan> old, DateTime start) async {
    final dayBefore = DateTime(start.year, start.month, start.day - 1);
    for (final r in old) {
      if (!r.start.isBefore(start)) {
        await writer.delete(db.budgetRules, r.id);
      } else if (r.end == null || !r.end!.isBefore(start)) {
        await writer.update(
          db.budgetRules,
          r.id,
          BudgetRulesCompanion(endDate: Value(dayBefore)),
        );
      }
    }
  }

  /// Removes all budgets of a period.
  Future<void> clearPeriod(DateTime periodStart) =>
      writer.transaction(() async {
        for (final b in await _periodQuery(periodStart).get()) {
          await writer.delete(db.budgets, b.id);
        }
      });

  /// Copies amounts of [source] into [target] (existing amounts of the
  /// copied categories are overwritten, others kept). Returns the number of
  /// categories copied.
  Future<int> copyPeriod(DateRange source, DateRange target) async {
    final rows = await period(source.start);
    await setAmounts(target.start, {
      for (final r in rows) r.categoryId: r.amountMinor,
    });
    return rows.length;
  }

  /// Average net spending per expense category (direct bookings, not rolled
  /// up) over [periods]; categories without spending are omitted.
  Future<Map<String, int>> averageSpending(
    List<DateRange> periods, {
    int roundUpTo = 100,
  }) async {
    final byCat = <String, List<int>>{};
    final expense = {
      for (final c
          in await (db.select(db.categories)..where(
                (c) =>
                    c.deletedAt.isNull() &
                    c.kind.equalsValue(CategoryKind.expense),
              ))
              .get())
        c.id,
    };
    for (final p in periods) {
      final a = await actuals(p);
      for (final e in a.netByCategory.entries) {
        if (!expense.contains(e.key)) continue;
        byCat.putIfAbsent(e.key, () => []).add(-e.value);
      }
    }
    final out = <String, int>{};
    for (final e in byCat.entries) {
      final avg = averageAmount(e.value, periods.length, roundUpTo: roundUpTo);
      if (avg > 0) out[e.key] = avg;
    }
    return out;
  }

  /// Fills [target] with the average spending of the [n] periods before it.
  /// Returns the number of categories set.
  Future<int> fillFromAverage(
    BudgetPeriods periods,
    DateRange target,
    int n, {
    int roundUpTo = 100,
  }) async {
    final list = <DateRange>[];
    var p = target;
    for (var i = 0; i < n; i++) {
      p = periods.previous(p);
      list.add(p);
    }
    final avg = await averageSpending(list, roundUpTo: roundUpTo);
    await setAmounts(target.start, avg);
    return avg.length;
  }

  // --------------------------------------------------- category options ---

  /// Sets the category's rollover override (null = use the default).
  Future<void> setCategoryRollover(String categoryId, RolloverMode? mode) =>
      writer.update(
        db.categories,
        categoryId,
        CategoriesCompanion(rolloverOverride: Value(mode?.name)),
      );

  /// Sets the category's warning threshold in percent (null = global).
  Future<void> setCategoryThreshold(String categoryId, int? percent) =>
      writer.update(
        db.categories,
        categoryId,
        CategoriesCompanion(warnThresholdOverride: Value(percent)),
      );

  // --------------------------------------------------------- templates ---

  Stream<List<BudgetTemplate>> watchTemplates() =>
      (db.select(db.budgetTemplates)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm(expression: t.name)]))
          .watch();

  /// Saves the budgets of the period starting [periodStart] as a template.
  Future<String> saveTemplate(String name, DateTime periodStart) async {
    final rows = await period(periodStart);
    return await writer.insert(
      db.budgetTemplates,
      BudgetTemplatesCompanion(
        name: Value(name.trim()),
        items: Value(
          jsonEncode([
            for (final r in rows)
              BudgetTemplateItem(r.categoryId, r.amountMinor).toJson(),
          ]),
        ),
      ),
    );
  }

  Future<void> deleteTemplate(String id) =>
      writer.delete(db.budgetTemplates, id);

  /// Applies template [templateId] to the period starting [periodStart].
  /// Items of deleted categories are ignored. Returns the number applied.
  Future<int> applyTemplate(String templateId, DateTime periodStart) async {
    final t =
        await (db.select(db.budgetTemplates)
              ..where((x) => x.id.equals(templateId) & x.deletedAt.isNull()))
            .getSingleOrNull();
    if (t == null) return 0;
    final live = {
      for (final c in await (db.select(
        db.categories,
      )..where((c) => c.deletedAt.isNull())).get())
        c.id,
    };
    final items = BudgetTemplateItem.decodeList(t.items)
        .where((i) => live.contains(i.categoryId) && i.amountMinor >= 0);
    await setAmounts(periodStart, {
      for (final i in items) i.categoryId: i.amountMinor,
    });
    return items.length;
  }

  // ---------------------------------------------------------- rollover ---

  /// Recomputes rollovers along the chain of consecutive budgeted periods
  /// ending with [target] (at most [maxBack] periods back), stores changed
  /// `rolloverMinor` values and returns the rollover and unassigned carry
  /// for [target]. Idempotent.
  ///
  /// A period's rollover per category is `rolloverFor(mode, budget +
  /// rollover − spent)` of the previous period; the first period of a chain
  /// (whose predecessor has no budgets) gets 0. The envelope carry is the
  /// previous period's income + carry − assigned.
  Future<BudgetChain> syncChain({
    required BudgetPeriods periods,
    required DateRange target,
    required Map<String, Category> categories,
    required RolloverMode defaultMode,
    int maxBack = 12,
    bool write = true,
  }) async {
    final chain = <DateRange>[target];
    final rowsByPeriod = <DateRange, List<Budget>>{
      target: await period(target.start),
    };
    var anchored = false;
    var p = target;
    for (var i = 0; i < maxBack; i++) {
      final prev = periods.previous(p);
      if (!prev.start.isBefore(p.start)) break;
      final rows = await period(prev.start);
      // A period with only budgets of their own length still belongs to
      // the chain (envelope carry).
      if (rows.isEmpty && (await windows(prev)).isEmpty) {
        anchored = true;
        break;
      }
      chain.insert(0, prev);
      rowsByPeriod[prev] = rows;
      p = prev;
    }
    if (chain.length == 1 && !anchored) anchored = true;

    final children = <String, List<String>>{};
    for (final c in categories.values) {
      if (c.parentId != null) {
        children.putIfAbsent(c.parentId!, () => []).add(c.id);
      }
    }
    RolloverMode modeFor(String catId) =>
        parseRolloverMode(categories[catId]?.rolloverOverride) ?? defaultMode;

    var rollover = <String, int>{
      if (!anchored)
        for (final r in rowsByPeriod[chain.first]!)
          r.categoryId: r.rolloverMinor,
    };
    var carry = 0;
    final updates = <String, int>{};
    for (var i = 0; i < chain.length; i++) {
      final rows = rowsByPeriod[chain[i]]!;
      if (i > 0 || anchored) {
        for (final r in rows) {
          final computed = rollover[r.categoryId] ?? 0;
          if (r.rolloverMinor != computed) updates[r.id] = computed;
        }
      }
      if (i == chain.length - 1) break;
      final actual = await actuals(chain[i]);
      final next = <String, int>{};
      for (final r in rows) {
        final spent = actual.spentOf(
          r.categoryId,
          children[r.categoryId] ?? const [],
        );
        final available = r.amountMinor + (rollover[r.categoryId] ?? 0);
        final carried = rolloverFor(modeFor(r.categoryId), available - spent);
        if (carried != 0) next[r.categoryId] = carried;
      }
      final a = assignedInPeriod(
        periods: periods,
        period: chain[i],
        periodRows: rows,
        windowRows: await windows(chain[i]),
        categories: categories,
      );
      final assigned = a.periodMinor + a.windowMinor;
      carry = toBeBudgeted(
        incomeMinor: actual.incomeMinor,
        carryMinor: carry,
        assignedMinor: assigned,
      );
      rollover = next;
    }
    if (write && updates.isNotEmpty) {
      await writer.transaction(() async {
        for (final e in updates.entries) {
          await writer.update(
            db.budgets,
            e.key,
            BudgetsCompanion(rolloverMinor: Value(e.value)),
          );
        }
      });
    }
    return BudgetChain(rolloverByCategory: rollover, carryMinor: carry);
  }
}
