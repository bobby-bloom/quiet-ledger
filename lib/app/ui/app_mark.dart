import 'package:flutter/widgets.dart';

/// The Quiet Ledger mark: a reconciling tick over an accountant's double
/// rule, the line drawn under a total that balances. The second rule is
/// drawn at reduced opacity.
///
/// Geometry is defined on a 1024 canvas and matches the icon source
/// (`mark.svg`) exactly; it stays inside a centred circle of diameter 600 so
/// it survives every platform's icon mask. It is scaled to the shortest side
/// of the painted area and centred.
class AppMarkPainter extends CustomPainter {
  const AppMarkPainter({
    required this.color,
    this.background,
    this.radiusFraction = 0.28,
  });

  /// Mark colour, normally `onPrimary`.
  final Color color;

  /// When set, a rounded square in this colour (normally `primary`) is
  /// painted behind the mark, as on desktop and web.
  final Color? background;

  /// Background corner radius as a fraction of its side (0.28 = 9 px at 32).
  final double radiusFraction;

  /// Opacity of the second rule of the double underline.
  static const double secondaryOpacity = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    canvas
      ..save()
      ..translate((size.width - side) / 2, (size.height - side) / 2);

    final background = this.background;
    if (background != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & Size.square(side),
          Radius.circular(radiusFraction * side),
        ),
        Paint()..color = background,
      );
    }

    canvas.scale(side / 1024);
    final paint = Paint()..color = color;

    // Tick: polyline (398,368) (478,448) (626,300), width 92, round caps and
    // join, as one filled outline.
    const r = Radius.circular(46);
    final tick = Path()
      ..moveTo(430.527, 335.473)
      ..lineTo(478, 382.946)
      ..lineTo(593.473, 267.473)
      ..arcToPoint(const Offset(658.527, 332.527), radius: r)
      ..lineTo(510.527, 480.527)
      ..arcToPoint(const Offset(445.473, 480.527), radius: r)
      ..lineTo(365.473, 400.527)
      ..arcToPoint(const Offset(430.527, 335.473), radius: r)
      ..close();
    canvas.drawPath(tick, paint);

    // Double rule: the total line, then the faded second line.
    const ends = Radius.circular(32);
    canvas
      ..drawRRect(RRect.fromLTRBR(352, 576, 672, 640, ends), paint)
      ..drawRRect(
        RRect.fromLTRBR(352, 704, 672, 768, ends),
        Paint()..color = color.withValues(alpha: color.a * secondaryOpacity),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(AppMarkPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.background != background ||
      oldDelegate.radiusFraction != radiusFraction;
}
