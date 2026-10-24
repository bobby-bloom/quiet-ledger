import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/calendar/recurrence.dart';
import 'package:personal_finance/features/recurring/domain/schedule.dart';
import 'package:personal_finance/features/recurring/domain/schedule_text.dart';

void main() {
  group('ScheduleSpec', () {
    test('presets round-trip through RRULE text', () {
      final specs = [
        const ScheduleSpec(monthDay: 15),
        const ScheduleSpec(monthDay: 31, interval: 2),
        const ScheduleSpec(monthDay: 15, interval: 3),
        const ScheduleSpec(kind: ScheduleKind.lastDay),
        const ScheduleSpec(kind: ScheduleKind.lastBusinessDay),
        const ScheduleSpec(
          kind: ScheduleKind.weekly,
          weekdays: {DateTime.monday, DateTime.thursday},
        ),
        const ScheduleSpec(
          kind: ScheduleKind.weekly,
          interval: 2,
          weekdays: {DateTime.friday},
        ),
        const ScheduleSpec(kind: ScheduleKind.yearly, month: 3, monthDay: 15),
        const ScheduleSpec(kind: ScheduleKind.yearly, month: 2, monthDay: 29),
        const ScheduleSpec(kind: ScheduleKind.daily, interval: 3),
      ];
      for (final s in specs) {
        final parsed = ScheduleSpec.parse(s.toRRule());
        expect(parsed.kind, s.kind, reason: s.toRRule());
        expect(parsed.toRRule(), s.toRRule());
        expect(s.isValid, isTrue, reason: s.toRRule());
      }
    });

    test('uses the RRules helpers', () {
      expect(
        const ScheduleSpec(monthDay: 31).toRRule(),
        RRules.clampMonthDay(31),
      );
      expect(
        const ScheduleSpec(kind: ScheduleKind.lastBusinessDay).toRRule(),
        RRules.lastBusinessDayOfMonth(),
      );
      expect(
        ScheduleSpec.parse('RRULE:FREQ=MONTHLY;BYMONTHDAY=-1').kind,
        ScheduleKind.lastDay,
      );
    });

    test('unknown rules become custom', () {
      final s = ScheduleSpec.parse('FREQ=MONTHLY;BYDAY=2TU');
      expect(s.kind, ScheduleKind.custom);
      expect(s.toRRule(), 'FREQ=MONTHLY;BYDAY=2TU');
      expect(s.isValid, isTrue);
      expect(isValidRRule('FREQ=SOMETIMES'), isFalse);
      expect(isValidRRule('FREQ=HOURLY'), isFalse);
      expect(isValidRRule(''), isFalse);
    });

    test('yearly 29 Feb clamps to 28 Feb in common years', () {
      final r = const ScheduleSpec(
        kind: ScheduleKind.yearly,
        month: 2,
        monthDay: 29,
      ).toRRule();
      final occ = expandRecurrence(
        rrule: r,
        start: DateTime(2027),
        from: DateTime(2027),
        to: DateTime(2028, 12, 31),
      );
      expect(occ.map((o) => o.date), [
        DateTime(2027, 2, 28),
        DateTime(2028, 2, 29),
      ]);
    });
  });

  group('describeSchedule', () {
    String en(ScheduleSpec s) => describeSchedule(s.toRRule(), 'en');
    String de(ScheduleSpec s) => describeSchedule(s.toRRule(), 'de');

    test('English', () {
      expect(en(const ScheduleSpec()), 'Monthly on the 1st');
      expect(en(const ScheduleSpec(monthDay: 22)), 'Monthly on the 22nd');
      expect(en(const ScheduleSpec(monthDay: 13)), 'Monthly on the 13th');
      expect(
        en(const ScheduleSpec(monthDay: 31)),
        'Monthly on the 31st (or last day)',
      );
      expect(
        en(const ScheduleSpec(monthDay: 15, interval: 3)),
        'Quarterly on the 15th',
      );
      expect(
        en(const ScheduleSpec(monthDay: 15, interval: 2)),
        'Every 2 months on the 15th',
      );
      expect(
        en(const ScheduleSpec(kind: ScheduleKind.lastBusinessDay)),
        'Monthly on the last business day',
      );
      expect(
        en(const ScheduleSpec(kind: ScheduleKind.lastDay)),
        'Monthly on the last day',
      );
      expect(
        en(
          const ScheduleSpec(
            kind: ScheduleKind.weekly,
            weekdays: {DateTime.friday},
          ),
        ),
        'Weekly on Friday',
      );
      expect(
        en(
          const ScheduleSpec(
            kind: ScheduleKind.weekly,
            interval: 2,
            weekdays: {DateTime.monday, DateTime.thursday},
          ),
        ),
        'Every 2 weeks on Mon and Thu',
      );
      expect(
        en(
          const ScheduleSpec(
            kind: ScheduleKind.weekly,
            weekdays: {1, 2, 3, 4, 5},
          ),
        ),
        'Every weekday',
      );
      expect(
        en(
          const ScheduleSpec(kind: ScheduleKind.yearly, month: 3, monthDay: 15),
        ),
        'Yearly on 15 March',
      );
      expect(
        describeSchedule('FREQ=MONTHLY;BYDAY=2TU', 'en'),
        'Monthly (custom)',
      );
    });

    test('German', () {
      expect(de(const ScheduleSpec(monthDay: 15)), 'Monatlich am 15.');
      expect(
        de(const ScheduleSpec(monthDay: 31)),
        'Monatlich am 31. (oder letzten Tag)',
      );
      expect(
        de(const ScheduleSpec(monthDay: 15, interval: 3)),
        'Vierteljährlich am 15.',
      );
      expect(de(const ScheduleSpec(interval: 2)), 'Alle 2 Monate am 1.');
      expect(
        de(const ScheduleSpec(kind: ScheduleKind.lastBusinessDay)),
        'Monatlich am letzten Werktag',
      );
      expect(
        de(
          const ScheduleSpec(
            kind: ScheduleKind.weekly,
            interval: 2,
            weekdays: {DateTime.friday},
          ),
        ),
        'Alle 2 Wochen am Freitag',
      );
      expect(
        de(
          const ScheduleSpec(
            kind: ScheduleKind.weekly,
            weekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
          ),
        ),
        'Wöchentlich am Mo, Mi und Fr',
      );
      expect(
        de(
          const ScheduleSpec(kind: ScheduleKind.yearly, month: 3, monthDay: 15),
        ),
        'Jährlich am 15. März',
      );
      expect(de(const ScheduleSpec(kind: ScheduleKind.daily)), 'Täglich');
      expect(
        describeSchedule('FREQ=WEEKLY;BYDAY=1MO', 'de'),
        'Wöchentlich (benutzerdefiniert)',
      );
    });
  });
}
