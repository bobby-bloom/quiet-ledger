import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/finance_colors.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/core/settings/app_settings.dart';

/// Builds the Material 3 theme from the Quiet Ledger tokens.
class AppTheme {
  const AppTheme({
    this.accent = AccentScheme.spruce,
    this.customAccent = const Color(0xFF1F5A53),
    this.highContrast = false,
    this.density = Density.comfortable,
  });

  final AccentScheme accent;
  final Color customAccent;

  final bool highContrast;
  final Density density;

  static const _seeds = <AccentScheme, Color>{
    AccentScheme.blue: Color(0xFF2D5DA8),
    AccentScheme.violet: Color(0xFF6A4C7C),
    AccentScheme.amber: Color(0xFF8A6200),
    AccentScheme.rose: Color(0xFFA2405A),
    AccentScheme.slate: Color(0xFF4A5560),
  };

  ThemeData light() => _build(Brightness.light);
  ThemeData dark() => _build(Brightness.dark);

  static ColorScheme spruceScheme(Brightness b) => b == Brightness.light
      ? const ColorScheme(
          brightness: Brightness.light,
          primary: LightTokens.primary,
          onPrimary: LightTokens.onPrimary,
          primaryContainer: LightTokens.primaryContainer,
          onPrimaryContainer: LightTokens.onPrimaryContainer,
          secondary: LightTokens.secondary,
          onSecondary: LightTokens.onSecondary,
          secondaryContainer: LightTokens.secondaryContainer,
          onSecondaryContainer: LightTokens.onSecondaryContainer,
          tertiary: LightTokens.tertiary,
          onTertiary: LightTokens.onTertiary,
          tertiaryContainer: LightTokens.tertiaryContainer,
          onTertiaryContainer: LightTokens.onTertiaryContainer,
          error: LightTokens.error,
          onError: LightTokens.onError,
          errorContainer: LightTokens.errorContainer,
          onErrorContainer: LightTokens.onErrorContainer,
          surface: LightTokens.surface,
          onSurface: LightTokens.onSurface,
          onSurfaceVariant: LightTokens.onSurfaceVariant,
          surfaceContainerLowest: LightTokens.surfaceContainerLowest,
          surfaceContainerLow: LightTokens.surfaceContainerLow,
          surfaceContainer: LightTokens.surfaceContainer,
          surfaceContainerHigh: LightTokens.surfaceContainerHigh,
          surfaceContainerHighest: LightTokens.surfaceContainerHighest,
          outline: LightTokens.outline,
          outlineVariant: LightTokens.outlineVariant,
          inverseSurface: LightTokens.inverseSurface,
          onInverseSurface: LightTokens.onInverseSurface,
          inversePrimary: LightTokens.inversePrimary,
          scrim: LightTokens.scrim,
          shadow: Color(0xFF000000),
          surfaceTint: Colors.transparent,
        )
      : const ColorScheme(
          brightness: Brightness.dark,
          primary: DarkTokens.primary,
          onPrimary: DarkTokens.onPrimary,
          primaryContainer: DarkTokens.primaryContainer,
          onPrimaryContainer: DarkTokens.onPrimaryContainer,
          secondary: DarkTokens.secondary,
          onSecondary: DarkTokens.onSecondary,
          secondaryContainer: DarkTokens.secondaryContainer,
          onSecondaryContainer: DarkTokens.onSecondaryContainer,
          tertiary: DarkTokens.tertiary,
          onTertiary: DarkTokens.onTertiary,
          tertiaryContainer: DarkTokens.tertiaryContainer,
          onTertiaryContainer: DarkTokens.onTertiaryContainer,
          error: DarkTokens.error,
          onError: DarkTokens.onError,
          errorContainer: DarkTokens.errorContainer,
          onErrorContainer: DarkTokens.onErrorContainer,
          surface: DarkTokens.surface,
          onSurface: DarkTokens.onSurface,
          onSurfaceVariant: DarkTokens.onSurfaceVariant,
          surfaceContainerLowest: DarkTokens.surfaceContainerLowest,
          surfaceContainerLow: DarkTokens.surfaceContainerLow,
          surfaceContainer: DarkTokens.surfaceContainer,
          surfaceContainerHigh: DarkTokens.surfaceContainerHigh,
          surfaceContainerHighest: DarkTokens.surfaceContainerHighest,
          outline: DarkTokens.outline,
          outlineVariant: DarkTokens.outlineVariant,
          inverseSurface: DarkTokens.inverseSurface,
          onInverseSurface: DarkTokens.onInverseSurface,
          inversePrimary: DarkTokens.inversePrimary,
          scrim: DarkTokens.scrim,
          shadow: Color(0xFF000000),
          surfaceTint: Colors.transparent,
        );

