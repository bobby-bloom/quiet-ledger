import 'package:meta/meta.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/calendar/holidays.dart';
import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/core/settings/setting_enums.dart';
import 'package:personal_finance/features/forecast/domain/forecast_dates.dart';

// Inputs of the forecast engine. Everything here is plain data (no
// closures, no DB handles) so it can be sent to a background isolate.

/// An account as seen by the forecast and the projection.
@immutable
class ForecastAccount {
  const ForecastAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.balanceMinor,
    this.thresholdMinor,
    this.expectedReturnBp,
    this.interestRateBp,
    this.inForecast = true,
    this.inNetWorth = true,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final AccountType type;

  /// Balance at the end of "today" (cleared + pending, planned entries up to
  /// today when the forecast includes planned ones).
  final int balanceMinor;

  /// Resolved low-balance threshold: the account's own value, else the
  /// account-scoped setting, else the global setting. null/0 = none.
  final int? thresholdMinor;
  final int? expectedReturnBp;
  final int? interestRateBp;
  final bool inForecast;
  final bool inNetWorth;
  final int sortOrder;

  ForecastAccount copyWith({int? balanceMinor}) => ForecastAccount(
    id: id,
    name: name,
    type: type,
    balanceMinor: balanceMinor ?? this.balanceMinor,
    thresholdMinor: thresholdMinor,
    expectedReturnBp: expectedReturnBp,
    interestRateBp: interestRateBp,
    inForecast: inForecast,
    inNetWorth: inNetWorth,
    sortOrder: sortOrder,
  );
}

/// The part of a recurring template booked to one category (base amount,
/// same sign as the template).
@immutable
class CategoryShare {
  const CategoryShare(this.categoryId, this.amountMinor);

  final String? categoryId;
  final int amountMinor;
}

/// A scenario change applied to each occurrence of a recurring item from
/// [from] (by scheduled date). With [categoryId] only that category's share
/// changes. [percentBp] scales the amount; [deltaMinor] increases its
/// magnitude (more spending for outflows, more income for inflows).
@immutable
class AmountModifier {
  const AmountModifier({
    required this.from,
    this.categoryId,
    this.percentBp,
    this.deltaMinor,
  });

  final DateTime from;
  final String? categoryId;
  final int? percentBp;
  final int? deltaMinor;
}

/// A recurring rule ready for expansion.
@immutable
class RecurringItem {
  const RecurringItem({
    required this.id,
    required this.name,
    required this.rrule,
    required this.startDate,
    required this.accountId,
    required this.amountMinor,
    this.endDate,
    this.count,
    this.shift = WeekendShift.none,
    this.type = TxnType.expense,
    this.transferAccountId,
    this.amountChanges = const {},
    this.categories = const [],
    this.lastPostedDate,
    this.modifiers = const [],
  });

  final String id;
  final String name;
  final String rrule;
  final DateTime startDate;
  final DateTime? endDate;
  final int? count;
  final WeekendShift shift;
  final TxnType type;
  final String accountId;

  /// Receives `-amount` for transfers.
  final String? transferAccountId;

  /// Signed base amount for [accountId].
  final int amountMinor;

  /// fromDate -> amountMinor (rent increase etc.).
  final Map<DateTime, int> amountChanges;
  final List<CategoryShare> categories;
  final DateTime? lastPostedDate;
  final List<AmountModifier> modifiers;

  bool get isTransfer =>
      type == TxnType.transfer &&
      transferAccountId != null &&
      transferAccountId!.isNotEmpty;

  bool booksTo(String categoryId) =>
      !isTransfer && categories.any((c) => c.categoryId == categoryId);

  RecurringItem copyWith({
    DateTime? endDate,
    List<AmountModifier>? modifiers,
  }) => RecurringItem(
    id: id,
    name: name,
    rrule: rrule,
    startDate: startDate,
    endDate: endDate ?? this.endDate,
    count: count,
    shift: shift,
    type: type,
    accountId: accountId,
    transferAccountId: transferAccountId,
    amountMinor: amountMinor,
    amountChanges: amountChanges,
    categories: categories,
    lastPostedDate: lastPostedDate,
    modifiers: modifiers ?? this.modifiers,
  );
}

enum ForecastEventKind {
  /// Expanded recurring rule occurrence.
  recurring,

  /// Future-dated cleared/pending/planned ledger entry.
  scheduled,

  /// Monthly goal contribution.
  goal,

