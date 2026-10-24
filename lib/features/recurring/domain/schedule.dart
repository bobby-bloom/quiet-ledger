import 'package:meta/meta.dart';
import 'package:personal_finance/core/calendar/recurrence.dart';
import 'package:rrule/rrule.dart';

/// The friendly schedule presets of the rule editor. Everything else is
/// [ScheduleKind.custom] (raw RRULE text).
enum ScheduleKind {
  /// Every [ScheduleSpec.interval] months on day [ScheduleSpec.monthDay]
  /// (falls back to the month's last day when it is shorter).
  monthly,

  /// Every [ScheduleSpec.interval] months on the last day.
  lastDay,

  /// Every [ScheduleSpec.interval] months on the last weekday (Mon–Fri).
  lastBusinessDay,

  /// Every [ScheduleSpec.interval] weeks on [ScheduleSpec.weekdays].
  weekly,

  /// Every [ScheduleSpec.interval] years on [ScheduleSpec.month] /
  /// [ScheduleSpec.monthDay] (clamped, e.g. 29 Feb → 28 Feb).
  yearly,

  /// Every [ScheduleSpec.interval] days.
  daily,

  /// Any RFC 5545 rule in [ScheduleSpec.custom].
  custom,
}

/// A recurrence schedule as edited in the UI, convertible to and from an
/// RRULE string (without the `RRULE:` prefix).
@immutable
class ScheduleSpec {
  const ScheduleSpec({
    this.kind = ScheduleKind.monthly,
    this.interval = 1,
    this.monthDay = 1,
    this.weekdays = const {DateTime.monday},
    this.month = 1,
    this.custom = '',
  });

  /// A sensible default for a rule starting on [start]: monthly on that day.
  factory ScheduleSpec.monthlyFrom(DateTime start) =>
      ScheduleSpec(monthDay: start.day, weekdays: {start.weekday});

  /// Recognises the presets; anything else becomes [ScheduleKind.custom].
  factory ScheduleSpec.parse(String rrule) {
    final text = _strip(rrule);
    final parts = <String, String>{};
    for (final p in text.split(';')) {
      if (p.trim().isEmpty) continue;
      final i = p.indexOf('=');
      if (i <= 0) return ScheduleSpec(kind: ScheduleKind.custom, custom: text);
      parts[p.substring(0, i).trim().toUpperCase()] = p
          .substring(i + 1)
          .trim()
          .toUpperCase();
    }
    ScheduleSpec custom() =>
        ScheduleSpec(kind: ScheduleKind.custom, custom: text);
    final freq = parts.remove('FREQ');
    final interval = int.tryParse(parts.remove('INTERVAL') ?? '1') ?? 0;
    parts.remove('WKST');
    if (interval < 1) return custom();
    final byMonthDay = parts.remove('BYMONTHDAY');
    final byDay = parts.remove('BYDAY');
    final bySetPos = parts.remove('BYSETPOS');
    final byMonth = parts.remove('BYMONTH');
    if (parts.isNotEmpty) return custom();

    List<int>? ints(String? s) {
      if (s == null) return null;
      final out = <int>[];
      for (final x in s.split(',')) {
        final v = int.tryParse(x);
        if (v == null) return null;
        out.add(v);
      }
      return out;
    }

    // Day lists produced by RRules.clampMonthDay: 28,29,...,N + BYSETPOS=-1.
    int? clampedDay(List<int>? days, String? setPos) {
      if (days == null || days.isEmpty) return null;
      if (days.length == 1 && setPos == null) {
        final d = days.single;
        return d >= 1 && d <= 31 ? d : null;
      }
      if (setPos != '-1' || days.first != 28) return null;
      for (var i = 0; i < days.length; i++) {
        if (days[i] != 28 + i) return null;
      }
      return days.last <= 31 ? days.last : null;
    }

    switch (freq) {
      case 'DAILY':
        if (byMonthDay != null || byDay != null || bySetPos != null) break;
        if (byMonth != null) break;
        return ScheduleSpec(kind: ScheduleKind.daily, interval: interval);
      case 'WEEKLY':
        if (byMonthDay != null || bySetPos != null || byMonth != null) break;
        if (byDay == null) break;
        final days = <int>{};
        for (final d in byDay.split(',')) {
          final w = _weekdayCodes.indexOf(d);
          if (w < 0) return custom();
          days.add(w + 1);
        }
        return ScheduleSpec(
          kind: ScheduleKind.weekly,
          interval: interval,
          weekdays: days,
        );
      case 'MONTHLY':
        if (byMonth != null) break;
        if (byMonthDay == '-1' && byDay == null && bySetPos == null) {
          return ScheduleSpec(kind: ScheduleKind.lastDay, interval: interval);
        }
        if (byMonthDay == null &&
            byDay == 'MO,TU,WE,TH,FR' &&
            bySetPos == '-1') {
          return ScheduleSpec(
            kind: ScheduleKind.lastBusinessDay,
            interval: interval,
          );
        }
        if (byDay != null) break;
        final day = clampedDay(ints(byMonthDay), bySetPos);
        if (day == null) break;
        return ScheduleSpec(interval: interval, monthDay: day);
      case 'YEARLY':
        if (byDay != null) break;
        final m = int.tryParse(byMonth ?? '');
        if (m == null || m < 1 || m > 12) break;
        final day = clampedDay(ints(byMonthDay), bySetPos);
        if (day == null) break;
        return ScheduleSpec(
          kind: ScheduleKind.yearly,
          interval: interval,
          month: m,
          monthDay: day,
        );
    }
    return custom();
  }

