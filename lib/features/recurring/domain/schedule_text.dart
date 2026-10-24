import 'package:personal_finance/features/recurring/domain/schedule.dart';

// Human-readable schedule descriptions in English and German. The rrule
// package's own text encoder has no German, so this is a small formatter for
// the presets of [ScheduleSpec] plus a generic fallback for custom rules.

const _weekdaysEn = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _weekdaysShortEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _weekdaysDe = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];
const _weekdaysShortDe = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const _monthsEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _monthsDe = [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
];

/// English ordinal: 1st, 2nd, 3rd, 4th, 11th, 21st ...
String ordinalEn(int n) {
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

/// Describes [rrule] in [languageCode] ('en' or 'de'), e.g.
/// "Monthly on the 15th" / "Monatlich am 15.".
String describeSchedule(String rrule, String languageCode) {
  final de = languageCode.toLowerCase().startsWith('de');
  final spec = ScheduleSpec.parse(rrule);
  return de ? _de(spec) : _en(spec);
}

String _en(ScheduleSpec s) {
  final n = s.interval;
  String every(String singular, String plural, {String? special}) {
    if (n == 1) return singular;
    if (special != null) return special;
    return 'Every $n $plural';
  }

  switch (s.kind) {
    case ScheduleKind.monthly:
      final day = s.monthDay > 28
          ? 'the ${ordinalEn(s.monthDay)} (or last day)'
          : 'the ${ordinalEn(s.monthDay)}';
      final base = every(
        'Monthly',
        'months',
        special: n == 3
            ? 'Quarterly'
            : n == 6
            ? 'Twice a year'
            : null,
      );
      return '$base on $day';
    case ScheduleKind.lastDay:
      return '${every('Monthly', 'months', special: n == 3 ? 'Quarterly' : null)}'
          ' on the last day';
    case ScheduleKind.lastBusinessDay:
      return '${every('Monthly', 'months', special: n == 3 ? 'Quarterly' : null)}'
          ' on the last business day';
    case ScheduleKind.weekly:
      final days = (s.weekdays.toList()..sort());
      if (n == 1 && days.length == 7) return 'Daily';
      if (n == 1 && _isWorkdays(days)) return 'Every weekday';
      final names = days.length == 1
          ? _weekdaysEn[days.single - 1]
          : _joinEn(days.map((d) => _weekdaysShortEn[d - 1]).toList());
      return '${every('Weekly', 'weeks', special: n == 2 ? 'Every 2 weeks' : null)}'
          ' on $names';
    case ScheduleKind.yearly:
      final date = '${s.monthDay} ${_monthsEn[s.month - 1]}';
      return '${every('Yearly', 'years')} on $date';
    case ScheduleKind.daily:
      return every('Daily', 'days');
    case ScheduleKind.custom:
      return _customEn(s.custom);
  }
}

String _de(ScheduleSpec s) {
  final n = s.interval;
  String every(String singular, String plural, {String? special}) {
    if (n == 1) return singular;
    if (special != null) return special;
    return 'Alle $n $plural';
  }

  switch (s.kind) {
    case ScheduleKind.monthly:
      final day = s.monthDay > 28
          ? 'am ${s.monthDay}. (oder letzten Tag)'
          : 'am ${s.monthDay}.';
      final base = every(
        'Monatlich',
        'Monate',
        special: n == 3
            ? 'Vierteljährlich'
            : n == 6
            ? 'Halbjährlich'
            : null,
      );
      return '$base $day';
    case ScheduleKind.lastDay:
      return '${every('Monatlich', 'Monate', special: n == 3 ? 'Vierteljährlich' : null)}'
          ' am letzten Tag';
    case ScheduleKind.lastBusinessDay:
      return '${every('Monatlich', 'Monate', special: n == 3 ? 'Vierteljährlich' : null)}'
          ' am letzten Werktag';
    case ScheduleKind.weekly:
      final days = (s.weekdays.toList()..sort());
      if (n == 1 && days.length == 7) return 'Täglich';
      if (n == 1 && _isWorkdays(days)) return 'Jeden Werktag';
      final names = days.length == 1
          ? _weekdaysDe[days.single - 1]
          : _joinDe(days.map((d) => _weekdaysShortDe[d - 1]).toList());
      return '${every('Wöchentlich', 'Wochen')} am $names';
    case ScheduleKind.yearly:
      final date = '${s.monthDay}. ${_monthsDe[s.month - 1]}';
      return '${every('Jährlich', 'Jahre')} am $date';
    case ScheduleKind.daily:
      return every('Täglich', 'Tage');
    case ScheduleKind.custom:
      return _customDe(s.custom);
  }
}

bool _isWorkdays(List<int> sortedDays) =>
    sortedDays.length == 5 &&
    sortedDays.first == DateTime.monday &&
    sortedDays.last == DateTime.friday;

String _joinEn(List<String> items) => items.length <= 2
    ? items.join(' and ')
    : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';

String _joinDe(List<String> items) => items.length <= 2
    ? items.join(' und ')
    : '${items.sublist(0, items.length - 1).join(', ')} und ${items.last}';

Map<String, String> _parts(String rule) {
  final out = <String, String>{};
  for (final p in rule.split(';')) {
    final i = p.indexOf('=');
    if (i > 0) {
      out[p.substring(0, i).trim().toUpperCase()] = p
          .substring(i + 1)
          .trim()
          .toUpperCase();
    }
  }
  return out;
}

String _customEn(String rule) {
  final p = _parts(rule);
  final n = int.tryParse(p['INTERVAL'] ?? '1') ?? 1;
  final base = switch (p['FREQ']) {
    'DAILY' => n == 1 ? 'Daily' : 'Every $n days',
    'WEEKLY' => n == 1 ? 'Weekly' : 'Every $n weeks',
    'MONTHLY' => n == 1 ? 'Monthly' : 'Every $n months',
    'YEARLY' => n == 1 ? 'Yearly' : 'Every $n years',
    _ => null,
  };
  if (base == null) return 'Custom schedule';
  return '$base (custom)';
}

String _customDe(String rule) {
  final p = _parts(rule);
  final n = int.tryParse(p['INTERVAL'] ?? '1') ?? 1;
  final base = switch (p['FREQ']) {
    'DAILY' => n == 1 ? 'Täglich' : 'Alle $n Tage',
    'WEEKLY' => n == 1 ? 'Wöchentlich' : 'Alle $n Wochen',
    'MONTHLY' => n == 1 ? 'Monatlich' : 'Alle $n Monate',
    'YEARLY' => n == 1 ? 'Jährlich' : 'Alle $n Jahre',
    _ => null,
  };
  if (base == null) return 'Benutzerdefinierter Zeitplan';
  return '$base (benutzerdefiniert)';
}
