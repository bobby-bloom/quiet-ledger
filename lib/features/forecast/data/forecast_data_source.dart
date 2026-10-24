import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/calendar/holidays.dart';
import 'package:personal_finance/core/calendar/recurrence.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/budgets/domain/budget_rules.dart';
import 'package:personal_finance/features/forecast/domain/forecast_dates.dart';
import 'package:personal_finance/features/forecast/domain/forecast_models.dart';

/// Reads everything the forecast engine needs from the database (read
/// only; aggregations run in SQL).
///
/// * Start balances: opening balance + live entries up to and including
///   today (cleared and pending; planned ones too when the forecast
///   includes planned entries).
/// * Future entries (after today): cleared always, pending/planned per
///   `ForecastSettings.includePending/includePlanned`.
/// * Spending history: the trailing 12 complete months plus the current
///   month on forecast accounts, without transfers, planned entries and
///   entries created by recurring rules; split entries count per split.
/// * Recurring rules: active, with their dated amount changes. A change
///   amount takes the template's sign (changes may be stored as
///   magnitudes).
class ForecastDataSource {
  ForecastDataSource(this.db);

  final AppDatabase db;

  Future<ForecastInput> gather({
    required DateTime today,
    required SettingsSnapshot settings,
    int firstDayOfWeek = DateTime.monday,
  }) async {
    final day = dayOf(today);
    final includePending = settings.get(ForecastSettings.includePending);
    final includePlanned = settings.get(ForecastSettings.includePlanned);
    final statuses = [
      TxnStatus.cleared.name,
      if (includePending) TxnStatus.pending.name,
      if (includePlanned) TxnStatus.planned.name,
    ];

    final accountRows =
        await (db.select(db.accounts)
              ..where((a) => a.deletedAt.isNull() & a.archived.equals(false))
              ..orderBy([
                (a) => OrderingTerm(expression: a.sortOrder),
                (a) => OrderingTerm(expression: a.name),
              ]))
            .get();
    final balances = await _balances(day, includePlanned: includePlanned);
    final accounts = [
      for (final (i, a) in accountRows.indexed)
        ForecastAccount(
          id: a.id,
          name: a.name,
          type: a.type,
          balanceMinor: balances[a.id] ?? a.openingBalanceMinor,
          thresholdMinor:
              a.lowBalanceThresholdMinor ??
              settings.get(
                ForecastSettings.lowBalanceThreshold,
                scope: 'account:${a.id}',
              ),
          expectedReturnBp: a.expectedAnnualReturnBp,
          interestRateBp: a.interestRateBp,
          inForecast: a.includeInForecast,
          inNetWorth: a.includeInNetWorth,
          sortOrder: i,
        ),
    ];
    final forecastIds = [
      for (final a in accountRows)
        if (a.includeInForecast) a.id,
    ];
    final netWorthIds = [
      for (final a in accountRows)
        if (a.includeInNetWorth) a.id,
    ];

    final calendar = _calendar(settings);
    final recurring = await _recurring();
    final periodConfig = BudgetPeriodConfig(
      type: settings.get(BudgetSettings.periodType),
      startDay: settings.get(BudgetSettings.startDay),
      shift: settings.get(BudgetSettings.weekendShift),
      calendar: calendar,
      firstDayOfWeek: firstDayOfWeek,
      fiscalYearStartMonth: settings.get(GeneralSettings.fiscalYearStartMonth),
      salaryDates: _salaryDates(settings, recurring, day, calendar),
    );
    final period = BudgetPeriods(periodConfig).periodOf(day);

    final categories = await (db.select(
      db.categories,
    )..where((c) => c.deletedAt.isNull())).get();

    final defaultAccount = settings.get(EntrySettings.defaultAccountId);
    String? primary;
    if (defaultAccount != null && forecastIds.contains(defaultAccount)) {
      primary = defaultAccount;
    } else {
      for (final a in accountRows) {
        if (a.includeInForecast && a.type == AccountType.checking) {
          primary = a.id;
          break;
        }
      }
      primary ??= forecastIds.isEmpty ? null : forecastIds.first;
    }

    final historyStart = DateTime(day.year, day.month - 12);
    return ForecastInput(
      today: day,
      accounts: accounts,
      recurring: recurring,
      scheduled: await _scheduled(day, statuses),
      postedOccurrences: await _posted(day, statuses),
      history: SpendingHistory(
        months: await _monthlySpending(historyStart, day, forecastIds),
        firstTxnDate: await _firstTxnDate(),
        categoryAccount: await _usualAccounts(historyStart, day, forecastIds),
        spentThisMonth: await _spentSince(monthStart(day), day, forecastIds),
        spentThisPeriod: await _spentSince(period.start, day, forecastIds),
        expenseCategoryIds: {
          for (final c in categories)
            if (c.kind == CategoryKind.expense) c.id,
        },
        incomeCategoryIds: {
          for (final c in categories)
            if (c.kind == CategoryKind.income) c.id,
        },
        categoryNames: {for (final c in categories) c.id: c.name},
        monthlyNet: await _monthlyNet(day, netWorthIds),
      ),
      budgets: await _budgets(day, BudgetPeriods(periodConfig)),
      goals: await _goals(),
      primaryAccountId: primary,
      method: settings.get(ForecastSettings.variableMethod),
      periodConfig: periodConfig,
      calendar: calendar,
      globalThresholdMinor: settings.get(ForecastSettings.lowBalanceThreshold),
    );
  }

