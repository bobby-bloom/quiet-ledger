import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/calendar/recurrence.dart';
import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/forecast/domain/cashflow_engine.dart';
import 'package:personal_finance/features/forecast/domain/forecast_dates.dart';
import 'package:personal_finance/features/forecast/domain/forecast_models.dart';
import 'package:personal_finance/features/forecast/domain/recurring_expansion.dart';

import 'forecast_fixtures.dart';

CashflowResult run(ForecastInput input, {int months = 3}) =>
    simulateCashflow(prepareCashflowModel(input, horizonMonths: months));

void main() {
  group('helpers', () {
    test('allocateEvenly never drifts and spreads remainders evenly', () {
      expect(allocateEvenly(40000, 30).fold(0, (a, b) => a + b), 40000);
      expect(allocateEvenly(-40001, 31).fold(0, (a, b) => a + b), -40001);
      expect(allocateEvenly(10, 3), [3, 3, 4]);
      expect(allocateEvenly(-7, 3), [-2, -2, -3]);
      expect(allocateEvenly(2, 4), [0, 1, 0, 1]);
      expect(allocateEvenly(0, 4), [0, 0, 0, 0]);
      expect(allocateEvenly(5, 0), isEmpty);
    });

    test('divRound rounds half away from zero', () {
      expect(divRound(5, 2), 3);
      expect(divRound(-5, 2), -3);
      expect(divRound(4, 3), 1);
      expect(divRound(-4, 3), -1);
      expect(divRound(7, 0), 0);
    });

    test('horizon end clamps the day of month', () {
      expect(horizonEnd(today, 3), d(2027, 1, 23));
      expect(horizonEnd(d(2026, 11, 30), 3), d(2027, 2, 28));
      expect(horizonEnd(d(2027, 1, 31), 1), d(2027, 2, 28));
    });
  });

  group('recurring expansion into balances', () {
    late CashflowResult r;
    setUp(() => r = run(baseInput()));

    test('covers today through the horizon end at daily resolution', () {
      expect(r.start, today);
      expect(r.end, d(2027, 1, 23));
      expect(r.dayCount, 93);
      expect(r.series('checking').first, 100000);
    });

    test('books salary, rent, the transfer and the amount change', () {
      int c(DateTime day) => r.balanceOn('checking', day);
      int s(DateTime day) => r.balanceOn('savings', day);
      expect(c(d(2026, 10, 27)), 100000);
      expect(c(d(2026, 10, 28)), 400000);
      expect(c(d(2026, 11, 1)), 280000);
      expect(c(d(2026, 11, 2)), 230000);
      expect(s(d(2026, 11, 2)), 250000);
      // 28 Nov 2026 is a Saturday: shifted to Friday 27 Nov.
      expect(c(d(2026, 11, 26)), 230000);
      expect(c(d(2026, 11, 27)), 530000);
      expect(c(d(2026, 12, 2)), 360000);
      expect(c(d(2026, 12, 28)), 660000);
      // Rent is 1,300.00 from January.
      expect(c(d(2027, 1, 1)), 530000);
      expect(c(d(2027, 1, 2)), 480000);
      expect(c(d(2027, 1, 23)), 480000);
      expect(s(d(2027, 1, 23)), 350000);
    });

    test('transfers do not change the total', () {
      expect(r.balanceOn(null, d(2026, 11, 1)), 480000);
      expect(r.balanceOn(null, d(2026, 11, 2)), 480000);
      expect(r.total.last, 480000 + 350000);
    });

    test('lists events and big events in date order', () {
      expect(r.events.first.date, d(2026, 10, 28));
      expect(r.events.first.label, 'salary');
      final transfer = r.events.firstWhere((e) => e.refId == 'save');
      expect(transfer.counterAccountId, 'savings');
      expect(r.bigEvents.length, r.events.length);
      final dates = [for (final e in r.events) e.date];
      expect(dates, [...dates]..sort());
    });

    test('month-end balances and period lows', () {
      expect(r.months.map((m) => m.range.start), [
        d(2026, 10, 1),
        d(2026, 11, 1),
        d(2026, 12, 1),
        d(2027, 1, 1),
      ]);
      final oct = r.months.first;
      expect(oct.clipped, isTrue);
      expect(oct.endOf('checking'), 400000);
      expect(oct.lowOf('checking'), LowPoint(today, 100000));
      final nov = r.months[1];
      expect(nov.clipped, isFalse);
      expect(nov.endOf('checking'), 530000);
      expect(nov.lowOf('checking'), LowPoint(d(2026, 11, 2), 230000));
      expect(nov.endTotal, 530000 + 250000);
      final jan = r.months.last;
      expect(jan.clipped, isTrue);
      expect(jan.endOf('checking'), 480000);
      // Monthly budget periods by default.
      expect(r.periods.length, 4);
    });

    test('holiday shift to the next business day', () {
      final res = run(
        baseInput(
          recurring: [
            rule(
              'bonus',
              rrule: 'FREQ=YEARLY;BYMONTH=12;BYMONTHDAY=25',
              amount: 10000,
              shift: WeekendShift.next,
            ),
          ],
        ),
      );
      // 25/26 Dec are holidays, 27 Dec 2026 is a Sunday.
      expect(res.balanceOn('checking', d(2026, 12, 27)), 100000);
      expect(res.balanceOn('checking', d(2026, 12, 28)), 110000);
    });

    test('month-end rule falls back to the last day of shorter months', () {
      final res = run(
        baseInput(
          recurring: [
            rule('fee', rrule: RRules.clampMonthDay(31), amount: -1000),
          ],
        ),
        months: 5,
      );
      final dates = [for (final e in res.events) e.date];
      expect(dates, [
        d(2026, 10, 31),
        d(2026, 11, 30),
        d(2026, 12, 31),
        d(2027, 1, 31),
        d(2027, 2, 28),
      ]);
    });

    test('respects end date, count and lastPostedDate', () {
      final res = run(
        baseInput(
          recurring: [
            rule(
              'ending',
              rrule: 'FREQ=MONTHLY;BYMONTHDAY=5',
              amount: -1000,
              end: d(2026, 12, 31),
            ),
            rule(
              'posted',
              rrule: 'FREQ=MONTHLY;BYMONTHDAY=5',
              amount: -2000,
              lastPosted: d(2026, 11, 5),
            ),
          ],
        ),
      );
      final byRule = <String, List<DateTime>>{};
      for (final e in res.events) {
        (byRule[e.refId!] ??= []).add(e.date);
      }
      expect(byRule['ending'], [d(2026, 11, 5), d(2026, 12, 5)]);
      expect(byRule['posted'], [d(2026, 12, 5), d(2027, 1, 5)]);
    });

    test('occurrences already posted (exactly or ±3 days) are skipped', () {
      final res = run(
        baseInput(
          posted: {
            // Salary confirmed one day early.
            'salary': [d(2026, 10, 27)],
            // Rent of 1 Nov already planned in the ledger.
            'rent': [d(2026, 11, 1)],
          },
        ),
      );
      final salary = res.events.where((e) => e.refId == 'salary');
      expect(salary.first.date, d(2026, 11, 27));
      final rent = res.events.where((e) => e.refId == 'rent');
      expect(rent.first.date, d(2026, 12, 1));
    });

    test('an invalid RRULE is ignored instead of failing', () {
      final res = run(
        baseInput(recurring: [rule('bad', rrule: 'FREQ=NOPE', amount: -1)]),
      );
      expect(res.events, isEmpty);
    });

    test('occurrence due today is part of day 0', () {
      final res = run(
        baseInput(
          recurring: [
            rule('today', rrule: 'FREQ=MONTHLY;BYMONTHDAY=23', amount: -500),
          ],
        ),
      );
      expect(res.series('checking').first, 99500);
    });
  });

  group('lowest point and warnings', () {
    test('below the account threshold before the salary', () {
      final r = run(baseInput());
      expect(r.lowestByAccount['checking'], LowPoint(today, 100000));
      final w = r.warning('checking')!;
      expect(w.kind, WarningKind.belowThreshold);
      expect(w.firstDate, today);
      expect(w.daysBelow, 5); // 23–27 Oct
      expect(w.thresholdMinor, 150000);
      expect(r.warning('savings'), isNull);
    });

    test('below zero is reported as the most severe kind', () {
      final r = run(
        baseInput(
          scheduled: [
            PlannedEvent(
              date: d(2026, 10, 25),
              accountId: 'checking',
              amountMinor: -150000,
              label: 'Laptop',
              kind: ForecastEventKind.scheduled,
            ),
          ],
        ),
      );
      final w = r.warning('checking')!;
      expect(w.kind, WarningKind.belowZero);
      expect(w.firstDate, d(2026, 10, 25));
      expect(w.lowest, LowPoint(d(2026, 10, 25), -50000));
      // Below the 1,500.00 threshold 23–27 Oct and again 1–26 Nov (after
      // rent and the savings transfer, until the next salary).
      expect(w.daysBelow, 5 + 26);
      expect(r.bigEvents.first.label, 'Laptop');
    });

    test('total uses the global threshold', () {
      final r = run(baseInput(globalThreshold: 400000));
      expect(r.totalThreshold, 400000);
      final w = r.warning(null)!;
      expect(w.kind, WarningKind.belowThreshold);
      expect(w.daysBelow, 5);
      expect(r.lowestTotal, LowPoint(today, 300000));
    });

    test('liabilities never warn for being negative', () {
      final r = run(
        ForecastInput(
          today: today,
          accounts: [
            account('card', balance: -42000, type: AccountType.creditCard),
            account(
              'loan',
              balance: -900000,
              type: AccountType.loan,
              threshold: 1000,
            ),
          ],
        ),
      );
      expect(r.warning('card'), isNull);
      expect(r.warning('loan'), isNull);
    });

    test('no threshold and never negative means no warning', () {
      final input = baseInput();
      final r = run(
        ForecastInput(
          today: input.today,
          accounts: [account('checking', balance: 100000)],
          recurring: input.recurring,
        ),
      );
      expect(r.warnings, isEmpty);
      expect(r.threshold('checking'), isNull);
    });

    test('earliest minimum wins for ties', () {
      expect(
        lowestOf([5, 3, 4, 3], today),
        LowPoint(today.add(const Duration(days: 1)), 3),
      );
    });
  });

  group('scheduled ledger entries', () {
    test('only future entries within the horizon are booked', () {
      PlannedEvent e(DateTime date, int amount) => PlannedEvent(
        date: date,
        accountId: 'checking',
        amountMinor: amount,
        label: 'x',
        kind: ForecastEventKind.scheduled,
      );
      final r = run(
        baseInput(
          recurring: const [],
          scheduled: [
            e(today, -1), // already in the start balance
            e(d(2026, 10, 24), -2000),
            e(d(2027, 1, 23), -3000),
            e(d(2027, 1, 24), -4000), // after the horizon
          ],
        ),
      );
      expect(r.series('checking').last, 100000 - 2000 - 3000);
      expect(r.events.length, 2);
    });
  });

  group('goal contributions', () {
    test('monthly transfer into the linked account until reached', () {
      final r = run(
        baseInput(
          recurring: const [],
          goals: const [
            GoalInput(
              id: 'g1',
              name: 'Holiday',
              targetMinor: 300000,
              accountId: 'savings',
              contributionMinor: 40000,
            ),
          ],
        ),
      );
      final goal = r.events.where((e) => e.kind == ForecastEventKind.goal);
      expect(goal.map((e) => (e.date, e.amountMinor)), [
        (d(2026, 11, 1), -40000),
        (d(2026, 12, 1), -40000),
        (d(2027, 1, 1), -20000),
      ]);
      expect(r.series('savings').last, 300000);
      expect(r.series('checking').last, 0);
    });

    test('skipped when a recurring transfer already feeds the account', () {
      final r = run(
        baseInput(
          goals: const [
            GoalInput(
              id: 'g1',
              name: 'Holiday',
              targetMinor: 900000,
              accountId: 'savings',
              contributionMinor: 40000,
            ),
          ],
        ),
      );
      expect(r.events.where((e) => e.kind == ForecastEventKind.goal), isEmpty);
    });

    test('unlinked goal money leaves the primary account', () {
      final r = run(
        baseInput(
          recurring: const [],
          goals: const [
            GoalInput(
              id: 'g2',
              name: 'Bike',
              targetMinor: 50000,
              contributionMinor: 20000,
            ),
          ],
        ),
      );
      expect(r.series('checking').last, 100000 - 50000);
      expect(r.series('savings').last, 200000);
    });
  });

  group('what-if', () {
    test('Can I afford 900.00 on 30 Oct? reports the new lowest point', () {
      final model = prepareCashflowModel(baseInput());
      final a = checkAffordability(
        model,
        amountMinor: 90000,
        date: d(2026, 10, 30),
        accountId: 'checking',
      );
      // Before: lowest from 30 Oct on is 230,000 (2 Nov).
      expect(a.before, LowPoint(d(2026, 11, 2), 230000));
      expect(a.after, LowPoint(d(2026, 11, 2), 140000));
      expect(a.belowThreshold, isTrue);
      expect(a.belowZero, isFalse);
      expect(a.affordable, isFalse);
      expect(a.totalAfter.amountMinor, 140000 + 250000);
    });

    test('affordable when the balance stays above the threshold', () {
      final model = prepareCashflowModel(baseInput());
      final a = checkAffordability(
        model,
        amountMinor: 50000,
        date: d(2026, 12, 15),
        accountId: 'checking',
      );
      expect(a.after.amountMinor, greaterThanOrEqualTo(150000));
      expect(a.affordable, isTrue);
    });
  });

  group('occurrence amounts', () {
    test('modifiers apply from their date on the scheduled date', () {
      final item =
          rule(
            'r',
            rrule: 'FREQ=MONTHLY',
            amount: -10000,
            changes: {d(2027, 1, 1): -12000},
          ).copyWith(
            modifiers: [
              AmountModifier(from: d(2027, 2, 1), percentBp: 1000),
              AmountModifier(from: d(2027, 3, 1), deltaMinor: 500),
            ],
          );
      expect(occurrenceAmount(item, d(2026, 12, 1)), -10000);
      expect(occurrenceAmount(item, d(2027, 1, 1)), -12000);
      expect(occurrenceAmount(item, d(2027, 2, 1)), -13200);
      expect(occurrenceAmount(item, d(2027, 3, 1)), -13700);
    });

    test('a reduction never flips the sign', () {
      final item = rule('r', rrule: 'FREQ=MONTHLY', amount: -1000).copyWith(
        modifiers: [AmountModifier(from: d(2026, 1, 1), deltaMinor: -5000)],
      );
      expect(occurrenceAmount(item, d(2026, 5, 1)), 0);
    });
  });
}
