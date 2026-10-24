import 'package:personal_finance/core/calendar/holidays.dart';
import 'package:personal_finance/core/calendar/recurrence.dart';
import 'package:personal_finance/features/forecast/domain/forecast_dates.dart';
import 'package:personal_finance/features/forecast/domain/forecast_models.dart';

/// One expanded occurrence of a [RecurringItem] with its effective amount.
typedef ItemOccurrence = ({Occurrence occurrence, int amountMinor});

/// Rounds `numerator / denominator` half away from zero.
int divRound(int numerator, int denominator) {
  if (denominator == 0) return 0;
  final negative = (numerator < 0) != (denominator < 0);
  final n = numerator.abs();
  final d = denominator.abs();
  final q = (2 * n + d) ~/ (2 * d);
  return negative ? -q : q;
}

/// Part of [amount] (an occurrence amount of [item]) that belongs to
/// [categoryId], proportional to the template's category shares.
int categoryPortion(RecurringItem item, String categoryId, int amount) {
  final shareBase = item.categories
      .where((c) => c.categoryId == categoryId)
      .fold(0, (a, c) => a + c.amountMinor);
  if (shareBase == 0 || item.amountMinor == 0) return 0;
  if (shareBase == item.amountMinor) return amount;
  return divRound(amount * shareBase, item.amountMinor);
}

/// Effective amount of [item] for an occurrence scheduled on [scheduled]:
/// the dated amount changes first, then scenario modifiers in order.
int occurrenceAmount(RecurringItem item, DateTime scheduled) {
  var amount = amountOn(scheduled, item.amountMinor, item.amountChanges);
  for (final m in item.modifiers) {
    if (scheduled.isBefore(m.from)) continue;
    final share = m.categoryId == null
        ? amount
        : categoryPortion(item, m.categoryId!, amount);
    if (m.percentBp != null) {
      amount += divRound(share * m.percentBp!, 10000);
    }
    if (m.deltaMinor != null && (m.categoryId == null || share != 0)) {
      final sign = (share != 0 ? share : item.amountMinor) < 0 ? -1 : 1;
      final next = amount + sign * m.deltaMinor!;
      // A reduction never flips an outflow into an inflow (or vice versa).
      amount = (amount != 0 && next.sign != amount.sign && next != 0)
          ? 0
          : next;
    }
  }
  return amount;
}

/// All occurrences of [item] whose (shifted) date lies in `[from, to]`,
/// ignoring posting state.
List<ItemOccurrence> expandItem(
  RecurringItem item,
  DateTime from,
  DateTime to, {
  HolidayCalendar? calendar,
}) {
  if (to.isBefore(from)) return const [];
  final List<Occurrence> occs;
  try {
    occs = expandRecurrence(
      rrule: item.rrule,
      start: item.startDate,
      from: from,
      to: to,
      end: item.endDate,
      count: item.count,
      shift: item.shift,
      calendar: calendar,
      maxOccurrences: 200000,
    );
  } on Object {
    // An invalid RRULE must not break the whole forecast.
    return const [];
  }
  return [
    for (final o in occs)
      (occurrence: o, amountMinor: occurrenceAmount(item, o.scheduled)),
  ];
}

/// Occurrences of [item] in `[today, end]` that are not yet in the ledger.
///
/// An occurrence counts as posted when it is scheduled on or before the
/// rule's `lastPostedDate`, or when a ledger entry created by the rule
/// ([posted]) lies on its date — or, failing an exact match, within ±3 days
/// (the user confirmed it early or late). Each ledger entry matches at most
/// one occurrence. Overdue occurrences before today are not forecast.
List<ItemOccurrence> expandUnposted(
  RecurringItem item,
  DateTime today,
  DateTime end, {
  HolidayCalendar? calendar,
  List<DateTime> posted = const [],
}) {
  final all = expandItem(item, addDays(today, -7), end, calendar: calendar);
  if (all.isEmpty) return const [];
  final matched = List<bool>.filled(all.length, false);
  final remaining = <DateTime>[];
  for (final p in posted) {
    final d = dayOf(p);
    var hit = false;
    for (var i = 0; i < all.length; i++) {
      final o = all[i].occurrence;
      if (!matched[i] && (o.date == d || o.scheduled == d)) {
        matched[i] = true;
        hit = true;
        break;
      }
    }
    if (!hit) remaining.add(d);
  }
  for (final d in remaining) {
    var best = -1;
    var bestDist = 4;
    for (var i = 0; i < all.length; i++) {
      if (matched[i]) continue;
      final dist = daysBetween(d, all[i].occurrence.date).abs();
      if (dist < bestDist) {
        best = i;
        bestDist = dist;
      }
    }
    if (best >= 0) matched[best] = true;
  }
  final last = item.lastPostedDate == null ? null : dayOf(item.lastPostedDate!);
  return [
    for (var i = 0; i < all.length; i++)
      if (!matched[i] &&
          !all[i].occurrence.date.isBefore(today) &&
          (last == null || all[i].occurrence.scheduled.isAfter(last)))
        all[i],
  ];
}
