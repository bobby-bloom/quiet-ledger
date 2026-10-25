import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/core/board/board_layout.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// The height of a card in arrange mode, and so of every slot standing in
/// for one: a 48 dp ⋮ button with a little air.
const double arrangeCardHeight = 52;

/// The name of [split]: the split picker's tooltips and screen-reader names.
String splitName(AppLocalizations l, RowSplit split) => switch (split.weights) {
  [1] => l.boardSplitOne,
  [1, 1] => l.boardSplitHalves,
  [2, 1] => l.boardSplitWideNarrow,
  [1, 2] => l.boardSplitNarrowWide,
  [1, 1, 1] => l.boardSplitThirds,
  final w => w.join(':'),
};

/// The three faces of a drop target in arrange mode.
enum DropSlotKind {
  /// Where the dragged card would land: a dashed, tinted slot.
  insertion,

  /// A column without cards: a dashed outline, "Drag a card here".
  emptyColumn,

  /// The gap between two rows, hovered: a full-width slot previewing a row
  /// of one column, "New row".
  newRow,
}

/// A card-sized placeholder in arrange mode. Not focusable: the result of
/// a drop is announced instead.
class DropSlot extends StatelessWidget {
  const DropSlot({required this.kind, super.key, this.label});

  final DropSlotKind kind;

  /// The words of [DropSlotKind.emptyColumn] and [DropSlotKind.newRow].
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isTarget = kind != DropSlotKind.emptyColumn;

    return DashedOutline(
      color: isTarget ? colors.primary : colors.outline,
      strokeWidth: 2,
      child: Container(
        height: arrangeCardHeight,
        padding: const EdgeInsets.symmetric(horizontal: Space.sm),
        color: isTarget ? colors.primary.withValues(alpha: 0.1) : null,
        alignment: kind == DropSlotKind.newRow
            ? AlignmentDirectional.centerStart
            : Alignment.center,
        child: switch (kind) {
          DropSlotKind.insertion => null,
          DropSlotKind.emptyColumn => Text(
            label ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          DropSlotKind.newRow => Row(
            spacing: Space.xs,
            children: [
              const SplitDiagram(weights: [1]),
              Flexible(
                child: Text(
                  label ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        },
      ),
    );
  }
}

/// A row split drawn small: one outlined box per weight, as wide as its
/// weight.
class SplitDiagram extends StatelessWidget {
  const SplitDiagram({required this.weights, super.key});

  final List<int> weights;

  static const _size = Size(24, 16);

  @override
  Widget build(BuildContext context) {
    final color =
        IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    return ExcludeSemantics(
      child: SizedBox.fromSize(
        size: _size,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 2,
          children: [
            for (final weight in weights)
              Expanded(
                flex: weight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: color, width: 1.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// [child] clipped to a rounded rectangle of [radius] with a dashed [color]
/// outline on top. Dashing reads as "a place, not a thing": rows, slots and
/// empty columns.
class DashedOutline extends StatelessWidget {
  const DashedOutline({
    required this.color,
    required this.child,
    super.key,
    this.strokeWidth = 1,
    this.radius = Radii.md,
  });

  final Color color;
  final Widget child;
  final double strokeWidth;
  final double radius;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _DashedOutlinePainter(
      color: color,
      strokeWidth: strokeWidth,
      radius: radius,
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: child),
  );
}

class _DashedOutlinePainter extends CustomPainter {
  _DashedOutlinePainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(inset),
          Radius.circular(math.max(0, radius - inset)),
        ),
      );
    canvas.drawPath(
      dashedPath(outline, dash: 6, space: 4),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(_DashedOutlinePainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.radius != radius;
}

/// [source] as [dash]-on / [space]-off dashes.
Path dashedPath(Path source, {required double dash, required double space}) {
  final dashed = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final next = math.min(distance + dash, metric.length);
      dashed.addPath(metric.extractPath(distance, next), Offset.zero);
      distance = next + space;
    }
  }
  return dashed;
}