  final ScheduleKind kind;
  final int interval;

  /// 1–31 for [ScheduleKind.monthly] and [ScheduleKind.yearly].
  final int monthDay;

  /// DateTime.monday..DateTime.sunday for [ScheduleKind.weekly].
  final Set<int> weekdays;

  /// 1–12 for [ScheduleKind.yearly].
  final int month;

  /// Raw rule text for [ScheduleKind.custom].
  final String custom;

  static const _weekdayCodes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

  static String _strip(String rrule) {
    final t = rrule.trim();
    return t.toUpperCase().startsWith('RRULE:') ? t.substring(6).trim() : t;
  }

  /// The RRULE string (without prefix).
  String toRRule() {
    final n = interval < 1 ? 1 : interval;
    switch (kind) {
      case ScheduleKind.monthly:
        return RRules.clampMonthDay(monthDay.clamp(1, 31), interval: n);
      case ScheduleKind.lastDay:
        return RRules.lastDayOfMonth(interval: n);
      case ScheduleKind.lastBusinessDay:
        return RRules.lastBusinessDayOfMonth(interval: n);
      case ScheduleKind.weekly:
        final days = (weekdays.isEmpty ? {DateTime.monday} : weekdays).toList()
          ..sort();
        final codes = days.map((d) => _weekdayCodes[d - 1]).join(',');
        return 'FREQ=WEEKLY;INTERVAL=$n;BYDAY=$codes';
      case ScheduleKind.yearly:
        final maxDay = DateTime(2024, month + 1, 0).day; // leap year
        final d = monthDay.clamp(1, maxDay);
        if (d <= 28) {
          return 'FREQ=YEARLY;INTERVAL=$n;BYMONTH=$month;BYMONTHDAY=$d';
        }
        final days = [for (var x = 28; x <= d; x++) x].join(',');
        return 'FREQ=YEARLY;INTERVAL=$n;BYMONTH=$month;BYMONTHDAY=$days;'
            'BYSETPOS=-1';
      case ScheduleKind.daily:
        return 'FREQ=DAILY;INTERVAL=$n';
      case ScheduleKind.custom:
        return _strip(custom);
    }
  }

  /// Whether [toRRule] yields a rule the RRULE engine accepts.
  bool get isValid => isValidRRule(toRRule());

  ScheduleSpec copyWith({
    ScheduleKind? kind,
    int? interval,
    int? monthDay,
    Set<int>? weekdays,
    int? month,
    String? custom,
  }) => ScheduleSpec(
    kind: kind ?? this.kind,
    interval: interval ?? this.interval,
    monthDay: monthDay ?? this.monthDay,
    weekdays: weekdays ?? this.weekdays,
    month: month ?? this.month,
    custom: custom ?? this.custom,
  );

  @override
  bool operator ==(Object other) =>
      other is ScheduleSpec && other.toRRule() == toRRule();

  @override
  int get hashCode => toRRule().hashCode;

  @override
  String toString() => 'ScheduleSpec(${toRRule()})';
}

/// Whether [rrule] (with or without `RRULE:` prefix) parses and produces at
/// least one instance.
bool isValidRRule(String rrule) {
  final t = rrule.trim();
  if (t.isEmpty) return false;
  try {
    final rule = RecurrenceRule.fromString(
      t.toUpperCase().startsWith('RRULE:') ? t : 'RRULE:$t',
    );
    // Ledger dates have no time of day: sub-daily rules are not supported.
    if (rule.frequency == Frequency.hourly ||
        rule.frequency == Frequency.minutely ||
        rule.frequency == Frequency.secondly) {
      return false;
    }
    return rule
        .getInstances(start: DateTime.utc(2024), before: DateTime.utc(2100))
        .take(1)
        .isNotEmpty;
  } on Object {
    return false;
  }
}