  ColorScheme _scheme(Brightness b) {
    final paper = spruceScheme(b);
    final seed = switch (accent) {
      AccentScheme.spruce => null,
      AccentScheme.custom => customAccent,
      _ => _seeds[accent],
    };
    if (seed == null && !highContrast) return paper;
    final generated = ColorScheme.fromSeed(
      seedColor: seed ?? paper.primary,
      brightness: b,
      contrastLevel: highContrast ? 1.0 : 0.0,
    );
    if (highContrast) {
      return generated.copyWith(surfaceTint: Colors.transparent);
    }
    // Keep the paper-toned neutrals; take accent roles from the seed.
    return paper.copyWith(
      primary: generated.primary,
      onPrimary: generated.onPrimary,
      primaryContainer: generated.primaryContainer,
      onPrimaryContainer: generated.onPrimaryContainer,
      secondary: generated.secondary,
      onSecondary: generated.onSecondary,
      secondaryContainer: generated.secondaryContainer,
      onSecondaryContainer: generated.onSecondaryContainer,
      inversePrimary: generated.inversePrimary,
    );
  }

  static TextTheme textTheme(Color onSurface) {
    const tab = [FontFeature.tabularFigures()];
    TextStyle s(double size, double height, FontWeight w, [double ls = 0]) =>
        TextStyle(
          fontFamily: Fonts.ui,
          fontSize: size,
          height: height / size,
          fontWeight: w,
          letterSpacing: ls,
          fontFeatures: tab,
          color: onSurface,
        );
    return TextTheme(
      displayLarge: s(57, 64, FontWeight.w800, -1.5),
      displayMedium: s(45, 52, FontWeight.w800, -1.2),
      displaySmall: s(38, 44, FontWeight.w800, -1),
      headlineLarge: s(32, 40, FontWeight.w800, -0.8),
      headlineMedium: s(28, 36, FontWeight.w800, -0.7),
      headlineSmall: s(24, 32, FontWeight.w800, -0.6),
      titleLarge: s(22, 28, FontWeight.w800, -0.4),
      titleMedium: s(17, 24, FontWeight.w700),
      titleSmall: s(15, 20, FontWeight.w700),
      bodyLarge: s(15, 22, FontWeight.w600),
      bodyMedium: s(14, 20, FontWeight.w500),
      bodySmall: s(13, 18, FontWeight.w400),
      labelLarge: s(15, 20, FontWeight.w700),
      labelMedium: s(12, 16, FontWeight.w600),
      labelSmall: s(11, 16, FontWeight.w700),
    );
  }

  ThemeData _build(Brightness b) {
    final cs = _scheme(b);
    final finance = b == Brightness.light
        ? FinanceColors.light
        : FinanceColors.dark;
    final text = textTheme(cs.onSurface);
    final hairline = BorderSide(color: cs.surfaceContainerHigh);
    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.full),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      brightness: b,
      fontFamily: Fonts.ui,
      textTheme: text,
      scaffoldBackgroundColor: cs.surface,
      canvasColor: cs.surface,
      visualDensity: density == Density.compact
          ? VisualDensity.compact
          : VisualDensity.standard,
      extensions: [finance],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleMedium,
      ),
      cardTheme: CardThemeData(
        color: b == Brightness.light
            ? cs.surfaceContainerLowest
            : cs.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: hairline,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: cs.surfaceContainerHigh,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.listInset),
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        iconColor: cs.onSurfaceVariant,
        minVerticalPadding: 8,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        backgroundColor: cs.surfaceContainer,
        indicatorColor: cs.secondaryContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelMedium?.copyWith(
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
            color: s.contains(WidgetState.selected)
                ? cs.onSecondaryContainer
                : cs.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: cs.surfaceContainerLow,
        indicatorColor: cs.secondaryContainer,
        selectedLabelTextStyle: text.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.onSecondaryContainer,
        ),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(
          color: cs.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surfaceContainerLow,
        modalBackgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xl),
        ),
        titleTextStyle: text.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: b == Brightness.light
            ? cs.surfaceContainerLowest
            : cs.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        labelStyle: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        hintStyle: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        side: BorderSide(color: cs.outlineVariant),
        labelStyle: text.labelMedium?.copyWith(color: cs.onSurface),
        backgroundColor: cs.surface,
        selectedColor: cs.secondaryContainer,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: pill,
          minimumSize: const Size(64, 48),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: pill,
          minimumSize: const Size(64, 48),
          side: BorderSide(color: cs.outline),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: pill,
          minimumSize: const Size(48, 44),
          textStyle: text.labelLarge?.copyWith(fontSize: 13),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: cs.secondaryContainer,
          selectedForegroundColor: cs.onSecondaryContainer,
          side: BorderSide(color: cs.outlineVariant),
          textStyle: text.labelLarge?.copyWith(fontSize: 14),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: cs.surfaceContainerHigh,
        linearMinHeight: 6,
        borderRadius: BorderRadius.circular(3),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: cs.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cs.inverseSurface,
          borderRadius: BorderRadius.circular(Radii.xs),
        ),
        textStyle: text.labelMedium?.copyWith(color: cs.onInverseSurface),
      ),
    );
  }
}

/// Theme parts that depend on the window size; wraps every route through
/// `MaterialApp.builder`. App bar actions end on the page margin (phone
/// 16, wider windows 24), less the 4 px an IconButton's circle sits inside
/// its tap target, so screens add no trailing spacer of their own.
class WindowSizedTheme extends StatelessWidget {
  const WindowSizedTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gutter = WindowSize.of(context).isCompact
        ? Space.phoneGutter
        : Space.desktopGutter;
    return Theme(
      data: theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(
          actionsPadding: EdgeInsetsDirectional.only(end: gutter - Space.xxs),
        ),
      ),
      child: child,
    );
  }
}
