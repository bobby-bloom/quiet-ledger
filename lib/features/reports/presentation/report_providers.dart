import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/reports/data/report_queries.dart';
import 'package:personal_finance/features/reports/domain/report_models.dart';
import 'package:personal_finance/features/reports/domain/report_periods.dart';

/// "Now" for reports; overridden in tests.
final reportClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The state of one report screen: its filter plus report-specific options.
@immutable
class ReportViewState {
  const ReportViewState({
    required this.filter,
    this.preset,
    this.includeExcluded = false,
    this.interval = ReportInterval.month,
    this.kind = CategoryKind.expense,
    this.payeeSort = PayeeSort.total,
    this.trendCategoryIds = const [],
    this.drillParentId,
  });

  final ReportFilter filter;

  /// The period preset the range came from; null for a custom or stepped
  /// range.
  final ReportPeriod? preset;

  /// Ignore the exclusions of Settings › Reports.
  final bool includeExcluded;
  final ReportInterval interval;

  /// Expense or income (spending, comparison).
  final CategoryKind kind;
  final PayeeSort payeeSort;

  /// Categories of the trend report; empty = the top 3 by spending.
  final List<String> trendCategoryIds;

  /// Spending report drilled into this top-level category.
  final String? drillParentId;

  DateRange get range => filter.range;

  static const _unset = Object();

  ReportViewState copyWith({
    ReportFilter? filter,
    Object? preset = _unset,
    bool? includeExcluded,
    ReportInterval? interval,
    CategoryKind? kind,
    PayeeSort? payeeSort,
    List<String>? trendCategoryIds,
    Object? drillParentId = _unset,
  }) => ReportViewState(
    filter: filter ?? this.filter,
    preset: preset == _unset ? this.preset : preset as ReportPeriod?,
    includeExcluded: includeExcluded ?? this.includeExcluded,
    interval: interval ?? this.interval,
    kind: kind ?? this.kind,
    payeeSort: payeeSort ?? this.payeeSort,
    trendCategoryIds: trendCategoryIds ?? this.trendCategoryIds,
    drillParentId: drillParentId == _unset
        ? this.drillParentId
        : drillParentId as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is ReportViewState &&
      other.filter == filter &&
      other.preset == preset &&
      other.includeExcluded == includeExcluded &&
      other.interval == interval &&
      other.kind == kind &&
      other.payeeSort == payeeSort &&
      const ListEquality<String>().equals(
        other.trendCategoryIds,
        trendCategoryIds,
      ) &&
      other.drillParentId == drillParentId;

  @override
  int get hashCode => Object.hash(
    filter,
    preset,
    includeExcluded,
    interval,
    kind,
    payeeSort,
    Object.hashAll(trendCategoryIds),
    drillParentId,
  );
}

/// Per-report view state (kept while the app runs).
final reportViewProvider =
    NotifierProvider.family<ReportViewController, ReportViewState, ReportType>(
      ReportViewController.new,
    );

class ReportViewController extends Notifier<ReportViewState> {
  ReportViewController(this.type);

  final ReportType type;

  DateTime get _today => ref.read(reportClockProvider)();

  @override
  ReportViewState build() {
    final preset = type.isTimeSeries
        ? ReportPeriod.last12Months
        : ref.read(settingsProvider).get(ReportSettings.defaultPeriod);
    return ReportViewState(
      filter: ReportFilter(range: reportPeriodRange(preset, _today)),
      preset: preset,
    );
  }

  void setPreset(ReportPeriod p) => state = state.copyWith(
    filter: state.filter.copyWith(range: reportPeriodRange(p, _today)),
    preset: p,
  );

  void setRange(DateRange r) => state = state.copyWith(
    filter: state.filter.copyWith(range: r),
    preset: null,
  );

  /// Moves the range by [steps] of its own length.
  void step(int steps) => setRange(shiftRange(state.range, steps));

  void setAccounts(Set<String> ids) =>
      state = state.copyWith(filter: state.filter.copyWith(accountIds: ids));

  void setTags(Set<String> ids) =>
      state = state.copyWith(filter: state.filter.copyWith(tagIds: ids));

  void setCustomField(CustomFieldFilter? f) =>
      state = state.copyWith(filter: state.filter.copyWith(customField: f));

  void clearNarrowing() => state = state.copyWith(
    filter: ReportFilter(range: state.range),
    includeExcluded: false,
  );

  void setIncludeExcluded({required bool value}) =>
      state = state.copyWith(includeExcluded: value);