  /// Scenario one-off event.
  oneOff,

  /// "Can I afford" probe (never saved).
  whatIf,
}

/// A discrete money movement on one day. For transfers [counterAccountId]
/// receives `-amountMinor`.
@immutable
class PlannedEvent {
  const PlannedEvent({
    required this.date,
    required this.accountId,
    required this.amountMinor,
    required this.label,
    required this.kind,
    this.counterAccountId,
    this.categoryId,
    this.refId,
  });

  final DateTime date;
  final String accountId;
  final int amountMinor;
  final String label;
  final ForecastEventKind kind;
  final String? counterAccountId;
  final String? categoryId;

  /// Source id (transaction, rule, goal...).
  final String? refId;

  bool get isTransfer => counterAccountId != null;
}

/// Money spread evenly over the days of `[start, end)` (e.g. expected
/// grocery spending for one month). Days outside the forecast horizon are
/// computed but not booked, so a window clipped by the horizon books only
/// its share.
@immutable
class SpreadItem {
  const SpreadItem({
    required this.accountId,
    required this.start,
    required this.end,
    required this.totalMinor,
    this.categoryId,
  });

  final String accountId;
  final String? categoryId;
  final DateTime start;

  /// Exclusive.
  final DateTime end;

  /// Signed (negative = spending).
  final int totalMinor;

  int get days => daysBetween(start, end);
}

/// Spending of one expense category in one calendar month (positive =
/// money spent; refunds reduce it).
@immutable
class CategoryMonthTotal {
  const CategoryMonthTotal({
    required this.categoryId,
    required this.year,
    required this.month,
    required this.spentMinor,
  });

  final String categoryId;
  final int year;
  final int month;
  final int spentMinor;
}

/// Historic aggregates gathered from the ledger (transfers and transactions
/// generated by recurring rules are excluded).
@immutable
class SpendingHistory {
  const SpendingHistory({
    this.months = const [],
    this.firstTxnDate,
    this.categoryAccount = const {},
    this.spentThisMonth = const {},
    this.spentThisPeriod = const {},
    this.expenseCategoryIds = const {},
    this.incomeCategoryIds = const {},
    this.categoryNames = const {},
    this.monthlyNet = const [],
  });

  final List<CategoryMonthTotal> months;

  /// Date of the earliest ledger entry; months before it do not count as
  /// zero-spending months.
  final DateTime? firstTxnDate;

  /// Category -> account where it is usually paid (most entries).
  final Map<String, String> categoryAccount;

  /// Spending per category from the 1st of the current month to today.
  final Map<String, int> spentThisMonth;

  /// Spending per category from the start of the current budget period.
  final Map<String, int> spentThisPeriod;
  final Set<String> expenseCategoryIds;
  final Set<String> incomeCategoryIds;
  final Map<String, String> categoryNames;

  /// Net (income − expenses, no transfers) of each of the trailing complete
  /// months on net-worth accounts, oldest first.
  final List<int> monthlyNet;
}

@immutable
class BudgetRow {
  const BudgetRow({
    required this.categoryId,
    required this.periodStart,
    required this.amountMinor,
  });

  final String categoryId;
  final DateTime periodStart;
  final int amountMinor;
}

@immutable
class GoalInput {
  const GoalInput({
    required this.id,
    required this.name,
    required this.targetMinor,
    this.savedMinor = 0,
    this.accountId,
    this.contributionMinor,
    this.targetDate,
  });

  final String id;
  final String name;
  final int targetMinor;

  /// Saved amount for goals without a linked account.
  final int savedMinor;
  final String? accountId;
  final int? contributionMinor;
  final DateTime? targetDate;

  /// Pseudo account that holds an unlinked goal's money in the projection.
  String get bucketId => accountId ?? 'goal:$id';
}

/// Everything the forecast needs, gathered by the data layer.
@immutable
class ForecastInput {
  const ForecastInput({
    required this.today,
    required this.accounts,
    this.recurring = const [],
    this.scheduled = const [],
    this.postedOccurrences = const {},
    this.history = const SpendingHistory(),
    this.budgets = const [],
    this.goals = const [],
    this.primaryAccountId,
    this.method = VariableSpendingMethod.median6,
    this.periodConfig = const BudgetPeriodConfig(),
    this.calendar,
    this.globalThresholdMinor,
    this.bigEventMinMinor = 10000,
  });

  final DateTime today;
  final List<ForecastAccount> accounts;
  final List<RecurringItem> recurring;

