import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/features/forecast/domain/forecast_dates.dart';

/// One line of a balance chart (minor units, one value per step).
@immutable
class ChartLine {
  const ChartLine({
    required this.values,
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final List<int> values;
  final Color color;
  final String label;
  final bool dashed;
}

/// Balance chart of the forecast board / projection: a solid baseline,
/// dashed scenario lines, an optional dashed threshold line with a tinted
/// band below it and a marker on the lowest point. Values become doubles
/// only as chart coordinates. The whole chart is one image for
/// accessibility, described by [semanticLabel].
class BalanceLineChart extends ConsumerWidget {
  const BalanceLineChart({
    required this.lines,
    required this.dateOf,
    required this.semanticLabel,
    super.key,
    this.thresholdMinor,
    this.markIndex,
    this.markWarning = false,
    this.height = 200,
    this.monthly = false,
    this.verticalMarks = const [],
  });

  /// First line = baseline.
  final List<ChartLine> lines;

  /// Date of step i.
  final DateTime Function(int i) dateOf;
  final String semanticLabel;
  final int? thresholdMinor;

  /// Step of the lowest-point marker on the baseline.
  final int? markIndex;
  final bool markWarning;
  final double height;

  /// Steps are months (projection) instead of days.
  final bool monthly;

  /// Steps marked with a thin dashed vertical line (milestones).
  final List<int> verticalMarks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(moneyFormatterProvider);
    final dates = ref.watch(dateFormatsProvider);
    final locale = ref.watch(formatLocaleProvider);
    final hidden = ref.watch(privacyModeProvider);
    final colors = context.colors;
    final finance = context.finance;
    final n = lines.first.values.length;
    if (n == 0) return SizedBox(height: height);

    var minY = double.infinity;
    var maxY = -double.infinity;
    for (final l in lines) {
      for (final v in l.values) {
        minY = math.min(minY, v / 100);
        maxY = math.max(maxY, v / 100);
      }
    }
    final t = thresholdMinor == null ? null : thresholdMinor! / 100;
    if (t != null) {
      minY = math.min(minY, t);
      maxY = math.max(maxY, t);
    }
    // Anchor at zero when the curve is not far above it (like the design).
    if (minY >= 0 && minY <= maxY * 0.6) minY = 0;
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }
    final interval = _niceInterval(maxY - minY);
    minY = (minY / interval).floor() * interval;
    maxY = (maxY / interval).ceil() * interval;

    final labelSteps = _labelSteps(n);
    final labelStyle = context.text.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: colors.onSurfaceVariant,
    );
    final compact = NumberFormat.compactSimpleCurrency(
      locale: locale,
      name: 'EUR',
    );
    final longRange = monthly ? n > 13 * 12 : n > 400;

    String axisDate(DateTime d) {
      if (monthly) return DateFormat.y(locale).format(d);
      return longRange
          ? DateFormat.yMMM(locale).format(d)
          : dates.monthShort(d);
    }

