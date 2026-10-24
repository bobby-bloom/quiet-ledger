import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/platform/notifications.dart';
import 'package:personal_finance/features/budgets/data/budgets_repository.dart';
import 'package:personal_finance/features/goals/data/goals_repository.dart';
import 'package:personal_finance/features/goals/presentation/goal_editor_screen.dart';
import 'package:personal_finance/features/plan/plan_providers.dart';
import 'package:personal_finance/features/plan/presentation/plan_screen.dart';
import 'package:personal_finance/features/recurring/data/recurring_repository.dart';
import 'package:personal_finance/features/recurring/presentation/bills_calendar_screen.dart';
import 'package:personal_finance/features/recurring/presentation/rule_editor_screen.dart';

import '../../helpers/test_app.dart';
import 'plan_fixtures.dart';

void main() {
  late AppDatabase db;
  late String ruleId;

  setUp(() => db = newTestDb());

  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    final f = PlanFixture(db);
    final checking = await f.account('Checking');
    final rent = await f.category('Rent');
    final writer = f.writer;
    ruleId = await RecurringRepository(db, writer, f.ledger).create(
      RecurringRuleDraft(
        name: 'Rent',
        rrule: 'FREQ=MONTHLY;BYMONTHDAY=1',
        startDate: DateTime(2026, 10),
        template: TxnDraft(
          accountId: checking,
          amountMinor: -98000,
          date: DateTime(2026, 10),
          categoryId: rent,
        ),
      ),
    );
    await GoalsRepository(db, writer).create(
      const GoalDraft(
        name: 'Holiday',
        targetMinor: 200000,
        savedMinor: 50000,
        contributionMinor: 25000,
      ),
    );
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
    await tester.pump(const Duration(seconds: 1));
  }

  Widget app(Widget child, {Locale locale = const Locale('en')}) => testApp(
    child,
    db: db,
    locale: locale,
    overrides: [
      planTodayProvider.overrideWithValue(DateTime(2026, 10, 23)),
      notificationServiceProvider.overrideWithValue(
        const NoopNotificationService(),
      ),
    ],
  );

  testWidgets('plan hub tabs: recurring due list and goals', (tester) async {
    await seed(tester);
    await tester.pumpWidget(app(const PlanScreen(initialTab: 'recurring')));
    await settle(tester);
    expect(find.text('Rent'), findsWidgets);
    expect(find.text('Waiting for confirmation'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Goals'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await settle(tester);
    expect(find.text('Holiday'), findsOneWidget);
    expect(find.text('Add contribution'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('each tab adds from the header', (tester) async {
    await seed(tester);
    await tester.runAsync(() async {
      final f = PlanFixture(db);
      final food = await f.category('Groceries');
      await BudgetsRepository(
        db,
        f.writer,
      ).setAmount(food, DateTime(2026, 10), 40000);
    });
    await tester.pumpWidget(app(const PlanScreen(initialTab: 'budgets')));
    await settle(tester);
    expect(find.text('Groceries'), findsWidgets);
    // Not as a button below the list.
    expect(find.text('Add budget'), findsNothing);
    await tester.tap(find.byTooltip('Add budget'));
    await settle(tester);
    expect(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_CategoryPicker',
      ),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);

    for (final (tab, tooltip) in [
      ('Recurring', 'New recurring item'),
      ('Goals', 'New goal'),
    ]) {
      await tester.tap(find.widgetWithText(Tab, tab));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await settle(tester);
      expect(find.byTooltip('Add budget'), findsNothing);
      expect(find.byTooltip(tooltip), findsOneWidget);
    }
    await dispose(tester);
  });

  testWidgets('rule editor, goal editor and calendar render in German', (
    tester,
  ) async {
    await seed(tester);
    await tester.pumpWidget(
      app(RuleEditorScreen(ruleId: ruleId), locale: const Locale('de')),
    );
    await settle(tester);
    expect(find.text('Dauerauftrag bearbeiten'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      app(const RuleEditorScreen(), locale: const Locale('de')),
    );
    await settle(tester);
    expect(find.text('Neuer Dauerauftrag'), findsOneWidget);

    await tester.pumpWidget(
      app(const GoalEditorScreen(), locale: const Locale('de')),
    );
    await settle(tester);
    expect(find.text('Neues Ziel'), findsOneWidget);

    await tester.pumpWidget(
      app(const BillsCalendarScreen(), locale: const Locale('de')),
    );
    await settle(tester);
    expect(find.text('Zahlungskalender'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await dispose(tester);
  });
}
