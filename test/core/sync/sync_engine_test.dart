import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/sync/change.dart';
import 'package:personal_finance/core/sync/hlc.dart';
import 'package:personal_finance/core/sync/raw_rows.dart';
import 'package:personal_finance/core/sync/sync_backend.dart';
import 'package:personal_finance/core/sync/sync_engine.dart';

import '../../helpers/test_app.dart';

const _base = 1700000000000;

/// One simulated device: own DB, clock (with controllable wall time),
/// writer, ledger and engine.
class Device {
  Device(this.name, SyncBackend backend) {
    db = newTestDb();
    clock = HlcClock(name, now: () => now++);
    writer = SyncWriter(
      db,
      clock,
      name,
      now: () => DateTime.fromMillisecondsSinceEpoch(now),
    );
    ledger = LedgerRepository(db, writer);
    engine = SyncEngine(db: db, clock: clock, deviceId: name, backend: backend);
  }

  final String name;
  int now = _base;
  late final AppDatabase db;
  late final HlcClock clock;
  late final SyncWriter writer;
  late final LedgerRepository ledger;
  late final SyncEngine engine;

  Future<SyncResult> sync() => engine.sync();
}

/// Every synced table's raw rows, ordered by id.
Future<Map<String, List<Map<String, Object?>>>> dump(AppDatabase db) async => {
  for (final t in syncedTableNames)
    t: await selectRawRows(db, db.tableByName(t), orderBy: 'id'),
};

Future<void> expectConverged(Device a, Device b) async {
  expect(await dump(a.db), await dump(b.db));
}