  void setInterval(ReportInterval i) => state = state.copyWith(interval: i);

  void setKind(CategoryKind k) =>
      state = state.copyWith(kind: k, drillParentId: null);

  void setPayeeSort(PayeeSort s) => state = state.copyWith(payeeSort: s);

  void setTrendCategories(List<String> ids) =>
      state = state.copyWith(trendCategoryIds: ids);

  void drillInto(String? parentId) =>
      state = state.copyWith(drillParentId: parentId);
}

/// Exclusions applying to a report type (none when "include excluded" is on).
final effectiveExclusionsProvider =
    Provider.family<ReportExclusions, ReportType>((ref, type) {
      final include = ref.watch(
        reportViewProvider(type).select((s) => s.includeExcluded),
      );
      return include
          ? ReportExclusions.none
          : ref.watch(reportExclusionsProvider);
    });

/// Buckets of a time-series report for its range and interval.
final reportBucketsProvider = Provider.family<List<DateRange>, ReportType>((
  ref,
  type,
) {
  final s = ref.watch(reportViewProvider(type));
  if (type == ReportType.netWorth) return monthBuckets(s.range);
  return bucketsFor(
    s.range,
    s.interval,
    budget: ref.watch(reportBudgetPeriodsProvider),
    fiscalYearStartMonth: ref.watch(
      settingsProvider.select(
        (x) => x.get(GeneralSettings.fiscalYearStartMonth),
      ),
    ),
  );
});

/// Live child category ids per parent id (for roll-up drill-down links).
final categoryChildrenProvider = Provider<Map<String, List<String>>>((ref) {
  final out = <String, List<String>>{};
  for (final c in ref.watch(categoriesProvider).value ?? const <Category>[]) {
    if (c.parentId != null) (out[c.parentId!] ??= []).add(c.id);
  }
  return out;
});

// ---------------------------------------------------------------- data ---

final spendingReportProvider = StreamProvider<List<CategoryAmount>>((ref) {
  const t = ReportType.spending;
  final s = ref.watch(reportViewProvider(t));
  return ref
      .watch(reportQueriesProvider)
      .watchByCategory(
        s.filter,
        ref.watch(effectiveExclusionsProvider(t)),
        kind: s.kind,
        parentId: s.drillParentId,
      );
});

final incomeExpenseReportProvider = StreamProvider<List<PeriodTotals>>((ref) {
  const t = ReportType.incomeExpense;
  final s = ref.watch(reportViewProvider(t));
  return ref
      .watch(reportQueriesProvider)
      .watchIncomeExpense(
        s.filter,
        ref.watch(effectiveExclusionsProvider(t)),
        ref.watch(reportBucketsProvider(t)),
      );
});

final netWorthReportProvider = StreamProvider<List<NetWorthPoint>>((ref) {
  const t = ReportType.netWorth;
  final s = ref.watch(reportViewProvider(t));
  return ref
      .watch(reportQueriesProvider)
      .watchNetWorth(
        ref.watch(reportBucketsProvider(t)),
        ref.watch(effectiveExclusionsProvider(t)),
        accountIds: s.filter.accountIds,
      );
});

final categoryTrendReportProvider = StreamProvider<TrendReport>((ref) async* {
  const t = ReportType.categoryTrend;
  final s = ref.watch(reportViewProvider(t));
  final q = ref.watch(reportQueriesProvider);
  final ex = ref.watch(effectiveExclusionsProvider(t));
  final buckets = ref.watch(reportBucketsProvider(t));
  final ids = s.trendCategoryIds.isNotEmpty
      ? s.trendCategoryIds
      : await q.topCategoryIds(s.filter, ex);
  yield* q.watchCategoryTrend(s.filter, ex, ids, buckets);
});

final topPayeesReportProvider = StreamProvider<List<PayeeStat>>((ref) {
  const t = ReportType.topPayees;
  final s = ref.watch(reportViewProvider(t));
  return ref
      .watch(reportQueriesProvider)
      .watchTopPayees(
        s.filter,
        ref.watch(effectiveExclusionsProvider(t)),
        sort: s.payeeSort,
        kind: s.kind,
      );
});

final comparisonReportProvider = StreamProvider<ComparisonReport>((ref) {
  const t = ReportType.comparison;
  final s = ref.watch(reportViewProvider(t));
  return ref
      .watch(reportQueriesProvider)
      .watchComparison(
        s.filter,
        ref.watch(effectiveExclusionsProvider(t)),
        kind: s.kind,
      );
});
