import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/calendar/holidays.dart';
import 'package:personal_finance/core/calendar/recurrence.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/recurring/data/recurring_repository.dart';
import 'package:personal_finance/features/recurring/domain/recurring_logic.dart';

import '../../helpers/test_app.dart';
import '../plan/plan_fixtures.dart';

void main() {
  late AppDatabase db;
  late PlanFixture f;
  late RecurringRepository repo;
  late String checking;
  late String savings;
  late String rent;
  final none = HolidayCalendar.none();
  final de = HolidayCalendar(country: 'DE');

  setUp(() async {
    db = newTestDb();
    f = PlanFixture(db);
    final writer = SyncWriter(db, testClock(), 'test');
    repo = RecurringRepository(db, writer, LedgerRepository(db, writer));
    checking = await f.account('Checking');
    savings = await f.account('Savings');
    rent = await f.category('Rent');
  });

  tearDown(() => db.close());

  RecurringRuleDraft rule({
    String rrule = 'FREQ=MONTHLY;INTERVAL=1;BYMONTHDAY=1',
    DateTime? start,
    int amount = -100000,
    PostingMode mode = PostingMode.autoPost,
    WeekendShift shift = WeekendShift.none,
    int? count,
    List<SplitDraft> splits = const [],
    TxnType type = TxnType.expense,
    String? transferTo,
  }) => RecurringRuleDraft(
    name: 'Rent',
    rrule: rrule,
    startDate: start ?? DateTime(2026),
    count: count,
    postingMode: mode,
    weekendShift: shift,
    template: TxnDraft(
      accountId: checking,
      amountMinor: amount,
      date: DateTime(2026),
      type: type,
      categoryId: splits.isEmpty && type != TxnType.transfer ? rent : null,
      transferAccountId: transferTo,
      splits: splits,
      payee: 'Landlord',
    ),
  );

  Future<List<Txn>> posted(String ruleId) =>
      (db.select(db.transactions)
            ..where(
              (t) => t.recurringRuleId.equals(ruleId) & t.deletedAt.isNull(),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.date)]))
          .get();

  test('auto-post is idempotent: running twice posts once', () async {
    final id = await repo.create(rule());
    final r1 = await repo.postDue(today: DateTime(2026, 3, 15), calendar: none);
    expect(r1.posted, 3);
    expect(r1.rules, {id});
    final r2 = await repo.postDue(today: DateTime(2026, 3, 15), calendar: none);
    expect(r2.posted, 0);
    final txns = await posted(id);
    expect(txns.map((t) => t.date), [
      DateTime(2026),
      DateTime(2026, 2),
      DateTime(2026, 3),
    ]);
    expect(txns.every((t) => t.amountMinor == -100000), isTrue);
    expect(txns.first.payee, 'Landlord');
    expect(txns.first.categoryId, rent);
    expect((await repo.ruleById(id))!.lastPostedDate, DateTime(2026, 3));

    // Next month only the new occurrence is posted.
    final r3 = await repo.postDue(today: DateTime(2026, 4), calendar: none);
    expect(r3.posted, 1);
    expect((await posted(id)).length, 4);
  });

  test('remind & confirm rules are not auto-posted', () async {
    final id = await repo.create(rule(mode: PostingMode.remindConfirm));
    final r = await repo.postDue(today: DateTime(2026, 3, 15), calendar: none);
    expect(r.posted, 0);
    final plan = (await repo.planById(id))!;
    final pending = plan.pending(DateTime(2026, 3, 15), none);
    expect(pending.length, 3);

    // Confirm the first with an edited amount and date, skip the second.
    await repo.confirm(
      plan,
      pending[0],
      amountMinor: -99000,
      date: DateTime(2026, 1, 2),
    );
    var p = (await repo.planById(id))!;
    await repo.skip(p, p.pending(DateTime(2026, 3, 15), none).first);
    p = (await repo.planById(id))!;
    final rest = p.pending(DateTime(2026, 3, 15), none);
    expect(rest.single.date, DateTime(2026, 3));
    final txns = await posted(id);
    expect(txns.single.amountMinor, -99000);
    expect(txns.single.date, DateTime(2026, 1, 2));
    expect(p.lastPostedDate, DateTime(2026, 2));
  });

  test('amount change mid-series keeps past postings unchanged', () async {
    final id = await repo.create(rule());
    await repo.postDue(today: DateTime(2026, 2, 15), calendar: none);
    await repo.addAmountChange(id, DateTime(2026, 3), -110000);
    await repo.postDue(today: DateTime(2026, 4, 15), calendar: none);
    final amounts = [for (final t in await posted(id)) t.amountMinor];
    expect(amounts, [-100000, -100000, -110000, -110000]);
    // Same date again replaces the amount instead of adding a duplicate.
    await repo.addAmountChange(id, DateTime(2026, 3), -120000);
    final plan = (await repo.planById(id))!;
    expect(plan.amountChanges, {DateTime(2026, 3): -120000});
    expect(amounts.length, (await posted(id)).length);
  });

  test('month-end clamp: the 31st falls back to the last day', () async {
    final id = await repo.create(
      rule(rrule: RRules.clampMonthDay(31), start: DateTime(2026, 1, 31)),
    );
    await repo.postDue(today: DateTime(2026, 5), calendar: none);
    expect(
      [for (final t in await posted(id)) t.date],
      [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
      ],
    );
  });

  test(
    'holiday shift: 3 Oct 2026 (Saturday, holiday) moves to 5 Oct',
    () async {
      final id = await repo.create(
        rule(
          rrule: 'FREQ=MONTHLY;BYMONTHDAY=3',
          start: DateTime(2026, 9, 3),
          shift: WeekendShift.next,
        ),
      );
      await repo.postDue(today: DateTime(2026, 10, 4), calendar: de);
      expect(
        [for (final t in await posted(id)) t.date],
        [DateTime(2026, 9, 3)],
      );
      await repo.postDue(today: DateTime(2026, 10, 5), calendar: de);
      expect(
        [for (final t in await posted(id)) t.date],
        [DateTime(2026, 9, 3), DateTime(2026, 10, 5)],
      );
      // Amount changes apply by scheduled date even when shifted.
      final plan = (await repo.planById(id))!;
      final occ = plan.occurrences(
        DateTime(2026, 10),
        DateTime(2026, 10, 31),
        de,
      );
      expect(occ.single.scheduled, DateTime(2026, 10, 3));
    },
  );

  test('count limits the series', () async {
    final id = await repo.create(rule(count: 2));
    await repo.postDue(today: DateTime(2026, 12, 31), calendar: none);
    expect((await posted(id)).length, 2);
  });

  test(
    'splits are scaled to changed amounts; transfers post two legs',
    () async {
      final food = await f.category('Food');
      final id = await repo.create(
        rule(
          splits: [
            SplitDraft(amountMinor: -60000, categoryId: rent),
            SplitDraft(amountMinor: -40000, categoryId: food),
          ],
        ),
      );
      await repo.addAmountChange(id, DateTime(2026), -50000);
      await repo.postDue(today: DateTime(2026), calendar: none);
      final t = (await posted(id)).single;
      final splits = await (db.select(
        db.transactionSplits,
      )..where((s) => s.transactionId.equals(t.id))).get();
      expect(splits.map((s) => s.amountMinor).toList()..sort(), [
        -30000,
        -20000,
      ]);

      final tr = await repo.create(
        rule(type: TxnType.transfer, transferTo: savings, amount: -20000),
      );
      await repo.postDue(today: DateTime(2026), calendar: none);
      final legs = await posted(tr);
      expect(legs.length, 2);
      expect(legs.map((l) => l.amountMinor).toSet(), {-20000, 20000});
    },
  );

  test('deleted and paused rules do not post', () async {
    final a = await repo.create(rule());
    final b = await repo.create(rule());
    await repo.delete(a);
    await repo.setActive(b, false);
    final r = await repo.postDue(today: DateTime(2026, 3), calendar: none);
    expect(r.posted, 0);
  });

  test('scaleSplits keeps the total exact', () {
    final s = scaleSplits(
      const [
        SplitDraft(amountMinor: -333),
        SplitDraft(amountMinor: -333),
        SplitDraft(amountMinor: -334),
      ],
      -1000,
      -1001,
    );
    expect(s.fold(0, (a, x) => a + x.amountMinor), -1001);
  });

  test('validation rejects incomplete rules', () {
    final bad = RecurringRuleDraft(
      name: ' ',
      rrule: 'FREQ=NOPE',
      startDate: DateTime(2026),
      endDate: DateTime(2025),
      template: TxnDraft(accountId: '', amountMinor: 0, date: DateTime(2026)),
    );
    expect(
      bad.validate(),
      containsAll(['name', 'rrule', 'amount', 'endBeforeStart', 'accountId']),
    );
    expect(() => repo.create(bad), throwsArgumentError);
  });
}