  /// Future ledger entries (date after today) already filtered by the
  /// include pending/planned settings. Each transfer leg is its own entry.
  final List<PlannedEvent> scheduled;

  /// Rule id -> dates of ledger entries created by that rule (recent and
  /// future). Occurrences within ±3 days of one are treated as posted.
  final Map<String, List<DateTime>> postedOccurrences;
  final SpendingHistory history;
  final List<BudgetRow> budgets;
  final List<GoalInput> goals;

  /// Default account (Settings › Entry) or the first checking account:
  /// source of goal contributions and fallback for category spending.
  final String? primaryAccountId;
  final VariableSpendingMethod method;
  final BudgetPeriodConfig periodConfig;

  /// Holiday calendar for business-day shifting of recurring rules.
  final HolidayCalendar? calendar;
  final int? globalThresholdMinor;

  /// Discrete events at or above this magnitude are "big events".
  final int bigEventMinMinor;

  ForecastInput copyWith({
    DateTime? today,
    List<ForecastAccount>? accounts,
    List<RecurringItem>? recurring,
    List<PlannedEvent>? scheduled,
    List<GoalInput>? goals,
    List<BudgetRow>? budgets,
    SpendingHistory? history,
    VariableSpendingMethod? method,
  }) => ForecastInput(
    today: today ?? this.today,
    accounts: accounts ?? this.accounts,
    recurring: recurring ?? this.recurring,
    scheduled: scheduled ?? this.scheduled,
    postedOccurrences: postedOccurrences,
    history: history ?? this.history,
    budgets: budgets ?? this.budgets,
    goals: goals ?? this.goals,
    primaryAccountId: primaryAccountId,
    method: method ?? this.method,
    periodConfig: periodConfig,
    calendar: calendar,
    globalThresholdMinor: globalThresholdMinor,
    bigEventMinMinor: bigEventMinMinor,
  );
}

/// The prepared cash-flow model: accounts plus every flow over
/// `[today, end]`. Scenarios transform a model before it is simulated.
@immutable
class CashflowModel {
  const CashflowModel({
    required this.today,
    required this.end,
    required this.accounts,
    required this.recurring,
    required this.events,
    required this.spread,
    this.postedOccurrences = const {},
    this.calendar,
    this.periodConfig = const BudgetPeriodConfig(),
    this.globalThresholdMinor,
    this.bigEventMinMinor = 10000,
    this.categoryAccount = const {},
    this.expenseCategoryIds = const {},
    this.incomeCategoryIds = const {},
    this.primaryAccountId,
  });

  final DateTime today;

  /// Inclusive last day.
  final DateTime end;
  final List<ForecastAccount> accounts;
  final List<RecurringItem> recurring;
  final List<PlannedEvent> events;
  final List<SpreadItem> spread;
  final Map<String, List<DateTime>> postedOccurrences;
  final HolidayCalendar? calendar;
  final BudgetPeriodConfig periodConfig;
  final int? globalThresholdMinor;
  final int bigEventMinMinor;
  final Map<String, String> categoryAccount;
  final Set<String> expenseCategoryIds;
  final Set<String> incomeCategoryIds;
  final String? primaryAccountId;

  int get dayCount => daysBetween(today, end) + 1;

  CashflowModel copyWith({
    List<ForecastAccount>? accounts,
    List<RecurringItem>? recurring,
    List<PlannedEvent>? events,
    List<SpreadItem>? spread,
  }) => CashflowModel(
    today: today,
    end: end,
    accounts: accounts ?? this.accounts,
    recurring: recurring ?? this.recurring,
    events: events ?? this.events,
    spread: spread ?? this.spread,
    postedOccurrences: postedOccurrences,
    calendar: calendar,
    periodConfig: periodConfig,
    globalThresholdMinor: globalThresholdMinor,
    bigEventMinMinor: bigEventMinMinor,
    categoryAccount: categoryAccount,
    expenseCategoryIds: expenseCategoryIds,
    incomeCategoryIds: incomeCategoryIds,
    primaryAccountId: primaryAccountId,
  );
}

// ------------------------------------------------------------- results ---

/// A balance on a date (lowest point, period low).
@immutable
class LowPoint {
  const LowPoint(this.date, this.amountMinor);

  final DateTime date;
  final int amountMinor;

  @override
  bool operator ==(Object other) =>
      other is LowPoint &&
      other.date == date &&
      other.amountMinor == amountMinor;

