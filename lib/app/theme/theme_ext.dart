import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/finance_colors.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

extension ThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  FinanceColors get finance =>
      Theme.of(this).extension<FinanceColors>() ?? FinanceColors.light;
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Monospace style for sheet cells, codes and IDs (Plex Mono 12/16).
  TextStyle get mono => const TextStyle(
    fontFamily: 'IBMPlexMono',
    fontSize: 12,
    height: 16 / 12,
    fontFeatures: [FontFeature.tabularFigures()],
  ).copyWith(color: colors.onSurface);
}
