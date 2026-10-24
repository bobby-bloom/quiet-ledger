import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/features/reports/domain/report_links.dart';
import 'package:personal_finance/features/reports/domain/report_models.dart';
import 'package:personal_finance/features/reports/domain/report_table.dart';
import 'package:personal_finance/features/reports/presentation/report_format.dart';
import 'package:personal_finance/features/reports/presentation/report_providers.dart';
import 'package:personal_finance/features/reports/presentation/widgets/report_charts.dart';

/// Everything a report screen shows, built from the report's data: the
/// chart (with a spoken summary), an optional header (hero figures,
/// drill-down breadcrumb), the data table (also used for CSV export) and a
/// small preview for the overview card.
class ReportContent {
  const ReportContent({
    required this.chart,
    required this.table,
    required this.summary,
    required this.preview,
    this.header,
    this.isEmpty = false,
    this.onDrill,
    this.drillTooltip,
  });

  final Widget chart;
  final Widget? header;
  final ReportTable table;
  final String summary;
  final Widget preview;
  final bool isEmpty;
  final ValueChanged<String>? onDrill;
  final String? drillTooltip;
}

/// Localised title of a report.
String reportTitle(
  BuildContext context,
  ReportType type, {
  CategoryKind? kind,
}) {
  final l = context.l10n;
  return switch (type) {
    ReportType.spending =>
      kind == CategoryKind.income
          ? l.reportsIncomeByCategoryTitle
          : l.reportsSpendingTitle,
    ReportType.incomeExpense => l.reportsIncomeExpenseTitle,
    ReportType.netWorth => l.reportsNetWorthTitle,
    ReportType.categoryTrend => l.reportsCategoryTrendTitle,
    ReportType.topPayees => l.reportsTopPayeesTitle,
    ReportType.comparison => l.reportsComparisonTitle,
  };
}

IconData reportIcon(ReportType type) => switch (type) {
  ReportType.spending => Icons.donut_large_outlined,
  ReportType.incomeExpense => Icons.bar_chart_outlined,
  ReportType.netWorth => Icons.show_chart_outlined,
  ReportType.categoryTrend => Icons.stacked_line_chart_outlined,
  ReportType.topPayees => Icons.storefront_outlined,
  ReportType.comparison => Icons.compare_arrows_outlined,
};

/// Watches the data of [type] and builds its [ReportContent].
AsyncValue<ReportContent> watchReportContent(
  BuildContext context,
  WidgetRef ref,
  ReportType type,
) => switch (type) {
  ReportType.spending => _spending(context, ref),
  ReportType.incomeExpense => _incomeExpense(context, ref),
  ReportType.netWorth => _netWorth(context, ref),
  ReportType.categoryTrend => _trend(context, ref),
  ReportType.topPayees => _payees(context, ref),
  ReportType.comparison => _comparison(context, ref),
};

// ------------------------------------------------------------ helpers ---

const _maxSlices = 6;

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: context.text.labelMedium?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 2),
      DefaultTextStyle.merge(
        style: context.text.titleMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        child: child,
      ),
    ],
  );
}

Widget _stats(List<Widget> stats) =>
    Wrap(spacing: Space.xl, runSpacing: Space.sm, children: stats);

Widget _empty(BuildContext context) => SizedBox(
  height: 120,
  child: Center(
    child: Text(
      context.l10n.reportsNoData,
      style: context.text.bodyMedium?.copyWith(
        color: context.colors.onSurfaceVariant,
      ),
    ),
  ),
);

/// Short "A €1, B €2, C €3" list for spoken summaries.
String _topItems(Iterable<(String, String)> items) =>
    items.map((e) => '${e.$1} ${e.$2}').join(', ');

int _shareBp(int part, int whole) =>
    whole <= 0 ? 0 : (part * 10000 / whole).round();

// ----------------------------------------------------------- spending ---

