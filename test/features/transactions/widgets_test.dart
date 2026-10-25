import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/transactions/presentation/quick_add.dart';
import 'package:personal_finance/features/transactions/presentation/transaction_list_view.dart';
import 'package:personal_finance/features/transactions/presentation/transaction_tile.dart';
import 'package:personal_finance/features/transactions/presentation/transactions_screen.dart';

import '../../helpers/test_app.dart';
import 'seed.dart';

void main() {
  late AppDatabase db;
  late Seed s;

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(400 * 3, 860 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> dispose(WidgetTester tester) async {
    // Everything in the test zone: queries started by the tree must be able
    // to finish before the DB closes (awaiting in runAsync would deadlock).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    unawaited(db.close());
    await tester.pump(const Duration(seconds: 1));
  }

  /// Runs [body] and always tears the tree and DB down; otherwise a failing
  /// expectation leaves drift streams open and the test never finishes.
  Future<void> guarded(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    try {
      await body();
    } finally {
      await dispose(tester);
    }
  }

  testWidgets('list groups rows by day with day sums', (tester) async {
    phone(tester);
    final today = dateOnly(DateTime.now());
    await tester.runAsync(() async {
      db = newTestDb();
      s = await Seed.create(db);
      Future<void> add(int a, DateTime d, String payee) => s.ledger
          .create(
            TxnDraft(
              accountId: s.checking,
              amountMinor: a,
              date: d,
              payee: payee,
              categoryId: s.groceries,
            ),
          )
          .then((_) {});
      await add(-2480, today, 'Corner Grocer');
      await add(-640, today, 'Daily Bakery');
      await add(-1850, today.subtract(const Duration(days: 1)), 'Pharmacy');
      await add(-999, DateTime(2020, 3, 4), 'Old shop');
    });

    await guarded(tester, () async {
      await tester.pumpWidget(
        testApp(
          const Scaffold(body: TransactionListView(embedded: true)),
          db: db,
        ),
      );
      await settle(tester);

      expect(find.byType(TransactionTile), findsNWidgets(4));
      expect(find.textContaining('Today · '), findsOneWidget);
      expect(find.textContaining('Yesterday · '), findsOneWidget);
      expect(find.text('Corner Grocer'), findsOneWidget);
      // Day sum of today's two expenses.
      expect(find.text('−€31.20'), findsOneWidget);
      // Older year: medium date with year in the header.
      expect(find.textContaining('2020'), findsOneWidget);

      // Month grouping via settings.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TransactionListView)),
      );
      // Written in the test zone: awaiting a DB write in runAsync while a
      // stream query of the widget tree holds drift's lock would deadlock.
      unawaited(
        container
            .read(settingsProvider.notifier)
            .set(TransactionSettings.grouping, TxnGrouping.month),
      );
      await settle(tester);
      expect(find.textContaining('Today · '), findsNothing);
      expect(find.text('March 2020'), findsOneWidget);

      // No grouping: no headers at all.
      // Written in the test zone: awaiting a DB write in runAsync while a
      // stream query of the widget tree holds drift's lock would deadlock.
      unawaited(
        container
            .read(settingsProvider.notifier)
            .set(TransactionSettings.grouping, TxnGrouping.none),
      );
      await settle(tester);
      expect(find.text('March 2020'), findsNothing);
      expect(find.byType(TxnGroupHeader), findsNothing);
      expect(find.byType(TransactionTile), findsNWidgets(4));
    });
  });

  testWidgets('quick add saves an expense: amount → category → save', (
    tester,
  ) async {
    phone(tester);
    await tester.runAsync(() async {
      db = newTestDb();
      s = await Seed.create(db);
      await s.writer.update(
        db.categories,
        s.groceries,
        const CategoriesCompanion(favourite: Value(true)),
      );
    });

    await guarded(tester, () async {
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showQuickAdd(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          db: db,
        ),
      );
      await settle(tester);
      await tester.tap(find.text('open'));
      await settle(tester);

      expect(find.text('New transaction'), findsOneWidget);
      // The amount field calculates: 20 + 4.80 = 24.80
      final amount = find.byType(TextField).first;
      await tester.enterText(amount, '20+4.8');
      await tester.pump();
      expect(find.text('= €24.80'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('24.80'), findsOneWidget);

      await tester.tap(find.text('Groceries'));
      await tester.pump();
      await tester.tap(find.text('Save expense'));
      await settle(tester);

      expect(find.text('New transaction'), findsNothing);
      expect(find.text('Expense saved'), findsOneWidget);

      final rows = await tester.runAsync(
        () => (db.select(
          db.transactions,
        )..where((t) => t.deletedAt.isNull())).get(),
      );
      expect(rows, hasLength(1));
      final t = rows!.single;
      expect(t.amountMinor, -2480);
      expect(t.categoryId, s.groceries);
      expect(t.accountId, s.checking);
      expect(t.type, TxnType.expense);
      expect(t.date, dateOnly(DateTime.now()));
    });
  });

  testWidgets('quick add validates a missing amount', (tester) async {
    phone(tester);
    await tester.runAsync(() async {
      db = newTestDb();
      s = await Seed.create(db);
    });
    await guarded(tester, () async {
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showQuickAdd(context),
                child: const Text('open'),
              ),
            ),
          ),
          db: db,
        ),
      );
      await settle(tester);
      await tester.tap(find.text('open'));
      await settle(tester);
      await tester.tap(find.text('Save expense'));
      await settle(tester);
      expect(find.text('Enter an amount'), findsOneWidget);
      final count = await tester.runAsync(
        () => db.select(db.transactions).get(),
      );
      expect(count, isEmpty);
    });
  });

  Future<void> seedList(WidgetTester tester) => tester.runAsync(() async {
    db = newTestDb();
    s = await Seed.create(db);
    final today = dateOnly(DateTime.now());
    await s.ledger.create(
      TxnDraft(
        accountId: s.checking,
        amountMinor: -2480,
        date: today,
        payee: 'Corner Grocer',
        categoryId: s.groceries,
        tagIds: [s.vacationTag],
      ),
    );
    await s.ledger.create(
      TxnDraft(
        accountId: s.checking,
        amountMinor: -15000,
        date: today,
        type: TxnType.transfer,
        transferAccountId: s.savings,
      ),
    );
    await s.ledger.create(
      TxnDraft(
        accountId: s.checking,
        amountMinor: 320000,
        date: today.subtract(const Duration(days: 3)),
        payee: 'ACME',
        categoryId: s.salary,
        type: TxnType.income,
        status: TxnStatus.pending,
      ),
    );
  });

  testWidgets('desktop: table, detail pane and edit with undo', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seedList(tester);
    await guarded(tester, () async {
      await tester.pumpWidget(testApp(const TransactionsScreen(), db: db));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(TxnTableRow), findsNWidgets(3));
      expect(find.byType(TxnTableHeader), findsOneWidget);
      expect(find.text('3 entries'), findsOneWidget);
      expect(find.text('To Holiday savings'), findsOneWidget);

      await tester.tap(find.text('Corner Grocer'));
      await settle(tester);
      expect(find.text('TRANSACTION'), findsOneWidget);
      expect(find.text('#vacation'), findsWidgets);

      await tester.tap(find.text('Edit transaction'));
      await settle(tester);
      expect(find.text('24.80'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, '24.80'), '24');
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await settle(tester);
      expect(find.text('Changes saved'), findsOneWidget);
      var t = (await tester.runAsync(
        () => (db.select(
          db.transactions,
        )..where((x) => x.payee.equals('Corner Grocer'))).getSingle(),
      ))!;
      expect(t.amountMinor, -2400);
      // Tags survive the edit.
      expect(await tester.runAsync(() => s.ledger.tagIdsFor(t.id)), [
        s.vacationTag,
      ]);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      t = (await tester.runAsync(
        () =>
            (db.select(db.transactions)..where(
                  (x) => x.payee.equals('Corner Grocer') & x.deletedAt.isNull(),
                ))
                .getSingle(),
      ))!;
      expect(t.amountMinor, -2480);
    });
  });

  testWidgets('phone: list, chips and search render without errors', (
    tester,
  ) async {
    phone(tester);
    await seedList(tester);
    await guarded(tester, () async {
      await tester.pumpWidget(testApp(const TransactionsScreen(), db: db));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(TransactionTile), findsNWidgets(3));
      expect(find.text('Search payee, note, category'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'acme');
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);
      expect(find.byType(TransactionTile), findsOneWidget);
      expect(find.text('1 entry'), findsOneWidget);
      // Long-press starts multi-select.
      await tester.longPress(find.text('ACME'));
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);
    });
  });
}
