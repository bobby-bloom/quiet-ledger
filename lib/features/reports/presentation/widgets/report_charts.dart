import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';

// Chart building blocks on top of fl_chart, following the "Quiet Ledger"
// language: hairline recessive grid, 2px lines, thin rounded bars, 2px
// surface gaps between donut segments, series colours from FinanceColors,
// text in text tokens only. Every chart is wrapped in a Semantics summary;
// the data table beneath it carries the details.

/// Tooltip surface used by all charts.
Color _tooltipBg(BuildContext c) => c.colors.inverseSurface;

TextStyle _tooltipText(BuildContext c) =>
    (c.text.labelMedium ?? const TextStyle()).copyWith(
      color: c.colors.onInverseSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

TextStyle _axisText(BuildContext c) =>
    (c.text.labelSmall ?? const TextStyle()).copyWith(
      color: c.colors.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Wraps [child] (a chart) as one image with a spoken [summary].
class ChartSemantics extends StatelessWidget {
  const ChartSemantics({required this.summary, required this.child, super.key});

  final String summary;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    image: true,
    label: summary,
    child: ExcludeSemantics(child: child),
  );
}

/// A legend entry: colour swatch + label.
class LegendEntry {
  const LegendEntry(this.color, this.label, {this.dashed = false});

  final Color color;
  final String label;
  final bool dashed;
}

class ChartLegend extends StatelessWidget {
  const ChartLegend({required this.entries, super.key, this.onTap});

  final List<LegendEntry> entries;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.md,
      runSpacing: Space.xxs,
      children: [
        for (var i = 0; i < entries.length; i++)
          InkWell(
            borderRadius: BorderRadius.circular(Radii.sm),
            onTap: onTap == null ? null : () => onTap!(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xxs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: entries[i].color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: Space.xs - 2),
                  Text(
                    entries[i].label,
                    style: context.text.labelMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------- donut ---

class DonutSlice {
  const DonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;

  /// Positive amount in minor units.
  final int value;
  final Color color;
}

/// Donut with the total (or the hovered/touched slice) in the centre.
class CategoryDonut extends StatefulWidget {
  const CategoryDonut({
    required this.slices,
    required this.total,
    required this.totalLabel,
    required this.formatAmount,
    super.key,
    this.onTapSlice,
    this.compact = false,
  });

  final List<DonutSlice> slices;
  final int total;
  final String totalLabel;
  final String Function(int minor) formatAmount;
  final ValueChanged<int>? onTapSlice;

  /// Small preview without interaction and centre label.
  final bool compact;

  @override
  State<CategoryDonut> createState() => _CategoryDonutState();
}

class _CategoryDonutState extends State<CategoryDonut> {
  int? _active;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = math.min(
          box.maxWidth,
          box.maxHeight.isFinite ? box.maxHeight : box.maxWidth,
        );
        final ring = widget.compact ? size * 0.14 : math.max(18, size * 0.12);
        final radius = size / 2;
        final hole = radius - ring - 4;
        final active = _active;
        final centerLabel = active == null || active >= widget.slices.length
            ? widget.totalLabel
            : widget.slices[active].label;
        final centerValue = active == null || active >= widget.slices.length
            ? widget.total
            : widget.slices[active].value;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: hole,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    enabled: !widget.compact,
                    touchCallback: _onTouch,
                    mouseCursorResolver: (event, r) =>
                        r?.touchedSection?.touchedSectionIndex == null ||
                            r!.touchedSection!.touchedSectionIndex < 0
                        ? MouseCursor.defer
                        : SystemMouseCursors.click,
                  ),
                  sections: [
                    for (var i = 0; i < widget.slices.length; i++)
                      PieChartSectionData(
                        value: widget.slices[i].value.toDouble(),
                        color: widget.slices[i].color,
                        radius: ring + (i == active ? 4 : 0),
                        showTitle: false,
                      ),
                  ],
                ),
                duration: Duration.zero,
              ),
              if (!widget.compact)
                SizedBox(
                  width: hole * 1.6,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        centerLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: context.text.labelMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AmountText(
                          centerValue,
                          colored: false,
                          style: context.text.titleLarge,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _onTouch(FlTouchEvent event, PieTouchResponse? r) {
    final idx = r?.touchedSection?.touchedSectionIndex;
    final valid = idx != null && idx >= 0 ? idx : null;
    if (event is FlPointerExitEvent || event is FlLongPressEnd) {
      setState(() => _active = null);
      return;
    }
    if (event is FlTapUpEvent) {
      if (valid != null) widget.onTapSlice?.call(valid);
      return;
    }
    if (event.isInterestedForInteractions && valid != _active) {
      setState(() => _active = valid);
    }
  }
}

// -------------------------------------------------------- bar chart ---

class BarSeries {
  const BarSeries({
    required this.label,
    required this.color,
    required this.values,
  });

  final String label;
  final Color color;
  final List<int> values;
}

double _niceMax(double v) {
  if (v <= 0) return 1;
  final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  for (final m in [1, 2, 2.5, 5, 10]) {
    if (m * exp >= v) return m * exp;
  }
  return 10 * exp;
}

/// Axis bounds and tick step with round values (about four intervals).
(double, double, double) _niceScale(
  double lo,
  double hi, {
  bool includeZero = true,
}) {
  var a = includeZero ? math.min(0, lo).toDouble() : lo;
  var b = includeZero ? math.max(0, hi).toDouble() : hi;
  if (a == b) {
    a -= 1;
    b += 1;
  }
  final step = _niceMax((b - a) / 4);
  final bottom = (a / step).floor() * step;
  var top = (b / step).ceil() * step;
  if (top == bottom) top += step;
  return (bottom, top, step);
}

Widget _bottomTitle(
  BuildContext context,
  List<String> labels,
  double value,
  int every,
) {
  final i = value.round();
  if (i < 0 || i >= labels.length || i % every != 0) {
    return const SizedBox.shrink();
  }
  return Padding(
    padding: const EdgeInsets.only(top: Space.xxs),
    child: Text(labels[i], style: _axisText(context)),
  );
}

FlGridData _grid(BuildContext context, double interval) => FlGridData(
  drawVerticalLine: false,
  horizontalInterval: interval,
  getDrawingHorizontalLine: (_) =>
      FlLine(color: context.colors.surfaceContainerHigh, strokeWidth: 1),
);

/// Grouped column chart (e.g. income vs expenses per period).
class GroupedBarChart extends StatelessWidget {
  const GroupedBarChart({
    required this.series,
    required this.labels,
    required this.formatAmount,
    required this.formatAxis,
    super.key,
    this.compact = false,
    this.tooltipTitles,
  });

  final List<BarSeries> series;

  /// Axis label per group.
  final List<String> labels;

  /// Tooltip title per group (defaults to [labels]).
  final List<String>? tooltipTitles;
  final String Function(int minor) formatAmount;
  final String Function(int minor) formatAxis;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final groups = labels.length;
    var maxV = 0;
    var minV = 0;
    for (final s in series) {
      for (final v in s.values) {
        maxV = math.max(maxV, v);
        minV = math.min(minV, v);
      }
    }
    // Chart coordinates are in major units.
    final (bottom, top, interval) = _niceScale(minV / 100, maxV / 100);
    final rodWidth = math
        .min(12, groups == 0 ? 12 : 240 / (groups * series.length))
        .toDouble()
        .clamp(3, 12)
        .toDouble();
    final every = math.max(1, (groups / (compact ? 6 : 12)).ceil());
    final titles = tooltipTitles ?? labels;
    return BarChart(
      BarChartData(
        maxY: top,
        minY: bottom,
        alignment: BarChartAlignment.spaceAround,
        groupsSpace: 4,
        gridData: compact
            ? const FlGridData(show: false)
            : _grid(context, interval),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: !compact,
              reservedSize: 52,
              interval: interval,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  formatAxis((v * 100).round()),
                  style: _axisText(context),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, meta) =>
                  _bottomTitle(context, labels, v, every),
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: !compact,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => _tooltipBg(context),
            tooltipBorderRadius: BorderRadius.circular(Radii.sm),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            maxContentWidth: 200,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              rodIndex == 0 ? '${titles[groupIndex]}\n' : '',
              _tooltipText(context).copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.left,
              children: [
                TextSpan(
                  text:
                      '${series[rodIndex].label}: '
                      '${formatAmount(series[rodIndex].values[groupIndex])}',
                  style: _tooltipText(context),
                ),
              ],
            ),
          ),
        ),
        barGroups: [
          for (var g = 0; g < groups; g++)
            BarChartGroupData(
              x: g,
              barsSpace: 2,
              barRods: [
                for (final s in series)
                  BarChartRodData(
                    toY: s.values[g] / 100,
                    color: s.color,
                    width: rodWidth,
                    borderRadius: s.values[g] >= 0
                        ? const BorderRadius.vertical(top: Radius.circular(4))
                        : const BorderRadius.vertical(
                            bottom: Radius.circular(4),
                          ),
                  ),
              ],
            ),
        ],
      ),
      duration: Duration.zero,
    );
  }
}