AsyncValue<ReportContent> _spending(BuildContext context, WidgetRef ref) {
  const t = ReportType.spending;
  final s = ref.watch(reportViewProvider(t));
  final ctrl = ref.read(reportViewProvider(t).notifier);
  final fmt = ReportFormat.of(context, ref);
  final l = context.l10n;
  final fin = context.finance;
  final cats = ref.watch(categoryMapProvider);
  final children = ref.watch(categoryChildrenProvider);
  final title = reportTitle(context, t, kind: s.kind);
  final drill = s.drillParentId;

  return ref.watch(spendingReportProvider).whenData((rows) {
    final positive = rows.where((r) => r.amountMinor > 0).toList();
    final positiveTotal = positive.fold(0, (a, r) => a + r.amountMinor);
    final total = rows.fold(0, (a, r) => a + r.amountMinor);

    String link(CategoryAmount r) => transactionsLocation(
      range: s.range,
      filter: s.filter,
      kind: s.kind,
      categoryId: r.categoryId,
      uncategorized: r.categoryId == null,
      childIds: drill == null ? children[r.categoryId] ?? const [] : const [],
    );

    String name(CategoryAmount r) => fmt.categoryName(r.name);

    // Slices: up to six, otherwise five plus "Other".
    final slices = <DonutSlice>[];
    final sliceRows = <CategoryAmount?>[];
    final split = positive.length > _maxSlices
        ? _maxSlices - 1
        : positive.length;
    for (var i = 0; i < split; i++) {
      slices.add(
        DonutSlice(
          label: name(positive[i]),
          value: positive[i].amountMinor,
          color: fin.chartAt(i),
        ),
      );
      sliceRows.add(positive[i]);
    }
    if (positive.length > split) {
      slices.add(
        DonutSlice(
          label: l.reportsOther,
          value: positive.skip(split).fold(0, (a, r) => a + r.amountMinor),
          color: fin.chartOther,
        ),
      );
      sliceRows.add(null);
    }

    void tapSlice(int i) {
      final r = sliceRows[i];
      if (r == null) return;
      if (drill == null && r.hasChildren && r.categoryId != null) {
        ctrl.drillInto(r.categoryId);
      } else {
        context.go(link(r));
      }
    }

    final legend = [
      for (final sl in slices)
        LegendEntry(sl.color, '${sl.label} · ${fmt.amount(sl.value)}'),
    ];

    final summary = l.reportsDonutSummary(
      title,
      fmt.amount(total),
      _topItems(
        positive
            .take(3)
            .map(
              (r) => (
                name(r),
                '${fmt.amount(r.amountMinor)} '
                    '(${fmt.percent(_shareBp(r.amountMinor, positiveTotal))})',
              ),
            ),
      ),
    );

    final table = ReportTable(
      columns: [
        ReportColumn(l.fieldCategory),
        ReportColumn(l.fieldAmount, numeric: true),
        ReportColumn(l.reportsColShare, numeric: true),
        ReportColumn(l.reportsColCount, numeric: true),
      ],
      rows: [
        for (final r in rows)
          ReportRow(
            [
              ReportCell.text(
                r.archived ? '${name(r)} (${l.reportsArchived})' : name(r),
              ),
              ReportCell.money(r.amountMinor),
              ReportCell.percent(
                r.amountMinor > 0
                    ? _shareBp(r.amountMinor, positiveTotal)
                    : null,
              ),
              ReportCell.count(r.count),
            ],
            link: link(r),
            drill: drill == null && r.hasChildren ? r.categoryId : null,
          ),
        if (rows.isNotEmpty)
          ReportRow([
            ReportCell.text(l.reportsTotal),
            ReportCell.money(total),
            const ReportCell.percent(10000),
            ReportCell.count(rows.fold(0, (a, r) => a + r.count)),
          ], emphasis: true),
      ],
    );

    final parent = drill == null ? null : cats[drill];
    final header = drill == null
        ? null
        : Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Space.xs,
            children: [
              TextButton.icon(
                onPressed: () => ctrl.drillInto(null),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(l.reportsAllCategories),
              ),
              Text(
                parent?.name ?? l.reportsUncategorized,
                style: context.text.titleSmall,
              ),
              TextButton(
                onPressed: () => context.go(
                  transactionsLocation(
                    range: s.range,
                    filter: s.filter,
                    kind: s.kind,
                    categoryId: drill,
                    childIds: children[drill] ?? const [],
                  ),
                ),
                child: Text(l.reportsShowTransactions),
              ),
            ],
          );

    final chart = positive.isEmpty
        ? _empty(context)
        : ChartSemantics(
            summary: summary,
            child: LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth >= 520;
                final donut = SizedBox(
                  width: wide ? 260 : 240,
                  height: wide ? 260 : 240,
                  child: CategoryDonut(
                    slices: slices,
                    total: positiveTotal,
                    totalLabel: l.reportsTotal,
                    formatAmount: fmt.amount,
                    onTapSlice: tapSlice,
                  ),
                );
                final leg = ChartLegend(entries: legend, onTap: tapSlice);
                if (!wide) {
                  return Column(
                    children: [
                      donut,
                      const SizedBox(height: Space.md),
                      leg,
                    ],
                  );
                }
                return Row(
                  children: [
                    donut,
                    const SizedBox(width: Space.xl),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < legend.length; i++)
                            ChartLegend(
                              entries: [legend[i]],
                              onTap: (_) => tapSlice(i),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );

    final preview = positive.isEmpty
        ? _empty(context)
        : Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: CategoryDonut(
                  slices: slices,
                  total: positiveTotal,
                  totalLabel: l.reportsTotal,
                  formatAmount: fmt.amount,
                  compact: true,
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AmountText(
                      positiveTotal,
                      colored: false,
                      style: context.text.titleLarge,
                    ),
                    const SizedBox(height: Space.xxs),
                    ChartLegend(entries: legend.take(3).toList()),
                  ],
                ),
              ),
            ],
          );

    return ReportContent(
      chart: chart,
      header: header,
      table: table,
      summary: summary,
      preview: preview,
      isEmpty: rows.isEmpty,
      onDrill: ctrl.drillInto,
      drillTooltip: l.reportsSubcategories,
    );
  });
}

