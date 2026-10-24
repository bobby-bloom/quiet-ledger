import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/app_mark.dart';

/// The app icon inside the app: the mark on the current accent (primary),
/// the same drawing as the platform icons (tool/app_icons).
class AppLogo extends StatelessWidget {
  const AppLogo({this.size = 32, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: AppMarkPainter(
        color: context.colors.onPrimary,
        background: context.colors.primary,
      ),
    ),
  );
}