  /// Tables whose changes invalidate the forecast.
  Set<TableInfo<Table, dynamic>> get watchedTables => {
    db.accounts,
    db.transactions,
    db.transactionSplits,
    db.categories,
    db.recurringRules,
    db.recurringAmountChanges,
    db.budgets,
    db.goals,
  };

  static HolidayCalendar _calendar(SettingsSnapshot s) {
    final country = s.get(BudgetSettings.holidayCountry);
    if (country == 'none' || country.isEmpty) return HolidayCalendar.none();
    return HolidayCalendar(
      country: country,
      region: s.get(BudgetSettings.holidayRegion),
    );
  }

  /// Salary-based budget periods: the dates the chosen income rule lands.
  static List<DateTime> _salaryDates(
    SettingsSnapshot s,
    List<RecurringItem> rules,
    DateTime today,
    HolidayCalendar calendar,
  ) {
    if (!s.get(BudgetSettings.salaryBased)) return const [];
    final id = s.get(BudgetSettings.salaryRuleId);
    final rule = rules.where((r) => r.id == id).firstOrNull;
    if (rule == null) return const [];
    try {
      return [
        for (final o in expandRecurrence(
          rrule: rule.rrule,
          start: rule.startDate,
          from: DateTime(today.year, today.month - 3),
          to: DateTime(today.year, today.month + 38),
          end: rule.endDate,
          count: rule.count,
          shift: rule.shift,
          calendar: calendar,
        ))
          o.date,
      ];
    } on Object {
      return const [];
    }
  }

  Future<Map<String, int>> _balances(
    DateTime today, {
    required bool includePlanned,
  }) async {
    final statuses = [
      TxnStatus.cleared.name,
      TxnStatus.pending.name,
      if (includePlanned) TxnStatus.planned.name,
    ];
    final rows = await db
        .customSelect(
          'SELECT a.id AS id, a.opening_balance_minor + COALESCE( ( '
          'SELECT SUM(t.amount_minor) FROM transactions t '
          'WHERE t.account_id = a.id AND t.deleted_at IS NULL '
          'AND t.status IN (${_marks(statuses.length)}) AND t.date <= ? '
          '), 0) AS balance FROM accounts a WHERE a.deleted_at IS NULL',
          variables: [
            for (final s in statuses) Variable<String>(s),
            Variable<DateTime>(today),
          ],
          readsFrom: {db.accounts, db.transactions},
        )
        .get();
    return {for (final r in rows) r.read<String>('id'): r.read<int>('balance')};
  }

