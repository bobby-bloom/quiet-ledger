import 'package:meta/meta.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/calendar/holidays.dart';
import 'package:personal_finance/core/calendar/recurrence.dart';
import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/features/recurring/domain/recurring_logic.dart';

/// Where an outstanding amount comes from.
enum OutstandingSource {
  /// A ledger entry with status `planned`.
  planned,

  /// An occurrence of a recurring rule that has not been posted yet.
  recurring,
}

/// Money that is expected in a budget period but not spent yet: one
/// category share of a planned transaction or of an unposted recurring
/// occurrence (split templates give one item per split line).
@immutable
class OutstandingItem {
  const OutstandingItem({
    required this.source,
    required this.date,
    required this.amountMinor,
    required this.type,
    required this.accountId,
    required this.overdue,
    this.categoryId,
    this.isSplit = false,
    this.title,
    this.transactionId,
    this.plan,
    this.occurrence,
  });

  final OutstandingSource source;
  final DateTime date;

  /// Signed share for [categoryId] (negative = money leaves).
  final int amountMinor;
  final TxnType type;
  final String accountId;
  final String? categoryId;
  final bool isSplit;

  /// Dated before today and still not booked.
  final bool overdue;

  /// Payee or note (planned) or the rule name (recurring).
  final String? title;

  /// Set for [OutstandingSource.planned].
  final String? transactionId;

  /// Set for [OutstandingSource.recurring].
  final RecurringPlan? plan;
  final Occurrence? occurrence;

  @override
  bool operator ==(Object other) =>
      other is OutstandingItem &&
      other.source == source &&
      other.date == date &&
      other.amountMinor == amountMinor &&
      other.type == type &&
      other.accountId == accountId &&
      other.categoryId == categoryId &&
      other.isSplit == isSplit &&
      other.overdue == overdue &&
      other.title == title &&
      other.transactionId == transactionId &&
      other.plan?.id == plan?.id &&
      other.occurrence == occurrence;

  @override
  int get hashCode => Object.hash(
    source,
    date,
    amountMinor,
    type,
    accountId,
    categoryId,
    isSplit,
    overdue,
    transactionId,
    plan?.id,
    occurrence,
  );
}

/// Unposted occurrences of [plans] dated in [range] that count toward
/// budgets, one item per category share.
///
/// * Inactive rules, transfers and rules booking on accounts outside
///   [budgetAccountIds] are ignored.
/// * Only occurrences after the rule's `lastPostedDate` count. Auto-post
///   occurrences before [today] are left out (the startup task posts them);
///   remind & confirm ones stay until they are confirmed or skipped.
/// * An occurrence is left out when a ledger row of the rule already exists
///   on that date ([posted] holds `(ruleId, date)` pairs), so a planned
///   entry created for it is not counted twice.
List<OutstandingItem> recurringOutstanding({
  required List<RecurringPlan> plans,
  required DateRange range,
  required DateTime today,
  required HolidayCalendar calendar,
  required Set<String> budgetAccountIds,
  Set<(String, DateTime)> posted = const {},
}) {
  final day = DateTime(today.year, today.month, today.day);
  final out = <OutstandingItem>[];
  for (final p in plans) {
    if (!p.active || p.isTransfer) continue;
    if (!budgetAccountIds.contains(p.template.accountId)) continue;
    for (final o in p.occurrences(range.start, range.last, calendar)) {
      final last = p.lastPostedDate;
      if (last != null && !o.date.isAfter(last)) continue;
      if (p.mode == PostingMode.autoPost && o.date.isBefore(day)) continue;
      if (posted.contains((p.id, o.date))) continue;
      final amount = p.amountFor(o);
      final splits = scaleSplits(
        p.template.splits,
        p.template.amountMinor,
        amount,
      );
      final shares = splits.isEmpty
          ? [(p.template.categoryId, amount)]
          : [for (final s in splits) (s.categoryId, s.amountMinor)];
      for (final (categoryId, share) in shares) {
        out.add(
          OutstandingItem(
            source: OutstandingSource.recurring,
            date: o.date,
            amountMinor: share,
            type: p.type,
            accountId: p.template.accountId,
            categoryId: categoryId,
            isSplit: splits.isNotEmpty,
            overdue: o.date.isBefore(day),
            title: p.name,
            plan: p,
            occurrence: o,
          ),
        );
      }
    }
  }
  return out;
}

/// Outstanding amounts of a budget period, aggregated like `PeriodActuals`.
@immutable
class PeriodPlanned {
  const PeriodPlanned({
    this.items = const [],
    this.netByCategory = const {},
    this.incomeMinor = 0,
    this.uncategorizedSpentMinor = 0,
  });

  /// Aggregates [items]; [kinds] maps live category ids to their kind
  /// (items of unknown categories count as uncategorised).
  factory PeriodPlanned.fromItems(
    List<OutstandingItem> items,
    Map<String, CategoryKind> kinds,
  ) {
    final net = <String, int>{};
    var income = 0;
    var uncategorized = 0;
    for (final i in items) {
      final cat = i.categoryId;
      final kind = cat == null ? null : kinds[cat];
      if (cat != null && kind != null) {
        net[cat] = (net[cat] ?? 0) + i.amountMinor;
        if (kind == CategoryKind.income) income += i.amountMinor;
      } else if (i.type == TxnType.income) {
        income += i.amountMinor;
      } else {
        uncategorized -= i.amountMinor;
      }
    }
    final sorted = [...items]
      ..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : (a.title ?? '').compareTo(b.title ?? '');
      });
    return PeriodPlanned(
      items: sorted,
      netByCategory: net,
      incomeMinor: income,
      uncategorizedSpentMinor: uncategorized,
    );
  }

  static const empty = PeriodPlanned();

  /// Sorted by date.
  final List<OutstandingItem> items;

  /// Signed net outstanding amount per category id (children separate).
  final Map<String, int> netByCategory;

  /// Expected income: income categories plus uncategorised income.
  final int incomeMinor;

  /// Outstanding spending without a category (positive = to be spent).
  final int uncategorizedSpentMinor;

  bool get isEmpty => items.isEmpty;

  /// Net outstanding spending (positive = still to be spent) of
  /// [categoryId] including its [children].
  int spentOf(String categoryId, [Iterable<String> children = const []]) {
    var net = netByCategory[categoryId] ?? 0;
    for (final c in children) {
      net += netByCategory[c] ?? 0;
    }
    return -net;
  }

  /// Items booked on any of [categoryIds], by date.
  List<OutstandingItem> itemsFor(Set<String> categoryIds) => [
    for (final i in items)
      if (i.categoryId != null && categoryIds.contains(i.categoryId)) i,
  ];

  @override
  bool operator ==(Object other) =>
      other is PeriodPlanned &&
      other.incomeMinor == incomeMinor &&
      other.uncategorizedSpentMinor == uncategorizedSpentMinor &&
      _listEquals(other.items, items);

  @override
  int get hashCode =>
      Object.hash(incomeMinor, uncategorizedSpentMinor, Object.hashAll(items));

  static bool _listEquals(List<OutstandingItem> a, List<OutstandingItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