  @override
  int get hashCode => Object.hash(date, amountMinor);

  @override
  String toString() => 'LowPoint($date, $amountMinor)';
}

enum WarningKind { belowZero, belowThreshold }

/// The balance of an account (or the total when [accountId] is null) drops
/// below zero or below its threshold within the horizon.
@immutable
class BalanceWarning {
  const BalanceWarning({
    required this.accountId,
    required this.kind,
    required this.firstDate,
    required this.lowest,
    required this.daysBelow,
    this.thresholdMinor,
  });

  final String? accountId;

  /// The most severe kind reached.
  final WarningKind kind;

  /// First day below the limit of [kind] (zero or threshold).
  final DateTime firstDate;
  final LowPoint lowest;

  /// Days below the threshold (or below zero when there is none).
  final int daysBelow;
  final int? thresholdMinor;
}

/// Balances within one month or budget period of the horizon.
@immutable
class PeriodSummary {
  const PeriodSummary({
    required this.range,
    required this.clipped,
    required this.endByAccount,
    required this.endTotal,
    required this.lowByAccount,
    required this.lowTotal,
  });

  final DateRange range;

  /// The horizon starts or ends inside this period; [endTotal] is then the
  /// balance on the horizon's last day.
  final bool clipped;
  final Map<String, int> endByAccount;
  final int endTotal;
  final Map<String, LowPoint> lowByAccount;
  final LowPoint lowTotal;

  int endOf(String? accountId) =>
      accountId == null ? endTotal : endByAccount[accountId] ?? 0;

  LowPoint? lowOf(String? accountId) =>
      accountId == null ? lowTotal : lowByAccount[accountId];
}

/// A discrete event in the forecast (for the "upcoming" list).
@immutable
class ForecastEvent {
  const ForecastEvent({
    required this.date,
    required this.accountId,
    required this.amountMinor,
    required this.label,
    required this.kind,
    this.counterAccountId,
    this.refId,
  });

  final DateTime date;
  final String accountId;
  final int amountMinor;
  final String label;
  final ForecastEventKind kind;
  final String? counterAccountId;
  final String? refId;

  bool get isTransfer => counterAccountId != null;
}

/// Output of the daily cash-flow simulation.
@immutable
class CashflowResult {
  const CashflowResult({
    required this.start,
    required this.end,
    required this.accountIds,
    required this.startBalances,
    required this.balances,
    required this.total,
    required this.lowestByAccount,
    required this.lowestTotal,
    required this.thresholds,
    required this.totalThreshold,
    required this.warnings,
    required this.months,
    required this.periods,
    required this.events,
    required this.bigEvents,
  });

  /// Day 0 (today).
  final DateTime start;

  /// Last day (inclusive).
  final DateTime end;
  final List<String> accountIds;
  final Map<String, int> startBalances;

  /// End-of-day balance per account, index 0 = today.
  final Map<String, List<int>> balances;
  final List<int> total;
  final Map<String, LowPoint> lowestByAccount;
  final LowPoint lowestTotal;
  final Map<String, int?> thresholds;
  final int? totalThreshold;
  final List<BalanceWarning> warnings;
  final List<PeriodSummary> months;
  final List<PeriodSummary> periods;
  final List<ForecastEvent> events;
  final List<ForecastEvent> bigEvents;

  int get dayCount => total.length;

  DateTime dateAt(int index) => addDays(start, index);

  /// Daily series of [accountId], or of the total when null.
  List<int> series(String? accountId) =>
      accountId == null ? total : balances[accountId] ?? const [];

  LowPoint? lowest(String? accountId) =>
      accountId == null ? lowestTotal : lowestByAccount[accountId];

  int? threshold(String? accountId) =>
      accountId == null ? totalThreshold : thresholds[accountId];

  BalanceWarning? warning(String? accountId) {
    for (final w in warnings) {
      if (w.accountId == accountId) return w;
    }
    return null;
  }

  /// Balance of [accountId] (or total) on [date]; clamps to the horizon.
  int balanceOn(String? accountId, DateTime date) {
    final s = series(accountId);
    if (s.isEmpty) return 0;
    final i = daysBetween(start, date).clamp(0, s.length - 1);
    return s[i];
  }

  /// Days on which [accountId] (or total) is below [limit].
  int daysBelow(String? accountId, int limit) =>
      series(accountId).where((b) => b < limit).length;
}