// --------------------------------------------------- income vs expense ---

AsyncValue<ReportContent> _incomeExpense(BuildContext context, WidgetRef ref) {
  const t = ReportType.incomeExpense;
  final s = ref.watch(reportViewProvider(t));
  final fmt = ReportFormat.of(context, ref);
  final l = context.l10n;
  final fin = context.finance;

  return ref.watch(incomeExpenseReportProvider).whenData((rows) {
    final income = rows.fold(0, (a, r) => a + r.incomeMinor);
    final expense = rows.fold(0, (a, r) => a + r.expenseMinor);
    final total = PeriodTotals(
      range: s.range,
      incomeMinor: income,
      expenseMinor: expense,
    );
    final labels = [
      for (final r in rows) fmt.bucket(r.range, s.interval, short: true),
    ];
    final titles = [for (final r in rows) fmt.bucket(r.range, s.interval)];
    final series = [
      BarSeries(
        label: l.reportsColIncome,
        color: fin.income,
        values: [for (final r in rows) r.incomeMinor],
      ),
      BarSeries(
        label: l.reportsColExpenses,
        color: fin.expenseFill,
        values: [for (final r in rows) r.expenseMinor],
      ),
    ];
    final summary = l.reportsBarsSummary(
      rows.length,
      fmt.amount(income),
      fmt.amount(expense),
    );
    final isEmpty = income == 0 && expense == 0;
    final legend = ChartLegend(
      entries: [for (final x in series) LegendEntry(x.color, x.label)],
    );

    final table = ReportTable(
      columns: [
        ReportColumn(l.reportsColPeriod),
        ReportColumn(l.reportsColIncome, numeric: true),
        ReportColumn(l.reportsColExpenses, numeric: true),
        ReportColumn(l.reportsColNet, numeric: true),
        ReportColumn(l.reportsColSavingsRate, numeric: true),
      ],
      rows: [
        for (var i = 0; i < rows.length; i++)
          ReportRow(
            [
              ReportCell.text(titles[i]),
              ReportCell.money(rows[i].incomeMinor),
              ReportCell.money(rows[i].expenseMinor),
              ReportCell.money(rows[i].netMinor, signed: true),
              ReportCell.percent(rows[i].savingsRateBp),
            ],
            link: transactionsLocation(range: rows[i].range, filter: s.filter),
          ),
        if (rows.length > 1)
          ReportRow([
            ReportCell.text(l.reportsTotal),
            ReportCell.money(income),
            ReportCell.money(expense),
            ReportCell.money(total.netMinor, signed: true),
            ReportCell.percent(total.savingsRateBp),
          ], emphasis: true),
      ],
    );

    final header = _stats([
      _Stat(label: l.reportsColIncome, child: AmountText(income)),
      _Stat(
        label: l.reportsColExpenses,
        child: AmountText(-expense, colored: false),
      ),
      _Stat(
        label: l.reportsNetChange,
        child: AmountText(total.netMinor, explicitPlus: true, colored: false),
      ),
      _Stat(
        label: l.reportsSavingsRate,
        child: Text(
          total.savingsRateBp == null ? '–' : fmt.percent(total.savingsRateBp!),
        ),
      ),
    ]);

    Widget chartOf({required bool compact}) => GroupedBarChart(
      series: series,
      labels: labels,
      tooltipTitles: titles,
      formatAmount: fmt.amount,
      formatAxis: fmt.compact,
      compact: compact,
    );

    return ReportContent(
      chart: isEmpty
          ? _empty(context)
          : ChartSemantics(
              summary: summary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  legend,
                  const SizedBox(height: Space.sm),
                  SizedBox(height: 260, child: chartOf(compact: false)),
                ],
              ),
            ),
      header: header,
      table: table,
      summary: summary,
      isEmpty: isEmpty,
      preview: isEmpty
          ? _empty(context)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                legend,
                const SizedBox(height: Space.xs),
                Expanded(child: chartOf(compact: true)),
              ],
            ),
    );
  });
}

