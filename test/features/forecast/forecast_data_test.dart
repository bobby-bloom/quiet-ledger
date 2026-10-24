import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/forecast/data/forecast_data_source.dart';
import 'package:personal_finance/features/forecast/domain/forecast_models.dart';
import 'package:personal_finance/features/forecast/domain/forecast_pipeline.dart';

import '../../helpers/test_app.dart';

void main() {
  late AppDatabase db;
  late SyncWriter writer;
  late LedgerRepository ledger;
  late String checking;
  late String card;
  late String savings;
  late String groceries;
  late String household;
  late String salary;
  late String rent;
  late String ruleRent;
  final today = DateTime(2026, 10, 23);

  SettingsSnapshot settings(Map<String, Object?> values) => SettingsSnapshot({
    for (final e in values.entries) 'global|${e.key}': e.value,
    'account:$savings|forecast.lowBalanceThreshold': 20000,
  });

  setUp(() async {
    db = newTestDb();
    writer = SyncWriter(db, testClock(), 'dev-1');
    ledger = LedgerRepository(db, writer);
    Future<String> account(
      String name,
      AccountType type,
      int opening, {
      bool forecast = true,
      int? threshold,
      int sort = 0,
    }) => writer.insert(
      db.accounts,
      AccountsCompanion(
        name: Value(name),
        type: Value(type),
        openingBalanceMinor: Value(opening),
        openingDate: Value(DateTime(2026)),
        includeInForecast: Value(forecast),
        lowBalanceThresholdMinor: Value(threshold),
        sortOrder: Value(sort),
      ),
    );
    Future<String> category(String name, CategoryKind kind) => writer.insert(
      db.categories,
      CategoriesCompanion(name: Value(name), kind: Value(kind)),
    );
    checking = await account(
      'Checking',
      AccountType.checking,
      100000,
      threshold: 50000,
    );
    card = await account(
      'Card',
      AccountType.creditCard,
      0,
      forecast: false,
      sort: 1,
    );
    savings = await account('Savings', AccountType.savings, 500000, sort: 2);
    groceries = await category('Groceries', CategoryKind.expense);
    household = await category('Household', CategoryKind.expense);
    salary = await category('Salary', CategoryKind.income);
    rent = await category('Rent', CategoryKind.expense);

    ruleRent = await writer.insert(
      db.recurringRules,
      RecurringRulesCompanion(
        name: const Value('Rent'),
        rrule: const Value('FREQ=MONTHLY;BYMONTHDAY=1'),
        startDate: Value(DateTime(2026)),
        template: Value(
          jsonEncode(
            TxnDraft(
              accountId: checking,
              amountMinor: -90000,
              date: DateTime(2026),
              categoryId: rent,
            ).toJson(),
          ),
        ),
        postingMode: const Value(PostingMode.autoPost),
        weekendShift: const Value('previous'),
      ),
    );
    // Stored as a magnitude: takes the template's sign.
    await writer.insert(
      db.recurringAmountChanges,
      RecurringAmountChangesCompanion(
        ruleId: Value(ruleRent),
        fromDate: Value(DateTime(2027)),
        amountMinor: const Value(95000),
      ),
    );
    await writer.insert(
      db.recurringRules,
      RecurringRulesCompanion(
        name: const Value('Inactive'),
        rrule: const Value('FREQ=WEEKLY'),
        startDate: Value(DateTime(2026)),
        template: Value(
          jsonEncode(
            TxnDraft(
              accountId: checking,
              amountMinor: -1,
              date: DateTime(2026),
            ).toJson(),
          ),
        ),
        postingMode: const Value(PostingMode.autoPost),
        active: const Value(false),
      ),
    );

    TxnDraft spend(
      DateTime date,
      int amount, {
      String? account,
      String? category,
      TxnStatus status = TxnStatus.cleared,
    }) => TxnDraft(
      accountId: account ?? checking,
      amountMinor: amount,
      date: date,
      categoryId: category ?? groceries,
      status: status,
    );
    await ledger.createAll([
      // Groceries history: Jul 100, Aug 200 (+ split 30), Sep 300.
      spend(DateTime(2026, 7, 5), -10000),
      spend(DateTime(2026, 8, 5), -20000),
      TxnDraft(
        accountId: checking,
        amountMinor: -5000,
        date: DateTime(2026, 8, 6),
        splits: [
          SplitDraft(amountMinor: -3000, categoryId: groceries),
          SplitDraft(amountMinor: -2000, categoryId: household),
        ],
      ),
      spend(DateTime(2026, 9, 5), -30000),
      // Card spending: groceries also, but less often than checking.
      spend(DateTime(2026, 9, 6), -7000, account: card),
      // Household mostly from the card (not in the forecast).
      spend(DateTime(2026, 9, 7), -1000, account: card, category: household),
      spend(DateTime(2026, 9, 8), -1000, account: card, category: household),
      // Excluded from history: posted by a recurring rule.
      spend(
        DateTime(2026, 9),
        -90000,
        category: rent,
      ).copyWith(recurringRuleId: ruleRent),
      spend(
        DateTime(2026, 10),
        -90000,
        category: rent,
      ).copyWith(recurringRuleId: ruleRent),
      // Income.
      spend(DateTime(2026, 9, 28), 250000, category: salary),
      // A transfer (excluded from history and net).
      TxnDraft(
        accountId: checking,
        amountMinor: -40000,
        date: DateTime(2026, 9, 29),
        type: TxnType.transfer,
        transferAccountId: savings,
      ),
      // This month so far.
      spend(DateTime(2026, 10, 10), -4500),
      // Today: in the start balance.
      spend(today, -500),
      // Future entries.
      spend(DateTime(2026, 11, 3), -1500, status: TxnStatus.pending),
      spend(DateTime(2026, 11, 4), -2500, status: TxnStatus.planned),
      spend(DateTime(2026, 11, 5), -3500),
      // Planned rent of 1 Nov created by the rule.
      spend(
        DateTime(2026, 11),
        -90000,
        category: rent,
        status: TxnStatus.planned,
      ).copyWith(recurringRuleId: ruleRent),
    ]);

    await writer.insert(
      db.budgets,
      BudgetsCompanion(
        categoryId: Value(groceries),
        periodStart: Value(DateTime(2026, 10)),
        amountMinor: const Value(25000),
      ),
    );
    await writer.insert(
      db.goals,
      GoalsCompanion(
        name: const Value('Holiday'),
        targetMinor: const Value(800000),
        accountId: Value(savings),
        contributionMinor: const Value(20000),
      ),
    );
    await writer.insert(
      db.goals,
      const GoalsCompanion(
        name: Value('Archived'),
        targetMinor: Value(1),
        archived: Value(true),
      ),
    );
  });

  tearDown(() => db.close());

  Future<ForecastInput> gather({Map<String, Object?> values = const {}}) =>
      ForecastDataSource(db).gather(today: today, settings: settings(values));

  test('accounts, start balances and thresholds', () async {
    final input = await gather();
    final byId = {for (final a in input.accounts) a.id: a};
    expect(byId.keys, [checking, card, savings]);
    // 1,000 + 2,500 salary − 600 groceries(+split 50) − 1,800 rent − 400
    // transfer − 45 − 5 today.
    expect(
      byId[checking]!.balanceMinor,
      100000 -
          10000 -
          20000 -
          5000 -
          30000 -
          90000 -
          90000 +
          250000 -
          40000 -
          4500 -
          500,
    );
    expect(byId[savings]!.balanceMinor, 540000);
    expect(byId[card]!.inForecast, isFalse);
    expect(byId[checking]!.thresholdMinor, 50000);
    expect(byId[savings]!.thresholdMinor, 20000);
    expect(byId[card]!.thresholdMinor, 0);
    expect(input.primaryAccountId, checking);
  });

  test('future entries follow the include pending/planned settings', () async {
    var input = await gather();
    expect(input.scheduled.map((e) => e.amountMinor), [
      -90000,
      -1500,
      -2500,
      -3500,
    ]);
    expect(input.postedOccurrences[ruleRent], contains(DateTime(2026, 11)));

    input = await gather(
      values: {
        'forecast.includePending': false,
        'forecast.includePlanned': false,
      },
    );
    expect(input.scheduled.map((e) => e.amountMinor), [-3500]);
    // The planned rent is excluded, so the rule occurrence is forecast
    // instead.
    expect(
      input.postedOccurrences[ruleRent] ?? const <DateTime>[],
      isNot(contains(DateTime(2026, 11))),
    );
  });

  test('history excludes transfers, rule entries and planned ones', () async {
    final input = await gather();
    final h = input.history;
    final groceriesByMonth = {
      for (final m in h.months)
        if (m.categoryId == groceries) m.month: m.spentMinor,
    };
    // September's card purchase is outside the forecast accounts.
    expect(groceriesByMonth, {7: 10000, 8: 23000, 9: 30000});
    expect(
      h.months.where((m) => m.categoryId == household).single.spentMinor,
      2000,
      reason: 'card entries are outside the forecast accounts',
    );
    expect(h.months.any((m) => m.categoryId == rent), isFalse);
    expect(h.firstTxnDate, DateTime(2026, 7, 5));
    expect(h.categoryAccount[groceries], checking);
    expect(h.spentThisMonth, {groceries: 5000});
    expect(h.spentThisPeriod, {groceries: 5000});
    expect(h.expenseCategoryIds, {groceries, household, rent});
    expect(h.incomeCategoryIds, {salary});
    // Jul −100, Aug −250, Sep +2,500 − 300 − 70 − 20 (card) − 900 rent.
    expect(h.monthlyNet, [
      -10000,
      -25000,
      250000 - 30000 - 7000 - 2000 - 90000,
    ]);
  });

  test('recurring rules with amount changes, budgets and goals', () async {
    final input = await gather();
    final r = input.recurring.single;
    expect(r.id, ruleRent);
    expect(r.amountMinor, -90000);
    expect(r.amountChanges, {DateTime(2027): -95000});
    expect(r.shift, WeekendShift.previous);
    expect(r.categories.single.categoryId, rent);
    expect(input.budgets.single.amountMinor, 25000);
    expect(input.goals.single.name, 'Holiday');
    expect(input.method, VariableSpendingMethod.median6);
  });

  test('end to end: gathered input runs through the engine', () async {
    final input = await gather(values: {'forecast.variableMethod': 'mean3'});
    final r = runCashflow(CashflowRequest(input: input, horizonMonths: 3));
    final start = input.accounts.first.balanceMinor;
    expect(r.series(checking).first, start);
    // The planned rent of 1 Nov is booked once (ledger entry, not the rule).
    final rentEvents = r.events.where(
      (e) => e.amountMinor == -90000 && e.date == DateTime(2026, 11),
    );
    expect(rentEvents, hasLength(1));
    // Rent rises from January. 1 Jan 2027 is a holiday and 31 Dec a bank
    // closing day, so the payment moves to Wednesday 30 Dec; the raise
    // still applies because it follows the scheduled date.
    expect(
      r.events.any((e) => e.refId == ruleRent && e.amountMinor == -95000),
      isTrue,
    );
    expect(
      r.events.firstWhere((e) => e.amountMinor == -95000).date,
      DateTime(2026, 12, 30),
    );
    // Goal contribution moves money into savings.
    expect(r.series(savings).last, greaterThan(540000));
  });
}
