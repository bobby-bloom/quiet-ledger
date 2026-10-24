import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/accounts/data/account_queries.dart';
import 'package:personal_finance/features/accounts/data/accounts_repository.dart';
import 'package:personal_finance/features/accounts/data/net_worth.dart';
import 'package:personal_finance/features/accounts/data/reconciliation.dart';
import 'package:personal_finance/features/accounts/domain/account_draft.dart';
import 'package:personal_finance/features/accounts/domain/account_grouping.dart';

import '../../helpers/test_app.dart';

void main() {
  late AppDatabase db;
  late SyncWriter writer;
  late LedgerRepository ledger;
  late AccountsRepository repo;

  setUp(() {
    db = newTestDb();
    writer = SyncWriter(db, testClock(), 'dev-1');
    ledger = LedgerRepository(db, writer);
    repo = AccountsRepository(db, writer);
  });

  tearDown(() => db.close());

  Future<String> account(
    String name, {
    AccountType type = AccountType.checking,
    int opening = 0,
    bool inNetWorth = true,
    String? groupId,
  }) => repo.create(
    AccountDraft(
      name: name,
      type: type,
      openingDate: DateTime(2026),
      openingBalanceMinor: opening,
      includeInNetWorth: inNetWorth,
      groupId: groupId,
    ),
  );

  Future<String> txn(
    String accountId,
    int amount,
    DateTime date, {
    TxnStatus status = TxnStatus.cleared,
    String? payee,
  }) => ledger.create(
    TxnDraft(
      accountId: accountId,
      amountMinor: amount,
      date: date,
      type: amount >= 0 ? TxnType.income : TxnType.expense,
      status: status,
      payee: payee,
    ),
  );

  Future<List<Account>> liveAccounts() =>
      (db.select(db.accounts)..where((a) => a.deletedAt.isNull())).get();

  group('AccountsRepository', () {
    test('create appends to the end and validates the name', () async {
      final a = await account('A');
      final b = await account('B');
      final rows = await liveAccounts();
      final byId = {for (final r in rows) r.id: r};
      expect(byId[a]!.sortOrder, 0);
      expect(byId[b]!.sortOrder, 1);
      expect(
        () => repo.create(
          AccountDraft(
            name: '  ',
            type: AccountType.cash,
            openingDate: DateTime(2026),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('reorder writes only changed rows', () async {
      final a = await account('A');
      final b = await account('B');
      final c = await account('C');
      final before = await db.select(db.changeLog).get();
      await repo.reorder([c, a, b]);
      final rows = {for (final r in await liveAccounts()) r.id: r.sortOrder};
      expect(rows, {c: 0, a: 1, b: 2});
      final after = await db.select(db.changeLog).get();
      expect(after.length - before.length, 3);
      await repo.reorder([c, a, b]);
      expect((await db.select(db.changeLog).get()).length, after.length);
    });

    test('applyLayout moves accounts between groups', () async {
      final g1 = await repo.createGroup('Daily');
      final g2 = await repo.createGroup('Savings');
      final a = await account('A', groupId: g1);
      final b = await account('B', groupId: g1);
      final c = await account('C');
      final layout = resolveLayout([
        LayoutEntry.header(g1),
        LayoutEntry.account(b),
        LayoutEntry.header(g2),
        LayoutEntry.account(a),
        const LayoutEntry.header(null),
        LayoutEntry.account(c),
      ]);
      await repo.applyLayout(layout);
      final rows = {for (final r in await liveAccounts()) r.id: r};
      expect(rows[b]!.groupId, g1);
      expect(rows[b]!.sortOrder, 0);
      expect(rows[a]!.groupId, g2);
      expect(rows[a]!.sortOrder, 1);
      expect(rows[c]!.groupId, isNull);
    });

    test('deleting a group ungroups its accounts', () async {
      final g = await repo.createGroup('Daily');
      final a = await account('A', groupId: g);
      await repo.deleteGroup(g);
      final acc = (await liveAccounts()).single;
      expect(acc.id, a);
      expect(acc.groupId, isNull);
      final groups = await (db.select(
        db.accountGroups,
      )..where((x) => x.deletedAt.isNull())).get();
      expect(groups, isEmpty);
    });

    test('delete is refused while transactions exist', () async {
      final a = await account('A');
      final b = await account('B');
      await txn(a, -100, DateTime(2026, 3));
      await expectLater(repo.delete(a), throwsA(isA<AccountInUseException>()));
      await repo.delete(b);
      expect((await liveAccounts()).map((x) => x.id), [a]);
    });
  });

  group('net worth', () {
    test('counts liabilities negative and skips excluded accounts', () async {
      final checking = await account('Checking', opening: 150000);
      final card = await account(
        'Card',
        type: AccountType.creditCard,
        opening: -20000,
      );
      final loan = await account('Loan', type: AccountType.loan);
      await account('Hidden', opening: 999999, inNetWorth: false);
      await txn(checking, -5000, DateTime(2026, 2));
      await txn(card, -1500, DateTime(2026, 2));
      await txn(loan, -400000, DateTime(2026));
      // Planned entries are not part of the balance.
      await txn(
        checking,
        -100000,
        DateTime(2026, 12),
        status: TxnStatus.planned,
      );

      final summary = await watchNetWorthSummary(db).first;
      expect(summary.assetsMinor, 145000);
      expect(summary.liabilitiesMinor, -21500 - 400000);
      expect(summary.netMinor, 145000 - 421500);

      final container = testContainer(db);
      addTearDown(container.dispose);
      final sub = container.listen(netWorthProvider.future, (_, _) {});
      expect(await sub.read(), 145000 - 421500);
    });

    test('computeNetWorth matches the SQL summary', () async {
      final a = await account('A', opening: 1000);
      await account('L', type: AccountType.loan, opening: -500);
      await txn(a, 250, DateTime(2026, 1, 5));
      final accounts = await liveAccounts();
      final balances = await ledger.balances();
      expect(
        computeNetWorth(accounts, balances),
        await watchNetWorthSummary(db).first,
      );
    });
  });

  group('balance history', () {
    test('daily series starts with the opening balance', () async {
      final a = await account('A', opening: 10000);
      await txn(a, -1000, DateTime(2026, 1, 10));
      await txn(a, 5000, DateTime(2026, 2));
      await txn(a, -2000, DateTime(2026, 2));
      await txn(a, -700, DateTime(2026, 3, 15));
      // Outside the range.
      await txn(a, -300, DateTime(2026, 4, 2));

      final series = await accountBalanceHistory(
        db,
        a,
        DateTime(2026, 2),
        DateTime(2026, 4),
      );
      // The start balance (9000) is replaced by the end of the first day.
      expect(series, [
        BalancePoint(DateTime(2026, 2), 12000),
        BalancePoint(DateTime(2026, 3, 15), 11300),
        BalancePoint(DateTime(2026, 3, 31), 11300),
      ]);
    });

    test('monthly buckets end on the last day of the month', () async {
      final a = await account('A');
      await txn(a, 1000, DateTime(2026, 1, 3));
      await txn(a, 1000, DateTime(2026, 1, 20));
      await txn(a, -500, DateTime(2026, 3, 2));
      final series = await accountBalanceHistory(
        db,
        a,
        DateTime(2026),
        DateTime(2026, 3, 10),
        bucket: BalanceBucket.month,
      );
      expect(series, [
        BalancePoint(DateTime(2026), 0),
        BalancePoint(DateTime(2026, 1, 31), 2000),
        BalancePoint(DateTime(2026, 3, 9), 1500),
      ]);
    });

    test('net worth history covers all included accounts', () async {
      final a = await account('A', opening: 100);
      final b = await account('B', type: AccountType.loan, opening: -50);
      await account('X', opening: 1000, inNetWorth: false);
      await txn(a, 10, DateTime(2026, 5, 5));
      await txn(b, 5, DateTime(2026, 5, 6));
      final series = await watchBalanceHistory(
        db,
        from: DateTime(2026, 5),
        to: DateTime(2026, 6),
      ).first;
      expect(series.first.balanceMinor, 50);
      expect(series.last.balanceMinor, 65);
      expect(series.last.date, DateTime(2026, 5, 31));
    });

    test('sparkline series walks back from the current balance', () {
      final s = sparklineSeries(
        1000,
        {'2026-08': 100, '2026-10': -50, '2026-12': 7},
        ['2026-08', '2026-09', '2026-10'],
      );
      // end of window = 1000 - 7 = 993; start = 993 - 100 + 50 = 943.
      expect(s, [943, 1043, 1043, 1000]);
    });
  });

  group('reconciliation', () {
    test('correction makes the cleared balance match the bank', () async {
      final a = await account('A', opening: 100000);
      await txn(a, -2500, DateTime(2026, 3));
      final pendingId = await txn(
        a,
        -1200,
        DateTime(2026, 3, 2),
        status: TxnStatus.pending,
      );
      final service = ReconciliationService(db, ledger);
      final asOf = DateTime(2026, 3, 5);

      final recorded = await service.recorded(a, asOf);
      expect(recorded.clearedMinor, 97500);
      expect(recorded.pendingMinor, -1200);
      expect(recorded.pendingCount, 1);

      // The bank booked the pending one and a fee of 3.30 we missed.
      const bank = 97500 - 1200 - 330;
      expect(await service.difference(a, bank, asOf), -1530);
      final pending = await service.watchPending(a, asOf).first;
      expect(pending.map((t) => t.id), [pendingId]);
      await service.markCleared([pendingId]);
      expect(await service.difference(a, bank, asOf), -330);

      final id = await service.createCorrection(
        accountId: a,
        actualMinor: bank,
        asOf: asOf,
        payee: 'Reconciliation',
      );
      final t = (await ledger.txnById(id!))!;
      expect(t.amountMinor, -330);
      expect(t.type, TxnType.expense);
      expect(t.status, TxnStatus.cleared);
      expect(t.payee, 'Reconciliation');
      expect(await service.difference(a, bank, asOf), 0);
      expect(
        await service.createCorrection(
          accountId: a,
          actualMinor: bank,
          asOf: asOf,
          payee: 'Reconciliation',
        ),
        isNull,
      );
    });

    test('a positive difference creates income', () async {
      final a = await account('A');
      final service = ReconciliationService(db, ledger);
      final id = await service.createCorrection(
        accountId: a,
        actualMinor: 4200,
        asOf: DateTime(2026, 6),
        payee: 'Kontoabgleich',
      );
      final t = (await ledger.txnById(id!))!;
      expect(t.amountMinor, 4200);
      expect(t.type, TxnType.income);
    });
  });

  test('recent transactions include category and transfer peer', () async {
    final a = await account('A');
    final b = await account('B');
    final cat = await writer.insert(
      db.categories,
      const CategoriesCompanion(
        name: Value('Food'),
        kind: Value(CategoryKind.expense),
      ),
    );
    await ledger.create(
      TxnDraft(
        accountId: a,
        amountMinor: -500,
        date: DateTime(2026, 1, 2),
        categoryId: cat,
        payee: 'Shop',
      ),
    );
    await ledger.create(
      TxnDraft(
        accountId: a,
        amountMinor: -1000,
        date: DateTime(2026, 1, 3),
        type: TxnType.transfer,
        transferAccountId: b,
      ),
    );
    final rows = await watchRecentTransactions(db, a).first;
    expect(rows, hasLength(2));
    expect(rows[0].peerAccountName, 'B');
    expect(rows[1].categoryName, 'Food');
    expect(rows[1].payee, 'Shop');
    expect(rows[1].date, DateTime(2026, 1, 2));
  });

  group('grouping', () {
    test('user groups first, then ungrouped by type', () async {
      final g = await repo.createGroup('Daily');
      await account('Cash', type: AccountType.cash);
      await account('Main', groupId: g);
      await account('Card', type: AccountType.creditCard);
      await account('Giro');
      final groups = await db.select(db.accountGroups).get();
      final sections = groupAccounts(await liveAccounts(), groups);
      expect(sections.map((s) => s.group?.name ?? s.type!.name), [
        'Daily',
        'checking',
        'cash',
        'creditCard',
      ]);
    });

    test('reorderList follows ReorderableListView semantics', () {
      expect(reorderList([1, 2, 3, 4], 0, 3), [2, 3, 1, 4]);
      expect(reorderList([1, 2, 3, 4], 3, 0), [4, 1, 2, 3]);
    });
  });
}
