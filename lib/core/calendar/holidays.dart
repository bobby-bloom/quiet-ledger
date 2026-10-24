/// Public holiday calendars used for business-day shifting.
///
/// Germany is the default. [region] is a federal state code (e.g. `BY`);
/// empty means nationwide holidays only. For Germany, 24 and 31 December
/// are also treated as non-business days because banks do not settle on
/// them.
class HolidayCalendar {
  HolidayCalendar({required this.country, this.region = ''});

  /// A calendar without holidays (only weekends are non-business days).
  HolidayCalendar.none() : country = 'none', region = '';

  final String country;
  final String region;

  final Map<int, Set<DateTime>> _cache = {};

  bool isHoliday(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return _cache.putIfAbsent(d.year, () => holidaysOf(d.year)).contains(day);
  }

  bool isWeekend(DateTime d) =>
      d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

  bool isBusinessDay(DateTime d) => !isWeekend(d) && !isHoliday(d);

  /// Moves [d] to the previous business day if it is not one.
  DateTime previousBusinessDay(DateTime d) {
    var x = DateTime(d.year, d.month, d.day);
    while (!isBusinessDay(x)) {
      x = DateTime(x.year, x.month, x.day - 1);
    }
    return x;
  }

  /// Moves [d] to the next business day if it is not one.
  DateTime nextBusinessDay(DateTime d) {
    var x = DateTime(d.year, d.month, d.day);
    while (!isBusinessDay(x)) {
      x = DateTime(x.year, x.month, x.day + 1);
    }
    return x;
  }

  /// All holidays of [year] for this calendar.
  Set<DateTime> holidaysOf(int year) {
    final e = easterSunday(year);
    DateTime rel(int days) => DateTime(e.year, e.month, e.day + days);
    DateTime fix(int m, int d) => DateTime(year, m, d);
    switch (country) {
      case 'DE':
        final r = region.toUpperCase();
        return {
          fix(1, 1),
          rel(-2), // Karfreitag
          rel(1), // Ostermontag
          fix(5, 1),
          rel(39), // Christi Himmelfahrt
          rel(50), // Pfingstmontag
          fix(10, 3),
          fix(12, 24), // bank closing day
          fix(12, 25),
          fix(12, 26),
          fix(12, 31), // bank closing day
          if (const {'BW', 'BY', 'ST'}.contains(r)) fix(1, 6),
          if (r == 'BE' && year >= 2019) fix(3, 8),
          if (r == 'MV' && year >= 2023) fix(3, 8),
          if (const {'BW', 'BY', 'HE', 'NW', 'RP', 'SL'}.contains(r)) rel(60),
          if (r == 'SL') fix(8, 15),
          if (r == 'TH' && year >= 2019) fix(9, 20),
          if (const {'BB', 'MV', 'SN', 'ST', 'TH'}.contains(r) ||
              (const {'HB', 'HH', 'NI', 'SH'}.contains(r) && year >= 2018))
            fix(10, 31),
          if (year == 2017) fix(10, 31),
          if (const {'BW', 'BY', 'NW', 'RP', 'SL'}.contains(r)) fix(11, 1),
          if (r == 'SN') _bussUndBettag(year),
        };
      case 'AT':
        return {
          fix(1, 1),
          fix(1, 6),
          rel(1),
          fix(5, 1),
          rel(39),
          rel(50),
          rel(60),
          fix(8, 15),
          fix(10, 26),
          fix(11, 1),
          fix(12, 8),
          fix(12, 24),
          fix(12, 25),
          fix(12, 26),
          fix(12, 31),
        };
      case 'CH':
        return {
          fix(1, 1),
          fix(1, 2),
          rel(-2),
          rel(1),
          rel(39),
          rel(50),
          fix(8, 1),
          fix(12, 25),
          fix(12, 26),
        };
      default:
        return const {};
    }
  }

  /// Wednesday before 23 November.
  static DateTime _bussUndBettag(int year) {
    var d = DateTime(year, 11, 22);
    while (d.weekday != DateTime.wednesday) {
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return d;
  }

  /// Gregorian Easter Sunday (anonymous algorithm).
  static DateTime easterSunday(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }
}
