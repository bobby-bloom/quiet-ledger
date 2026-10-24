import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/features/forecast/domain/forecast_dates.dart';
import 'package:personal_finance/features/forecast/domain/forecast_models.dart';
import 'package:personal_finance/features/forecast/domain/recurring_expansion.dart';
import 'package:personal_finance/features/forecast/domain/variable_spending.dart';

/// Which accounts a model covers.
enum AccountScope {
  /// Accounts with "include in forecast" (cash-flow forecast).
  forecast,

  /// Accounts with "include in net worth" (long-term projection).
  netWorth,
}

/// Builds the cash-flow model for `[today, today + horizonMonths]` (or up
/// to [endOverride]): accounts in [scope], all recurring rules, future
/// ledger entries, goal contributions and expected variable spending.
CashflowModel prepareCashflowModel(
  ForecastInput input, {
  int horizonMonths = 3,
  AccountScope scope = AccountScope.forecast,
  DateTime? endOverride,
}) {
  final today = dayOf(input.today);
  final end = endOverride == null
      ? horizonEnd(today, horizonMonths)
      : dayOf(endOverride);
  final accounts = [
    for (final a in input.accounts)
      if (scope == AccountScope.forecast ? a.inForecast : a.inNetWorth) a,
  ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final ids = {for (final a in accounts) a.id};
  final events = <PlannedEvent>[
    for (final e in input.scheduled)
      if (e.date.isAfter(today) && !e.date.isAfter(end)) e,
    ...planGoalContributions(input, end),
  ];
  return CashflowModel(
    today: today,
    end: end,
    accounts: accounts,
    recurring: input.recurring,
    events: events,
    spread: planVariableSpending(input, end, accountIds: ids),
    postedOccurrences: input.postedOccurrences,
    calendar: input.calendar,
    periodConfig: input.periodConfig,
    globalThresholdMinor: input.globalThresholdMinor,
    bigEventMinMinor: input.bigEventMinMinor,
    categoryAccount: input.history.categoryAccount,
    expenseCategoryIds: input.history.expenseCategoryIds,
    incomeCategoryIds: input.history.incomeCategoryIds,
    primaryAccountId: input.primaryAccountId,
  );
}

/// Monthly goal contributions as transfers from the primary account into
/// the goal's linked account (or out of the cash accounts into the goal's
/// own bucket when it has no account).
///
/// Heuristics: contributions are booked on the 1st of every month after
/// today until the goal's remaining amount is reached (the last one may be
/// partial). Goals whose linked account already receives a recurring
/// transfer are skipped (that rule is the contribution), as are goals
/// linked to the primary account itself.
List<PlannedEvent> planGoalContributions(ForecastInput input, DateTime end) {
  final source = input.primaryAccountId;
  if (source == null) return const [];
  final balances = {for (final a in input.accounts) a.id: a.balanceMinor};
  final out = <PlannedEvent>[];
  for (final g in input.goals) {
    final contribution = g.contributionMinor ?? 0;
    if (contribution <= 0) continue;
    final linked = g.accountId;
    if (linked == source) continue;
    if (linked != null &&
        input.recurring.any(
          (r) =>
              r.isTransfer &&
              ((r.transferAccountId == linked && r.amountMinor < 0) ||
                  (r.accountId == linked && r.amountMinor > 0)),
        )) {
      continue;
    }
    final current = linked != null && balances.containsKey(linked)
        ? balances[linked]!
        : g.savedMinor;
    var remaining = g.targetMinor - current;
    var date = nextMonthStart(input.today);
    while (remaining > 0 && !date.isAfter(end)) {
      final amount = contribution < remaining ? contribution : remaining;
      out.add(
        PlannedEvent(
          date: date,
          accountId: source,
          amountMinor: -amount,
          counterAccountId: g.bucketId,
          label: g.name,
          kind: ForecastEventKind.goal,
          refId: g.id,
        ),
      );
      remaining -= amount;
      date = nextMonthStart(date);
    }
  }
  return out;
}

/// Receives every flow of a model once: day index (0 = today), account,
/// signed amount for that account, and for transfers the counter account
/// (which receives `-amountMinor`). [indexed] marks income/spending that
/// recurs (rules, variable spending) and grows with inflation in the
/// long-term projection; one-off entries and transfers do not.
typedef FlowSink = void Function(
  int day,
  String accountId,
  String? counterAccountId,
  int amountMinor, {
  required bool indexed,
});

/// Visits every flow of [model] (recurring occurrences, events and daily
/// spread shares) within the horizon. Discrete events are also passed to
/// [onEvent]. The sink decides which accounts it tracks.
void visitFlows(
  CashflowModel model, {
  required FlowSink sink,
  void Function(ForecastEvent event, {required bool external})? onEvent,
}) {
  final today = model.today;
  final n = model.dayCount;
  for (final item in model.recurring) {
    final occs = expandUnposted(
      item,
      today,
      model.end,
      calendar: model.calendar,
      posted: model.postedOccurrences[item.id] ?? const [],
    );
    for (final o in occs) {
      final i = daysBetween(today, o.occurrence.date);
      if (i < 0 || i >= n || o.amountMinor == 0) continue;
      sink(
        i,
        item.accountId,
        item.isTransfer ? item.transferAccountId : null,
        o.amountMinor,
        indexed: !item.isTransfer,
      );
      onEvent?.call(
        ForecastEvent(
          date: o.occurrence.date,
          accountId: item.accountId,
          amountMinor: o.amountMinor,
          label: item.name,
          kind: ForecastEventKind.recurring,
          counterAccountId: item.isTransfer ? item.transferAccountId : null,
          refId: item.id,
        ),
        external: !item.isTransfer,
      );
    }
  }
  for (final e in model.events) {
    final i = daysBetween(today, e.date);
    if (i < 0 || i >= n || e.amountMinor == 0) continue;
    sink(i, e.accountId, e.counterAccountId, e.amountMinor, indexed: false);
    onEvent?.call(
      ForecastEvent(
        date: e.date,
        accountId: e.accountId,
        amountMinor: e.amountMinor,
        label: e.label,
        kind: e.kind,
        counterAccountId: e.counterAccountId,
        refId: e.refId,
      ),
      external: e.counterAccountId == null,
    );
  }
  for (final s in model.spread) {
    final days = s.days;
    if (days <= 0 || s.totalMinor == 0) continue;
    final shares = allocateEvenly(s.totalMinor, days);
    final offset = daysBetween(today, s.start);
    for (var k = 0; k < days; k++) {
      final i = offset + k;
      if (i < 0) continue;
      if (i >= n) break;
      if (shares[k] != 0) sink(i, s.accountId, null, shares[k], indexed: true);
    }
  }
}

/// Runs the daily simulation of [model].
CashflowResult simulateCashflow(CashflowModel model) {
  final n = model.dayCount;
  final ids = [for (final a in model.accounts) a.id];
  final deltas = {for (final id in ids) id: List<int>.filled(n, 0)};
  final events = <ForecastEvent>[];
  visitFlows(
    model,
    sink: (i, account, counter, amount, {required indexed}) {
      final d = deltas[account];
      if (d != null) d[i] += amount;
      if (counter != null) {
        final c = deltas[counter];
        if (c != null) c[i] -= amount;
      }
    },
    onEvent: (e, {required external}) {
      if (deltas.containsKey(e.accountId)) {
        events.add(e);
      } else if (e.counterAccountId != null &&
          deltas.containsKey(e.counterAccountId)) {
        // Show the event from the side that is in the forecast.
        events.add(
          ForecastEvent(
            date: e.date,
            accountId: e.counterAccountId!,
            amountMinor: -e.amountMinor,
            label: e.label,
            kind: e.kind,
            counterAccountId: e.accountId,
            refId: e.refId,
          ),
        );
      }
    },
  );

  final balances = <String, List<int>>{};
  final startBalances = <String, int>{};
  final total = List<int>.filled(n, 0);
  for (final a in model.accounts) {
    final d = deltas[a.id]!;
    final s = List<int>.filled(n, 0);
    var b = a.balanceMinor;
    for (var i = 0; i < n; i++) {
      b += d[i];
      s[i] = b;
      total[i] += b;
    }
    balances[a.id] = s;
    startBalances[a.id] = a.balanceMinor;
  }

  final thresholds = <String, int?>{
    for (final a in model.accounts) a.id: _positive(a.thresholdMinor),
  };
  final totalThreshold = _positive(model.globalThresholdMinor);
  final lowestByAccount = {
    for (final id in ids) id: lowestOf(balances[id]!, model.today),
  };
  final lowestTotal = lowestOf(total, model.today);

  // Liabilities (credit cards, loans) are normally negative, so low-balance
  // warnings do not apply to them.
  final liabilities = {
    for (final a in model.accounts)
      if (a.type.isLiability) a.id,
  };
  final warnings = <BalanceWarning>[
    for (final id in ids)
      if (!liabilities.contains(id))
        ?warningFor(id, balances[id]!, thresholds[id], model.today),
    ?warningFor(null, total, totalThreshold, model.today),
  ];

  final monthRanges = <DateRange>[
    for (
      var m = monthStart(model.today);
      !m.isAfter(model.end);
      m = nextMonthStart(m)
    )
      DateRange(m, nextMonthStart(m)),
  ];
  final periodRanges = BudgetPeriods(model.periodConfig)
      .periodsBetween(model.today, model.end);

  events.sort((a, b) {
    final c = a.date.compareTo(b.date);
    return c != 0 ? c : a.amountMinor.compareTo(b.amountMinor);
  });
  final big = [
    for (final e in events)
      if (e.amountMinor.abs() >= model.bigEventMinMinor) e,
  ];

  return CashflowResult(
    start: model.today,
    end: model.end,
    accountIds: ids,
    startBalances: startBalances,
    balances: balances,
    total: total,
    lowestByAccount: lowestByAccount,
    lowestTotal: lowestTotal,
    thresholds: thresholds,
    totalThreshold: totalThreshold,
    warnings: warnings,
    months: _summaries(monthRanges, model, balances, total),
    periods: _summaries(periodRanges, model, balances, total),
    events: events,
    bigEvents: big,
  );
}

int? _positive(int? v) => v != null && v > 0 ? v : null;

/// Earliest minimum of [series] (day 0 = [start]).
LowPoint lowestOf(List<int> series, DateTime start, {int from = 0}) {
  if (series.isEmpty || from >= series.length) return LowPoint(start, 0);
  var best = from < 0 ? 0 : from;
  for (var i = best + 1; i < series.length; i++) {
    if (series[i] < series[best]) best = i;
  }
  return LowPoint(addDays(start, best), series[best]);
}

/// A warning when [series] drops below zero or below [threshold].
BalanceWarning? warningFor(
  String? accountId,
  List<int> series,
  int? threshold,
  DateTime start,
) {
  if (series.isEmpty) return null;
  final low = lowestOf(series, start);
  final limit = threshold ?? 0;
  final WarningKind kind;
  if (low.amountMinor < 0) {
    kind = WarningKind.belowZero;
  } else if (threshold != null && low.amountMinor < threshold) {
    kind = WarningKind.belowThreshold;
  } else {
    return null;
  }
  final firstLimit = kind == WarningKind.belowZero ? 0 : limit;
  final first = series.indexWhere((b) => b < firstLimit);
  final countLimit = threshold != null && threshold > 0 ? threshold : 0;
  return BalanceWarning(
    accountId: accountId,
    kind: kind,
    firstDate: addDays(start, first),
    lowest: low,
    daysBelow: series.where((b) => b < countLimit).length,
    thresholdMinor: threshold,
  );
}

List<PeriodSummary> _summaries(
  List<DateRange> ranges,
  CashflowModel model,
  Map<String, List<int>> balances,
  List<int> total,
) {
  final n = total.length;
  final out = <PeriodSummary>[];
  for (final r in ranges) {
    final i0 = daysBetween(model.today, r.start).clamp(0, n - 1);
    final i1 = daysBetween(model.today, r.last).clamp(0, n - 1);
    if (daysBetween(model.today, r.last) < 0 ||
        daysBetween(model.today, r.start) >= n) {
      continue;
    }
    LowPoint low(List<int> s) {
      var best = i0;
      for (var i = i0 + 1; i <= i1; i++) {
        if (s[i] < s[best]) best = i;
      }
      return LowPoint(addDays(model.today, best), s[best]);
    }

    out.add(
      PeriodSummary(
        range: r,
        clipped: r.start.isBefore(model.today) || r.last.isAfter(model.end),
        endByAccount: {for (final e in balances.entries) e.key: e.value[i1]},
        endTotal: total[i1],
        lowByAccount: {for (final e in balances.entries) e.key: low(e.value)},
        lowTotal: low(total),
      ),
    );
  }
  return out;
}

/// Answer to "Can I afford X on D from account A?".
class AffordabilityResult {
  const AffordabilityResult({
    required this.accountId,
    required this.amountMinor,
    required this.date,
    required this.before,
    required this.after,
    required this.totalAfter,
    this.thresholdMinor,
  });

  final String accountId;

  /// Positive amount spent.
  final int amountMinor;
  final DateTime date;

  /// Lowest balance of the account from [date] on, without the purchase.
  final LowPoint before;

  /// Lowest balance of the account from [date] on, with the purchase.
  final LowPoint after;

  /// Lowest total balance from [date] on, with the purchase.
  final LowPoint totalAfter;
  final int? thresholdMinor;

  bool get belowZero => after.amountMinor < 0;

  bool get belowThreshold =>
      thresholdMinor != null && after.amountMinor < thresholdMinor!;

  bool get affordable => !belowZero && !belowThreshold;
}

/// Adds a one-off spend of [amountMinor] (positive) on [date] from
/// [accountId] to [model] and reports the new lowest point. Nothing is
/// saved.
AffordabilityResult checkAffordability(
  CashflowModel model, {
  required int amountMinor,
  required DateTime date,
  required String accountId,
  String label = '',
  CashflowResult? baseline,
}) {
  final base = baseline ?? simulateCashflow(model);
  final day = dayOf(date).isBefore(model.today) ? model.today : dayOf(date);
  final probe = model.copyWith(
    events: [
      ...model.events,
      PlannedEvent(
        date: day,
        accountId: accountId,
        amountMinor: -amountMinor.abs(),
        label: label,
        kind: ForecastEventKind.whatIf,
      ),
    ],
  );
  final r = simulateCashflow(probe);
  final from = daysBetween(model.today, day);
  return AffordabilityResult(
    accountId: accountId,
    amountMinor: amountMinor.abs(),
    date: day,
    before: lowestOf(base.series(accountId), model.today, from: from),
    after: lowestOf(r.series(accountId), model.today, from: from),
    totalAfter: lowestOf(r.total, model.today, from: from),
    thresholdMinor: r.threshold(accountId),
  );
}
