import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/tables.dart';

// Pure value types of the reports feature (no Flutter imports).

/// The available reports. [slug] is the path segment of `/reports/:type`.
enum ReportType {
  spending('spending'),
  incomeExpense('income-expense'),
  netWorth('net-worth'),
  categoryTrend('category-trend'),
  topPayees('top-payees'),
  comparison('comparison');

  ReportType(this.slug);

  final String slug;

  static ReportType? fromSlug(String? slug) =>
      values.firstWhereOrNull((t) => t.slug == slug);

  /// Reports that plot a time series and therefore default to the last 12
  /// months instead of the configured default period.
  bool get isTimeSeries =>
      this == incomeExpense || this == netWorth || this == categoryTrend;
}

/// Bucket size for time-series reports.
enum ReportInterval { month, quarter, year, budgetPeriod }

/// Ranking of the top payees report.
enum PayeeSort { total, count, average }

/// Filter on one custom field. [value] is a JSON-compatible scalar: a
/// `String` (text, select, an option of a multiselect), a `num`, a `bool` or
/// a `DateTime` (matched on the calendar day).
@immutable
class CustomFieldFilter {
  const CustomFieldFilter({required this.fieldId, required this.value});

  final String fieldId;
  final Object value;

  @override
  bool operator ==(Object other) =>
      other is CustomFieldFilter &&
      other.fieldId == fieldId &&
      other.value == value;

  @override
  int get hashCode => Object.hash(fieldId, value);
}

/// What a report covers. Empty id sets mean "all".
@immutable
class ReportFilter {
  const ReportFilter({
    required this.range,
    this.accountIds = const {},
    this.tagIds = const {},
    this.customField,
  });

  final DateRange range;

  /// Only these accounts (empty = all).
  final Set<String> accountIds;

  /// Only transactions carrying at least one of these tags (empty = all).
  final Set<String> tagIds;
  final CustomFieldFilter? customField;

  bool get hasNarrowing =>
      accountIds.isNotEmpty || tagIds.isNotEmpty || customField != null;

  static const _unset = Object();

  ReportFilter copyWith({
    DateRange? range,
    Set<String>? accountIds,
    Set<String>? tagIds,
    Object? customField = _unset,
  }) => ReportFilter(
    range: range ?? this.range,
    accountIds: accountIds ?? this.accountIds,
    tagIds: tagIds ?? this.tagIds,
    customField: customField == _unset
        ? this.customField
        : customField as CustomFieldFilter?,
  );

  static const _setEq = SetEquality<String>();

  @override
  bool operator ==(Object other) =>
      other is ReportFilter &&
      other.range == range &&
      _setEq.equals(other.accountIds, accountIds) &&
      _setEq.equals(other.tagIds, tagIds) &&
      other.customField == customField;

  @override
  int get hashCode => Object.hash(
    range,
    _setEq.hash(accountIds),
    _setEq.hash(tagIds),
    customField,
  );
}

/// Global exclusions from Settings › Reports. Excluding a top-level category
/// also excludes its children.
@immutable
class ReportExclusions {
  const ReportExclusions({
    this.categoryIds = const {},
    this.accountIds = const {},
    this.tagIds = const {},
  });

  static const none = ReportExclusions();

  final Set<String> categoryIds;
  final Set<String> accountIds;
  final Set<String> tagIds;

  bool get isEmpty =>
      categoryIds.isEmpty && accountIds.isEmpty && tagIds.isEmpty;

  static const _setEq = SetEquality<String>();

  @override
  bool operator ==(Object other) =>
      other is ReportExclusions &&
      _setEq.equals(other.categoryIds, categoryIds) &&
      _setEq.equals(other.accountIds, accountIds) &&
      _setEq.equals(other.tagIds, tagIds);

  @override
  int get hashCode => Object.hash(
    _setEq.hash(categoryIds),
    _setEq.hash(accountIds),
    _setEq.hash(tagIds),
  );
}

/// Total of one category (or of "uncategorised" when [categoryId] is null).
/// [amountMinor] is positive for net spending (expense reports) or net
/// income (income reports); refunds reduce it.
@immutable
class CategoryAmount {
  const CategoryAmount({
    required this.categoryId,
    required this.name,
    required this.amountMinor,
    required this.count,
    this.icon,
    this.color,
    this.archived = false,
    this.hasChildren = false,
  });

  final String? categoryId;

  /// Category name; null for uncategorised lines.
  final String? name;
  final String? icon;
  final int? color;
  final bool archived;
  final int amountMinor;

  /// Number of distinct transactions.
  final int count;

  /// True when part of the total comes from child categories, so the slice
  /// can be drilled into.
  final bool hasChildren;

  @override
  bool operator ==(Object other) =>
      other is CategoryAmount &&
      other.categoryId == categoryId &&
      other.name == name &&
      other.amountMinor == amountMinor &&
      other.count == count &&
      other.hasChildren == hasChildren;

  @override
  int get hashCode =>
      Object.hash(categoryId, name, amountMinor, count, hasChildren);

  @override
  String toString() => 'CategoryAmount($categoryId, $name, $amountMinor)';
}

