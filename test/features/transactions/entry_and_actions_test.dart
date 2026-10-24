import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/transactions/data/entry_repository.dart';
import 'package:personal_finance/features/transactions/data/saved_filters_repository.dart';
import 'package:personal_finance/features/transactions/data/templates_repository.dart';
import 'package:personal_finance/features/transactions/data/txn_actions.dart';
import 'package:personal_finance/features/transactions/domain/txn_filter.dart';

import '../../helpers/test_app.dart';
import 'seed.dart';

void main() {
  late AppDatabase db;
  late Seed s;

  setUp(() async {
    db = newTestDb();
    s = await Seed.create(db);
  });

  tearDown(() => db.close());

  TxnDraft draft(
    int amount, {
    String? payee,
    String? category,
    String? account,
    DateTime? date,
    TxnType type = TxnType.expense,
    String? to,
    List<SplitDraft> splits = const [],
  }) => TxnDraft(
    accountId: account ?? s.checking,
    amountMinor: amount,
    date: date ?? DateTime(2026, 10),
    payee: payee,
    categoryId: category,
    type: type,
    transferAccountId: to,
    splits: splits,
  );

  group('payee suggestions', () {
    test('learn the latest category and account per payee', () async {
      final repo = EntryRepository(db);
      await s.ledger.create(
        draft(
          -1000,
          payee: 'Corner Grocer',
          category: s.eatingOut,
          date: DateTime(2026, 9),
        ),
      );
      await s.ledger.create(
        draft(
          -2000,
          payee: 'Corner Grocer',
          category: s.groceries,
          account: s.savings,
          date: DateTime(2026, 10),
        ),
      );
      await s.ledger.create(
        draft(-300, payee: 'Corner Café', category: s.eatingOut),
      );

      final list = await repo.suggestPayees('corn');
      expect(list.map((p) => p.payee), ['Corner Grocer', 'Corner Café']);
      expect(list.first.count, 2);
      expect(list.first.categoryId, s.groceries);
      expect(list.first.accountId, s.savings);

      expect((await repo.suggestPayees('groc')).single.payee, 'Corner Grocer');
      expect(await repo.suggestPayees(''), isEmpty);
      // Notes are not payees.
      expect(await repo.suggestPayees('nothing'), isEmpty);

      final last = await repo.lastForPayee('corner GROCER');
      expect(last?.categoryId, s.groceries);
      expect(last?.accountId, s.savings);
      expect(await repo.lastForPayee('Unknown'), isNull);
    });

    test('deleted entries are forgotten', () async {
      final repo = EntryRepository(db);
      final id = await s.ledger.create(
        draft(-100, payee: 'Gone', category: s.groceries),
      );
      expect(await repo.suggestPayees('gone'), hasLength(1));
      await s.ledger.delete(id);
      expect(await repo.suggestPayees('gone'), isEmpty);
      expect(await repo.lastForPayee('Gone'), isNull);
    });

    test('recent categories include split lines, newest first', () async {
      final repo = EntryRepository(db);
      await s.ledger.create(draft(-100, category: s.eatingOut));
      await s.ledger.create(
        draft(
          -300,
          splits: [
            SplitDraft(amountMinor: -100, categoryId: s.household),
            SplitDraft(amountMinor: -200, categoryId: s.household),
          ],
        ),
      );
      await s.ledger.create(draft(-100, category: s.groceries));
      expect(await repo.watchRecentCategories(limit: 5).first, [
        s.groceries,
        s.household,
        s.eatingOut,
      ]);
      expect(await repo.watchRecentCategories(limit: 1).first, [s.groceries]);
      expect(await repo.watchRecentCategories(limit: 0).first, isEmpty);
    });
  });

  group('TxnActions', () {
    late TxnActions actions;
    setUp(() => actions = TxnActions(s.ledger));

    test('bulk edit and undo', () async {
      final a = await s.ledger.create(draft(-1000, category: s.groceries));
      final b = await s.ledger.create(draft(-2000, category: s.eatingOut));
      final snap = await actions.bulkUpdate(
        [a, b],
        categoryId: s.household,
        status: TxnStatus.pending,
        date: DateTime(2026, 10, 15),
        addTagIds: [s.vacationTag],
      );
      for (final id in [a, b]) {
        final t = (await s.ledger.txnById(id))!;
        expect(t.categoryId, s.household);
        expect(t.status, TxnStatus.pending);
        expect(t.date, DateTime(2026, 10, 15));
        expect(await s.ledger.tagIdsFor(id), [s.vacationTag]);
      }

      await actions.restoreSnapshot(snap);
      final ta = (await s.ledger.txnById(a))!;
      final tb = (await s.ledger.txnById(b))!;
      expect(ta.categoryId, s.groceries);
      expect(tb.categoryId, s.eatingOut);
      expect(ta.status, TxnStatus.cleared);
      expect(ta.date, DateTime(2026, 10));
      expect(await s.ledger.tagIdsFor(a), isEmpty);
    });

    test('bulk category on a split transaction replaces the split', () async {
      final id = await s.ledger.create(
        draft(
          -300,
          splits: [
            SplitDraft(amountMinor: -100, categoryId: s.groceries),
            SplitDraft(amountMinor: -200, categoryId: s.household),
          ],
        ),
      );
      final snap = await actions.bulkUpdate([id], categoryId: s.eatingOut);
      expect((await s.ledger.txnById(id))!.categoryId, s.eatingOut);
      expect(await s.ledger.splitsFor(id), isEmpty);
      await actions.restoreSnapshot(snap);
      expect(await s.ledger.splitsFor(id), hasLength(2));
      expect((await s.ledger.txnById(id))!.categoryId, isNull);
    });

    test('bulk status on the incoming transfer leg, then undo', () async {
      final out = await s.ledger.create(
        draft(-5000, type: TxnType.transfer, to: s.savings),
      );
      final incoming = (await s.ledger.txnById(out))!.transferPeerId!;
      expect(await actions.editableId(incoming), out);
      final snap = await actions.bulkUpdate([
        incoming,
      ], status: TxnStatus.planned);
      expect((await s.ledger.txnById(out))!.status, TxnStatus.planned);
      await actions.restoreSnapshot(snap);
      final o = (await s.ledger.txnById(out))!;
      final i = (await s.ledger.txnById(incoming))!;
      expect(o.status, TxnStatus.cleared);
      expect(i.status, TxnStatus.cleared);
      expect(o.accountId, s.checking);
      expect(i.accountId, s.savings);
      expect(i.amountMinor, 5000);
    });

    test('delete and undo, toggle cleared and undo', () async {
      final a = await s.ledger.create(draft(-1000, category: s.groceries));
      final b = await s.ledger.create(draft(-2000));
      final deleted = await actions.delete([a, b, a]);
      expect(deleted, [a, b]);
      expect(await s.ledger.txnById(a), isNull);
      await actions.undoDelete(deleted);
      expect(await s.ledger.txnById(a), isNotNull);
      expect(await s.ledger.txnById(b), isNotNull);

      final snap = await actions.toggleCleared(a);
      expect((await s.ledger.txnById(a))!.status, TxnStatus.pending);
      await actions.restoreSnapshot(snap);
      expect((await s.ledger.txnById(a))!.status, TxnStatus.cleared);
    });

    test('duplicate copies the draft with a new date', () async {
      final a = await s.ledger.create(
        draft(-1234, payee: 'X', category: s.groceries),
      );
      final copy = await actions.duplicate(a, date: DateTime(2026, 10, 20));
      final t = (await s.ledger.txnById(copy!))!;
      expect(t.payee, 'X');
      expect(t.amountMinor, -1234);
      expect(t.date, DateTime(2026, 10, 20));
    });
  });

  group('saved filters and templates', () {
    test('saved filter CRUD keeps the JSON', () async {
      final repo = SavedFiltersRepository(db, s.writer);
      final f = TxnFilter(
        accountIds: {s.checking},
        statuses: const {TxnStatus.pending},
        datePreset: DatePreset.thisMonth,
      );
      final id = await repo.create('Pending', f);
      final second = await repo.create(
        'Big',
        const TxnFilter(minAmountMinor: 20000),
      );
      var all = await repo.watchAll().first;
      expect(all.map((x) => x.name), ['Pending', 'Big']);
      expect(decodeSavedFilter(all.first), f);

      await repo.update(
        id,
        name: 'Open',
        filter: f.copyWith(search: 'x'),
      );
      await repo.reorder([second, id]);
      all = await repo.watchAll().first;
      expect(all.map((x) => x.name), ['Big', 'Open']);
      expect(decodeSavedFilter(all.last).search, 'x');

      await repo.delete(id);
      expect(await repo.watchAll().first, hasLength(1));
      await repo.restore(id);
      expect(await repo.byId(id), isNotNull);
    });

    test('templates store the draft JSON without bookkeeping', () async {
      final repo = TemplatesRepository(db, s.writer);
      final d = draft(
        -4500,
        payee: 'Rent',
        category: s.household,
      ).copyWith(importBatchId: 'batch', recurringRuleId: 'rule');
      final id = await repo.create('Rent', d);
      final t = (await repo.byId(id))!;
      final back = templateDraft(t)!;
      expect(back.payee, 'Rent');
      expect(back.amountMinor, -4500);
      expect(back.categoryId, s.household);
      expect(back.importBatchId, isNull);
      expect(back.recurringRuleId, isNull);
      await repo.delete(id);
      expect(await repo.watchAll().first, isEmpty);
    });
  });
}