// ---------------------------------------------------------- net worth ---

AsyncValue<ReportContent> _netWorth(BuildContext context, WidgetRef ref) {
  final fmt = ReportFormat.of(context, ref);
  final l = context.l10n;

  return ref.watch(netWorthReportProvider).whenData((points) {
    final values = [for (final p in points) p.netWorthMinor];
    final labels = [
      for (final p in points) fmt.dates.monthShort(p.range.start),
    ];
    final titles = [for (final p in points) fmt.dates.monthYear(p.range.start)];
    final last = points.isEmpty ? 0 : points.last.netWorthMinor;
    final first = points.isEmpty ? 0 : points.first.netWorthMinor;
    final change = last - first;
    final summary = points.isEmpty
        ? l.reportsNoData
        : l.reportsLineSummary(
            titles.first,
            titles.last,
            fmt.amount(first),
            fmt.amount(last),
          );
    final series = [
      LineSeries(
        label: l.reportsColNetWorth,
        color: context.colors.primary,
        values: values,
        fill: true,
      ),
    ];
    final table = ReportTable(
      columns: [
        ReportColumn(l.reportsColMonth),
        ReportColumn(l.reportsColAssets, numeric: true),
        ReportColumn(l.reportsColLiabilities, numeric: true),
        ReportColumn(l.reportsColNetWorth, numeric: true),
      ],
      rows: [
        for (var i = 0; i < points.length; i++)
          ReportRow([
            ReportCell.text(titles[i]),
            ReportCell.money(points[i].assetsMinor),
            ReportCell.money(points[i].liabilitiesMinor),
            ReportCell.money(points[i].netWorthMinor),
          ]),
      ],
    );
    final hero = AmountText(
      last,
      colored: false,
      style: context.text.headlineSmall,
    );
    final changeText = Text(
      l.reportsChangeInPeriod(fmt.amount(change, signed: true)),
      style: context.text.bodyMedium?.copyWith(
        color: context.colors.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    Widget chartOf({required bool compact}) => SeriesLineChart(
      series: series,
      labels: labels,
      tooltipTitles: titles,
      formatAmount: fmt.amount,
      formatAxis: fmt.compact,
      compact: compact,
    );
    return ReportContent(
      chart: points.isEmpty
          ? _empty(context)
          : ChartSemantics(
              summary: summary,
              child: SizedBox(height: 260, child: chartOf(compact: false)),
            ),
      header: Wrap(
        spacing: Space.md,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [hero, changeText],
      ),
      table: table,
      summary: summary,
      isEmpty: points.isEmpty,
      preview: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AmountText(last, colored: false, style: context.text.titleLarge),
          changeText,
          const SizedBox(height: Space.xs),
          Expanded(child: chartOf(compact: true)),
        ],
      ),
    );
  });
}

