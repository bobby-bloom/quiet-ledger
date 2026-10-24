import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/transactions/data/txn_list_repository.dart';
import 'package:personal_finance/features/transactions/data/txn_query.dart';
import 'package:personal_finance/features/transactions/domain/txn_filter.dart';
import 'package:personal_finance/features/transactions/domain/txn_grouping.dart';
import 'package:personal_finance/features/transactions/presentation/txn_pager.dart';

import '../../helpers/test_app.dart';
import 'seed.dart';

void main() {
  group('TxnFilter', () {
    final full = TxnFilter(
      search: 'corner',
      payee: 'Corner Grocer',
      accountIds: const {'b', 'a'},
      categoryIds: const {'c1'},
      uncategorized: true,
      tagIds: const {'t1'},
      types: const {TxnType.income, TxnType.expense},
      statuses: const {TxnStatus.pending},
      minAmountMinor: 100,
      maxAmountMinor: 20000,
      datePreset: DatePreset.custom,
      dateFrom: DateTime(2026, 10),
      dateTo: DateTime(2026, 10, 31),
      customFields: const [
        CustomFieldFilter(
          fieldId: 'f1',
          op: CustomFieldOp.contains,
          value: 'R-0',
        ),
      ],
    );

    test('JSON round-trip and stable encoding', () {
      final json = jsonEncode(full.toJson());
      final back = TxnFilter.fromJson(
        (jsonDecode(json) as Map).cast<String, Object?>(),
      );
      expect(back, full);
      expect(back.hashCode, full.hashCode);
      expect(full.toJson()['accounts'], ['a', 'b']);
      expect(full.toJson()['types'], ['expense', 'income']);
      expect(TxnFilter.empty.toJson(), isEmpty);
      expect(TxnFilter.fromJson(const {}), TxnFilter.empty);
    });

    test('unknown enum values are ignored', () {
      final f = TxnFilter.fromJson(const {
        'types': ['expense', 'bogus'],
        'datePreset': 'nope',
      });
      expect(f.types, {TxnType.expense});
      expect(f.datePreset, isNull);
    });

    test('activeCount and isEmpty', () {
      expect(TxnFilter.empty.isEmpty, isTrue);
      expect(const TxnFilter(search: '  ').isEmpty, isTrue);
      expect(const TxnFilter(search: 'x').activeCount, 0);
      expect(full.activeCount, 9);
    });

    test('deep-link query parameters', () {
      final f = TxnFilter.fromQuery(const {
        'account': 'a1,a2',
        'category': 'c1',
        'tag': 't1',
        'payee': ' Corner Grocer ',
        'from': '2026-10-01',
        'to': '2026-10-31',
        'type': 'expense,transfer,bogus',
        'q': 'milk',
      });
      expect(f.accountIds, {'a1', 'a2'});
      expect(f.categoryIds, {'c1'});
      expect(f.tagIds, {'t1'});
      expect(f.payee, 'Corner Grocer');
      expect(f.datePreset, DatePreset.custom);
      expect(f.dateFrom, DateTime(2026, 10));
      expect(f.dateTo, DateTime(2026, 10, 31));
      expect(f.types, {TxnType.expense, TxnType.transfer});
      expect(f.search, 'milk');
      expect(TxnFilter.fromQuery(f.toQuery()), f);
      expect(TxnFilter.fromQuery(const {}).isEmpty, isTrue);
      expect(TxnFilter.fromQuery(const {'from': 'garbage'}).hasDate, isFalse);
    });

    test('deep links: category=none and custom field', () {
      final f = TxnFilter.fromQuery(const {
        'category': 'none,c1',
        'field': 'f1',
        'fieldValue': 'R-0398',
      });
      expect(f.uncategorized, isTrue);
      expect(f.categoryIds, {'c1'});
      expect(f.customFields.single.op, CustomFieldOp.matches);
      expect(f.customFields.single.value, 'R-0398');
      expect(TxnFilter.fromQuery(f.toQuery()), f);
      final any = TxnFilter.fromQuery(const {'field': 'f1'});
      expect(any.customFields.single.op, CustomFieldOp.isSet);
    });

    test('date presets resolve relative to now', () {
      final now = DateTime(2026, 1, 15, 13);
      final m = const TxnFilter(datePreset: DatePreset.lastMonth)
          .dateSpan(now)!;
      expect(m.start, DateTime(2025, 12));
      expect(m.end, DateTime(2026));
      final d = const TxnFilter(datePreset: DatePreset.last30Days)
          .dateSpan(now)!;
      expect(d.start, DateTime(2025, 12, 17));
      expect(d.end, DateTime(2026, 1, 16));
      final c = TxnFilter(
        datePreset: DatePreset.custom,
        dateFrom: DateTime(2026, 1, 3),
      ).dateSpan(now)!;
      expect(c.start, DateTime(2026, 1, 3));
    });

    test('FTS query building', () {
      expect(TxnQuery.ftsQuery('Corner groc'), '"Corner"* "groc"*');
      expect(TxnQuery.ftsQuery('#vacation-2026'), '"vacation"* "2026"*');
      expect(TxnQuery.ftsQuery('café "x'), '"café"* "x"*');
      expect(TxnQuery.ftsQuery('  ** '), '');
      expect(TxnQuery.searchAmount('24,80'), 2480);
      expect(TxnQuery.searchAmount('€12'), 1200);
      expect(TxnQuery.searchAmount('rent 12'), isNull);
    });
  });

  group('grouping', () {
    test('week start honours the first day of week', () {
      final wed = DateTime(2026, 10, 21);
      expect(
        groupStart(wed, TxnGrouping.week, DateTime.monday),
        DateTime(2026, 10, 19),
      );
      expect(
        groupStart(wed, TxnGrouping.week, DateTime.sunday),
        DateTime(2026, 10, 18),
      );
      expect(groupStart(wed, TxnGrouping.month, 1), DateTime(2026, 10));
      expect(groupEnd(DateTime(2026, 12), TxnGrouping.month), DateTime(2027));
      expect(groupingApplies(TxnGrouping.day, TxnSort.amountDesc), isFalse);
    });
  });

  group('TxnListRepository', () {
    late AppDatabase db;
    late Seed s;
    late TxnListRepository repo;
    final now = DateTime(2026, 10, 23);

    Future<String> add(
      int amount,
      DateTime date, {
      String? payee,
      String? note,
      String? category,
      String? account,
      TxnType type = TxnType.expense,
      TxnStatus status = TxnStatus.cleared,
      List<String> tags = const [],
      List<SplitDraft> splits = const [],
      String? to,
      Map<String, Object?> custom = const {},
    }) => s.ledger.create(
      TxnDraft(
        accountId: account ?? s.checking,
        amountMinor: amount,
        date: date,
        payee: payee,
        note: note,
        categoryId: category,
        type: type,
        status: status,
        tagIds: tags,
        splits: splits,
        transferAccountId: to,
        customFields: custom,
      ),
    );

    Future<List<String>> ids(
      TxnFilter f, {
      TxnSort sort = TxnSort.dateDesc,
    }) async => [
      for (final r in await repo.fetch(f, sort: sort, limit: null, now: now))
        r.id,
    ];

    late String grocer;
    late String bakery;
    late String salaryId;
    late String transfer;
    late String split;
    late String pending;

    setUp(() async {
      db = newTestDb();
      s = await Seed.create(db);
      repo = TxnListRepository(db);
      grocer = await add(
        -2480,
        DateTime(2026, 10, 23),
        payee: 'Corner Grocer',
        category: s.groceries,
        custom: {s.receiptField: 'R-0398'},
      );
      bakery = await add(
        -640,
        DateTime(2026, 10, 23),
        payee: 'Daily Bakery',
        category: s.eatingOut,
        note: 'croissants',
      );
      salaryId = await add(
        320000,
        DateTime(2026, 10),
        payee: 'ACME GmbH',
        category: s.salary,
        type: TxnType.income,
      );
      transfer = await add(
        -15000,
        DateTime(2026, 10, 22),
        type: TxnType.transfer,
        to: s.savings,
      );
      split = await add(
        -6312,
        DateTime(2026, 10, 21),
        payee: 'Corner Grocer',
        splits: [
          SplitDraft(amountMinor: -4872, categoryId: s.groceries),
          SplitDraft(amountMinor: -1440, categoryId: s.household),
        ],
        tags: [s.vacationTag],
      );
      pending = await add(
        -3260,
        DateTime(2026, 9, 20),
        payee: 'Thai Garden',
        category: s.eatingOut,
        status: TxnStatus.pending,
      );
    });

    tearDown(() => db.close());

    test('unfiltered: newest first, transfers once', () async {
      expect(await ids(TxnFilter.empty), [
        bakery,
        grocer,
        transfer,
        split,
        salaryId,
        pending,
      ]);
    });

    test('account filter shows the matching transfer leg', () async {
      final savings = await repo.fetch(
        TxnFilter(accountIds: {s.savings}),
        now: now,
      );
      expect(savings, hasLength(1));
      expect(savings.single.amountMinor, 15000);
      expect(savings.single.peerAccountId, s.checking);
      // Both accounts selected: the transfer still appears once.
      final both = await ids(TxnFilter(accountIds: {s.checking, s.savings}));
      expect(both.where((id) => id == transfer), hasLength(1));
      expect(both, hasLength(6));
    });

    test('full-text search with prefixes, category and tag names', () async {
      expect(await ids(const TxnFilter(search: 'corn')), [grocer, split]);
      expect(await ids(const TxnFilter(search: 'corner groc')), [
        grocer,
        split,
      ]);
      expect(await ids(const TxnFilter(search: 'croiss')), [bakery]);
      expect(await ids(const TxnFilter(search: 'eating')), [bakery, pending]);
      expect(await ids(const TxnFilter(search: 'vacation')), [split]);
      expect(await ids(const TxnFilter(search: 'nothing')), isEmpty);
      // A plain amount matches the amount.
      expect(await ids(const TxnFilter(search: '24,80')), [grocer]);
    });

    test('search excludes deleted transactions', () async {
      await s.ledger.delete(bakery);
      expect(await ids(const TxnFilter(search: 'bakery')), isEmpty);
    });

    test('category filter includes split lines and sub-categories', () async {
      expect(await ids(TxnFilter(categoryIds: {s.household})), [split]);
      expect(await ids(TxnFilter(categoryIds: {s.groceries})), [grocer, split]);
      expect(await ids(const TxnFilter(uncategorized: true)), isEmpty);
      final none = await add(-100, DateTime(2026, 10, 5));
      expect(await ids(const TxnFilter(uncategorized: true)), [none]);
    });

    test('tag, type, status, payee and amount filters', () async {
      expect(await ids(TxnFilter(tagIds: {s.vacationTag})), [split]);
      expect(await ids(const TxnFilter(types: {TxnType.income})), [salaryId]);
      expect(await ids(const TxnFilter(types: {TxnType.transfer})), [transfer]);
      expect(await ids(const TxnFilter(statuses: {TxnStatus.pending})), [
        pending,
      ]);
      expect(await ids(const TxnFilter(payee: 'corner grocer')), [
        grocer,
        split,
      ]);
      expect(
        await ids(const TxnFilter(minAmountMinor: 3000, maxAmountMinor: 16000)),
        [transfer, split, pending],
      );
      expect(await ids(const TxnFilter(maxAmountMinor: 700)), [bakery]);
    });

    test('date filter', () async {
      expect(await ids(const TxnFilter(datePreset: DatePreset.lastMonth)), [
        pending,
      ]);
      expect(
        await ids(
          TxnFilter(
            datePreset: DatePreset.custom,
            dateFrom: DateTime(2026, 10, 21),
            dateTo: DateTime(2026, 10, 22),
          ),
        ),
        [transfer, split],
      );
    });

    test('uncategorized: no category and no categorised split line', () async {
      final bare = await add(-100, DateTime(2026, 10, 5));
      final blankSplit = await add(
        -300,
        DateTime(2026, 10, 4),
        splits: const [
          SplitDraft(amountMinor: -100),
          SplitDraft(amountMinor: -200),
        ],
      );
      expect(await ids(const TxnFilter(uncategorized: true)), [
        bare,
        blankSplit,
      ]);
      expect(await ids(TxnFilter.fromQuery(const {'category': 'none'})), [
        bare,
        blankSplit,
      ]);
    });

    test(
      'custom field deep-link matching (text, number, multi-select)',
      () async {
        final num = await s.writer.insert(
          s.db.customFieldDefs,
          const CustomFieldDefsCompanion(
            name: Value('Km'),
            type: Value(CustomFieldType.number),
          ),
        );
        final multi = await s.writer.insert(
          s.db.customFieldDefs,
          const CustomFieldDefsCompanion(
            name: Value('Who'),
            type: Value(CustomFieldType.multiselect),
          ),
        );
        final a = await add(
          -100,
          DateTime(2026, 10, 6),
          custom: {
            num: 12.5,
            multi: ['Ann', 'Bob'],
          },
        );
        final b = await add(
          -100,
          DateTime(2026, 10, 7),
          custom: {
            multi: ['Bobby'],
          },
        );
        Future<List<String>> q(Map<String, String> p) =>
            ids(TxnFilter.fromQuery(p));
        expect(await q({'field': s.receiptField, 'fieldValue': 'R-0398'}), [
          grocer,
        ]);
        expect(await q({'field': num, 'fieldValue': '12.5'}), [a]);
        expect(await q({'field': multi, 'fieldValue': 'Bob'}), [a]);
        expect(await q({'field': multi, 'fieldValue': 'Bobby'}), [b]);
        expect(await q({'field': multi}), [b, a]);
      },
    );

    test('custom field filter', () async {
      final f = s.receiptField;
      expect(
        await ids(TxnFilter(customFields: [CustomFieldFilter(fieldId: f)])),
        [grocer],
      );
      expect(
        await ids(
          TxnFilter(
            customFields: [
              CustomFieldFilter(
                fieldId: f,
                op: CustomFieldOp.contains,
                value: 'r-03',
              ),
            ],
          ),
        ),
        [grocer],
      );
      expect(
        await ids(
          TxnFilter(
            customFields: [
              CustomFieldFilter(
                fieldId: f,
                op: CustomFieldOp.equals,
                value: 'R-0398',
              ),
            ],
          ),
        ),
        [grocer],
      );
      expect(
        await ids(
          TxnFilter(
            customFields: [
              CustomFieldFilter(
                fieldId: f,
                op: CustomFieldOp.equals,
                value: 'X',
              ),
            ],
          ),
        ),
        isEmpty,
      );
    });

    test('keyset pagination is stable for every sort order', () async {
      // Many rows with equal dates/amounts/payees to exercise tie-breaking.
      for (var i = 0; i < 37; i++) {
        await add(
          -(i % 4) * 100 - 100,
          DateTime(2026, 8, 1 + i % 3),
          payee: i.isEven ? 'Same' : null,
          category: s.groceries,
        );
      }
      for (final sort in TxnSort.values) {
        final all = await ids(TxnFilter.empty, sort: sort);
        final paged = <String>[];
        TxnCursor? after;
        while (true) {
          final page = await repo.fetch(
            TxnFilter.empty,
            sort: sort,
            after: after,
            limit: 5,
            now: now,
          );
          paged.addAll(page.map((r) => r.id));
          if (page.length < 5) break;
          after = page.last.cursor;
        }
        expect(paged, all, reason: '$sort');
        expect(paged.toSet(), hasLength(all.length), reason: '$sort');

        // Reloading a page by its bounds returns exactly that page.
        final first = await repo.fetch(
          TxnFilter.empty,
          sort: sort,
          limit: 7,
          now: now,
        );
        final second = await repo.fetch(
          TxnFilter.empty,
          sort: sort,
          after: first.last.cursor,
          limit: 7,
          now: now,
        );
        final reloaded = await repo.fetch(
          TxnFilter.empty,
          sort: sort,
          after: first.last.cursor,
          upTo: second.last.cursor,
          limit: null,
          now: now,
        );
        expect(
          reloaded.map((r) => r.id),
          second.map((r) => r.id),
          reason: '$sort',
        );
      }
    });

    test('sort orders', () async {
      expect(
        (await ids(TxnFilter.empty, sort: TxnSort.amountDesc)).first,
        salaryId,
      );
      expect(
        (await ids(TxnFilter.empty, sort: TxnSort.amountAsc)).first,
        bakery,
      );
      expect(
        (await ids(TxnFilter.empty, sort: TxnSort.dateAsc)).first,
        pending,
      );
      // Payee A→Z, rows without payee first ('' sorts first).
      final byPayee = await repo.fetch(
        TxnFilter.empty,
        sort: TxnSort.payee,
        limit: null,
        now: now,
      );
      expect(byPayee.map((r) => r.payee), [
        null,
        'ACME GmbH',
        'Corner Grocer',
        'Corner Grocer',
        'Daily Bakery',
        'Thai Garden',
      ]);
    });

    test('running balance for a single account', () async {
      final rows = await repo.fetch(
        TxnFilter(accountIds: {s.checking}),
        runningBalance: true,
        limit: null,
        now: now,
      );
      // Opening 1000.00; oldest first: −32.60, +3200, −63.12, −150, −24.80/−6.40.
      final byId = {for (final r in rows) r.id: r.runningBalance};
      expect(byId[pending], 100000 - 3260);
      expect(byId[salaryId], 100000 - 3260 + 320000);
      expect(byId[transfer], 100000 - 3260 + 320000 - 6312 - 15000);
      expect(
        rows.first.runningBalance,
        100000 - 3260 + 320000 - 6312 - 15000 - 2480 - 640,
      );
      // Not applicable without a single account.
      final none = await repo.fetch(
        TxnFilter.empty,
        runningBalance: true,
        now: now,
      );
      expect(none.every((r) => r.runningBalance == null), isTrue);
    });

    test(
      'totals and day sums exclude transfers unless filtered to accounts',
      () async {
        final t = await repo.watchTotals(TxnFilter.empty, now: now).first;
        expect(t.count, 6);
        expect(t.inMinor, 320000);
        expect(t.outMinor, -(2480 + 640 + 6312 + 3260));
        final acc = await repo
            .watchTotals(TxnFilter(accountIds: {s.checking}), now: now)
            .first;
        expect(acc.outMinor, -(2480 + 640 + 6312 + 3260 + 15000));
        final days = await repo.daySums(
          TxnFilter.empty,
          DateTime(2026, 10, 20),
          DateTime(2026, 10, 24),
          now: now,
        );
        expect(days[DateTime(2026, 10, 23)], -(2480 + 640));
        expect(days.containsKey(DateTime(2026, 10, 22)), isFalse);
        expect(days[DateTime(2026, 10, 21)], -6312);
      },
    );

    test('pager loads keyset pages and reloads them live', () async {
      for (var i = 0; i < 25; i++) {
        await add(-100 - i, DateTime(2026, 7, 1 + i), payee: 'P$i');
      }
      final pager = TxnPager(
        repository: repo,
        filter: TxnFilter.empty,
        sort: TxnSort.dateDesc,
        grouping: TxnGrouping.month,
        firstDayOfWeek: DateTime.monday,
        pageSize: 10,
      );
      addTearDown(pager.dispose);
      Future<void> idle() =>
          Future<void>.delayed(const Duration(milliseconds: 120));
      await idle();
      expect(pager.items, hasLength(10));
      expect(pager.hasMore, isTrue);
      await pager.loadMore();
      await pager.loadMore();
      await pager.loadMore();
      expect(pager.items, hasLength(31));
      expect(pager.hasMore, isFalse);
      // Group sums cover whole months.
      expect(
        pager.groupSums[DateTime(2026, 10)],
        -(2480 + 640 + 6312) + 320000,
      );

      // Insert into the middle of a loaded page and delete another row.
      final mid = await add(-777, DateTime(2026, 7, 10, 12), payee: 'Mid');
      await s.ledger.delete(bakery);
      await idle();
      final shown = pager.items.map((r) => r.id).toList();
      expect(shown, contains(mid));
      expect(shown, isNot(contains(bakery)));
      expect(shown, hasLength(31));
      expect(shown, await ids(TxnFilter.empty));
    });

    test('row details: splits, tags, attachments flags', () async {
      final rows = await repo.fetch(TxnFilter.empty, limit: null, now: now);
      final sp = rows.firstWhere((r) => r.id == split);
      expect(sp.splitCount, 2);
      expect(sp.splitCategoryIds, containsAll([s.groceries, s.household]));
      expect(sp.tagIds, [s.vacationTag]);
      final tr = rows.firstWhere((r) => r.id == transfer);
      expect(tr.isTransfer, isTrue);
      expect(tr.editId, transfer);
    });
  });
}
