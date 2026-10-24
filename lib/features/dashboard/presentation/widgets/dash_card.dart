import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';

/// Option entry of a widget's "⋮" menu.
class DashOption {
  const DashOption(this.label, this.icon, this.onSelected);
  final String label;
  final IconData icon;
  final VoidCallback onSelected;
}

/// Card shell of a dashboard widget: title (+ muted suffix), optional
/// action link ("All budgets ›") and a widget options menu.
class DashCard extends StatelessWidget {
  const DashCard({
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.options = const [],
    this.onTap,
    this.semanticLabel,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<DashOption> options;
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: title,
                      children: [
                        if (subtitle != null)
                          TextSpan(
                            text: ' · $subtitle',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    style: context.text.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (actionLabel != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.only(left: 12, right: 4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(actionLabel!),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                  ),
                if (options.isNotEmpty)
                  PopupMenuButton<int>(
                    tooltip: l.dashWidgetOptions,
                    icon: Icon(
                      Icons.more_vert,
                      color: context.colors.onSurfaceVariant,
                    ),
                    onSelected: (i) => options[i].onSelected(),
                    itemBuilder: (_) => [
                      for (final (i, o) in options.indexed)
                        PopupMenuItem(
                          value: i,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(o.icon),
                            title: Text(o.label),
                          ),
                        ),
                    ],
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.only(right: 8), child: child),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: semanticLabel ?? title,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// Minimal line sparkline: a polyline with an optional dashed threshold and
/// a marker on the lowest point.
class Sparkline extends StatelessWidget {
  const Sparkline({
    required this.values,
    super.key,
    this.height = 72,
    this.threshold,
    this.markLowest = false,
    this.fill = false,
    this.semanticLabel,
  });

  final List<int> values;
  final double height;
  final int? threshold;
  final bool markLowest;
  final bool fill;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Semantics(
      label: semanticLabel,
      image: semanticLabel != null,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SparklinePainter(
            values: values,
            threshold: threshold,
            markLowest: markLowest,
            fill: fill,
            line: cs.primary,
            thresholdColor: cs.outline,
            markerColor: context.finance.warning,
            markerFill: cs.surfaceContainerLowest,
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.threshold,
    required this.markLowest,
    required this.fill,
    required this.line,
    required this.thresholdColor,
    required this.markerColor,
    required this.markerFill,
  });

  final List<int> values;
  final int? threshold;
  final bool markLowest;
  final bool fill;
  final Color line;
  final Color thresholdColor;
  final Color markerColor;
  final Color markerFill;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    if (threshold != null) {
      if (threshold! < lo) lo = threshold!;
      if (threshold! > hi) hi = threshold!;
    }
    if (hi == lo) hi = lo + 1;
    const pad = 6.0;
    double y(int v) =>
        pad + (size.height - 2 * pad) * (1 - (v - lo) / (hi - lo));
    double x(int i) => size.width * i / (values.length - 1);

    if (threshold != null) {
      final ty = y(threshold!);
      final p = Paint()
        ..color = thresholdColor
        ..strokeWidth = 1;
      for (var dx = 0.0; dx < size.width; dx += 6) {
        canvas.drawLine(Offset(dx, ty), Offset(dx + 3, ty), p);
      }
    }
    final path = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }
    if (fill) {
      final area = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(area, Paint()..color = line.withValues(alpha: 0.10));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.75
        ..strokeJoin = StrokeJoin.round,
    );
    if (markLowest) {
      var li = 0;
      for (var i = 1; i < values.length; i++) {
        if (values[i] < values[li]) li = i;
      }
      final c = Offset(x(li), y(values[li]));
      canvas
        ..drawCircle(c, 5, Paint()..color = markerFill)
        ..drawCircle(
          c,
          5,
          Paint()
            ..color = markerColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.threshold != threshold || old.line != line;
}