// ----------------------------------------------------- category trend ---

AsyncValue<ReportContent> _trend(BuildContext context, WidgetRef ref) {
  const t = ReportType.categoryTrend;
  final s = ref.watch(reportViewProvider(t));
  final fmt = ReportFormat.of(context, ref);
  final l = context.l10n;
  final fin = context.finance;

  final children = ref.watch(categoryChildrenProvider);

  return ref.watch(categoryTrendReportProvider).whenData((report) {
    final buckets = report.buckets;
    final labels = [
      for (final b in buckets) fmt.bucket(b, s.interval, short: true),
    ];
    final titles = [for (final b in buckets) fmt.bucket(b, s.interval)];
    final series = [
      for (var i = 0; i < report.series.length; i++)
        LineSeries(
          label: report.series[i].name,
          color: fin.chartAt(i),
          values: report.series[i].values,
        ),
    ];
    String link(TrendSeries x) => transactionsLocation(
      range: s.range,
      filter: s.filter,
      kind: x.kind,
      categoryId: x.categoryId,
      childIds: children[x.categoryId] ?? const [],
    );
    final summary = l.reportsTrendSummary(
      buckets.length,
      _topItems(report.series.map((x) => (x.name, fmt.amount(x.totalMinor)))),
    );
    final isEmpty =
        report.series.isEmpty || report.series.every((x) => x.totalMinor == 0);
    final legend = ChartLegend(
      entries: [for (final x in series) LegendEntry(x.color, x.label)],
      onTap: (i) => context.go(link(report.series[i])),
    );
    final table = ReportTable(
      columns: [
        ReportColumn(l.reportsColPeriod),
        for (final x in report.series) ReportColumn(x.name, numeric: true),
      ],
      rows: [
        for (var b = 0; b < buckets.length; b++)
          ReportRow([
            ReportCell.text(titles[b]),
            for (final x in report.series) ReportCell.money(x.values[b]),
          ]),
        if (buckets.length > 1 && report.series.isNotEmpty)
          ReportRow([
            ReportCell.text(l.reportsTotal),
            for (final x in report.series) ReportCell.money(x.totalMinor),
          ], emphasis: true),
      ],
    );
    Widget chartOf({required bool compact}) => SeriesLineChart(
      series: series,
      labels: labels,
      tooltipTitles: titles,
      formatAmount: fmt.amount,
      formatAxis: fmt.compact,
      compact: compact,
    );
    return ReportContent(
      chart: isEmpty
          ? _empty(context)
          : ChartSemantics(
              summary: summary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  legend,
                  const SizedBox(height: Space.sm),
                  SizedBox(height: 260, child: chartOf(compact: false)),
                ],
              ),
            ),
      table: table,
      summary: summary,
      isEmpty: isEmpty,
      preview: isEmpty
          ? _empty(context)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChartLegend(
                  entries: [
                    for (final x in series) LegendEntry(x.color, x.label),
                  ],
                ),
                const SizedBox(height: Space.xs),
                Expanded(child: chartOf(compact: true)),
              ],
            ),
    );
  });
}

