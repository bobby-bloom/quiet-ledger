import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/accounts/data/accounts_repository.dart';
import 'package:personal_finance/features/accounts/domain/account_draft.dart';
import 'package:personal_finance/features/accounts/presentation/account_detail_screen.dart';
import 'package:personal_finance/features/accounts/presentation/account_form_screen.dart';
import 'package:personal_finance/features/accounts/presentation/accounts_screen.dart';
import 'package:personal_finance/features/accounts/presentation/reconcile_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late AppDatabase db;
  late AccountsRepository repo;
  late LedgerRepository ledger;

  setUp(() {
    db = newTestDb();
    final writer = SyncWriter(db, testClock(), 'dev-1');
    repo = AccountsRepository(db, writer);
    ledger = LedgerRepository(db, writer);
  });

  tearDown(() => db.close());

  Future<String> account(
    String name,
    AccountType type,
    int opening, {
    String? groupId,
  }) => repo.create(
    AccountDraft(
      name: name,
      type: type,
      openingDate: DateTime(2026),
      openingBalanceMinor: opening,
      groupId: groupId,
    ),
  );

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('accounts list shows groups, subtotals and net worth', (
    tester,
  ) async {
    final daily = await repo.createGroup('Daily');
    final main = await account(
      'Main account',
      AccountType.checking,
      100000,
      groupId: daily,
    );
    await account('Wallet', AccountType.cash, 5000, groupId: daily);
    await account('Visa', AccountType.creditCard, -20000);
    await account('Car loan', AccountType.loan, -400000);
    await ledger.create(
      TxnDraft(accountId: main, amountMinor: -2500, date: DateTime(2026, 3)),
    );

    await tester.pumpWidget(testApp(const AccountsScreen(), db: db));
    await tester.pumpAndSettle();

    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('DAILY'), findsOneWidget);
    expect(find.text('CREDIT CARD'), findsOneWidget);
    expect(find.text('LOAN'), findsOneWidget);
    expect(find.text('Main account'), findsOneWidget);
    // Group subtotal: 975.00 + 50.00.
    // ... which here equals the assets total.
    expect(find.textContaining('1,025.00'), findsNWidgets(2));
    // Net worth = 1,025.00 − 200.00 − 4,000.00.
    expect(find.textContaining('3,175.00'), findsOneWidget);
    expect(find.textContaining('4,200.00'), findsOneWidget);
    expect(find.text('Net worth'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('empty state offers to add an account', (tester) async {
    await tester.pumpWidget(testApp(const AccountsScreen(), db: db));
    await tester.pumpAndSettle();
    expect(find.text('Add account'), findsWidgets);
    expect(find.textContaining('No accounts yet'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('expanded layout shows list and detail side by side', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final id = await account('Main account', AccountType.checking, 100000);
    await ledger.create(
      TxnDraft(
        accountId: id,
        amountMinor: -2500,
        date: dateOnly(DateTime.now()).subtract(const Duration(days: 3)),
        payee: 'Corner Grocer',
      ),
    );

    await tester.pumpWidget(testApp(const AccountsScreen(), db: db));
    await tester.pumpAndSettle();

    expect(find.text('Balance over time'), findsOneWidget);
    expect(find.text('Corner Grocer'), findsOneWidget);
    expect(find.text('Main account'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('reconcile books a correction for the difference', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final id = await account('Main account', AccountType.checking, 10000);

    await tester.pumpWidget(testApp(ReconcileScreen(accountId: id), db: db));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter the bank balance'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '95,50');
    await tester.pumpAndSettle();
    expect(find.textContaining('Book correction of'), findsOneWidget);

    await tester.tap(find.textContaining('Book correction of'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book correction'));
    await tester.pumpAndSettle();

    final txns = await db.select(db.transactions).get();
    expect(txns.single.amountMinor, -450);
    expect(txns.single.payee, 'Reconciliation');
    expect(find.textContaining('Balanced'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('compact detail renders chart and recent transactions (dark)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final id = await repo.create(
      AccountDraft(
        name: 'Everyday checking',
        type: AccountType.checking,
        openingDate: DateTime(2025),
        openingBalanceMinor: 100000,
        lowBalanceThresholdMinor: 50000,
        includeInBudgets: false,
      ),
    );
    final today = dateOnly(DateTime.now());
    for (var i = 1; i <= 10; i++) {
      await ledger.create(
        TxnDraft(
          accountId: id,
          amountMinor: -1000 * i,
          date: today.subtract(Duration(days: i * 20)),
          payee: 'Payee $i',
          status: i == 1 ? TxnStatus.pending : TxnStatus.cleared,
        ),
      );
    }
    await tester.pumpWidget(
      testApp(
        AccountDetailScreen(accountId: id),
        db: db,
        themeMode: ThemeMode.dark,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Current balance'), findsOneWidget);
    expect(find.text('Payee 1'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.textContaining('Below the low-balance alert'), findsOneWidget);
    await tester.tap(find.text('All').first);
    await tester.pumpAndSettle();
    expect(find.text('Balance over time'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('account form validates the name (German)', (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(const AccountFormScreen(), db: db, locale: const Locale('de')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Neues Konto'), findsOneWidget);
    await tester.tap(find.text('Konto anlegen'));
    await tester.pumpAndSettle();
    expect(find.text('Gib einen Namen ein'), findsOneWidget);
    expect(await db.select(db.accounts).get(), isEmpty);
    await unmount(tester);
  });
}
