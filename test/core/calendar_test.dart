import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/calendar/holidays.dart';
import 'package:personal_finance/core/calendar/recurrence.dart';
import 'package:personal_finance/core/settings/app_settings.dart';

void main() {
  group('HolidayCalendar', () {
    test('Easter dates', () {
      expect(HolidayCalendar.easterSunday(2024), DateTime(2024, 3, 31));
      expect(HolidayCalendar.easterSunday(2025), DateTime(2025, 4, 20));
      expect(HolidayCalendar.easterSunday(2026), DateTime(2026, 4, 5));
    });

    test('German nationwide and regional holidays', () {
      final de = HolidayCalendar(country: 'DE');
      expect(de.isHoliday(DateTime(2026, 10, 3)), isTrue);
      expect(de.isHoliday(DateTime(2026, 4, 3)), isTrue); // Karfreitag
      expect(de.isHoliday(DateTime(2026, 6, 4)), isFalse); // Fronleichnam
      final by = HolidayCalendar(country: 'DE', region: 'BY');
      expect(by.isHoliday(DateTime(2026, 6, 4)), isTrue);
      expect(by.isHoliday(DateTime(2026, 1, 6)), isTrue);
      final sn = HolidayCalendar(country: 'DE', region: 'SN');
      expect(sn.isHoliday(DateTime(2026, 11, 18)), isTrue); // Buß- und Bettag
    });

    test('business day shifting', () {
      final de = HolidayCalendar(country: 'DE');
      // Sat 3 Oct 2026 (also a holiday) -> Fri 2 Oct / Mon 5 Oct.
      expect(
        de.previousBusinessDay(DateTime(2026, 10, 3)),
        DateTime(2026, 10, 2),
      );
      expect(de.nextBusinessDay(DateTime(2026, 10, 3)), DateTime(2026, 10, 5));
      // Easter Monday 2026-04-06 -> previous is Thu 2 Apr (Good Friday off).
      expect(
        de.previousBusinessDay(DateTime(2026, 4, 6)),
        DateTime(2026, 4, 2),
      );
    });
  });

  group('expandRecurrence', () {
    test('monthly on the 31st clamps to month end', () {
      final occ = expandRecurrence(
        rrule: RRules.clampMonthDay(31),
        start: DateTime(2026, 1, 31),
        from: DateTime(2026),
        to: DateTime(2026, 5, 31),
      );
      expect(occ.map((o) => o.date), [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
        DateTime(2026, 5, 31),
      ]);
    });

    test('leap year February', () {
      final occ = expandRecurrence(
        rrule: RRules.clampMonthDay(30),
        start: DateTime(2028, 1, 30),
        from: DateTime(2028, 2),
        to: DateTime(2028, 2, 29),
      );
      expect(occ.single.date, DateTime(2028, 2, 29));
    });

    test('last business day with holiday shift', () {
      final occ = expandRecurrence(
        rrule: RRules.lastBusinessDayOfMonth(),
        start: DateTime(2026),
        from: DateTime(2026, 12),
        to: DateTime(2026, 12, 31),
        shift: WeekendShift.previous,
        calendar: HolidayCalendar(country: 'DE'),
      );
      // 31 Dec 2026 is a Thursday but a bank closing day -> 30 Dec.
      expect(occ.single.date, DateTime(2026, 12, 30));
      expect(occ.single.scheduled, DateTime(2026, 12, 31));
    });

    test('every 3 months on the 15th with count', () {
      final occ = expandRecurrence(
        rrule: 'FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=15',
        start: DateTime(2026, 1, 15),
        count: 3,
        from: DateTime(2026),
        to: DateTime(2027, 12, 31),
      );
      expect(occ.map((o) => o.date), [
        DateTime(2026, 1, 15),
        DateTime(2026, 4, 15),
        DateTime(2026, 7, 15),
      ]);
    });

    test('end date stops expansion', () {
      final occ = expandRecurrence(
        rrule: RRules.weekly(),
        start: DateTime(2026, 10, 5),
        end: DateTime(2026, 10, 20),
        from: DateTime(2026, 10),
        to: DateTime(2026, 12, 31),
      );
      expect(occ, hasLength(3));
    });

    test('amount changes apply from their date', () {
      final changes = {DateTime(2026, 7): 1050, DateTime(2027): 1100};
      expect(amountOn(DateTime(2026, 6, 30), 980, changes), 980);
      expect(amountOn(DateTime(2026, 7), 980, changes), 1050);
      expect(amountOn(DateTime(2027, 3), 980, changes), 1100);
    });
  });

  group('BudgetPeriods', () {
    test('monthly from the 1st', () {
      final p = BudgetPeriods(const BudgetPeriodConfig())
          .periodOf(DateTime(2026, 10, 23));
      expect(p.start, DateTime(2026, 10));
      expect(p.end, DateTime(2026, 11));
      expect(p.days, 31);
    });

    test('monthly from the 25th', () {
      final b = BudgetPeriods(const BudgetPeriodConfig(startDay: 25));
      expect(b.periodOf(DateTime(2026, 10, 23)).start, DateTime(2026, 9, 25));
      expect(b.periodOf(DateTime(2026, 10, 25)).start, DateTime(2026, 10, 25));
      expect(b.periodOf(DateTime(2026, 1, 3)).start, DateTime(2025, 12, 25));
    });

    test('last day of month with previous-business-day shift', () {
      final b = BudgetPeriods(
        BudgetPeriodConfig(
          startDay: 0,
          shift: WeekendShift.previous,
          calendar: HolidayCalendar(country: 'DE'),
        ),
      );
      // 31 Oct 2026 is a Saturday -> period starts Fri 30 Oct.
      final p = b.periodOf(DateTime(2026, 11, 10));
      expect(p.start, DateTime(2026, 10, 30));
      // 30 Nov 2026 is a Monday.
      expect(p.end, DateTime(2026, 11, 30));
      expect(b.next(p).start, DateTime(2026, 11, 30));
    });

    test('weekly respects first day of week', () {
      final b = BudgetPeriods(
        const BudgetPeriodConfig(
          type: BudgetPeriodType.weekly,
          firstDayOfWeek: DateTime.sunday,
        ),
      );
      final p = b.periodOf(DateTime(2026, 10, 23)); // Friday
      expect(p.start, DateTime(2026, 10, 18));
      expect(p.days, 7);
    });

    test('bi-weekly periods are contiguous', () {
      final b = BudgetPeriods(
        const BudgetPeriodConfig(type: BudgetPeriodType.biWeekly),
      );
      final ps = b.periodsFrom(DateTime(2026, 10, 23), 4);
      for (var i = 1; i < ps.length; i++) {
        expect(ps[i].start, ps[i - 1].end);
        expect(ps[i].days, 14);
      }
    });

    test('quarterly follows fiscal year start', () {
      final b = BudgetPeriods(
        const BudgetPeriodConfig(
          type: BudgetPeriodType.quarterly,
          fiscalYearStartMonth: 2,
        ),
      );
      final p = b.periodOf(DateTime(2026, 10, 23));
      expect(p.start, DateTime(2026, 8));
      expect(p.end, DateTime(2026, 11));
    });

    test('salary-based periods', () {
      final b = BudgetPeriods(
        BudgetPeriodConfig(
          salaryDates: [
            DateTime(2026, 8, 28),
            DateTime(2026, 9, 30),
            DateTime(2026, 10, 30),
          ],
        ),
      );
      final p = b.periodOf(DateTime(2026, 10, 5));
      expect(p.start, DateTime(2026, 9, 30));
      expect(p.end, DateTime(2026, 10, 30));
      // Outside known salary dates: falls back to the configured rule.
      expect(b.periodOf(DateTime(2026, 11, 5)).start, DateTime(2026, 11));
    });

    test('progress tick', () {
      final p = DateRange(DateTime(2026, 10), DateTime(2026, 11));
      expect(p.progressAt(DateTime(2026, 10)), closeTo(0.016, 0.01));
      expect(p.progressAt(DateTime(2026, 12)), 1);
    });
  });
}
