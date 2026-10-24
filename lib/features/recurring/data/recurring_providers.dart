import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/calendar/holidays.dart';
import 'package:personal_finance/core/calendar/recurrence.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/features/budgets/data/budget_period_provider.dart';
import 'package:personal_finance/features/plan/plan_providers.dart';
import 'package:personal_finance/features/recurring/data/recurring_repository.dart';
import 'package:personal_finance/features/recurring/domain/recurring_logic.dart';

/// Live recurring rules (not deleted), sorted by name.
final recurringRulesProvider = StreamProvider<List<RecurringRule>>(
  (ref) => ref.watch(recurringRepositoryProvider).watchRules(),
);

/// Live amount changes grouped by rule id.
final recurringAmountChangesProvider =
    StreamProvider<Map<String, List<RecurringAmountChange>>>(
      (ref) => ref.watch(recurringRepositoryProvider).watchAmountChanges(),
    );

/// All live rules as [RecurringPlan]s (decoded template + amount changes).
final recurringPlansProvider = FutureProvider<List<RecurringPlan>>((ref) async {
  final rulesF = ref.watch(recurringRulesProvider.future);
  final changesF = ref.watch(recurringAmountChangesProvider.future);
  final rules = await rulesF;
  final changes = await changesF;
  return [
    for (final r in rules)
      RecurringPlan.fromRow(
        r,
        amountChanges: RecurringRepository.changeMap(changes[r.id]),
      ),
  ];
});

final recurringPlanProvider = FutureProvider.family<RecurringPlan?, String>((
  ref,
  id,
) async {
  final plans = await ref.watch(recurringPlansProvider.future);
  for (final p in plans) {
    if (p.id == id) return p;
  }
  return null;
});

/// One expected occurrence of a recurring rule, for the dashboard
/// "Upcoming bills" card, the due list and the bills calendar.
@immutable
class UpcomingOccurrence {
  const UpcomingOccurrence({
    required this.plan,
    required this.occurrence,
    required this.amountMinor,
    required this.today,
    this.account,
    this.transferAccount,
  });

  final RecurringPlan plan;
  final Occurrence occurrence;

  /// Signed amount (negative = money leaves [account]).
  final int amountMinor;
  final Account? account;
  final Account? transferAccount;
  final DateTime today;

  String get ruleId => plan.id;
  String get name => plan.name;
  DateTime get date => occurrence.date;
  PostingMode get postingMode => plan.mode;
  TxnType get type => plan.type;

  /// Already posted, confirmed or skipped.
  bool get isPosted =>
      plan.lastPostedDate != null && !date.isAfter(plan.lastPostedDate!);

  /// Pending and dated before today.
  bool get isOverdue => !isPosted && date.isBefore(today);

  bool get isDueToday => !isPosted && date == today;

  /// Days from today (negative when overdue).
  int get daysAway => DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;

  @override
  bool operator ==(Object other) =>
      other is UpcomingOccurrence &&
      other.plan.id == plan.id &&
      other.occurrence == occurrence &&
      other.amountMinor == amountMinor;

  @override
  int get hashCode => Object.hash(plan.id, occurrence, amountMinor);
}

/// Watches what [_expand] needs (synchronously, before any await).
(HolidayCalendar, Map<String, Account>, DateTime) _deps(Ref ref) => (
  ref.watch(holidayCalendarProvider),
  ref.watch(accountMapProvider),
  ref.watch(planTodayProvider),
);

List<UpcomingOccurrence> _expand(
  (HolidayCalendar, Map<String, Account>, DateTime) deps,
  List<RecurringPlan> plans,
  DateTime from,
  DateTime to, {
  bool pendingOnly = true,
}) {
  final (calendar, accounts, today) = deps;
  final out = <UpcomingOccurrence>[];
  for (final p in plans) {
    if (!p.active) continue;
    for (final o in p.occurrences(from, to, calendar)) {
      if (pendingOnly &&
          p.lastPostedDate != null &&
          !o.date.isAfter(p.lastPostedDate!)) {
        continue;
      }
      out.add(
        UpcomingOccurrence(
          plan: p,
          occurrence: o,
          amountMinor: p.amountFor(o),
          today: today,
          account: accounts[p.template.accountId],
          transferAccount: p.template.transferAccountId == null
              ? null
              : accounts[p.template.transferAccountId],
        ),
      );
    }
  }
  out.sort((a, b) {
    final c = a.date.compareTo(b.date);
    return c != 0 ? c : a.name.compareTo(b.name);
  });
  return out;
}

