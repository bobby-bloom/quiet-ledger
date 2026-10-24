import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/calendar/holidays.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/budgets/domain/outstanding.dart';
import 'package:personal_finance/features/recurring/domain/recurring_logic.dart';

void main() {
  final nov = DateRange(DateTime(2026, 11), DateTime(2026, 12));
  final calendar = HolidayCalendar.none();
  const checking = 'checking';

  RecurringPlan plan(
    String id,
    String rrule,
    int amount, {
    String? categoryId = 'rent',
    List<SplitDraft> splits = const [],
    PostingMode mode = PostingMode.remindConfirm,
    DateTime? lastPosted,
    TxnType type = TxnType.expense,
    String account = checking,
    bool active = true,
    Map<DateTime, int> changes = const {},
    WeekendShift shift = WeekendShift.none,
  }) => RecurringPlan(
    id: id,
    name: id,
    rrule: rrule,
    start: DateTime(2026),
    template: TxnDraft(
      accountId: account,
      amountMinor: amount,
      date: DateTime(2026),
      type: type,
      categoryId: splits.isEmpty ? categoryId : null,
      transferAccountId: type == TxnType.transfer ? 'savings' : null,
      splits: splits,
    ),
    mode: mode,
    lastPostedDate: lastPosted,
    active: active,
    amountChanges: changes,
    shift: shift,
  );

  List<OutstandingItem> expand(
    List<RecurringPlan> plans, {
    DateTime? today,
    Set<(String, DateTime)> posted = const {},
    Set<String> accounts = const {checking},
  }) => recurringOutstanding(
    plans: plans,
    range: nov,
    today: today ?? DateTime(2026, 10, 20),
    calendar: calendar,
    budgetAccountIds: accounts,
    posted: posted,
  );

  test('expands pending occurrences in the period with their amount', () {
    final items = expand([
      plan(
        'gym',
        'FREQ=WEEKLY;BYDAY=MO',
        -2000,
        categoryId: 'sport',
        changes: {DateTime(2026, 11, 15): -2500},
      ),
    ]);
    expect(items.map((i) => i.date.day), [2, 9, 16, 23, 30]);
    expect(items.map((i) => i.amountMinor), [
      -2000,
      -2000,
      -2500,
      -2500,
      -2500,
    ]);
    expect(items.first.source, OutstandingSource.recurring);
    expect(items.first.categoryId, 'sport');
    expect(items.first.overdue, isFalse);
    expect(items.first.plan?.id, 'gym');
  });

  test('splits the amount over the template splits', () {
    final items = expand([
      plan(
        'insurance',
        'FREQ=MONTHLY;BYMONTHDAY=1',
        -10000,
        splits: const [
          SplitDraft(amountMinor: -6000, categoryId: 'car'),
          SplitDraft(amountMinor: -4000, categoryId: 'home'),
        ],
        changes: {DateTime(2026, 11): -12000},
      ),
    ]);
    expect(items.map((i) => (i.categoryId, i.amountMinor)), [
      ('car', -7200),
      ('home', -4800),
    ]);
    expect(items.every((i) => i.isSplit), isTrue);
  });

  test('skips posted, inactive, transfer and non-budget rules', () {
    final items = expand(
      [
        plan(
          'posted',
          'FREQ=MONTHLY;BYMONTHDAY=5',
          -100,
          lastPosted: DateTime(2026, 11, 5),
        ),
        plan('inactive', 'FREQ=MONTHLY;BYMONTHDAY=5', -100, active: false),
        plan(
          'transfer',
          'FREQ=MONTHLY;BYMONTHDAY=5',
          -100,
          type: TxnType.transfer,
        ),
        plan('other', 'FREQ=MONTHLY;BYMONTHDAY=5', -100, account: 'business'),
        plan('booked', 'FREQ=MONTHLY;BYMONTHDAY=7', -100),
        plan('kept', 'FREQ=MONTHLY;BYMONTHDAY=9', -100),
      ],
      posted: {('booked', DateTime(2026, 11, 7))},
    );
    expect(items.map((i) => i.plan!.id), ['kept']);
  });

  test('auto-post keeps only future occurrences, remind & confirm keeps '
      'overdue ones', () {
    final today = DateTime(2026, 11, 10);
    final items = expand([
      plan(
        'auto',
        'FREQ=WEEKLY;BYDAY=MO',
        -100,
        mode: PostingMode.autoPost,
        lastPosted: DateTime(2026, 10, 26),
      ),
      plan(
        'remind',
        'FREQ=MONTHLY;BYMONTHDAY=3',
        -100,
        lastPosted: DateTime(2026, 10, 3),
      ),
    ], today: today);
    final auto = items.where((i) => i.plan!.id == 'auto');
    expect(auto.map((i) => i.date.day), [16, 23, 30]);
    final remind = items.singleWhere((i) => i.plan!.id == 'remind');
    expect(remind.date, DateTime(2026, 11, 3));
    expect(remind.overdue, isTrue);
  });

  test('uses the shifted date for the period edge', () {
    // 31 Oct 2026 is a Saturday: moved to Monday 2 Nov.
    final items = expand([
      plan(
        'loan',
        'FREQ=MONTHLY;BYMONTHDAY=31',
        -100,
        shift: WeekendShift.next,
      ),
    ]);
    expect(items.map((i) => i.date), [DateTime(2026, 11, 2)]);
  });

  test('PeriodPlanned aggregates like the actuals', () {
    final d = DateTime(2026, 11, 3);
    OutstandingItem item(String? cat, int amount, TxnType type) =>
        OutstandingItem(
          source: OutstandingSource.planned,
          date: d,
          amountMinor: amount,
          type: type,
          accountId: checking,
          overdue: false,
          categoryId: cat,
        );
    final p = PeriodPlanned.fromItems(
      [
        item('groceries', -3000, TxnType.expense),
        item('food', -1000, TxnType.expense),
        item('food', 500, TxnType.expense), // refund
        item('salary', 250000, TxnType.income),
        item(null, -700, TxnType.expense),
        item(null, 1200, TxnType.income),
        item('deleted', -50, TxnType.expense),
      ],
      const {
        'groceries': CategoryKind.expense,
        'food': CategoryKind.expense,
        'salary': CategoryKind.income,
      },
    );
    expect(p.spentOf('food', ['groceries']), 3500);
    expect(p.spentOf('groceries'), 3000);
    expect(p.incomeMinor, 251200);
    expect(p.uncategorizedSpentMinor, 750);
    expect(p.itemsFor({'food'}), hasLength(2));
    expect(PeriodPlanned.empty.isEmpty, isTrue);
  });
}