// --------------------------------------------------------- top payees ---

AsyncValue<ReportContent> _payees(BuildContext context, WidgetRef ref) {
  const t = ReportType.topPayees;
  final s = ref.watch(reportViewProvider(t));
  final fmt = ReportFormat.of(context, ref);
  final l = context.l10n;

  return ref.watch(topPayeesReportProvider).whenData((rows) {
    String link(PayeeStat p) => transactionsLocation(
      range: s.range,
      filter: s.filter,
      kind: s.kind,
      payee: p.payee,
    );
    int metric(PayeeStat p) => switch (s.payeeSort) {
      PayeeSort.total => p.totalMinor,
      PayeeSort.count => p.count,
      PayeeSort.average => p.averageMinor,
    };
    String metricText(PayeeStat p) => switch (s.payeeSort) {
      PayeeSort.count => '${p.count}',
      _ => fmt.amount(metric(p)),
    };
    HBarItem item(PayeeStat p) => HBarItem(
      label: p.payee,
      value: metric(p) < 0 ? 0 : metric(p),
      valueText: metricText(p),
      tooltip:
          '${p.payee}: ${fmt.amount(p.totalMinor)} · '
          '${l.reportsColCount} ${p.count} · '
          '${l.reportsColAverage} ${fmt.amount(p.averageMinor)}',
      onTap: () => context.go(link(p)),
    );
    final summary = l.reportsPayeesSummary(
      _topItems(rows.take(5).map((p) => (p.payee, metricText(p)))),
    );
    final table = ReportTable(
      columns: [
        ReportColumn(l.fieldPayee),
        ReportColumn(l.reportsSortTotal, numeric: true),
        ReportColumn(l.reportsColCount, numeric: true),
        ReportColumn(l.reportsColAverage, numeric: true),
      ],
      rows: [
        for (final p in rows)
          ReportRow([
            ReportCell.text(p.payee),
            ReportCell.money(p.totalMinor),
            ReportCell.count(p.count),
            ReportCell.money(p.averageMinor),
          ], link: link(p)),
      ],
    );
    final chartBars = HorizontalBars(
      items: [for (final p in rows.take(12)) item(p)],
      color: s.kind == CategoryKind.income
          ? context.finance.income
          : context.finance.expenseFill,
    );
    return ReportContent(
      chart: rows.isEmpty
          ? _empty(context)
          : ChartSemantics(summary: summary, child: chartBars),
      table: table,
      summary: summary,
      isEmpty: rows.isEmpty,
      preview: rows.isEmpty
          ? _empty(context)
          : HorizontalBars(
              items: [for (final p in rows.take(3)) item(p)],
              color: context.finance.expenseFill,
              compact: true,
            ),
    );
  });
}

// -------------------------------------------------- period comparison ---

