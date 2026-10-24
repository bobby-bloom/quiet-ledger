import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/core/money/money.dart';
import 'package:personal_finance/features/forecast/domain/cashflow_engine.dart';
import 'package:personal_finance/features/forecast/domain/forecast_dates.dart';
import 'package:personal_finance/features/forecast/domain/forecast_models.dart';
import 'package:personal_finance/features/forecast/domain/variable_spending.dart';

// Long-term net-worth projection (PLAN.md §2.4).
//
// Model (monthly steps, step m ends on today + m months):
// * Every net-worth account is projected on its own. Asset accounts with a
//   positive balance grow by their expected return (account value, else the
//   default return; checking and cash default to 0 %), liabilities with a
//   negative balance grow by their interest rate. Rates are nominal annual
//   rates compounded monthly (rate / 12), computed with Decimal and rounded
//   to the cent each month (half away from zero).
// * Transfers from the plan (recurring transfers such as loan repayments or
//   savings plans, goal contributions) move money between accounts. A
//   repayment never pushes a liability above 0: once it is paid off the
//   payment stays in the source account, so the freed money keeps saving.
// * Savings come from the plan (recurring income/expenses plus expected
//   variable spending, month by month, so rules that end are respected) or
//   from history (the mean net of the trailing 12 complete months, booked
//   on the primary account). Recurring income and spending (and the
//   historic savings) grow with inflation; transfers and one-off entries
//   stay nominal.
// * Real values divide by the inflation index (inflation / 12 compounded
//   monthly).

enum SavingsSource { history, plan }

@immutable
class ProjectionAssumptions {
  const ProjectionAssumptions({
    this.years = 20,
    this.inflationBp = 200,
    this.defaultReturnBp = 0,
    this.realValues = false,
    this.source = SavingsSource.history,
    this.accountReturnBp = const {},
    this.assetReturnBp,
  });

  final int years;
  final int inflationBp;

  /// Return of asset accounts without their own expected return (checking
  /// and cash accounts default to 0 instead).
  final int defaultReturnBp;
  final bool realValues;
  final SavingsSource source;

  /// Scenario overrides per account.
  final Map<String, int> accountReturnBp;

  /// Scenario override for every asset account except checking and cash.
  final int? assetReturnBp;

  int get months => years.clamp(1, 40) * 12;

  ProjectionAssumptions copyWith({
    int? years,
    int? inflationBp,
    int? defaultReturnBp,
    bool? realValues,
    SavingsSource? source,
    Map<String, int>? accountReturnBp,
    int? assetReturnBp,
  }) => ProjectionAssumptions(
    years: years ?? this.years,
    inflationBp: inflationBp ?? this.inflationBp,
    defaultReturnBp: defaultReturnBp ?? this.defaultReturnBp,
    realValues: realValues ?? this.realValues,
    source: source ?? this.source,
    accountReturnBp: accountReturnBp ?? this.accountReturnBp,
    assetReturnBp: assetReturnBp ?? this.assetReturnBp,
  );

  /// Effective annual rate of [a] in basis points.
  int rateOf(ForecastAccount a) {
    if (a.type.isLiability) return a.interestRateBp ?? 0;
    final own = accountReturnBp[a.id];
    if (own != null) return own;
    final cashLike =
        a.type == AccountType.checking || a.type == AccountType.cash;
    if (assetReturnBp != null && !cashLike) return assetReturnBp!;
    return a.expectedReturnBp ?? (cashLike ? 0 : defaultReturnBp);
  }

  @override
  bool operator ==(Object other) =>
      other is ProjectionAssumptions &&
      other.years == years &&
      other.inflationBp == inflationBp &&
      other.defaultReturnBp == defaultReturnBp &&
      other.realValues == realValues &&
      other.source == source &&
      other.assetReturnBp == assetReturnBp &&
      _mapEq(other.accountReturnBp, accountReturnBp);

  @override
  int get hashCode => Object.hash(
    years,
    inflationBp,
    defaultReturnBp,
    realValues,
    source,
    assetReturnBp,
    accountReturnBp.length,
  );
}

