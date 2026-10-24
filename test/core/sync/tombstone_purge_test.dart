import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/sync/tombstone_purge.dart';

import '../../helpers/test_app.dart';

void main() {
  late AppDatabase db;
  late DateTime now;
  late SyncWriter writer;
  late LedgerRepository ledger;

  setUp(() {
    db = newTestDb();
    now = DateTime(2026);
    writer = SyncWriter(db, testClock(), 'dev-1', now: () => now);
    ledger = LedgerRepository(db, writer);
  });

  tearDown(() => db.close());

  test('removes old tombstones with their log entries only', () async {
    final acc = await writer.insert(
      db.accounts,
      AccountsCompanion(
        name: const Value('A'),
        type: const Value(AccountType.cash),
        openingDate: Value(DateTime(2025)),
      ),
    );
    final cat = await writer.insert(
      db.categories,
      const CategoriesCompanion(
        name: Value('C'),
        kind: Value(CategoryKind.expense),
      ),
    );
    final oldTxn = await ledger.create(
      TxnDraft(
        accountId: acc,
        amountMinor: -100,
        date: DateTime(2025, 12),
        payee: 'Old',
        splits: [
          SplitDraft(amountMinor: -60, categoryId: cat),
          SplitDraft(amountMinor: -40, categoryId: cat),
        ],
      ),
    );
    final keepTxn = await ledger.create(
      TxnDraft(
        accountId: acc,
        amountMinor: -200,
        date: DateTime(2025, 12),
        payee: 'Recent',
      ),
    );
    final liveTxn = await ledger.create(
      TxnDraft(
        accountId: acc,
        amountMinor: -300,
        date: DateTime(2025, 12),
        payee: 'Live',
        categoryId: cat,
      ),
    );

    await ledger.delete(oldTxn); // deleted 2026-01-01
    now = DateTime(2026, 5);
    await ledger.delete(keepTxn); // deleted 2026-05-01

    final removed = await purgeTombstones(
      db,
      const Duration(days: 90),
      now: DateTime(2026, 6),
    );
    expect(removed, 3); // the old transaction and its two splits

    final ids = (await db.select(db.transactions).get()).map((t) => t.id);
    expect(ids, unorderedEquals([keepTxn, liveTxn]));
    expect(await db.select(db.transactionSplits).get(), isEmpty);
    final logged = (await db.select(db.changeLog).get()).map((e) => e.entityId);
    expect(logged, isNot(contains(oldTxn)));
    expect(logged, contains(keepTxn));
    expect(logged, contains(liveTxn));

    final fts = await db.customSelect('SELECT rowid FROM txn_search').get();
    expect(fts, hasLength(2));

    // Nothing left to purge.
    expect(
      await purgeTombstones(
        db,
        const Duration(days: 90),
        now: DateTime(2026, 6),
      ),
      0,
    );
  });
}
