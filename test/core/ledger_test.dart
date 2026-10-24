import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';

import '../helpers/test_app.dart';

void main() {
  late AppDatabase db;
  late SyncWriter writer;
  late LedgerRepository repo;
  late String checking;
  late String savings;
  late String groceries;
  late String household;

  setUp(() async {
    db = newTestDb();
    writer = SyncWriter(db, testClock(), 'dev-1');
    repo = LedgerRepository(db, writer);
    Future<String> account(String name, int opening) => writer.insert(
      db.accounts,
      AccountsCompanion(
        name: Value(name),
        type: const Value(AccountType.checking),
        openingBalanceMinor: Value(opening),
        openingDate: Value(DateTime(2026)),
      ),
    );
    Future<String> category(String name) => writer.insert(
      db.categories,
      CategoriesCompanion(
        name: Value(name),
        kind: const Value(CategoryKind.expense),
      ),
    );
    checking = await account('Checking', 100000);
    savings = await account('Savings', 0);
    groceries = await category('Groceries');
    household = await category('Household');
  });

  tearDown(() => db.close());

  test(
    'every write stamps sync columns and appends to the change log',
    () async {
      final row = await (db.select(
        db.accounts,
      )..where((a) => a.id.equals(checking))).getSingle();
      expect(row.originDeviceId, 'dev-1');
      expect(row.updatedAt, isNotEmpty);
      expect(row.createdAt, greaterThan(0));

      await writer.update(
        db.accounts,
        checking,
        const AccountsCompanion(name: Value('Main')),
      );
      await writer.delete(db.accounts, checking);

      final log = await (db.select(
        db.changeLog,
      )..where((c) => c.entityId.equals(checking))).get();
      expect(log.map((e) => e.op), [
        ChangeOp.insert,
        ChangeOp.update,
        ChangeOp.delete,
      ]);
      expect(jsonDecode(log[1].changedFields), {'name': 'Main'});
      expect(log.every((e) => !e.synced), isTrue);
      // HLCs increase.
      expect(log[0].hlc.compareTo(log[1].hlc), lessThan(0));
      expect(log[1].hlc.compareTo(log[2].hlc), lessThan(0));

      final deleted = await (db.select(
        db.accounts,
      )..where((a) => a.id.equals(checking))).getSingle();
      expect(deleted.deletedAt, isNotNull);
    },
  );

  test('expense with tags and balance', () async {
    final tag = await writer.insert(
      db.tags,
      const TagsCompanion(name: Value('vacation')),
    );
    final id = await repo.create(
      TxnDraft(
        accountId: checking,
        amountMinor: -2550,
        date: DateTime(2026, 10, 3, 15, 30),
        payee: 'Corner Grocer',
        categoryId: groceries,
        tagIds: [tag],
      ),
    );
    final t = (await repo.txnById(id))!;
    expect(t.date, DateTime(2026, 10, 3));
    expect(await repo.tagIdsFor(id), [tag]);
    expect((await repo.balances())[checking], 100000 - 2550);
  });

  test('transfer creates two linked legs and round-trips as draft', () async {
    final id = await repo.create(
      TxnDraft(
        accountId: checking,
        amountMinor: -50000,
        date: DateTime(2026, 10),
        type: TxnType.transfer,
        transferAccountId: savings,
      ),
    );
    final leg = (await repo.txnById(id))!;
    final peer = (await repo.txnById(leg.transferPeerId!))!;
    expect(peer.accountId, savings);
    expect(peer.amountMinor, 50000);
    expect(peer.transferPeerId, id);

    final balances = await repo.balances();
    expect(balances[checking], 50000);
    expect(balances[savings], 50000);

    final fromPeer = (await repo.draftFor(peer.id))!;
    expect(fromPeer.accountId, checking);
    expect(fromPeer.transferAccountId, savings);
    expect(fromPeer.amountMinor, -50000);

    // Turning it into an expense removes the peer.
    await repo.update(
      id,
      fromPeer.copyWith(type: TxnType.expense, transferAccountId: null),
    );
    expect(await repo.txnById(peer.id), isNull);
    expect((await repo.balances())[savings], 0);
  });

  test('split must balance and is stored as lines', () async {
    final bad = TxnDraft(
      accountId: checking,
      amountMinor: -1000,
      date: DateTime(2026, 10, 2),
      splits: const [SplitDraft(amountMinor: -400)],
    );
    expect(() => repo.create(bad), throwsArgumentError);

    final id = await repo.create(
      bad.copyWith(
        splits: [
          SplitDraft(amountMinor: -600, categoryId: groceries),
          SplitDraft(amountMinor: -400, categoryId: household),
        ],
      ),
    );
    final t = (await repo.txnById(id))!;
    expect(t.categoryId, isNull);
    final splits = await repo.splitsFor(id);
    expect(splits.map((s) => s.amountMinor), [-600, -400]);
  });

  test('delete and restore (undo) include children', () async {
    final tag = await writer.insert(
      db.tags,
      const TagsCompanion(name: Value('x')),
    );
    final id = await repo.create(
      TxnDraft(
        accountId: checking,
        amountMinor: -1000,
        date: DateTime(2026, 10, 2),
        tagIds: [tag],
        splits: [
          SplitDraft(amountMinor: -500, categoryId: groceries),
          SplitDraft(amountMinor: -500, categoryId: household),
        ],
      ),
    );
    await repo.delete(id);
    expect(await repo.txnById(id), isNull);
    expect(await repo.splitsFor(id), isEmpty);
    expect((await repo.balances())[checking], 100000);

    await repo.restore(id);
    expect(await repo.txnById(id), isNotNull);
    expect(await repo.splitsFor(id), hasLength(2));
    expect(await repo.tagIdsFor(id), [tag]);
  });

  test('planned transactions are excluded from balances by default', () async {
    await repo.create(
      TxnDraft(
        accountId: checking,
        amountMinor: -1000,
        date: DateTime(2026, 11),
        status: TxnStatus.planned,
      ),
    );
    expect((await repo.balances())[checking], 100000);
    expect((await repo.balances(includePlanned: true))[checking], 99000);
  });

  test('full-text search finds payee, category and tag', () async {
    final tag = await writer.insert(
      db.tags,
      const TagsCompanion(name: Value('vacation')),
    );
    await repo.create(
      TxnDraft(
        accountId: checking,
        amountMinor: -1000,
        date: DateTime(2026, 10, 2),
        payee: 'Café Müller',
        categoryId: groceries,
        tagIds: [tag],
      ),
    );
    Future<int> count(String q) async {
      final r = await db
          .customSelect(
            'SELECT count(*) AS c FROM txn_search WHERE txn_search MATCH ?',
            variables: [Variable<String>(q)],
          )
          .getSingle();
      return r.read<int>('c');
    }

    expect(await count('cafe'), 1);
    expect(await count('groceries'), 1);
    expect(await count('vacation'), 1);
    expect(await count('nothing'), 0);
  });

  test('draft JSON round-trip', () {
    final d = TxnDraft(
      accountId: 'a',
      amountMinor: -123,
      date: DateTime(2026, 1, 31),
      payee: 'P',
      splits: const [SplitDraft(amountMinor: -123, categoryId: 'c')],
      tagIds: const ['t'],
      customFields: const {'f': 'x'},
    );
    expect(
      TxnDraft.fromJson(
        jsonDecode(jsonEncode(d.toJson())) as Map<String, Object?>,
      ),
      d,
    );
  });
}