/// Income and expenses of one period. Both are positive magnitudes.
@immutable
class PeriodTotals {
  const PeriodTotals({
    required this.range,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final DateRange range;
  final int incomeMinor;
  final int expenseMinor;

  /// Income minus expenses.
  int get netMinor => incomeMinor - expenseMinor;

  /// Share of income kept, in basis points (2730 = 27.30 %); null when there
  /// was no income.
  int? get savingsRateBp =>
      incomeMinor <= 0 ? null : (netMinor * 10000 / incomeMinor).round();

  @override
  bool operator ==(Object other) =>
      other is PeriodTotals &&
      other.range == range &&
      other.incomeMinor == incomeMinor &&
      other.expenseMinor == expenseMinor;

  @override
  int get hashCode => Object.hash(range, incomeMinor, expenseMinor);

  @override
  String toString() => 'PeriodTotals($range, +$incomeMinor, -$expenseMinor)';
}

/// Summary for the dashboard's month summary widget.
typedef MonthSummary = PeriodTotals;

/// Net worth at the end of [range] (balances of all transactions dated
/// before `range.end`).
@immutable
class NetWorthPoint {
  const NetWorthPoint({
    required this.range,
    required this.assetsMinor,
    required this.liabilitiesMinor,
  });

  final DateRange range;

  /// Sum of balances of asset accounts.
  final int assetsMinor;

  /// Sum of balances of liability accounts (normally negative).
  final int liabilitiesMinor;

  int get netWorthMinor => assetsMinor + liabilitiesMinor;

  @override
  bool operator ==(Object other) =>
      other is NetWorthPoint &&
      other.range == range &&
      other.assetsMinor == assetsMinor &&
      other.liabilitiesMinor == liabilitiesMinor;

  @override
  int get hashCode => Object.hash(range, assetsMinor, liabilitiesMinor);

  @override
  String toString() =>
      'NetWorthPoint(${range.start}, $assetsMinor, $liabilitiesMinor)';
}

/// Monthly (or other bucket) totals of one category, including its
/// children. Values are positive for spending (expense categories) or
/// income (income categories).
@immutable
class TrendSeries {
  const TrendSeries({
    required this.categoryId,
    required this.name,
    required this.kind,
    required this.values,
  });

  final String categoryId;
  final String name;
  final CategoryKind kind;

  /// One value per bucket, in bucket order.
  final List<int> values;

  int get totalMinor => values.fold(0, (a, b) => a + b);
}

@immutable
class TrendReport {
  const TrendReport({required this.buckets, required this.series});

  final List<DateRange> buckets;
  final List<TrendSeries> series;
}

@immutable
class PayeeStat {
  const PayeeStat({
    required this.payee,
    required this.totalMinor,
    required this.count,
  });

  final String payee;

  /// Net spending (positive).
  final int totalMinor;
  final int count;

  int get averageMinor => count == 0 ? 0 : (totalMinor / count).round();

  @override
  bool operator ==(Object other) =>
      other is PayeeStat &&
      other.payee == payee &&
      other.totalMinor == totalMinor &&
      other.count == count;

  @override
  int get hashCode => Object.hash(payee, totalMinor, count);

  @override
  String toString() => 'PayeeStat($payee, $totalMinor, $count)';
}

/// One category in the period comparison.
@immutable
class ComparisonRow {
  const ComparisonRow({
    required this.categoryId,
    required this.name,
    required this.currentMinor,
    required this.previousMinor,
    required this.lastYearMinor,
  });

  final String? categoryId;
  final String? name;
  final int currentMinor;
  final int previousMinor;
  final int lastYearMinor;

  int get deltaPreviousMinor => currentMinor - previousMinor;
  int get deltaLastYearMinor => currentMinor - lastYearMinor;

  /// Change vs the previous period in basis points; null when the previous
  /// value is zero.
  int? get deltaPreviousBp => pctChangeBp(previousMinor, currentMinor);
  int? get deltaLastYearBp => pctChangeBp(lastYearMinor, currentMinor);

  @override
  bool operator ==(Object other) =>
      other is ComparisonRow &&
      other.categoryId == categoryId &&
      other.currentMinor == currentMinor &&
      other.previousMinor == previousMinor &&
      other.lastYearMinor == lastYearMinor;

  @override
  int get hashCode =>
      Object.hash(categoryId, currentMinor, previousMinor, lastYearMinor);

  @override
  String toString() =>
      'ComparisonRow($name, $currentMinor, $previousMinor, $lastYearMinor)';
}

@immutable
class ComparisonReport {
  const ComparisonReport({
    required this.current,
    required this.previous,
    required this.lastYear,
    required this.rows,
  });

  final DateRange current;
  final DateRange previous;
  final DateRange lastYear;

  /// Sorted by current value, descending.
  final List<ComparisonRow> rows;

  ComparisonRow get total => ComparisonRow(
    categoryId: null,
    name: null,
    currentMinor: rows.fold(0, (a, r) => a + r.currentMinor),
    previousMinor: rows.fold(0, (a, r) => a + r.previousMinor),
    lastYearMinor: rows.fold(0, (a, r) => a + r.lastYearMinor),
  );
}

/// Relative change from [from] to [to] in basis points (null if [from] is 0).
int? pctChangeBp(int from, int to) =>
    from == 0 ? null : ((to - from) * 10000 / from.abs()).round();
