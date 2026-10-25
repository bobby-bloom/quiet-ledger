import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/fold_card.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/dashboard/data/dashboard_layout.dart';

export 'package:personal_finance/app/ui/fold_card.dart' show CardOption;

/// Open state of the dashboard widgets, keyed by `DashboardWidgetType.name`
/// and shared by the phone and wide views.
final dashboardFoldsProvider = cardFoldsProvider(
  DashboardSettings.cardExpansion,
);

/// Card shell of a dashboard widget: a [FoldCard] that folds when [type] is
/// set (see there for the layout).
class DashCard extends StatelessWidget {
  const DashCard({
    required this.title,
    required this.child,
    super.key,
    this.type,
    this.peek,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.options = const [],
    this.onTap,
    this.semanticLabel,
  });

  final String title;
  final String? subtitle;

  /// The widget whose open state ([dashboardFoldsProvider]) this card
  /// shows; null makes the card unfoldable.
  final DashboardWidgetType? type;

  /// First line of the card, shown open and folded.
  final Widget? peek;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<CardOption> options;
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => FoldCard(
    title: title,
    subtitle: subtitle,
    fold: type == null
        ? null
        : (setting: DashboardSettings.cardExpansion, id: type!.name),
    peek: peek,
    actionLabel: actionLabel,
    onAction: onAction,
    options: options,
    onTap: onTap,
    semanticLabel: semanticLabel,
    child: child,
  );
}

/// One line of a peek where `PeekText.slot(i)` in [text] is replaced by
/// [amounts]`[i]`, shown with [AmountText] so privacy mode masks it.
class PeekText extends StatelessWidget {
  const PeekText(
    this.text, {
    super.key,
    this.amounts = const [],
    this.style,
    this.explicitPlus = false,
  });

  /// Marker for the [i]th amount; pass it to the l10n message as the
  /// amount argument.
  static String slot([int i = 0]) => '\u{E000}$i\u{E001}';

  static final _slot = RegExp('\u{E000}(\\d+)\u{E001}');

  final String text;
  final List<int> amounts;
  final TextStyle? style;

  /// Whether a positive amount shows its "+" (a change, not a balance).
  final bool explicitPlus;

  @override
  Widget build(BuildContext context) {
    final base =
        style ??
        context.text.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: context.colors.onSurfaceVariant,
        );
    final spans = <InlineSpan>[];
    var at = 0;
    for (final m in _slot.allMatches(text)) {
      if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
      final i = int.parse(m.group(1)!);
      if (i < amounts.length) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: AmountText(
              amounts[i],
              colored: false,
              explicitPlus: explicitPlus,
              style: base?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colors.onSurface,
              ),
            ),
          ),
        );
      }
      at = m.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(
      TextSpan(children: spans),
      style: base,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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