  Future<List<RecurringItem>> _recurring() async {
    final rules = await (db.select(
      db.recurringRules,
    )..where((r) => r.deletedAt.isNull() & r.active.equals(true))).get();
    final changes = await (db.select(
      db.recurringAmountChanges,
    )..where((c) => c.deletedAt.isNull())).get();
    final byRule = <String, List<RecurringAmountChange>>{};
    for (final c in changes) {
      (byRule[c.ruleId] ??= []).add(c);
    }
    final out = <RecurringItem>[];
    for (final r in rules) {
      final TxnDraft t;
      try {
        t = TxnDraft.fromJson((jsonDecode(r.template) as Map).cast());
      } on Object {
        continue;
      }
      if (t.accountId.isEmpty) continue;
      final sign = t.amountMinor < 0 ? -1 : 1;
      out.add(
        RecurringItem(
          id: r.id,
          name: r.name,
          rrule: r.rrule,
          startDate: dayOf(r.startDate),
          endDate: r.endDate == null ? null : dayOf(r.endDate!),
          count: r.count,
          shift:
              WeekendShift.values.asNameMap()[r.weekendShift] ??
              WeekendShift.none,
          type: t.type,
          accountId: t.accountId,
          transferAccountId: t.isTransfer ? t.transferAccountId : null,
          amountMinor: t.amountMinor,
          amountChanges: {
            for (final c in byRule[r.id] ?? const <RecurringAmountChange>[])
              dayOf(c.fromDate): t.amountMinor == 0
                  ? c.amountMinor
                  : sign * c.amountMinor.abs(),
          },
          categories: t.isTransfer
              ? const []
              : t.isSplit
              ? [
                  for (final s in t.splits)
                    CategoryShare(s.categoryId, s.amountMinor),
                ]
              : [CategoryShare(t.categoryId, t.amountMinor)],
          lastPostedDate: r.lastPostedDate,
        ),
      );
    }
    return out;
  }