bool _mapEq(Map<String, int> a, Map<String, int> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

/// A money move between two accounts within one step (always positive,
/// from [from] to [to]).
@immutable
class TransferFlow {
  const TransferFlow(this.from, this.to, this.amountMinor);

  final String from;
  final String to;
  final int amountMinor;
}

/// Flows of a model aggregated into monthly steps.
class MonthlyFlows {
  MonthlyFlows(this.stepEnds)
    : indexed = List.generate(stepEnds.length, (_) => <String, int>{}),
      fixed = List.generate(stepEnds.length, (_) => <String, int>{}),
      transfers = List.generate(stepEnds.length, (_) => <TransferFlow>[]);

  /// Inclusive end date of each step.
  final List<DateTime> stepEnds;

  /// Recurring income/spending per account (grows with inflation).
  final List<Map<String, int>> indexed;

  /// One-off income/spending per account.
  final List<Map<String, int>> fixed;
  final List<List<TransferFlow>> transfers;

  int get steps => stepEnds.length;

  int indexedTotal(int step) => indexed[step].values.fold(0, (a, b) => a + b);

  int fixedTotal(int step) => fixed[step].values.fold(0, (a, b) => a + b);
}

/// Aggregates the flows of [model] into [months] monthly steps.
MonthlyFlows aggregateMonthly(CashflowModel model, int months) {
  final ends = [
    for (var m = 1; m <= months; m++) addMonthsClamped(model.today, m),
  ];
  final flows = MonthlyFlows(ends);
  final n = model.dayCount;
  final stepOfDay = List<int>.filled(n, months - 1);
  var step = 0;
  for (var i = 0; i < n; i++) {
    final d = addDays(model.today, i);
    while (step < months - 1 && d.isAfter(ends[step])) {
      step++;
    }
    stepOfDay[i] = step;
  }
  visitFlows(
    model,
    sink: (i, account, counter, amount, {required indexed}) {
      final s = stepOfDay[i];
      if (counter != null) {
        flows.transfers[s].add(
          amount < 0
              ? TransferFlow(account, counter, -amount)
              : TransferFlow(counter, account, amount),
        );
        return;
      }
      final target = indexed ? flows.indexed[s] : flows.fixed[s];
      target[account] = (target[account] ?? 0) + amount;
    },
  );
  return flows;
}

@immutable
class ProjectionPoint {
  const ProjectionPoint({
    required this.date,
    required this.nominalMinor,
    required this.realMinor,
    required this.assetsMinor,
    required this.liabilitiesMinor,
  });

  final DateTime date;
  final int nominalMinor;
  final int realMinor;

  /// Nominal sum of asset accounts (incl. goal buckets).
  final int assetsMinor;

  /// Nominal sum of liability accounts (≤ 0 while in debt).
  final int liabilitiesMinor;

  int value({required bool real}) => real ? realMinor : nominalMinor;
}

enum MilestoneKind { netWorth, debtFree, liabilityPaidOff, goalReached }

@immutable
class Milestone {
  const Milestone({
    required this.kind,
    required this.date,
    this.amountMinor,
    this.refId,
    this.label,
  });

  final MilestoneKind kind;
  final DateTime date;

  /// Net-worth level or goal target.
  final int? amountMinor;

  /// Account or goal id.
  final String? refId;
  final String? label;

  @override
  String toString() => 'Milestone($kind, $date, $amountMinor, $label)';
}

/// Net-worth levels that produce a milestone when crossed upwards.
const netWorthMilestones = <int>[
  1000000,
  2500000,
  5000000,
  10000000,
  25000000,
  50000000,
  100000000,
  250000000,
  500000000,
  1000000000,
];

@immutable
class NetWorthProjection {
  const NetWorthProjection({
    required this.points,
    required this.milestones,
    required this.real,
    required this.monthlySavingsMinor,
    required this.source,
  });

  /// Point 0 = today, then one per month.
  final List<ProjectionPoint> points;
  final List<Milestone> milestones;

  /// Whether milestones (and [values]) use real values.
  final bool real;

  /// Savings per month in the first month (history: the trailing mean;
  /// plan: the first full month of the plan).
  final int monthlySavingsMinor;
  final SavingsSource source;

  List<int> get values => [for (final p in points) p.value(real: real)];

  /// Points at the end of every year (plus today).
  List<ProjectionPoint> get yearly => [
    for (var i = 0; i < points.length; i += 12) points[i],
  ];

  ProjectionPoint get last => points.last;
}

/// Mean monthly savings of the trailing complete months.
int historicMonthlySavings(SpendingHistory history) =>
    meanOf(history.monthlyNet);

/// Projects net worth for [model] (net-worth scope, horizon at least
/// `assumptions.months`). For the history source with a scenario, pass the
/// baseline's flows as [baselineFlows]: the scenario's difference to the
/// baseline is then added to the historic savings.
NetWorthProjection projectNetWorth(
  CashflowModel model,
  ProjectionAssumptions assumptions, {
  List<GoalInput> goals = const [],
  int historyMonthlySavings = 0,
  MonthlyFlows? flows,
  MonthlyFlows? baselineFlows,
}) {
  final months = assumptions.months;
  final f = flows ?? aggregateMonthly(model, months);
  final accounts = <ForecastAccount>[
    ...model.accounts,
    for (final g in goals)
      if (g.accountId == null)
        ForecastAccount(
          id: g.bucketId,
          name: g.name,
          type: AccountType.otherAsset,
          balanceMinor: g.savedMinor,
        ),
  ];
  if (accounts.isEmpty) {
    accounts.add(
      const ForecastAccount(
        id: '_savings',
        name: '',
        type: AccountType.checking,
        balanceMinor: 0,
      ),
    );
  }
  final byId = {for (final a in accounts) a.id: a};
  final balances = {for (final a in accounts) a.id: a.balanceMinor};
  final rates = <String, Decimal>{
    for (final a in accounts)
      a.id: (Decimal.fromInt(assumptions.rateOf(a)) / Decimal.fromInt(120000))
          .toDecimal(scaleOnInfinitePrecision: 16),
  };
  final primary = _primaryAccount(accounts, model.primaryAccountId);
  final inflationStep =
      Decimal.one +
      (Decimal.fromInt(assumptions.inflationBp) / Decimal.fromInt(120000))
          .toDecimal(scaleOnInfinitePrecision: 16);
  var index = Decimal.one;

  void book(String id, int amount) {
    if (amount == 0) return;
    final b = balances[id];
    if (b != null) balances[id] = b + amount;
  }

  int liabilitiesNow() => [
    for (final a in accounts)
      if (a.type.isLiability) balances[a.id]!,
  ].fold(0, (x, y) => x + y);

  ProjectionPoint point(DateTime date) {
    final nominal = balances.values.fold(0, (a, b) => a + b);
    final liabilities = liabilitiesNow();
    return ProjectionPoint(
      date: date,
      nominalMinor: nominal,
      realMinor: _divideRound(nominal, index),
      assetsMinor: nominal - liabilities,
      liabilitiesMinor: liabilities,
    );
  }

  final points = <ProjectionPoint>[point(model.today)];
  final firstSavings = assumptions.source == SavingsSource.history
      ? historyMonthlySavings
      : (f.steps > 1 ? f.indexedTotal(1) : f.indexedTotal(0));
  final tracker = _MilestoneTracker(
    accounts: accounts,
    goals: goals,
    balances: balances,
    start: points.first,
    real: assumptions.realValues,
  );

  for (var m = 0; m < months; m++) {
    index = (index * inflationStep).round(scale: 14);
    // 1. Returns and interest on the balance at the start of the month.
    for (final a in accounts) {
      final r = rates[a.id]!;
      if (r == Decimal.zero) continue;
      final b = balances[a.id]!;
      if (a.type.isLiability ? b < 0 : b > 0) {
        balances[a.id] = b + Money(b).times(r).minor;
      }
    }
    // 2. Income and spending.
    final step = m < f.steps ? m : -1;
    if (assumptions.source == SavingsSource.plan) {
      if (step >= 0) {
        for (final e in f.indexed[step].entries) {
          book(e.key, Money(e.value).times(index).minor);
        }
        for (final e in f.fixed[step].entries) {
          book(e.key, e.value);
        }
      }
    } else {
      var amount = Money(historyMonthlySavings).times(index).minor;
      if (step >= 0 && baselineFlows != null && step < baselineFlows.steps) {
        final dIndexed =
            f.indexedTotal(step) - baselineFlows.indexedTotal(step);
        final dFixed = f.fixedTotal(step) - baselineFlows.fixedTotal(step);
        amount += Money(dIndexed).times(index).minor + dFixed;
      }
      book(primary, amount);
    }
    // 3. Transfers (savings plans, repayments, goal contributions).
    if (step >= 0) {
      for (final t in f.transfers[step]) {
        var amount = t.amountMinor;
        final to = byId[t.to];
        if (to != null && to.type.isLiability) {
          final room = -balances[t.to]!;
          amount = room <= 0 ? 0 : (amount < room ? amount : room);
        }
        if (amount == 0) continue;
        book(t.from, -amount);
        book(t.to, amount);
      }
    }
    final date = step >= 0
        ? f.stepEnds[step]
        : addMonthsClamped(model.today, m + 1);
    final p = point(date);
    points.add(p);
    tracker.check(p);
  }

  return NetWorthProjection(
    points: points,
    milestones: tracker.milestones,
    real: assumptions.realValues,
    monthlySavingsMinor: firstSavings,
    source: assumptions.source,
  );
}

String _primaryAccount(List<ForecastAccount> accounts, String? preferred) {
  if (preferred != null && accounts.any((a) => a.id == preferred)) {
    return preferred;
  }
  for (final type in const [
    AccountType.checking,
    AccountType.cash,
    AccountType.savings,
  ]) {
    for (final a in accounts) {
      if (a.type == type) return a.id;
    }
  }
  return accounts.first.id;
}

/// [minor] / [index], rounded half away from zero.
int _divideRound(int minor, Decimal index) {
  if (index == Decimal.one) return minor;
  final q = (Decimal.fromInt(minor) / index).toDecimal(
    scaleOnInfinitePrecision: 6,
  );
  final r = q.abs().round().toBigInt().toInt();
  return q < Decimal.zero ? -r : r;
}

class _MilestoneTracker {
  _MilestoneTracker({
    required this.accounts,
    required this.goals,
    required this.balances,
    required ProjectionPoint start,
    required this.real,
  }) {
    final v0 = start.value(real: real);
    pendingLevels = [
      for (final l in netWorthMilestones)
        if (l > v0) l,
    ];
    debts = {
      for (final a in accounts)
        if (a.type.isLiability && a.balanceMinor < 0) a.id,
    };
    debtCount = debts.length;
    pendingGoals = [
      for (final g in goals)
        if (balances.containsKey(g.bucketId) &&
            balances[g.bucketId]! < g.targetMinor)
          g,
    ];
  }

  final List<ForecastAccount> accounts;
  final List<GoalInput> goals;
  final Map<String, int> balances;
  final bool real;
  final milestones = <Milestone>[];
  late List<int> pendingLevels;
  late Set<String> debts;
  late int debtCount;
  late List<GoalInput> pendingGoals;

  void check(ProjectionPoint p) {
    final v = p.value(real: real);
    while (pendingLevels.isNotEmpty && v >= pendingLevels.first) {
      milestones.add(
        Milestone(
          kind: MilestoneKind.netWorth,
          date: p.date,
          amountMinor: pendingLevels.removeAt(0),
        ),
      );
    }
    if (debts.isNotEmpty) {
      final paid = [
        for (final id in debts)
          if (balances[id]! >= 0) id,
      ];
      for (final id in paid) {
        debts.remove(id);
        if (debtCount > 1) {
          milestones.add(
            Milestone(
              kind: MilestoneKind.liabilityPaidOff,
              date: p.date,
              refId: id,
              label: accounts.firstWhere((a) => a.id == id).name,
            ),
          );
        }
      }
      if (debts.isEmpty) {
        milestones.add(Milestone(kind: MilestoneKind.debtFree, date: p.date));
      }
    }
    pendingGoals.removeWhere((g) {
      if (balances[g.bucketId]! < g.targetMinor) return false;
      milestones.add(
        Milestone(
          kind: MilestoneKind.goalReached,
          date: p.date,
          amountMinor: g.targetMinor,
          refId: g.id,
          label: g.name,
        ),
      );
      return true;
    });
  }
}
