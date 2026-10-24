import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/calendar/holidays.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/platform/notifications.dart';
import 'package:personal_finance/features/plan/plan_providers.dart';
import 'package:personal_finance/features/recurring/data/recurring_providers.dart';
import 'package:personal_finance/features/recurring/data/recurring_repository.dart';
import 'package:personal_finance/features/recurring/data/reminders.dart';
import 'package:personal_finance/l10n/generated/app_localizations_en.dart';

import '../../helpers/test_app.dart';
import '../plan/plan_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProviderContainer c;
  late PlanFixture f;
  late String checking;
  final today = DateTime(2026, 10, 23);

  setUp(() async {
    db = newTestDb();
    f = PlanFixture(db);
    c = testContainer(
      db,
      overrides: [
        planTodayProvider.overrideWithValue(today),
        notificationServiceProvider.overrideWithValue(
          const NoopNotificationService(),
        ),
      ],
    );
    checking = await f.account('Checking');
    c.listen(accountsProvider, (_, _) {});
    await c.read(accountsProvider.future);
  });

  tearDown(() async {
    c.dispose();
    await db.close();
  });

  Future<String> rule(
    String name,
    String rrule,
    int amount, {
    PostingMode mode = PostingMode.autoPost,
    TxnType type = TxnType.expense,
    DateTime? start,
    int remindDays = 2,
  }) => c
      .read(recurringRepositoryProvider)
      .create(
        RecurringRuleDraft(
          name: name,
          rrule: rrule,
          startDate: start ?? DateTime(2026, 10),
          postingMode: mode,
          remindDaysBefore: remindDays,
          template: TxnDraft(
            accountId: checking,
            amountMinor: amount,
            date: today,
            type: type,
          ),
        ),
      );

  test(
    'upcomingOccurrencesProvider lists pending items in the window',
    () async {
      await rule('Mobile', 'FREQ=MONTHLY;BYMONTHDAY=28', -1999);
      await rule(
        'Rent',
        'FREQ=MONTHLY;BYMONTHDAY=1',
        -98000,
        mode: PostingMode.remindConfirm,
      );
      await rule(
        'Salary',
        'FREQ=MONTHLY;BYMONTHDAY=25',
        342000,
        type: TxnType.income,
      );
      final sub = c.listen(upcomingOccurrencesProvider(14), (_, _) {});
      final list = await c.read(upcomingOccurrencesProvider(14).future);
      // Rent of 1 Oct is overdue (remind & confirm) and still listed.
      expect(list.map((u) => '${u.name} ${u.date.month}/${u.date.day}'), [
        'Rent 10/1',
        'Salary 10/25',
        'Mobile 10/28',
        'Rent 11/1',
      ]);
      expect(list.first.isOverdue, isTrue);
      expect(list.first.account?.id, checking);
      expect(list[1].amountMinor, 342000);
      expect(list[1].postingMode, PostingMode.autoPost);
      sub.close();
    },
  );

  test('due list shows the earliest pending occurrence per rule', () async {
    final id = await rule(
      'Rent',
      'FREQ=WEEKLY;BYDAY=MO',
      -1000,
      mode: PostingMode.remindConfirm,
      start: DateTime(2026, 10, 5),
    );
    final sub = c.listen(dueOccurrencesProvider, (_, _) {});
    var due = await c.read(dueOccurrencesProvider.future);
    expect(due.single.occurrence.date, DateTime(2026, 10, 5));
    // 12 and 19 Oct are also due; 26 Oct is within the 2-day lead time but
    // not yet due.
    expect(due.single.morePending, 2);

    final repo = c.read(recurringRepositoryProvider);
    final plan = (await repo.planById(id))!;
    await repo.skip(plan, due.single.occurrence.occurrence);
    // Wait for the stream to deliver the update.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    due = await c.read(dueOccurrencesProvider.future);
    expect(due.single.occurrence.date, DateTime(2026, 10, 12));
    sub.close();
  });

  test('reminders: lead time, notify time and localized text', () async {
    final id = await rule(
      'Rent',
      'FREQ=MONTHLY;BYMONTHDAY=1',
      -98000,
      mode: PostingMode.remindConfirm,
    );
    final plan = (await c.read(recurringRepositoryProvider).planById(id))!;
    final reminders = remindersFor(
      plan,
      now: DateTime(2026, 10, 23, 12),
      calendar: HolidayCalendar.none(),
      l10n: AppLocalizationsEn(),
      money: (m) => '€${m ~/ 100}',
      date: (d) => '${d.day}.${d.month}.',
    );
    expect(reminders.length, maxRemindersPerRule);
    expect(reminders.first.at, DateTime(2026, 10, 30, 9));
    expect(reminders.first.title, 'Rent');
    expect(reminders.first.body, '€980 due on 1.11.');
    expect(reminders.first.kind, NotificationKind.bill);
  });

  group('notification helpers', () {
    test('quiet hours wrap past midnight', () {
      expect(inQuietHours(23 * 60, 22 * 60, 7 * 60), isTrue);
      expect(inQuietHours(6 * 60, 22 * 60, 7 * 60), isTrue);
      expect(inQuietHours(7 * 60, 22 * 60, 7 * 60), isFalse);
      expect(inQuietHours(12 * 60, 12 * 60, 12 * 60), isFalse);
      expect(
        applyQuietHours(DateTime(2026, 10, 23, 23), 22 * 60, 7 * 60),
        DateTime(2026, 10, 24, 7),
      );
      expect(
        applyQuietHours(DateTime(2026, 10, 23, 5), 22 * 60, 7 * 60),
        DateTime(2026, 10, 23, 7),
      );
      expect(
        applyQuietHours(DateTime(2026, 10, 23, 13), 12 * 60, 14 * 60),
        DateTime(2026, 10, 23, 14),
      );
      expect(
        applyQuietHours(DateTime(2026, 10, 23, 9), 22 * 60, 7 * 60),
        DateTime(2026, 10, 23, 9),
      );
    });

    test('reminder time and stable ids', () {
      expect(
        reminderTime(DateTime(2026, 11), 2, 9 * 60 + 30),
        DateTime(2026, 10, 30, 9, 30),
      );
      expect(notificationId('rule:a#0'), notificationId('rule:a#0'));
      expect(notificationId('rule:a#0'), isNot(notificationId('rule:a#1')));
      expect(notificationId('x'), lessThan(1 << 31));
    });
  });
}
