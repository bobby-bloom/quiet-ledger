import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/dashboard/data/dashboard_layout.dart';
import 'package:personal_finance/features/dashboard/presentation/dashboard_grid.dart';
import 'package:personal_finance/features/dashboard/presentation/dashboard_screen.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_providers.dart';

import '../../helpers/test_app.dart';

void main() {
  late AppDatabase db;

  Future<void> seed() async {
    db = newTestDb();
    final w = SyncWriter(db, testClock(), 'd');
    final ledger = LedgerRepository(db, w);
    final checking = await w.insert(
      db.accounts,
      AccountsCompanion(
        name: const Value('Everyday checking'),
        type: const Value(AccountType.checking),
        openingBalanceMinor: const Value(100000),
        openingDate: Value(DateTime(2025)),
      ),
    );
    final food = await w.insert(
      db.categories,
      const CategoriesCompanion(
        name: Value('Groceries'),
        kind: Value(CategoryKind.expense),
      ),
    );
    final salary = await w.insert(
      db.categories,
      const CategoriesCompanion(
        name: Value('Salary'),
        kind: Value(CategoryKind.income),
      ),
    );
    final today = dateOnly(DateTime.now());
    await ledger.create(
      TxnDraft(
        accountId: checking,
        amountMinor: -2480,
        date: today,
        payee: 'Corner Grocer',
        categoryId: food,
      ),
    );
    await ledger.create(
      TxnDraft(
        accountId: checking,
        amountMinor: 342000,
        date: DateTime(today.year, today.month),
        type: TxnType.income,
        payee: 'Employer',
        categoryId: salary,
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    unawaited(db.close());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        const DashboardScreen(),
        db: db,
        overrides: [
          forecastRunnerProvider.overrideWithValue(
            const ForecastRunner.inline(),
          ),
        ],
      ),
    );
    await settle(tester);
  }

  testWidgets('phone dashboard shows net worth and month summary', (
    tester,
  ) async {
    await tester.runAsync(seed);
    try {
      await pumpAt(tester, const Size(390, 844));
      expect(find.text('Net worth'), findsOneWidget);
      // 1,000.00 opening + 3,420.00 income − 24.80 expense.
      expect(find.textContaining('4,395'), findsWidgets);
      expect(find.text('Income'), findsOneWidget);
      expect(find.byType(DashboardGrid), findsOneWidget);
      expect(find.byTooltip('Edit dashboard'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await teardown(tester);
    }
  });

  testWidgets('desktop dashboard lays widgets out in columns', (tester) async {
    await tester.runAsync(seed);
    try {
      await pumpAt(tester, const Size(1440, 1000));
      final grid = tester.widget<DashboardGrid>(find.byType(DashboardGrid));
      expect(grid.columns, 3);
      expect(find.byTooltip('Edit dashboard'), findsOneWidget);
      expect(find.text('Recent transactions'), findsOneWidget);
      expect(find.text('Corner Grocer'), findsWidgets);
      expect(tester.takeException(), isNull);
    } finally {
      await teardown(tester);
    }
  });

  test('layout JSON round-trip skips unknown widget types', () async {
    final db = newTestDb();
    addTearDown(db.close);
    final c = testContainer(db);
    addTearDown(c.dispose);
    final repo = c.read(dashboardLayoutRepositoryProvider);
    expect(
      await repo.watch(DashboardBreakpoint.compact).first,
      defaultLayouts[DashboardBreakpoint.compact],
    );
    await repo.save(DashboardBreakpoint.compact, const [
      DashboardItem(
        DashboardWidgetType.goals,
        size: WidgetSize.wide,
        options: {'limit': 2},
      ),
    ]);
    final items = await repo.watch(DashboardBreakpoint.compact).first;
    expect(items.single.type, DashboardWidgetType.goals);
    expect(items.single.size, WidgetSize.wide);
    expect(items.single.options['limit'], 2);
    await repo.reset(DashboardBreakpoint.compact);
    expect(
      await repo.watch(DashboardBreakpoint.compact).first,
      defaultLayouts[DashboardBreakpoint.compact],
    );
  });
}