// ------------------------------------------------------- line chart ---

class LineSeries {
  const LineSeries({
    required this.label,
    required this.color,
    required this.values,
    this.fill = false,
  });

  final String label;
  final Color color;
  final List<int> values;

  /// Area wash at 10 % opacity.
  final bool fill;
}

/// Line chart of one or more series over shared buckets, with a crosshair
/// tooltip (hover on desktop, touch on mobile).
class SeriesLineChart extends StatelessWidget {
  const SeriesLineChart({
    required this.series,
    required this.labels,
    required this.formatAmount,
    required this.formatAxis,
    super.key,
    this.compact = false,
    this.tooltipTitles,
  });

  final List<LineSeries> series;
  final List<String> labels;
  final List<String>? tooltipTitles;
  final String Function(int minor) formatAmount;
  final String Function(int minor) formatAxis;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    var maxV = 0;
    var minV = 0;
    var first = true;
    for (final s in series) {
      for (final v in s.values) {
        if (first) {
          maxV = v;
          minV = v;
          first = false;
        }
        maxV = math.max(maxV, v);
        minV = math.min(minV, v);
      }
    }
    // Include 0 when the data is close to it.
    var lo = minV / 100;
    final hi = maxV / 100;
    if (lo > 0 && lo < hi * 0.3) lo = 0;
    final (bottom, top, interval) = _niceScale(lo, hi, includeZero: false);
    final every = math.max(1, (labels.length / (compact ? 6 : 12)).ceil());
    final titles = tooltipTitles ?? labels;
    final surface = context.colors.surfaceContainerLowest;
    return LineChart(
      LineChartData(
        minY: bottom,
        maxY: top,
        minX: 0,
        maxX: math.max(0, labels.length - 1).toDouble(),
        gridData: compact
            ? const FlGridData(show: false)
            : _grid(context, interval),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: !compact,
              reservedSize: 52,
              interval: interval,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  formatAxis((v * 100).round()),
                  style: _axisText(context),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: !compact || labels.length <= 12,
              interval: 1,
              getTitlesWidget: (v, meta) =>
                  _bottomTitle(context, labels, v, every),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: !compact,
          getTouchedSpotIndicator: (bar, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(color: context.colors.outline, strokeWidth: 1),
                FlDotData(
                  getDotPainter: (spot, _, b, _) => FlDotCirclePainter(
                    radius: 4,
                    color: b.color ?? context.colors.primary,
                    strokeWidth: 2,
                    strokeColor: surface,
                  ),
                ),
              ),
          ],
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => _tooltipBg(context),
            tooltipBorderRadius: BorderRadius.circular(Radii.sm),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            maxContentWidth: 220,
            getTooltipItems: (spots) => [
              for (var i = 0; i < spots.length; i++)
                LineTooltipItem(
                  i == 0 ? '${titles[spots[i].x.round()]}\n' : '',
                  _tooltipText(context).copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.left,
                  children: [
                    TextSpan(
                      text:
                          '${series.length > 1 ? '${series[spots[i].barIndex].label}: ' : ''}'
                          '${formatAmount(series[spots[i].barIndex].values[spots[i].x.round()])}',
                      style: _tooltipText(context),
                    ),
                  ],
                ),
            ],
          ),
        ),
        lineBarsData: [
          for (final s in series)
            LineChartBarData(
              spots: [
                for (var i = 0; i < s.values.length; i++)
                  FlSpot(i.toDouble(), s.values[i] / 100),
              ],
              color: s.color,
              isStrokeCapRound: true,
              isStrokeJoinRound: true,
              dotData: FlDotData(
                show: !compact && s.values.length <= 1,
                getDotPainter: (spot, _, b, _) => FlDotCirclePainter(
                  radius: 4,
                  color: s.color,
                  strokeWidth: 2,
                  strokeColor: surface,
                ),
              ),
              belowBarData: BarAreaData(
                show: s.fill,
                color: s.color.withValues(alpha: 0.10),
              ),
            ),
        ],
      ),
      duration: Duration.zero,
    );
  }
}

