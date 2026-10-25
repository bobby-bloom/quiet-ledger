import 'package:flutter/widgets.dart';

/// The Quiet Ledger mark: a reconciling tick over an accountant's double
/// rule, the line drawn under a total that balances. The second rule is
/// drawn at reduced opacity.
///
/// Geometry is defined on a 1024 canvas and matches the icon source
/// (`mark.svg`) exactly; it stays inside a centred circle of diameter 617
/// (inside Android's 66/108 adaptive safe circle) so it survives every
/// platform's icon mask. The rule edges sit on whole pixels at 16 and 32 px.
/// It is scaled to the shortest side of the painted area and centred.
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

    // Tick: polyline (383.75,366.25) (473.75,456.25) (640.25,289.75), width
    // 103.5, round caps and join, as one filled outline.
    const r = Radius.circular(51.75);
    final tick = Path()
      ..moveTo(420.343, 329.657)
      ..lineTo(473.75, 383.064)
      ..lineTo(603.657, 253.157)
      ..arcToPoint(const Offset(676.843, 326.343), radius: r)
      ..lineTo(510.343, 492.843)
      ..arcToPoint(const Offset(437.157, 492.843), radius: r)
      ..lineTo(347.157, 402.843)
      ..arcToPoint(const Offset(420.343, 329.657), radius: r)
      ..close();
    canvas.drawPath(tick, paint);

    // Double rule: the total line, then the faded second line.
    const ends = Radius.circular(32);
    canvas
      ..drawRRect(RRect.fromLTRBR(320, 576, 704, 640, ends), paint)
      ..drawRRect(
        RRect.fromLTRBR(320, 704, 704, 768, ends),
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