    final markColor = markWarning ? finance.warning : colors.primary;
    final bars = <LineChartBarData>[
      for (final (li, l) in lines.indexed)
        LineChartBarData(
          spots: [
            for (var i = 0; i < l.values.length; i++)
              FlSpot(i.toDouble(), l.values[i] / 100),
          ],
          color: l.color,
          barWidth: li == 0 ? 2 : 1.75,
          dashArray: l.dashed ? const [5, 3] : null,
          isStrokeJoinRound: true,
          dotData: FlDotData(
            show: li == 0 && markIndex != null,
            checkToShowDot: (spot, _) => spot.x.round() == markIndex,
            getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
              radius: 5,
              color: colors.surfaceContainerLowest,
              strokeWidth: 2.25,
              strokeColor: markColor,
            ),
          ),
        ),
    ];
    // Baseline on top.
    final ordered = [...bars.skip(1), bars.first];

    return Semantics(
      label: semanticLabel,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: math.max(1, n - 1).toDouble(),
              minY: minY,
              maxY: maxY,
              clipData: const FlClipData.horizontal(),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: v == 0 ? colors.outline : colors.surfaceContainerHigh,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(bottom: BorderSide(color: colors.outline)),
              ),
              rangeAnnotations: RangeAnnotations(
                horizontalRangeAnnotations: [
                  if (t != null && t > minY)
                    HorizontalRangeAnnotation(
                      y1: minY,
                      y2: t,
                      color: finance.warningContainer.withValues(alpha: 0.7),
                    ),
                ],
              ),
              extraLinesData: ExtraLinesData(
                verticalLines: [
                  for (final m in verticalMarks)
                    VerticalLine(
                      x: m.toDouble(),
                      color: colors.outline,
                      strokeWidth: 1,
                      dashArray: const [3, 3],
                    ),
                ],
                horizontalLines: [
                  if (t != null)
                    HorizontalLine(
                      y: t,
                      color: finance.warning,
                      strokeWidth: 1.25,
                      dashArray: const [4, 3],
                    ),
                ],
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                leftTitles: const AxisTitles(),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: !hidden,
                    reservedSize: 48,
                    interval: interval,
                    getTitlesWidget: (v, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(compact.format(v), style: labelStyle),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (v, meta) {
                      final i = v.round();
                      if ((v - i).abs() > 1e-6 || !labelSteps.contains(i)) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(axisDate(dateOf(i)), style: labelStyle),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                enabled: !hidden,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => colors.inverseSurface,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  maxContentWidth: 220,
                  // One item per touched spot, in the given order.
                  getTooltipItems: (spots) {
                    return [
                      for (final (k, s) in spots.indexed)
                        _tooltip(
                          context,
                          header: k == 0
                              ? (monthly
                                    ? dates.monthYear(dateOf(s.spotIndex))
                                    : dates.medium(dateOf(s.spotIndex)))
                              : null,
                          line: s.barIndex == lines.length - 1
                              ? lines.first
                              : lines[s.barIndex + 1],
                          value: fmt.minor((s.y * 100).round()),
                        ),
                    ];
                  },
                ),
              ),
              lineBarsData: ordered,
            ),
          ),
        ),
      ),
    );
  }

  LineTooltipItem _tooltip(
    BuildContext context, {
    required String? header,
    required ChartLine line,
    required String value,
  }) {
    final on = context.colors.onInverseSurface;
    return LineTooltipItem(
      header == null ? '' : '$header\n',
      TextStyle(color: on, fontSize: 12),
      textAlign: TextAlign.start,
      children: [
        TextSpan(
          text: lines.length > 1 ? '${line.label}: ' : '',
          style: TextStyle(color: on, fontSize: 12),
        ),
        TextSpan(
          text: value,
          style: TextStyle(
            color: on,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  /// Steps that get an axis label: month starts (days) or year starts
  /// (months), thinned to about six labels.
  Set<int> _labelSteps(int n) {
    final candidates = <int>[];
    if (monthly) {
      for (var i = 0; i < n; i += 12) {
        candidates.add(i);
      }
    } else {
      for (var i = 0; i < n; i++) {
        final d = dateOf(i);
        if (d.day == 1) candidates.add(i);
      }
      if (candidates.isEmpty || candidates.first > 6) candidates.insert(0, 0);
    }
    final every = math.max(1, (candidates.length / 6).ceil());
    return {for (var k = 0; k < candidates.length; k += every) candidates[k]};
  }

  static double _niceInterval(double span) {
    if (span <= 0) return 1;
    final raw = span / 3;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final x = raw / mag;
    final nice = x < 1.5
        ? 1
        : x < 3
        ? 2
        : x < 7
        ? 5
        : 10;
    return nice * mag;
  }
}

/// Small legend entry: a short solid/dashed line and a label.
class LegendEntry extends StatelessWidget {
  const LegendEntry({
    required this.color,
    required this.label,
    super.key,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(20, 8),
          painter: _LegendLinePainter(color, dashed: dashed),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: context.text.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LegendLinePainter extends CustomPainter {
  _LegendLinePainter(this.color, {required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.butt;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + 4, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LegendLinePainter old) =>
      old.color != color || old.dashed != dashed;
}

/// Index of [date] in a daily series starting at [start].
int dayIndex(DateTime start, DateTime date) => daysBetween(start, date);
