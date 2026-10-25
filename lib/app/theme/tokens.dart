import 'package:flutter/material.dart';

// "Quiet Ledger" design tokens (design draft, Foundations board).
// Paper-toned surfaces, one spruce accent, hairline structure. Colour is
// reserved for money direction and status.

abstract final class LightTokens {
  static const primary = Color(0xFF1F5A53);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFCDE8E1);
  static const onPrimaryContainer = Color(0xFF0A3530);
  static const secondary = Color(0xFF4A635E);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFD5E6E1);
  static const onSecondaryContainer = Color(0xFF0F2E29);
  static const tertiary = Color(0xFF6A4C7C);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFFEEDCF7);
  static const onTertiaryContainer = Color(0xFF251431);
  static const error = Color(0xFFB3261E);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFF9DEDC);
  static const onErrorContainer = Color(0xFF410E0B);
  static const surface = Color(0xFFF8F7F3);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF2F1EC);
  static const surfaceContainer = Color(0xFFECEBE5);
  static const surfaceContainerHigh = Color(0xFFE6E5DF);
  static const surfaceContainerHighest = Color(0xFFE0DFD9);
  static const onSurface = Color(0xFF1B1D1C);
  static const onSurfaceVariant = Color(0xFF4A4F4D);
  static const outline = Color(0xFF767C79);
  static const outlineVariant = Color(0xFFCFD0CA);
  static const inverseSurface = Color(0xFF2F3130);
  static const onInverseSurface = Color(0xFFF2F1EC);
  static const inversePrimary = Color(0xFF8FD3C6);
  static const scrim = Color(0x7A0C0E0D); // #0C0E0D · 48 %

  static const income = Color(0xFF2149B0);
  static const incomeContainer = Color(0xFFDCE4FA);
  static const onIncomeContainer = Color(0xFF0E2A73);
  static const expense = Color(0xFFA24A0E);
  static const expenseFill = Color(0xFFD8732B);
  static const expenseContainer = Color(0xFFFCE3D2);
  static const onExpenseContainer = Color(0xFF5C2804);
  static const transfer = Color(0xFF5B6470);
  static const transferContainer = Color(0xFFE3E6EA);
  static const warning = Color(0xFF7A5900);
  static const warningFill = Color(0xFFD19A1E);
  static const warningContainer = Color(0xFFFBEFC9);
  static const onWarningContainer = Color(0xFF4A3500);
}

abstract final class DarkTokens {
  static const primary = Color(0xFF8FD3C6);
  static const onPrimary = Color(0xFF00382F);
  static const primaryContainer = Color(0xFF21504A);
  static const onPrimaryContainer = Color(0xFFCDE8E1);
  static const secondary = Color(0xFFB4CCC6);
  static const onSecondary = Color(0xFF1F3531);
  static const secondaryContainer = Color(0xFF334B46);
  static const onSecondaryContainer = Color(0xFFD5E6E1);
  static const tertiary = Color(0xFFD7BAE6);
  static const onTertiary = Color(0xFF3A2249);
  static const tertiaryContainer = Color(0xFF523764);
  static const onTertiaryContainer = Color(0xFFEEDCF7);
  static const error = Color(0xFFF2B8B5);
  static const onError = Color(0xFF601410);
  static const errorContainer = Color(0xFF8C1D18);
  static const onErrorContainer = Color(0xFFF9DEDC);
  static const surface = Color(0xFF121413);
  static const surfaceContainerLowest = Color(0xFF0D0F0E);
  static const surfaceContainerLow = Color(0xFF1A1C1B);
  static const surfaceContainer = Color(0xFF1E2120);
  static const surfaceContainerHigh = Color(0xFF282B2A);
  static const surfaceContainerHighest = Color(0xFF333635);
  static const onSurface = Color(0xFFE3E3DE);
  static const onSurfaceVariant = Color(0xFFC1C6C2);
  static const outline = Color(0xFF8B918D);
  static const outlineVariant = Color(0xFF414745);
  static const inverseSurface = Color(0xFFE3E3DE);
  static const onInverseSurface = Color(0xFF2F3130);
  static const inversePrimary = Color(0xFF1F5A53);
  static const scrim = Color(0x99000000); // 60 %

  static const income = Color(0xFFB4C8FF);
  static const incomeContainer = Color(0xFF24376E);
  static const onIncomeContainer = Color(0xFFDCE4FA);
  static const expense = Color(0xFFEE9257);
  static const expenseFill = Color(0xFFEE9257);
  static const expenseContainer = Color(0xFF6A3410);
  static const onExpenseContainer = Color(0xFFFCE3D2);
  static const transfer = Color(0xFFAAB2BC);
  static const transferContainer = Color(0xFF3A4048);
  static const warning = Color(0xFFE8C25A);
  static const warningFill = Color(0xFFE8C25A);
  static const warningContainer = Color(0xFF574200);
  static const onWarningContainer = Color(0xFFFBEFC9);
}

/// Category & chart series palette. Baseline = primary; scenarios 1–3 =
/// tertiary, chart2, chart3; threshold = warning.
abstract final class ChartPalette {
  static const series = <Color>[
    Color(0xFF2A6F66),
    Color(0xFF4F79C2),
    Color(0xFFC9971F),
    Color(0xFF8A5A9E),
    Color(0xFFC0614F),
    Color(0xFF7E9A78),
  ];
  static const other = Color(0xFFA9ACA6);

  static Color at(int i) => series[i % series.length];
}

/// Spacing scale (px). Phone gutter 16, list inset 20, card padding 16,
/// card gap 10, desktop gutter 24. Touch targets ≥ 44.
abstract final class Space {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;

  static const phoneGutter = 16.0;
  static const listInset = 20.0;
  static const cardPadding = 16.0;

  /// Between neighbouring cards, stacked or side by side, on every screen
  /// (the boards' `boardGap` too).
  static const cardGap = 10.0;
  static const desktopGutter = 24.0;
  static const minTouch = 44.0;
}

/// Corner radii: xs badges, sm chips/selects, md fields/keys, lg cards/FAB,
/// xl sheets/dialogs, full = pill buttons and search.
abstract final class Radii {
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 28.0;
  static const full = 999.0;
}

/// Font families bundled under assets/fonts.
abstract final class Fonts {
  static const ui = 'Manrope';
  static const mono = 'IBMPlexMono';
}

/// Durations and curves. Things move because they changed; reduced motion
/// ([isReduced]) drops travel and keeps at most a short fade.
abstract final class Motion {
  /// Hover, press, lift.
  static const quick = Duration(milliseconds: 120);

  /// Expand and collapse, slots opening, neighbours sliding.
  static const standard = Duration(milliseconds: 220);

  /// A dropped card settling into its place.
  static const expressive = Duration(milliseconds: 380);

  static const curve = Curves.easeOutCubic;

  /// Overshoots slightly, like a spring.
  static const spring = Curves.easeOutBack;

  static bool isReduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
