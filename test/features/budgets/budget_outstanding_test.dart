import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/budgets/data/budget_period_provider.dart';
import 'package:personal_finance/features/budgets/data/budget_providers.dart';
import 'package:personal_finance/features/budgets/data/budgets_repository.dart';
import 'package:personal_finance/features/budgets/domain/budget_math.dart';
import 'package:personal_finance/features/budgets/domain/outstanding.dart';
import 'package:personal_finance/features/plan/plan_providers.dart';
import 'package:personal_finance/features/recurring/data/recurring_repository.dart';

import '../../helpers/test_app.dart';
import '../plan/plan_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProviderContainer c;
  late PlanFixture f;
  final today = DateTime(2026, 10, 14);

  setUp(() async {
    db = newTestDb();
    f = PlanFixture(db);
    c = testContainer(
      db,
      overrides: [planTodayProvider.overrideWithValue(today)],
    );
    // Plain calendar months for readable dates.
    await c
        .read(settingsProvider.notifier)
        .set(BudgetSettings.weekendShift, WeekendShift.none);
  });

  tearDown(() async {
    c.dispose();
    await db.close();
  });

  Future<BudgetSummary> board(DateRange period) async {
    final sub = c.listen(budgetBoardProvider(period), (_, _) {});
    addTearDown(sub.close);
    return await c.read(budgetBoardProvider(period).future);
  }

  group('repository', () {
    test('planned items: splits, overdue flag, transfers and other accounts '
        'excluded', () async {
      final repo = c.read(budgetsRepositoryProvider);
      final checking = await f.account('Checking');
      final business = await f.account('Business', includeInBudgets: false);
      final savings = await f.account('Savings');
      final food = await f.category('Food');
      final home = await f.category('Home');
      await f.expense(
        checking,
        food,
        2000,
        DateTime(2026, 10, 3),
        status: TxnStatus.planned,
      );
      await f.ledger.create(
        TxnDraft(
          accountId: checking,
          amountMinor: -10000,
          date: DateTime(2026, 10, 20),
          payee: 'IKEA',
          status: TxnStatus.planned,
          splits: [
            SplitDraft(amountMinor: -3000, categoryId: food),
            SplitDraft(amountMinor: -7000, categoryId: home),
          ],
        ),
      );
      await f.expense(
        business,
        food,
        500,
        DateTime(2026, 10, 20),
        status: TxnStatus.planned,
      );
      await f.ledger.create(
        TxnDraft(
          accountId: checking,
          amountMinor: -5000,
          date: DateTime(2026, 10, 20),
          type: TxnType.transfer,
          transferAccountId: savings,
          status: TxnStatus.planned,
        ),
      );
      await f.expense(checking, food, 999, DateTime(2026, 10, 20)); // cleared
      final oct = DateRange(DateTime(2026, 10), DateTime(2026, 11));
      final items = await repo.watchPlannedItems(oct, today).first;
      items.sort((a, b) => a.amountMinor.compareTo(b.amountMinor));
      expect(items.map((i) => (i.categoryId, i.amountMinor, i.isSplit)), [
        (home, -7000, true),
        (food, -3000, true),
        (food, -2000, false),
      ]);
      expect(items.firstWhere((i) => !i.isSplit).overdue, isTrue);
      expect(items.first.title, 'IKEA');
      expect(items.first.source, OutstandingSource.planned);
    });

    test('rule bookings list rows created for a rule', () async {
      final repo = c.read(budgetsRepositoryProvider);
      final checking = await f.account('Checking');
      await f.ledger.create(
        TxnDraft(
          accountId: checking,
          amountMinor: -100,
          date: DateTime(2026, 10, 5),
          recurringRuleId: 'r1',
          status: TxnStatus.planned,
        ),
      );
      final oct = DateRange(DateTime(2026, 10), DateTime(2026, 11));
      expect(await repo.watchRuleBookings(oct).first, {
        ('r1', DateTime(2026, 10, 5)),
      });
    });
  });

  test('board shows planned and recurring amounts without changing spent '
      'or state', () async {
    final checking = await f.account('Checking');
    final groceries = await f.category('Groceries');
    final rent = await f.category('Rent');
    final period = c.read(currentBudgetPeriodProvider);
    await c.read(budgetsRepositoryProvider).setAmounts(period.start, {
      groceries: 40000,
      rent: 90000,
    });
    await f.expense(checking, groceries, 30000, DateTime(2026, 10, 5));
    await f.expense(
      checking,
      groceries,
      15000,
      DateTime(2026, 10, 20),
      status: TxnStatus.planned,
    );
    final ruleId = await c
        .read(recurringRepositoryProvider)
        .create(
          RecurringRuleDraft(
            name: 'Rent',
            rrule: 'FREQ=MONTHLY;BYMONTHDAY=28',
            startDate: DateTime(2026),
            template: TxnDraft(
              accountId: checking,
              amountMinor: -90000,
              date: DateTime(2026),
              categoryId: rent,
            ),
          ),
        );
    final s = await board(period);
    final g = s.lineFor(groceries)!;
    expect(g.spentMinor, 30000);
    expect(g.plannedMinor, 15000);
    expect(g.state, BudgetState.onTrack); // alerts stay quiet
    expect(g.projectedState, BudgetState.over);
    expect(g.plannedPushesOver, isTrue);
    expect(g.projectedOverMinor, 5000);
    expect(s.lineFor(rent)!.plannedMinor, 90000);
    expect(s.totalPlannedMinor, 105000);
    expect(s.totalRemainingMinor, 100000);
    expect(s.projectedRemainingMinor, -5000);

    // A planned entry booked for the rule's occurrence replaces it.
    await f.ledger.create(
      TxnDraft(
        accountId: checking,
        amountMinor: -90000,
        date: DateTime(2026, 10, 28),
        categoryId: rent,
        recurringRuleId: ruleId,
        status: TxnStatus.planned,
      ),
    );
    final after = await board(period);
    expect(after.lineFor(rent)!.plannedMinor, 90000);
  });

  test('the setting turns outstanding amounts off', () async {
    final checking = await f.account('Checking');
    final groceries = await f.category('Groceries');
    final period = c.read(currentBudgetPeriodProvider);
    await c.read(budgetsRepositoryProvider).setAmounts(period.start, {
      groceries: 40000,
    });
    await f.expense(
      checking,
      groceries,
      15000,
      DateTime(2026, 10, 20),
      status: TxnStatus.planned,
    );
    expect((await board(period)).lineFor(groceries)!.plannedMinor, 15000);
    await c
        .read(settingsProvider.notifier)
        .set(BudgetSettings.showOutstanding, false);
    expect((await board(period)).lineFor(groceries)!.plannedMinor, 0);
  });

  test('expected income is shown but not assignable', () async {
    final checking = await f.account('Checking');
    final salary = await f.category('Salary', kind: CategoryKind.income);
    await c
        .read(settingsProvider.notifier)
        .set(BudgetSettings.mode, BudgetMode.envelope);
    await f.income(checking, salary, 100000, DateTime(2026, 10));
    await f.ledger.create(
      TxnDraft(
        accountId: checking,
        amountMinor: 50000,
        date: DateTime(2026, 10, 25),
        type: TxnType.income,
        categoryId: salary,
        status: TxnStatus.planned,
      ),
    );
    final s = await board(c.read(currentBudgetPeriodProvider));
    expect(s.incomeMinor, 100000);
    expect(s.plannedIncomeMinor, 50000);
    expect(s.toBeBudgetedMinor, 100000);
  });
}
