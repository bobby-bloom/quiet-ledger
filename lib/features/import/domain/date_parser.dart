import 'package:personal_finance/features/import/domain/raw_sheet.dart';
import 'package:personal_finance/features/import/domain/text_normalize.dart';

/// Date notations the importer understands (PLAN.md §2.5 step 5).
enum DateFormatKind {
  /// Detect per column.
  auto,

  /// Excel serial day numbers (`45000`), 1900 or 1904 system.
  excelSerial,

  /// Day first: `dd.MM.yyyy`, `dd.MM.yy`, `d.M.yyyy`, `dd/MM/yyyy`,
  /// `dd-MM-yyyy`, and `dd.MM.` with the year from the sheet name.
  dmy,

  /// Month first: `MM/dd/yyyy`, `M/d/yy`.
  mdy,

  /// Year first: ISO `yyyy-MM-dd` (optionally with a time), `yyyy/MM/dd`.
  ymd,

  /// Compact `yyyyMMdd`.
  compact,

  /// Month names in German or English: `5. Januar 2023`, `05 Jan 2023`,
  /// `Jan 5, 2023`, `05-Jan-23`.
  monthName,
}

/// Plausible serial range for auto-detecting plain numbers as dates:
/// 1950-01-01 .. 2099-12-31.
const _minPlausibleSerial = 18264;
const _maxPlausibleSerial = 73050;

/// Converts an Excel serial day number to a local date.
///
/// 1900 system: serial 1 = 1900-01-01. Excel wrongly treats 1900 as a leap
/// year, so serial 60 is the non-existent 1900-02-29 (mapped to 02-28) and
/// every later serial is shifted by one day. 1904 system: serial 0 =
/// 1904-01-01. Fractions (times) are ignored. Returns null outside
/// Excel's date range.
DateTime? excelSerialToDate(num serial, {bool date1904 = false}) {
  if (serial.isNaN || serial.isInfinite) return null;
  final days = serial.floor();
  if (date1904) {
    if (days < 0 || days > 2957003) return null;
    return DateTime(1904, 1, 1 + days);
  }
  if (days < 1 || days > 2958465) return null;
  if (days < 60) return DateTime(1899, 12, 31 + days);
  if (days == 60) return DateTime(1900, 2, 28);
  return DateTime(1899, 12, 30 + days);
}

/// Inverse of [excelSerialToDate] for the 1900 system (dates ≥ 1900-03-01).
int dateToExcelSerial(DateTime d) => DateTime.utc(
  d.year,
  d.month,
  d.day,
).difference(DateTime.utc(1899, 12, 30)).inDays;

const _monthNames = <String, int>{
  // English
  'january': 1, 'jan': 1, 'february': 2, 'feb': 2, 'march': 3, 'mar': 3,
  'april': 4, 'apr': 4, 'may': 5, 'june': 6, 'jun': 6, 'july': 7, 'jul': 7,
  'august': 8, 'aug': 8, 'september': 9, 'sep': 9, 'sept': 9, 'october': 10,
  'oct': 10, 'november': 11, 'nov': 11, 'december': 12, 'dec': 12,
  // German (folded: ä → ae)
  'januar': 1, 'jaenner': 1, 'jaen': 1, 'februar': 2, 'maerz': 3, 'mrz': 3,
  'maer': 3, 'mai': 5, 'juni': 6, 'juli': 7, 'oktober': 10, 'okt': 10,
  'dezember': 12, 'dez': 12,
};

/// Month number for a German or English month name or abbreviation.
int? monthFromName(String s) =>
    _monthNames[foldText(s).replaceAll('.', '').trim()];

final _sepDate = RegExp(
  r'^(\d{1,4})[./\-\s](\d{1,2})(?:[./\-\s](\d{1,4}))?\.?$',
);
final _compact = RegExp(r'^(\d{4})(\d{2})(\d{2})$');
final _timeSuffix = RegExp(
  r'(?:[T\s]+\d{1,2}:\d{2}(?::\d{2}(?:[.,]\d+)?)?\s*(?:[AaPp][Mm])?(?:Z|[+-]\d{2}:?\d{2})?)?$',
);
final _weekdayPrefix = RegExp(r'^[A-Za-zÄÖÜäöü]{2,10}\.?,?\s+(?=\d)');
final _plainNumber = RegExp(r'^\d+(?:[.,]\d+)?$');

