import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/platform/notifications.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/budgets/data/budgets_repository.dart';
import 'package:personal_finance/features/budgets/presentation/budget_detail_screen.dart';
import 'package:personal_finance/features/budgets/presentation/budgets_tab.dart';
import 'package:personal_finance/features/plan/plan_providers.dart';
import 'package:personal_finance/features/recurring/data/recurring_repository.dart';

import '../../helpers/test_app.dart';
import '../plan/plan_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = newTestDb());

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    final f = PlanFixture(db);
    final repo = BudgetsRepository(db, f.writer);
    final checking = await f.account('Checking');
    final groceries = await f.category('Groceries');
    final shopping = await f.category('Shopping');
    final eating = await f.category('Eating out');
    await repo.setAmounts(DateTime(2026, 10), {
      groceries: 40000,
      shopping: 16000,
      eating: 15000,
    });
    await f.expense(checking, groceries, 31240, DateTime(2026, 10, 5));
    await f.expense(checking, shopping, 18490, DateTime(2026, 10, 6));
    await f.expense(checking, eating, 13860, DateTime(2026, 10, 7));
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  Widget app() => testApp(
    const Scaffold(body: BudgetsTab()),
    db: db,
    overrides: [
      planTodayProvider.overrideWithValue(DateTime(2026, 10, 23)),
      notificationServiceProvider.overrideWithValue(
        const NoopNotificationService(),
      ),
    ],
  );

  testWidgets('budgets tab shows progress, states and period navigation', (
    tester,
  ) async {
    await seed(tester);
    await tester.pumpWidget(app());
    await settle(tester);

    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('€24.90 over budget'), findsOneWidget);
    expect(find.text('92% used · €11.40 left'), findsOneWidget);
    expect(find.text('€87.60 left'), findsOneWidget);
    expect(find.text('€710.00'), findsOneWidget); // budgeted
    expect(find.text('€635.90'), findsOneWidget); // spent
    expect(find.textContaining('Today, day 23 of'), findsOneWidget);
    // Over-budget rows come first.
    final shoppingY = tester.getTopLeft(find.text('Shopping')).dy;
    final groceriesY = tester.getTopLeft(find.text('Groceries')).dy;
    expect(shoppingY, lessThan(groceriesY));

    await tester.tap(find.byTooltip('Next period'));
    await settle(tester);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('No budgets for this period yet.'), findsOneWidget);

    await tester.tap(find.text('Copy previous period'));
    await settle(tester);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('€400.00 left'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await settle(tester);
    expect(find.text('October 2026'), findsOneWidget);

    await dispose(tester);
  });

  testWidgets('planned entries show as outstanding, not as spent', (
    tester,
  ) async {
    await seed(tester);
    await tester.runAsync(() async {
      final f = PlanFixture(db);
      final acc = (await db.select(db.accounts).get()).first.id;
      final cats = {
        for (final c in await db.select(db.categories).get()) c.name: c.id,
      };
      await f.expense(
        acc,
        cats['Groceries'],
        5000,
        DateTime(2026, 10, 25),
        status: TxnStatus.planned,
      );
      await f.expense(
        acc,
        cats['Eating out'],
        2000,
        DateTime(2026, 10, 26),
        status: TxnStatus.planned,
      );
    });
    await tester.pumpWidget(app());
    await settle(tester);

    expect(find.text('€87.60 left'), findsOneWidget); // spent unchanged
    expect(find.text('€50.00 planned'), findsOneWidget);
    expect(find.text('Planned: €8.60 over'), findsOneWidget);
    expect(find.text('€635.90'), findsOneWidget); // spent total unchanged
    expect(find.text('Planned'), findsOneWidget);
    expect(find.text('€70.00'), findsOneWidget);
    expect(find.text('After planned: €4.10 left'), findsOneWidget);

    await dispose(tester);
  });

  testWidgets('detail lists outstanding items and confirms the next one', (
    tester,
  ) async {
    await seed(tester);
    late String groceries;
    await tester.runAsync(() async {
      final acc = (await db.select(db.accounts).get()).first.id;
      groceries = (await db.select(db.categories).get())
          .firstWhere((c) => c.name == 'Groceries')
          .id;
      await RecurringRepository(
        db,
        PlanFixture(db).writer,
        PlanFixture(db).ledger,
      ).create(
        RecurringRuleDraft(
          name: 'Veg box',
          rrule: 'FREQ=WEEKLY;BYDAY=TU',
          startDate: DateTime(2026, 10, 27),
          template: TxnDraft(
            accountId: acc,
            amountMinor: -2500,
            date: DateTime(2026, 10, 27),
            categoryId: groceries,
          ),
        ),
      );
    });
    final period = DateRange(DateTime(2026, 10), DateTime(2026, 10, 30));
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: BudgetDetailView(categoryId: groceries, period: period),
        ),
        db: db,
        overrides: [
          planTodayProvider.overrideWithValue(DateTime(2026, 10, 23)),
          notificationServiceProvider.overrideWithValue(
            const NoopNotificationService(),
          ),
        ],
      ),
    );
    await settle(tester);

    expect(find.text('Outstanding'), findsOneWidget);
    expect(find.text('Veg box'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('€25.00 planned'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await settle(tester);
    expect(find.text('Outstanding'), findsNothing);
    expect(find.text('€337.40'), findsWidgets); // spent + confirmed

    await dispose(tester);
  });

  testWidgets('envelope mode shows money left to assign', (tester) async {
    await seed(tester);
    await tester.runAsync(() async {
      final f = PlanFixture(db);
      final salary = await f.category('Salary', kind: CategoryKind.income);
      final acc = (await db.select(db.accounts).get()).first.id;
      await f.income(acc, salary, 100000, DateTime(2026, 10));
      await f.writer.insert(
        db.settings,
        SettingsCompanion(
          key: Value(BudgetSettings.mode.key),
          value: const Value('"envelope"'),
        ),
        id: 'global|${BudgetSettings.mode.key}',
      );
    });
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.text('€290.00 left to assign'), findsOneWidget);

    await dispose(tester);
  });
}
