import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/platform/notifications.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/budgets/data/budgets_repository.dart';
import 'package:personal_finance/features/budgets/domain/budget_rules.dart';
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
    expect(
      find.text('€70.00 planned · After planned: €4.10 left'),
      findsOneWidget,
    );

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

  testWidgets('budgets repeat: Fill menu, this and following, new budgets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seed(tester);
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.text('Fill'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 1)); // menu animation
    await tester.tap(find.text('Repeat these budgets every period'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 1)); // menu closes
    expect(find.text('3 budgets now repeat every period'), findsOneWidget);
    expect(find.byIcon(Icons.repeat), findsNWidgets(3));

    await tester.tap(find.byTooltip('Next period'));
    await settle(tester);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('€400.00 left'), findsOneWidget); // generated

    // Change Groceries from November on.
    await tester.longPress(find.text('Groceries'));
    await settle(tester);
    expect(
      find.text('Repeats every period from November 2026'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).first, '450');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Change a repeating budget'), findsOneWidget);
    await tester.tap(find.text('This and following periods'));
    await settle(tester);
    expect(find.text('€450.00 left'), findsOneWidget);

    await tester.tap(find.byTooltip('Next period'));
    await settle(tester);
    expect(find.text('December 2026'), findsOneWidget);
    expect(find.text('€450.00 left'), findsOneWidget);

    // Only this period: December becomes an override, January keeps 450.
    await tester.longPress(find.text('Groceries'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, '500');
    await tester.tap(find.text('Save'));
    await settle(tester);
    await tester.tap(find.text('Only this period'));
    await settle(tester);
    expect(find.text('€500.00 left'), findsOneWidget);
    await tester.tap(find.byTooltip('Next period'));
    await settle(tester);
    expect(find.text('€450.00 left'), findsOneWidget);

    // Back in October nothing changed.
    await tester.tap(find.text('Today'));
    await settle(tester);
    expect(find.text('€87.60 left'), findsOneWidget);

    await dispose(tester);
  });

  testWidgets('a new budget repeats every period by default', (tester) async {
    await tester.runAsync(() async {
      final f = PlanFixture(db);
      await f.account('Checking');
      await f.category('Pets');
    });
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.text('Add budget').first);
    await settle(tester);
    await tester.tap(find.text('Pets'));
    await settle(tester);
    expect(find.text('Every period'), findsOneWidget);
    expect(find.text('Repeats every period from October 2026'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '60');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.byIcon(Icons.repeat), findsOneWidget);
    await tester.tap(find.byTooltip('Next period'));
    await settle(tester);
    expect(find.text('€60.00 left'), findsOneWidget);

    await dispose(tester);
  });

  testWidgets('a budget with its own length shows its window', (tester) async {
    await tester.runAsync(() async {
      final f = PlanFixture(db);
      final acc = await f.account('Checking');
      final pets = await f.category('Pets');
      await f.expense(acc, pets, 1500, DateTime(2026, 10, 22));
      await f.expense(acc, pets, 9900, DateTime(2026, 10, 2)); // other week
    });
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.text('Add budget').first);
    await settle(tester);
    await tester.tap(find.text('Pets'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('budget-length')));
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('One week').last);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Repeats every week from'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '40');
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.textContaining('Weekly · '), findsOneWidget);
    expect(find.text('€25.00 left'), findsOneWidget); // only this week
    expect(
      find.text("Totals don't include budgets with their own length."),
      findsOneWidget,
    );

    await dispose(tester);
  });

  testWidgets('removing a repeating budget: only this period with undo, '
      'then this and following', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      final f = PlanFixture(db);
      await f.account('Checking');
      final pets = await f.category('Pets');
      final periods = BudgetPeriods(const BudgetPeriodConfig());
      await BudgetsRepository(db, f.writer).repeatFrom(
        periods: periods,
        categoryId: pets,
        from: periods.periodOf(DateTime(2026, 10, 23)),
        amountMinor: 6000,
        repeat: const BudgetRepeat.everyPeriod(),
      );
    });
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.text('€60.00 left'), findsOneWidget);

    await tester.longPress(find.text('Pets'));
    await settle(tester);
    await tester.tap(find.text('Remove budget'));
    await settle(tester);
    expect(find.text('Remove a repeating budget'), findsOneWidget);
    await tester.tap(find.text('Only this period'));
    await settle(tester);
    expect(find.text('Pets'), findsNothing);
    expect(find.text('Budget for Pets removed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1)); // snackbar slides in
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(find.text('€60.00 left'), findsOneWidget);

    await tester.longPress(find.text('Pets'));
    await settle(tester);
    await tester.tap(find.text('Remove budget'));
    await settle(tester);
    await tester.tap(find.text('This and following periods'));
    await settle(tester);
    expect(find.text('Pets removed from this period on'), findsOneWidget);
    await tester.tap(find.byTooltip('Next period'));
    await settle(tester);
    expect(find.text('Pets'), findsNothing);

    await dispose(tester);
  });

  testWidgets('switching to a yearly budget keeps earlier months', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seed(tester);
    await tester.runAsync(() async {
      final f = PlanFixture(db);
      final groceries = (await db.select(db.categories).get())
          .firstWhere((c) => c.name == 'Groceries')
          .id;
      await BudgetsRepository(
        db,
        f.writer,
      ).setAmount(groceries, DateTime(2026, 9), 35000);
    });
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.longPress(find.text('Groceries'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('budget-length')));
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('One year').last);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField).first, '4800');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.textContaining('Yearly · '), findsOneWidget);

    await tester.tap(find.byTooltip('Previous period'));
    await settle(tester);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.textContaining('of €350.00'), findsOneWidget);

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
