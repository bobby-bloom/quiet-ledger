import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/features/accounts/data/net_worth.dart';

/// Step line chart of a balance series with an optional low-balance
/// threshold line. Values are converted to doubles only for chart
/// coordinates.
class BalanceChart extends ConsumerWidget {
  const BalanceChart({
    required this.points,
    required this.semanticLabel,
    super.key,
    this.thresholdMinor,
    this.color,
    this.height = 200,
  });

  final List<BalancePoint> points;
  final int? thresholdMinor;
  final Color? color;
  final double height;
  final String semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(moneyFormatterProvider);
    final dates = ref.watch(dateFormatsProvider);
    final locale = ref.watch(formatLocaleProvider);
    final hidden = ref.watch(privacyModeProvider);
    final lineColor = color ?? context.colors.primary;
    final origin = points.first.date;
    double x(DateTime d) => d.difference(origin).inHours / 24;

    final spots = [
      for (final p in points) FlSpot(x(p.date), p.balanceMinor / 100),
    ];
    var minY = spots.map((s) => s.y).reduce(math.min);
    var maxY = spots.map((s) => s.y).reduce(math.max);
    final t = thresholdMinor == null ? null : thresholdMinor! / 100;
    if (t != null) {
      minY = math.min(minY, t);
      maxY = math.max(maxY, t);
    }
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }
    final pad = (maxY - minY) * 0.08;
    minY -= pad;
    maxY += pad;
    final maxX = math.max(spots.last.x, 1).toDouble();
    final compact = NumberFormat.compact(locale: locale);
    final labelStyle = context.text.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: context.colors.onSurfaceVariant,
    );
    final spanDays = maxX;
    final longRange = spanDays > 400;

    return Semantics(
      label: semanticLabel,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: _niceInterval(maxY - minY),
                getDrawingHorizontalLine: (_) => FlLine(
                  color: context.colors.surfaceContainerHigh,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: !hidden,
                    reservedSize: 44,
                    interval: _niceInterval(maxY - minY),
                    getTitlesWidget: (v, meta) {
                      if (v == meta.min || v == meta.max) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(compact.format(v), style: labelStyle),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    maxIncluded: false,
                    interval: math.max(1, maxX / 4),
                    getTitlesWidget: (v, meta) {
                      final d = origin.add(Duration(hours: (v * 24).round()));
                      final label = longRange
                          ? DateFormat.yMMM(locale).format(d)
                          : (spanDays <= 45
                                ? DateFormat.MMMd(locale).format(d)
                                : dates.monthShort(d));
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(label, style: labelStyle),
                      );
                    },
                  ),
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  if (t != null)
                    HorizontalLine(
                      y: t,
                      color: context.finance.warning,
                      strokeWidth: 1.5,
                      dashArray: const [6, 4],
                    ),
                ],
              ),
              lineTouchData: LineTouchData(
                enabled: !hidden,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => context.colors.inverseSurface,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      LineTooltipItem(
                        '${dates.medium(points[s.spotIndex].date)}\n',
                        TextStyle(
                          color: context.colors.onInverseSurface,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: fmt.minor(points[s.spotIndex].balanceMinor),
                            style: TextStyle(
                              color: context.colors.onInverseSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isStepLineChart: true,
                  color: lineColor,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        lineColor.withValues(alpha: 0.18),
                        lineColor.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static double _niceInterval(double span) {
    if (span <= 0) return 1;
    final raw = span / 4;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final n = raw / mag;
    final nice = n < 1.5
        ? 1
        : n < 3
        ? 2
        : n < 7
        ? 5
        : 10;
    return nice * mag;
  }
}
