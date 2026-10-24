import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:personal_finance/core/calendar/holidays.dart';
import 'package:personal_finance/core/calendar/recurrence.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/settings/app_settings.dart';

/// Parses the `recurring_rules.weekend_shift` column.
WeekendShift parseWeekendShift(String? s) =>
    WeekendShift.values.asNameMap()[s] ?? WeekendShift.none;

/// Decodes a `recurring_rules.template` JSON into a [TxnDraft]. Corrupt
/// JSON yields an empty draft (accountId '') that fails validation instead
/// of throwing.
TxnDraft decodeTemplate(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is Map) return TxnDraft.fromJson(decoded.cast());
  } on Object {
    // fall through
  }
  return TxnDraft(accountId: '', amountMinor: 0, date: DateTime(2000));
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// A recurring rule with its decoded template and amount changes: the pure
/// model used for expansion, posting and display.
///
/// `lastPostedDate` is the (shifted) date of the last occurrence that was
/// posted, confirmed or skipped. Occurrences after it are still pending.
@immutable
class RecurringPlan {
  const RecurringPlan({
    required this.id,
    required this.name,
    required this.rrule,
    required this.start,
    required this.template,
    this.end,
    this.count,
    this.shift = WeekendShift.none,
    this.mode = PostingMode.remindConfirm,
    this.remindDaysBefore = 2,
    this.notifyTime = 9 * 60,
    this.lastPostedDate,
    this.active = true,
    this.amountChanges = const {},
  });

  factory RecurringPlan.fromRow(
    RecurringRule r, {
    Map<DateTime, int> amountChanges = const {},
  }) => RecurringPlan(
    id: r.id,
    name: r.name,
    rrule: r.rrule,
    start: _day(r.startDate),
    end: r.endDate == null ? null : _day(r.endDate!),
    count: r.count,
    shift: parseWeekendShift(r.weekendShift),
    template: decodeTemplate(r.template),
    mode: r.postingMode,
    remindDaysBefore: r.remindDaysBefore,
    notifyTime: r.notifyTime,
    lastPostedDate: r.lastPostedDate == null ? null : _day(r.lastPostedDate!),
    active: r.active,
    amountChanges: amountChanges,
  );

  final String id;
  final String name;
  final String rrule;
  final DateTime start;
  final DateTime? end;
  final int? count;
  final WeekendShift shift;
  final TxnDraft template;
  final PostingMode mode;
  final int remindDaysBefore;

  /// Minutes after midnight.
  final int notifyTime;
  final DateTime? lastPostedDate;
  final bool active;

  /// fromDate -> signed amount (same sign convention as the template).
  final Map<DateTime, int> amountChanges;

  TxnType get type => template.type;
  bool get isIncome => template.type == TxnType.income;
  bool get isTransfer => template.type == TxnType.transfer;

  /// All occurrences whose (shifted) date lies in `[from, to]`.
  List<Occurrence> occurrences(
    DateTime from,
    DateTime to,
    HolidayCalendar calendar,
  ) {
    if (to.isBefore(from)) return const [];
    try {
      return expandRecurrence(
        rrule: rrule,
        start: start,
        from: _day(from),
        to: _day(to),
        end: end,
        count: count,
        shift: shift,
        calendar: calendar,
      );
    } on Object {
      // Invalid RRULE text: the rule produces nothing.
      return const [];
    }
  }

  /// Occurrences after [lastPostedDate] (or since the start) up to and
  /// including [upTo].
  List<Occurrence> pending(DateTime upTo, HolidayCalendar calendar) {
    final from = lastPostedDate == null
        ? _addDays(start, -7)
        : _addDays(lastPostedDate!, 1);
    return occurrences(from, upTo, calendar)
        .where((o) => lastPostedDate == null || o.date.isAfter(lastPostedDate!))
        .toList();
  }

  /// The first occurrence on or after [from], or null when the series has
  /// ended.
  Occurrence? nextOn(DateTime from, HolidayCalendar calendar) {
    var windowStart = _day(from);
    for (var years = 1; years <= 16; years *= 2) {
      final to = DateTime(
        windowStart.year + years,
        windowStart.month,
        windowStart.day,
      );
      final list = occurrences(windowStart, to, calendar);
      if (list.isNotEmpty) return list.first;
      if (end != null && to.isAfter(end!)) return null;
      windowStart = _addDays(to, 1);
    }
    return null;
  }

  /// The next pending occurrence (after [lastPostedDate]) on or after
  /// [notBefore] when given.
  Occurrence? nextPending(HolidayCalendar calendar, {DateTime? notBefore}) {
    var from = lastPostedDate == null
        ? _addDays(start, -7)
        : _addDays(lastPostedDate!, 1);
    if (notBefore != null && notBefore.isAfter(from)) from = _day(notBefore);
    return nextOn(from, calendar);
  }

  /// Signed amount in effect for occurrence [o] (amount changes apply by
  /// scheduled date, so a rent increase from 1 Jan also applies when the
  /// payment is moved to 31 Dec).
  int amountFor(Occurrence o) =>
      amountOn(o.scheduled, template.amountMinor, amountChanges);

  /// The transaction to post for [o]. [amountMinor] (signed) and [date]
  /// override the defaults; splits are scaled to the amount.
  TxnDraft draftFor(Occurrence o, {int? amountMinor, DateTime? date}) {
    final amount = amountMinor ?? amountFor(o);
    return template.copyWith(
      date: _day(date ?? o.date),
      amountMinor: amount,
      splits: scaleSplits(template.splits, template.amountMinor, amount),
      recurringRuleId: id,
      status: TxnStatus.cleared,
    );
  }
}

/// Scales [splits] (which sum to [from]) proportionally so they sum to [to].
/// The rounding remainder goes to the last line.
List<SplitDraft> scaleSplits(List<SplitDraft> splits, int from, int to) {
  if (splits.isEmpty || from == to) return splits;
  if (from == 0) {
    return [
      for (var i = 0; i < splits.length; i++)
        splits[i].copyWith(amountMinor: i == splits.length - 1 ? to : 0),
    ];
  }
  final out = <SplitDraft>[];
  var used = 0;
  for (var i = 0; i < splits.length; i++) {
    final s = splits[i];
    if (i == splits.length - 1) {
      out.add(s.copyWith(amountMinor: to - used));
    } else {
      // Integer rounding half away from zero.
      final num = s.amountMinor * to;
      final q = (num.abs() * 2 + from.abs()) ~/ (from.abs() * 2);
      final v = (num < 0) != (from < 0) ? -q : q;
      used += v;
      out.add(s.copyWith(amountMinor: v));
    }
  }
  return out;
}