/// Expands a two-digit year: 00–69 → 2000–2069, 70–99 → 1970–1999.
int expandYear(int y) => y >= 100 ? y : (y < 70 ? 2000 + y : 1900 + y);

DateTime? _make(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31 || y < 1900 || y > 2200) {
    return null;
  }
  final dt = DateTime(y, m, d);
  return dt.month == m && dt.day == d ? dt : null;
}

String _stripTime(String s, {bool weekday = true}) {
  final first = s.isEmpty ? 0 : s.codeUnitAt(0);
  final startsWithDigit = first >= 48 && first <= 57;
  final t = weekday && !startsWithDigit
      ? s.replaceFirst(_weekdayPrefix, '')
      : s;
  // Fast path: no time part.
  if (!t.contains(':') && !t.contains('T') && !t.contains('Z')) return t.trim();
  final m = _timeSuffix.firstMatch(t);
  return (m == null || m.start == 0 ? t : t.substring(0, m.start)).trim();
}

/// Parses [input] as a date of [kind] (not [DateFormatKind.auto]).
/// [yearHint] supplies the year for `dd.MM.` dates (e.g. from a sheet named
/// "2023"). Returns null when the text does not fit.
DateTime? parseDateText(
  String input,
  DateFormatKind kind, {
  int? yearHint,
  bool date1904 = false,
}) {
  final raw = input.trim();
  if (raw.isEmpty) return null;
  switch (kind) {
    case DateFormatKind.auto:
      return null;
    case DateFormatKind.excelSerial:
      if (!_plainNumber.hasMatch(raw)) return null;
      final n = num.tryParse(raw.replaceAll(',', '.'));
      return n == null ? null : excelSerialToDate(n, date1904: date1904);
    case DateFormatKind.compact:
      final m = _compact.firstMatch(raw);
      if (m == null) return null;
      return _make(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
    case DateFormatKind.dmy:
    case DateFormatKind.mdy:
    case DateFormatKind.ymd:
      final s = _stripTime(raw);
      final m = _sepDate.firstMatch(s);
      if (m == null) return null;
      final a = m.group(1)!;
      final b = int.parse(m.group(2)!);
      final c = m.group(3);
      if (kind == DateFormatKind.ymd) {
        if (a.length != 4 || c == null) return null;
        return _make(int.parse(a), b, int.parse(c));
      }
      if (a.length > 2) return null;
      final first = int.parse(a);
      final int year;
      if (c == null) {
        if (yearHint == null) return null;
        year = yearHint;
      } else {
        if (c.length == 1 || c.length == 3) return null;
        year = expandYear(int.parse(c));
      }
      return kind == DateFormatKind.dmy
          ? _make(year, b, first)
          : _make(year, first, b);
    case DateFormatKind.monthName:
      return _parseMonthName(_stripTime(raw, weekday: false), yearHint);
  }
}

DateTime? _parseMonthName(String s, int? yearHint) {
  final tokens = RegExp(r'[A-Za-zÄÖÜäöüß]+|\d+')
      .allMatches(s)
      .map((m) => m[0]!);
  int? month;
  final numbers = <String>[];
  for (final t in tokens) {
    if (RegExp(r'^\d+$').hasMatch(t)) {
      numbers.add(t);
    } else {
      final m = monthFromName(t);
      if (m != null) {
        if (month != null) return null;
        month = m;
      } else if (t.length > 3 && !_isWeekday(t)) {
        return null;
      }
    }
  }
  if (month == null || numbers.isEmpty || numbers.length > 2) return null;
  int? day;
  int? year;
  if (numbers.length == 1) {
    if (numbers.single.length == 4 || yearHint == null) return null;
    day = int.parse(numbers.single);
    year = yearHint;
  } else {
    final four = numbers.where((n) => n.length == 4).toList();
    if (four.length == 1) {
      year = int.parse(four.single);
      day = int.parse(numbers.firstWhere((n) => n.length != 4));
    } else if (four.isEmpty) {
      // "05-Jan-23": day first, then two-digit year.
      day = int.parse(numbers[0]);
      year = expandYear(int.parse(numbers[1]));
    } else {
      return null;
    }
  }
  return _make(year, month, day);
}

bool _isWeekday(String t) => const {
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
  'mon',
  'tue',
  'wed',
  'thu',
  'fri',
  'sat',
  'sun',
  'montag',
  'dienstag',
  'mittwoch',
  'donnerstag',
  'freitag',
  'samstag',
  'sonntag',
  'sonnabend',
  'mo',
  'di',
  'mi',
  'do',
  'fr',
  'sa',
  'so',
}.contains(foldText(t));

/// Parses a cell as a date. Date cells are taken as they are; numbers are
/// Excel serials (when [kind] is auto or excelSerial); text uses [kind].
DateTime? parseDateCell(
  RawCell cell,
  DateFormatKind kind, {
  int? yearHint,
  bool date1904 = false,
}) {
  switch (cell.kind) {
    case RawKind.date:
      return cell.date;
    case RawKind.number:
      if (kind != DateFormatKind.auto &&
          kind != DateFormatKind.excelSerial &&
          kind != DateFormatKind.compact) {
        return null;
      }
      final text = cell.number!;
      if (kind == DateFormatKind.compact) {
        return parseDateText(text, kind);
      }
      final n = num.tryParse(text);
      return n == null ? null : excelSerialToDate(n, date1904: date1904);
    case RawKind.text:
      if (kind == DateFormatKind.auto) return null;
      return parseDateText(
        cell.text!,
        kind,
        yearHint: yearHint,
        date1904: date1904,
      );
    case RawKind.empty:
    case RawKind.boolean:
    case RawKind.error:
      return null;
  }
}

/// Picks the date notation that reads the most [samples]. Real date cells
/// are ignored (they need no format). [preferMonthFirst] decides ambiguous
/// slash dates like `03/04/2023` (e.g. when the amounts use 1,234.56).
DateFormatKind detectDateFormat(
  Iterable<RawCell> samples, {
  int? yearHint,
  bool preferMonthFirst = false,
}) {
  final texts = <String>[];
  var serials = 0;
  for (final c in samples) {
    if (c.kind == RawKind.number) {
      final n = num.tryParse(c.number!);
      if (n != null && n >= _minPlausibleSerial && n <= _maxPlausibleSerial) {
        serials++;
      }
    } else if (c.kind == RawKind.text) {
      texts.add(c.text!.trim());
    }
  }
  if (texts.isEmpty) {
    return serials > 0 ? DateFormatKind.excelSerial : DateFormatKind.auto;
  }
  const candidates = [
    DateFormatKind.ymd,
    DateFormatKind.dmy,
    DateFormatKind.mdy,
    DateFormatKind.monthName,
    DateFormatKind.compact,
    DateFormatKind.excelSerial,
  ];
  final scores = <DateFormatKind, int>{};
  for (final k in candidates) {
    var n = 0;
    for (final t in texts) {
      final d = parseDateText(t, k, yearHint: yearHint ?? 2000);
      if (d == null) continue;
      if (k == DateFormatKind.excelSerial) {
        final v = num.tryParse(t.replaceAll(',', '.'))!;
        if (v < _minPlausibleSerial || v > _maxPlausibleSerial) continue;
      }
      n++;
    }
    // Real serial numbers count for the serial notation.
    scores[k] = k == DateFormatKind.excelSerial ? n + serials : n;
  }
  final dmy = scores[DateFormatKind.dmy]!;
  final mdy = scores[DateFormatKind.mdy]!;
  var best = DateFormatKind.auto;
  var bestScore = 0;
  for (final k in candidates) {
    final s = scores[k]!;
    if (s > bestScore) {
      best = k;
      bestScore = s;
    }
  }
  if (bestScore == 0) {
    return serials > 0 ? DateFormatKind.excelSerial : DateFormatKind.dmy;
  }
  // dmy and mdy read the same values when no part exceeds 12; prefer by
  // separator convention ('.' is always day first) and the caller's hint.
  if ((best == DateFormatKind.dmy || best == DateFormatKind.mdy) &&
      dmy == mdy) {
    final dotted = texts.where((t) => t.contains('.')).length;
    if (dotted * 2 >= texts.length) return DateFormatKind.dmy;
    return preferMonthFirst ? DateFormatKind.mdy : DateFormatKind.dmy;
  }
  return best;
}

/// Year mentioned in a sheet name such as "2023" or "Konto 2024".
int? yearFromName(String name) {
  final m = RegExp(r'(?<!\d)((?:19|20)\d{2})(?!\d)').firstMatch(name);
  return m == null ? null : int.parse(m.group(1)!);
}