  Future<List<PlannedEvent>> _scheduled(
    DateTime today,
    List<String> statuses,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT t.id, t.account_id, t.date, t.amount_minor, t.payee, '
          't.note, t.category_id, c.name AS category_name '
          'FROM transactions t '
          'LEFT JOIN categories c ON c.id = t.category_id '
          'WHERE t.deleted_at IS NULL AND t.date > ? '
          'AND t.status IN (${_marks(statuses.length)}) '
          'ORDER BY t.date',
          variables: [
            Variable<DateTime>(today),
            for (final s in statuses) Variable<String>(s),
          ],
          readsFrom: {db.transactions, db.categories},
        )
        .get();
    return [
      for (final r in rows)
        PlannedEvent(
          date: dayOf(r.read<DateTime>('date')),
          accountId: r.read<String>('account_id'),
          amountMinor: r.read<int>('amount_minor'),
          label:
              _nonEmpty(r.readNullable<String>('payee')) ??
              _nonEmpty(r.readNullable<String>('note')) ??
              r.readNullable<String>('category_name') ??
              '',
          kind: ForecastEventKind.scheduled,
          categoryId: r.readNullable<String>('category_id'),
          refId: r.read<String>('id'),
        ),
    ];
  }

  Future<Map<String, List<DateTime>>> _posted(
    DateTime today,
    List<String> statuses,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT DISTINCT recurring_rule_id AS rule, date FROM transactions '
          'WHERE deleted_at IS NULL AND recurring_rule_id IS NOT NULL '
          'AND date >= ? AND status IN (${_marks(statuses.length)})',
          variables: [
            Variable<DateTime>(addDays(today, -14)),
            for (final s in statuses) Variable<String>(s),
          ],
          readsFrom: {db.transactions},
        )
        .get();
    final out = <String, List<DateTime>>{};
    for (final r in rows) {
      (out[r.read<String>('rule')] ??= []).add(dayOf(r.read<DateTime>('date')));
    }
    return out;
  }

  /// SQL CASE expression mapping `t.date` to the index of the month
  /// starting at [from] (0 = first month), and its variables.
  (String, List<Variable<Object>>) _monthBucket(DateTime from, int months) {
    final buf = StringBuffer('CASE');
    final vars = <Variable<Object>>[];
    for (var i = 0; i < months; i++) {
      buf.write(' WHEN t.date < ? THEN $i');
      vars.add(Variable<DateTime>(DateTime(from.year, from.month + i + 1)));
    }
    buf.write(' ELSE $months END');
    return (buf.toString(), vars);
  }

  static const _spendingFilter =
      't.deleted_at IS NULL AND t.type <> ? AND t.recurring_rule_id IS NULL '
      "AND t.status <> 'planned'";

  Future<List<CategoryMonthTotal>> _monthlySpending(
    DateTime from,
    DateTime today,
    List<String> accountIds,
  ) async {
    if (accountIds.isEmpty) return const [];
    final months = (today.year - from.year) * 12 + today.month - from.month;
    final (bucket, bucketVars) = _monthBucket(from, months);
    final rows = await db
        .customSelect(
          'SELECT cat, bucket, SUM(amount) AS total FROM ( '
          'SELECT COALESCE(s.category_id, t.category_id) AS cat, '
          'COALESCE(s.amount_minor, t.amount_minor) AS amount, '
          '$bucket AS bucket '
          'FROM transactions t '
          'LEFT JOIN transaction_splits s '
          'ON s.transaction_id = t.id AND s.deleted_at IS NULL '
          'WHERE $_spendingFilter '
          'AND t.account_id IN (${_marks(accountIds.length)}) '
          'AND t.date >= ? AND t.date < ? '
          ') WHERE cat IS NOT NULL AND bucket < ? GROUP BY cat, bucket',
          variables: [
            ...bucketVars,
            Variable<String>(TxnType.transfer.name),
            for (final id in accountIds) Variable<String>(id),
            Variable<DateTime>(from),
            Variable<DateTime>(monthStart(today)),
            Variable<int>(months),
          ],
          readsFrom: {db.transactions, db.transactionSplits},
        )
        .get();
    return [
      for (final r in rows)
        CategoryMonthTotal(
          categoryId: r.read<String>('cat'),
          year: DateTime(from.year, from.month + r.read<int>('bucket')).year,
          month: DateTime(from.year, from.month + r.read<int>('bucket')).month,
          spentMinor: -r.read<int>('total'),
        ),
    ];
  }

  /// Most frequent account per category (ties: account order).
  Future<Map<String, String>> _usualAccounts(
    DateTime from,
    DateTime today,
    List<String> accountIds,
  ) async {
    if (accountIds.isEmpty) return const {};
    final rows = await db
        .customSelect(
          'SELECT COALESCE(s.category_id, t.category_id) AS cat, '
          't.account_id AS account, COUNT(*) AS n '
          'FROM transactions t '
          'LEFT JOIN transaction_splits s '
          'ON s.transaction_id = t.id AND s.deleted_at IS NULL '
          'WHERE t.deleted_at IS NULL AND t.type <> ? '
          'AND t.account_id IN (${_marks(accountIds.length)}) '
          'AND t.date >= ? AND t.date <= ? '
          'GROUP BY cat, account',
          variables: [
            Variable<String>(TxnType.transfer.name),
            for (final id in accountIds) Variable<String>(id),
            Variable<DateTime>(from),
            Variable<DateTime>(today),
          ],
          readsFrom: {db.transactions, db.transactionSplits},
        )
        .get();
    final order = {for (final (i, id) in accountIds.indexed) id: i};
    final best = <String, (String, int)>{};
    for (final r in rows) {
      final cat = r.readNullable<String>('cat');
      if (cat == null) continue;
      final account = r.read<String>('account');
      final n = r.read<int>('n');
      final current = best[cat];
      if (current == null ||
          n > current.$2 ||
          (n == current.$2 && order[account]! < order[current.$1]!)) {
        best[cat] = (account, n);
      }
    }
    return {for (final e in best.entries) e.key: e.value.$1};
  }

  Future<Map<String, int>> _spentSince(
    DateTime from,
    DateTime today,
    List<String> accountIds,
  ) async {
    if (accountIds.isEmpty) return const {};
    final rows = await db
        .customSelect(
          'SELECT COALESCE(s.category_id, t.category_id) AS cat, '
          'SUM(COALESCE(s.amount_minor, t.amount_minor)) AS total '
          'FROM transactions t '
          'LEFT JOIN transaction_splits s '
          'ON s.transaction_id = t.id AND s.deleted_at IS NULL '
          'WHERE $_spendingFilter '
          'AND t.account_id IN (${_marks(accountIds.length)}) '
          'AND t.date >= ? AND t.date <= ? '
          'GROUP BY cat',
          variables: [
            Variable<String>(TxnType.transfer.name),
            for (final id in accountIds) Variable<String>(id),
            Variable<DateTime>(from),
            Variable<DateTime>(today),
          ],
          readsFrom: {db.transactions, db.transactionSplits},
        )
        .get();
    return {
      for (final r in rows)
        if (r.readNullable<String>('cat') != null)
          r.read<String>('cat'): -r.read<int>('total'),
    };
  }

  /// Net of income and expenses (no transfers, no planned entries) of each
  /// of the trailing 12 complete months that have data, oldest first.
  Future<List<int>> _monthlyNet(DateTime today, List<String> accountIds) async {
    if (accountIds.isEmpty) return const [];
    final first = await _firstTxnDate();
    if (first == null) return const [];
    final from = DateTime(today.year, today.month - 12);
    final (bucket, bucketVars) = _monthBucket(from, 12);
    final rows = await db
        .customSelect(
          'SELECT $bucket AS bucket, SUM(t.amount_minor) AS total '
          'FROM transactions t WHERE t.deleted_at IS NULL AND t.type <> ? '
          "AND t.status <> 'planned' "
          'AND t.account_id IN (${_marks(accountIds.length)}) '
          'AND t.date >= ? AND t.date < ? GROUP BY bucket',
          variables: [
            ...bucketVars,
            Variable<String>(TxnType.transfer.name),
            for (final id in accountIds) Variable<String>(id),
            Variable<DateTime>(from),
            Variable<DateTime>(monthStart(today)),
          ],
          readsFrom: {db.transactions},
        )
        .get();
    final totals = {
      for (final r in rows) r.read<int>('bucket'): r.read<int>('total'),
    };
    final firstMonth = monthStart(first);
    return [
      for (var i = 0; i < 12; i++)
        if (!DateTime(from.year, from.month + i).isBefore(firstMonth))
          totals[i] ?? 0,
    ];
  }

  Future<DateTime?> _firstTxnDate() async {
    final min = db.transactions.date.min();
    final row =
        await (db.selectOnly(db.transactions)
              ..addColumns([min])
              ..where(db.transactions.deletedAt.isNull()))
            .getSingle();
    final v = row.read(min);
    return v == null ? null : dayOf(v);
  }

  /// Budgets of the last two years per budget period. A budget with its own
  /// length is spread evenly over the budget periods it covers
  /// (`windowShare`), unless the category has a budget of that period.
  Future<List<BudgetRow>> _budgets(
    DateTime today,
    BudgetPeriods periods,
  ) async {
    final rows =
        await (db.select(db.budgets)..where(
              (b) =>
                  b.deletedAt.isNull() &
                  (b.periodEnd.isNull() |
                      b.periodEnd.isBiggerThanValue(
                        DateTime(today.year - 2, today.month),
                      )) &
                  (b.periodEnd.isNotNull() |
                      b.periodStart.isBiggerOrEqualValue(
                        DateTime(today.year - 2, today.month),
                      )),
            ))
            .get();
    final byPeriod = <(String, DateTime), int>{};
    final shares = <(String, DateTime), int>{};
    for (final b in rows) {
      final end = b.periodEnd;
      if (end == null) {
        byPeriod[(b.categoryId, dayOf(b.periodStart))] = b.amountMinor;
        continue;
      }
      final window = DateRange(dayOf(b.periodStart), dayOf(end));
      for (final p in windowTargets(periods, window)) {
        final key = (b.categoryId, p.start);
        shares[key] =
            (shares[key] ?? 0) + windowShare(periods, window, b.amountMinor, p);
      }
    }
    for (final e in shares.entries) {
      byPeriod.putIfAbsent(e.key, () => e.value);
    }
    return [
      for (final e in byPeriod.entries)
        BudgetRow(
          categoryId: e.key.$1,
          periodStart: e.key.$2,
          amountMinor: e.value,
        ),
    ];
  }

  Future<List<GoalInput>> _goals() async {
    final rows = await (db.select(
      db.goals,
    )..where((g) => g.deletedAt.isNull() & g.archived.equals(false))).get();
    return [
      for (final g in rows)
        GoalInput(
          id: g.id,
          name: g.name,
          targetMinor: g.targetMinor,
          savedMinor: g.savedMinor,
          accountId: g.accountId,
          contributionMinor: g.contributionMinor,
          targetDate: g.targetDate,
        ),
    ];
  }

  static String _marks(int n) => List.filled(n, '?').join(', ');

  static String? _nonEmpty(String? s) =>
      s == null || s.trim().isEmpty ? null : s;
}