void main() {
  late InMemorySyncBackend backend;
  late Device a;
  late Device b;

  setUp(() {
    backend = InMemorySyncBackend();
    a = Device('device-a', backend);
    b = Device('device-b', backend);
  });

  tearDown(() async {
    await a.db.close();
    await b.db.close();
  });

  Future<String> account(Device d, String name) => d.writer.insert(
    d.db.accounts,
    AccountsCompanion(
      name: Value(name),
      type: const Value(AccountType.checking),
      openingDate: Value(DateTime(2026)),
    ),
  );

  Future<Account> accountOn(Device d, String id) =>
      (d.db.select(d.db.accounts)..where((x) => x.id.equals(id))).getSingle();

  test('replicates inserts and does not re-log remote changes', () async {
    final id = await account(a, 'Checking');
    final r1 = await a.sync();
    expect(r1.pushed, 1);
    final r2 = await b.sync();
    expect(r2.pulled, 1);
    expect((await accountOn(b, id)).name, 'Checking');
    expect((await accountOn(b, id)).originDeviceId, 'device-a');
    await expectConverged(a, b);

    // Applied remote changes are logged as already synced, never pushed.
    expect(await b.engine.unsyncedCount(), 0);
    expect(await b.engine.push(), 0);
    // B's clock moved past A's HLC.
    final aRow = await accountOn(a, id);
    expect(b.clock.last > Hlc.parse(aRow.updatedAt), isTrue);
  });

  test('concurrent edits of different fields both survive', () async {
    final id = await account(a, 'Checking');
    await a.sync();
    await b.sync();

    await a.writer.update(
      a.db.accounts,
      id,
      const AccountsCompanion(name: Value('Main account')),
    );
    await b.writer.update(
      b.db.accounts,
      id,
      const AccountsCompanion(note: Value('joint')),
    );
    await a.sync();
    await b.sync();
    await a.sync();

    for (final d in [a, b]) {
      final row = await accountOn(d, id);
      expect(row.name, 'Main account');
      expect(row.note, 'joint');
    }
    await expectConverged(a, b);
  });

  test('same field: the later HLC wins regardless of sync order', () async {
    final id = await account(a, 'Checking');
    await a.sync();
    await b.sync();

    // B edits later in (wall-clock) time than A.
    a.now = _base + 10000;
    b.now = _base + 20000;
    await b.writer.update(
      b.db.accounts,
      id,
      const AccountsCompanion(name: Value('from B')),
    );
    await a.writer.update(
      a.db.accounts,
      id,
      const AccountsCompanion(name: Value('from A')),
    );
    // A syncs last, B's change must still win.
    await b.sync();
    await a.sync();
    await b.sync();

    expect((await accountOn(a, id)).name, 'from B');
    expect((await accountOn(b, id)).name, 'from B');
    await expectConverged(a, b);
  });

  test('delete vs later update: the update resurrects the row', () async {
    final id = await account(a, 'Checking');
    await a.sync();
    await b.sync();

    a.now = _base + 10000;
    b.now = _base + 20000;
    await a.writer.delete(a.db.accounts, id);
    await b.writer.update(
      b.db.accounts,
      id,
      const AccountsCompanion(name: Value('still here')),
    );
    await a.sync();
    await b.sync();
    await a.sync();

    for (final d in [a, b]) {
      final row = await accountOn(d, id);
      expect(row.deletedAt, isNull);
      expect(row.name, 'still here');
    }
    await expectConverged(a, b);
  });

  test('later delete wins over an earlier update', () async {
    final id = await account(a, 'Checking');
    await a.sync();
    await b.sync();

    a.now = _base + 20000;
    b.now = _base + 10000;
    await a.writer.delete(a.db.accounts, id);
    await b.writer.update(
      b.db.accounts,
      id,
      const AccountsCompanion(name: Value('edited')),
    );
    await b.sync();
    await a.sync();
    await b.sync();

    for (final d in [a, b]) {
      final row = await accountOn(d, id);
      expect(row.deletedAt, isNotNull);
      // The edit of the other field still merged.
      expect(row.name, 'edited');
    }
    await expectConverged(a, b);
  });

  test('undelete after delete replicates', () async {
    final id = await account(a, 'Checking');
    await a.writer.delete(a.db.accounts, id);
    await a.sync();
    await b.sync();
    expect((await accountOn(b, id)).deletedAt, isNotNull);
    await b.writer.undelete(b.db.accounts, id);
    await b.sync();
    await a.sync();
    expect((await accountOn(a, id)).deletedAt, isNull);
    await expectConverged(a, b);
  });

  group('split sets', () {
    late String acc;
    late String food;
    late String home;
    late String fun;
    late String txn;

    setUp(() async {
      acc = await account(a, 'Checking');
      Future<String> cat(String n) => a.writer.insert(
        a.db.categories,
        CategoriesCompanion(
          name: Value(n),
          kind: const Value(CategoryKind.expense),
        ),
      );
      food = await cat('Food');
      home = await cat('Home');
      fun = await cat('Fun');
      txn = await a.ledger.create(
        TxnDraft(
          accountId: acc,
          amountMinor: -10000,
          date: DateTime(2026, 10, 3),
          payee: 'Market',
          splits: [
            SplitDraft(amountMinor: -6000, categoryId: food),
            SplitDraft(amountMinor: -4000, categoryId: home),
          ],
        ),
      );
      await a.sync();
      await b.sync();
      await expectConverged(a, b);
    });

    Future<List<TxnSplit>> liveSplits(Device d) =>
        (d.db.select(d.db.transactionSplits)
              ..where((s) => s.transactionId.equals(txn) & s.deletedAt.isNull())
              ..orderBy([(s) => OrderingTerm(expression: s.sortOrder)]))
            .get();

    test('replicated as a unit', () async {
      expect((await liveSplits(b)).map((s) => s.amountMinor), [-6000, -4000]);
    });

    test('concurrent edits: the newer set replaces the older one', () async {
      a.now = _base + 10000;
      b.now = _base + 20000;
      final draftA = (await a.ledger.draftFor(txn))!;
      await a.ledger.update(
        txn,
        draftA.copyWith(
          splits: [
            SplitDraft(amountMinor: -5000, categoryId: food),
            SplitDraft(amountMinor: -3000, categoryId: home),
            SplitDraft(amountMinor: -2000, categoryId: fun),
          ],
        ),
      );
      final draftB = (await b.ledger.draftFor(txn))!;
      await b.ledger.update(
        txn,
        draftB.copyWith(
          splits: [
            SplitDraft(amountMinor: -1000, categoryId: fun),
            SplitDraft(amountMinor: -9000, categoryId: food),
          ],
        ),
      );
      await a.sync();
      await b.sync();
      await a.sync();

      for (final d in [a, b]) {
        final splits = await liveSplits(d);
        expect(splits.map((s) => s.amountMinor), [-1000, -9000]);
        expect(splits.map((s) => s.categoryId), [fun, food]);
      }
      await expectConverged(a, b);
    });

    test('the older set loses even when it arrives last', () async {
      a.now = _base + 20000;
      b.now = _base + 10000;
      final draftA = (await a.ledger.draftFor(txn))!;
      await a.ledger.update(
        txn,
        draftA.copyWith(
          splits: [
            SplitDraft(amountMinor: -7000, categoryId: food),
            SplitDraft(amountMinor: -3000, categoryId: fun),
          ],
        ),
      );
      final draftB = (await b.ledger.draftFor(txn))!;
      await b.ledger.update(
        txn,
        draftB.copyWith(splits: const [], categoryId: home),
      );
      await a.sync();
      await b.sync();
      await a.sync();

      for (final d in [a, b]) {
        expect((await liveSplits(d)).map((s) => s.amountMinor), [-7000, -3000]);
      }
      await expectConverged(a, b);
    });
  });

  test('idempotent re-pull', () async {
    final id = await account(a, 'Checking');
    await a.writer.update(
      a.db.accounts,
      id,
      const AccountsCompanion(name: Value('Renamed')),
    );
    await a.sync();
    await b.sync();
    final before = await dump(b.db);
    final logBefore = await b.db.select(b.db.changeLog).get();

    // Forget the cursor and pull everything again.
    await b.db.delete(b.db.syncState).go();
    expect(await b.engine.pull(), 0);
    // Re-applying the same changes directly is a no-op too.
    expect(await b.engine.applyRemote(backend.log), 0);

    expect(await dump(b.db), before);
    expect((await b.db.select(b.db.changeLog).get()).length, logBefore.length);
  });

  test('out-of-order delivery converges', () async {
    final reversing = InMemorySyncBackend(
      deliver: (changes) => changes.reversed.toList(),
    );
    final x = Device('device-x', reversing);
    final y = Device('device-y', reversing);
    addTearDown(() async {
      await x.db.close();
      await y.db.close();
    });

    final id = await account(x, 'Checking');
    await x.writer.update(
      x.db.accounts,
      id,
      const AccountsCompanion(name: Value('Second')),
    );
    await x.writer.update(
      x.db.accounts,
      id,
      const AccountsCompanion(note: Value('n')),
    );
    final other = await account(x, 'Cash');
    await x.writer.delete(x.db.accounts, other);
    await x.sync();
    // y receives update/delete before the inserts.
    await y.sync();

    expect(await dump(y.db), await dump(x.db));
    expect((await accountOn(y, id)).name, 'Second');
    expect((await accountOn(y, other)).deletedAt, isNotNull);
  });

  test('any application order gives the same result', () async {
    final id = await account(a, 'Checking');
    a.now = _base + 1000;
    await a.writer.update(
      a.db.accounts,
      id,
      const AccountsCompanion(name: Value('one')),
    );
    await a.sync();
    b.now = _base + 5000;
    await b.sync();
    await b.writer.update(
      b.db.accounts,
      id,
      const AccountsCompanion(name: Value('two'), note: Value('b')),
    );
    await b.sync();
    final changes = backend.log;

    final c1 = Device('device-c1', const NoopSyncBackend());
    final c2 = Device('device-c2', const NoopSyncBackend());
    addTearDown(() async {
      await c1.db.close();
      await c2.db.close();
    });
    c1.now = c2.now = _base + 6000;
    await c1.engine.applyRemote(changes);
    await c2.engine.applyRemote(changes.reversed);
    expect(await dump(c1.db), await dump(c2.db));
    expect((await accountOn(c1, id)).name, 'two');
  });

  test('rejects remote clocks too far ahead and applies nothing', () async {
    final id = await account(a, 'Checking');
    final remote = Change(
      entity: 'accounts',
      entityId: id,
      op: SyncOp.update,
      hlc: const Hlc(_base + 3600000, 0, 'device-z'),
      fields: const {'name': 'future'},
      originDeviceId: 'device-z',
    );
    await expectLater(
      a.engine.applyRemote([remote]),
      throwsA(isA<ClockDriftException>()),
    );
    expect((await accountOn(a, id)).name, 'Checking');
  });

  test('change JSON round trip', () {
    const c = Change(
      entity: 'accounts',
      entityId: 'x',
      op: SyncOp.update,
      hlc: Hlc(_base, 3, 'd'),
      fields: {
        'name': 'n',
        'archived': true,
        'tags': [1, 2],
      },
      originDeviceId: 'd',
      received: Hlc(4, 0, 'memory'),
    );
    final back = Change.fromJson(c.toJson());
    expect(back, c);
    expect(back.received, c.received);
  });
}