/// Pending occurrences of active rules from today up to `daysAhead` days
/// ahead (inclusive), plus overdue remind & confirm occurrences of the last
/// 60 days, sorted by date. Feeds the dashboard "Upcoming bills" card.
final upcomingOccurrencesProvider =
    FutureProvider.family<List<UpcomingOccurrence>, int>((
      ref,
      daysAhead,
    ) async {
      final deps = _deps(ref);
      final today = deps.$3;
      final plans = await ref.watch(recurringPlansProvider.future);
      final to = DateTime(today.year, today.month, today.day + daysAhead);
      final from = DateTime(today.year, today.month, today.day - 60);
      return _expand(deps, plans, from, to)
          .where(
            (u) =>
                !u.date.isBefore(today) ||
                u.postingMode == PostingMode.remindConfirm,
          )
          .toList();
    });

/// Remind & confirm occurrences awaiting a decision: the earliest pending
/// occurrence per rule that is due within its reminder lead time (overdue
/// ones included). Confirming or skipping it reveals the next one.
@immutable
class DueItem {
  const DueItem(this.occurrence, this.morePending);

  final UpcomingOccurrence occurrence;

  /// Further pending occurrences of the same rule up to today.
  final int morePending;
}

final dueOccurrencesProvider = FutureProvider<List<DueItem>>((ref) async {
  final (calendar, accounts, today) = _deps(ref);
  final plans = await ref.watch(recurringPlansProvider.future);
  final out = <DueItem>[];
  for (final p in plans) {
    if (!p.active || p.mode != PostingMode.remindConfirm) continue;
    final lead = p.remindDaysBefore.clamp(0, 60);
    final horizon = DateTime(today.year, today.month, today.day + lead);
    final pending = p.pending(horizon, calendar);
    if (pending.isEmpty) continue;
    final first = pending.first;
    out.add(
      DueItem(
        UpcomingOccurrence(
          plan: p,
          occurrence: first,
          amountMinor: p.amountFor(first),
          today: today,
          account: accounts[p.template.accountId],
          transferAccount: p.template.transferAccountId == null
              ? null
              : accounts[p.template.transferAccountId],
        ),
        pending.skip(1).where((o) => !o.date.isAfter(today)).length,
      ),
    );
  }
  out.sort((a, b) => a.occurrence.date.compareTo(b.occurrence.date));
  return out;
});

/// All occurrences (posted and pending) of active rules in `[from, to]`, for
/// the bills calendar. Key: (from, to).
final calendarOccurrencesProvider =
    FutureProvider.family<List<UpcomingOccurrence>, (DateTime, DateTime)>((
      ref,
      range,
    ) async {
      final deps = _deps(ref);
      final plans = await ref.watch(recurringPlansProvider.future);
      return _expand(deps, plans, range.$1, range.$2, pendingOnly: false);
    });

/// Next pending occurrence per rule id (for list rows).
final nextOccurrenceProvider = FutureProvider<Map<String, UpcomingOccurrence>>((
  ref,
) async {
  final (calendar, accounts, today) = _deps(ref);
  final plans = await ref.watch(recurringPlansProvider.future);
  final out = <String, UpcomingOccurrence>{};
  for (final p in plans) {
    final o = p.nextPending(calendar);
    if (o == null) continue;
    out[p.id] = UpcomingOccurrence(
      plan: p,
      occurrence: o,
      amountMinor: p.amountFor(o),
      today: today,
      account: accounts[p.template.accountId],
    );
  }
  return out;
});