// --------------------------------------------------- horizontal bars ---

class HBarItem {
  const HBarItem({
    required this.label,
    required this.value,
    required this.valueText,
    this.onTap,
    this.tooltip,
  });

  final String label;

  /// Bar length driver (non-negative minor units or counts).
  final int value;
  final String valueText;
  final VoidCallback? onTap;
  final String? tooltip;
}

/// Ranked horizontal bars with the label above and the value at the tip.
class HorizontalBars extends ConsumerWidget {
  const HorizontalBars({
    required this.items,
    super.key,
    this.color,
    this.compact = false,
  });

  final List<HBarItem> items;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(privacyModeProvider);
    final maxV = items.fold<int>(0, (a, b) => math.max(a, b.value));
    final c = color ?? context.colors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          Tooltip(
            message: item.tooltip ?? '',
            waitDuration: const Duration(milliseconds: 300),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.sm),
              onTap: item.onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: compact ? 3 : Space.xs - 2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: compact
                                ? context.text.bodySmall
                                : context.text.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: Space.xs),
                        if (hidden)
                          const Text('•••')
                        else
                          Text(
                            item.valueText,
                            style:
                                (compact
                                        ? context.text.bodySmall
                                        : context.text.bodyMedium)
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.xxs),
                    LayoutBuilder(
                      builder: (context, box) => Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: compact ? 6 : 8,
                          width: maxV <= 0
                              ? 0
                              : math.max(2, box.maxWidth * item.value / maxV),
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