AsyncValue<ReportContent> _comparison(BuildContext context, WidgetRef ref) {
  const t = ReportType.comparison;
  final s = ref.watch(reportViewProvider(t));
  final fmt = ReportFormat.of(context, ref);
  final l = context.l10n;
  final fin = context.finance;

  final children = ref.watch(categoryChildrenProvider);

  return ref.watch(comparisonReportProvider).whenData((r) {
    final total = r.total;
    String name(ComparisonRow x) => fmt.categoryName(x.name);
    String link(ComparisonRow x) => transactionsLocation(
      range: r.current,
      filter: s.filter,
      kind: s.kind,
      categoryId: x.categoryId,
      uncategorized: x.categoryId == null,
      childIds: children[x.categoryId] ?? const [],
    );
    String delta(int minor, int? bp) =>
        '${fmt.amount(minor, signed: true)}'
        '${bp == null ? '' : ' (${fmt.percent(bp, signed: true)})'}';

    final summary = l.reportsComparisonSummary(
      fmt.amount(total.currentMinor),
      fmt.amount(total.previousMinor),
      fmt.amount(total.lastYearMinor),
    );
    final top = r.rows.take(6).toList();
    final series = [
      BarSeries(
        label: fmt.range(r.current),
        color: context.colors.primary,
        values: [for (final x in top) x.currentMinor],
      ),
      BarSeries(
        label: fmt.range(r.previous),
        color: fin.chartOther,
        values: [for (final x in top) x.previousMinor],
      ),
      BarSeries(
        label: fmt.range(r.lastYear),
        color: fin.chartAt(1),
        values: [for (final x in top) x.lastYearMinor],
      ),
    ];
    final table = ReportTable(
      columns: [
        ReportColumn(l.fieldCategory),
        ReportColumn(l.reportsColCurrent, numeric: true),
        ReportColumn(l.reportsColPrevious, numeric: true),
        ReportColumn(l.reportsColDeltaPrevious, numeric: true),
        ReportColumn(l.reportsColDeltaPreviousPct, numeric: true),
        ReportColumn(l.reportsColLastYear, numeric: true),
        ReportColumn(l.reportsColDeltaLastYear, numeric: true),
        ReportColumn(l.reportsColDeltaLastYearPct, numeric: true),
      ],
      rows: [
        for (final x in [...r.rows, if (r.rows.isNotEmpty) total])
          ReportRow(
            [
              ReportCell.text(identical(x, total) ? l.reportsTotal : name(x)),
              ReportCell.money(x.currentMinor),
              ReportCell.money(x.previousMinor),
              ReportCell.money(x.deltaPreviousMinor, signed: true),
              ReportCell.percent(x.deltaPreviousBp, signed: true),
              ReportCell.money(x.lastYearMinor),
              ReportCell.money(x.deltaLastYearMinor, signed: true),
              ReportCell.percent(x.deltaLastYearBp, signed: true),
            ],
            link: identical(x, total) ? null : link(x),
            emphasis: identical(x, total),
          ),
      ],
    );
    final header = _stats([
      _Stat(
        label: fmt.range(r.current),
        child: AmountText(total.currentMinor, colored: false),
      ),
      _Stat(
        label: l.reportsVsPrevious,
        child: Text(delta(total.deltaPreviousMinor, total.deltaPreviousBp)),
      ),
      _Stat(
        label: l.reportsVsLastYear,
        child: Text(delta(total.deltaLastYearMinor, total.deltaLastYearBp)),
      ),
    ]);
    final isEmpty = r.rows.isEmpty;
    return ReportContent(
      chart: isEmpty
          ? _empty(context)
          : ChartSemantics(
              summary: summary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChartLegend(
                    entries: [
                      for (final x in series) LegendEntry(x.color, x.label),
                    ],
                  ),
                  const SizedBox(height: Space.sm),
                  SizedBox(
                    height: 260,
                    child: GroupedBarChart(
                      series: series,
                      labels: [for (final x in top) _shortLabel(name(x))],
                      tooltipTitles: [for (final x in top) name(x)],
                      formatAmount: fmt.amount,
                      formatAxis: fmt.compact,
                    ),
                  ),
                ],
              ),
            ),
      header: header,
      table: table,
      summary: summary,
      isEmpty: isEmpty,
      preview: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AmountText(
            total.currentMinor,
            colored: false,
            style: context.text.titleLarge,
          ),
          const SizedBox(height: Space.xs),
          _PreviewLine(
            label: l.reportsVsPrevious,
            value: delta(total.deltaPreviousMinor, total.deltaPreviousBp),
          ),
          _PreviewLine(
            label: l.reportsVsLastYear,
            value: delta(total.deltaLastYearMinor, total.deltaLastYearBp),
          ),
        ],
      ),
    );
  });
}

String _shortLabel(String s) => s.length <= 10 ? s : '${s.substring(0, 9)}…';

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: context.text.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          value,
          style: context.text.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

/// Range shown in the subtitle of a report card.
DateRange reportRange(WidgetRef ref, ReportType type) =>
    ref.watch(reportViewProvider(type).select((s) => s.range));
