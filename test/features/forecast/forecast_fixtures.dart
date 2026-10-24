import 'package:personal_finance/core/calendar/holidays.dart';
import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/forecast/domain/forecast_models.dart';

/// Friday, 23 October 2026.
final today = DateTime(2026, 10, 23);

DateTime d(int y, int m, int day) => DateTime(y, m, day);

ForecastAccount account(
  String id, {
  int balance = 0,
  AccountType type = AccountType.checking,
  int? threshold,
  int? returnBp,
  int? interestBp,
  bool inForecast = true,
  bool inNetWorth = true,
  int sortOrder = 0,
}) => ForecastAccount(
  id: id,
  name: id,
  type: type,
  balanceMinor: balance,
  thresholdMinor: threshold,
  expectedReturnBp: returnBp,
  interestRateBp: interestBp,
  inForecast: inForecast,
  inNetWorth: inNetWorth,
  sortOrder: sortOrder,
);

RecurringItem rule(
  String id, {
  required String rrule,
  required int amount,
  String accountId = 'checking',
  DateTime? start,
  DateTime? end,
  String? transferTo,
  String? categoryId,
  WeekendShift shift = WeekendShift.none,
  Map<DateTime, int> changes = const {},
  DateTime? lastPosted,
}) => RecurringItem(
  id: id,
  name: id,
  rrule: rrule,
  startDate: start ?? d(2026, 1, 1),
  endDate: end,
  accountId: accountId,
  amountMinor: amount,
  transferAccountId: transferTo,
  type: transferTo != null
      ? TxnType.transfer
      : (amount >= 0 ? TxnType.income : TxnType.expense),
  shift: shift,
  amountChanges: changes,
  categories: transferTo != null
      ? const []
      : [CategoryShare(categoryId, amount)],
  lastPostedDate: lastPosted,
);

final germany = HolidayCalendar(country: 'DE');

/// Checking (1,000.00, threshold 1,500.00) and savings (2,000.00) with
/// salary on the 28th (previous business day), rent on the 1st (raised from
/// January) and a savings transfer on the 2nd.
ForecastInput baseInput({
  List<RecurringItem>? recurring,
  List<PlannedEvent> scheduled = const [],
  SpendingHistory history = const SpendingHistory(),
  List<GoalInput> goals = const [],
  VariableSpendingMethod method = VariableSpendingMethod.mean3,
  List<BudgetRow> budgets = const [],
  Map<String, List<DateTime>> posted = const {},
  int? globalThreshold,
}) => ForecastInput(
  today: today,
  accounts: [
    account('checking', balance: 100000, threshold: 150000),
    account(
      'savings',
      balance: 200000,
      type: AccountType.savings,
      sortOrder: 1,
    ),
  ],
  recurring:
      recurring ??
      [
        rule(
          'salary',
          rrule: 'FREQ=MONTHLY;BYMONTHDAY=28',
          amount: 300000,
          categoryId: 'cat-salary',
          shift: WeekendShift.previous,
        ),
        rule(
          'rent',
          rrule: 'FREQ=MONTHLY;BYMONTHDAY=1',
          amount: -120000,
          categoryId: 'cat-rent',
          changes: {d(2027, 1, 1): -130000},
        ),
        rule(
          'save',
          rrule: 'FREQ=MONTHLY;BYMONTHDAY=2',
          amount: -50000,
          transferTo: 'savings',
        ),
      ],
  scheduled: scheduled,
  history: history,
  goals: goals,
  method: method,
  budgets: budgets,
  postedOccurrences: posted,
  primaryAccountId: 'checking',
  calendar: germany,
  globalThresholdMinor: globalThreshold,
);
