import 'package:intl/intl.dart';
import 'package:personal_finance/core/money/money.dart';

/// How negative amounts are written.
enum SignStyle {
  /// `-12,50`
  leadingMinus,

  /// `(12,50)`
  parentheses,

  /// `12,50 −`
  trailingMinus,
}

/// Formats [Money] for display according to user settings.
///
/// Uses U+2212 (minus sign) instead of the hyphen, as the design requires.
class MoneyFormatter {
  MoneyFormatter({
    required this.locale,
    this.showCents = true,
    this.signStyle = SignStyle.leadingMinus,
    this.showSymbol = true,
  });

  final String locale;
  final bool showCents;
  final SignStyle signStyle;
  final bool showSymbol;

  static const minus = '−';

  NumberFormat _numberFormat(Currency c, {required bool cents}) {
    final f = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: cents ? c.minorDigits : 0,
    );
    return f;
  }

  /// Unsigned number part, e.g. `1.234,56`.
  String formatNumber(Money m, {bool? cents}) {
    final c = m.currency;
    final withCents = cents ?? showCents;
    final f = _numberFormat(c, cents: withCents);
    final abs = m.minor.abs();
    if (withCents) {
      return f.format(abs / c.minorPerMajor);
    }
    // Round half away from zero to whole units.
    final whole = (abs + c.minorPerMajor ~/ 2) ~/ c.minorPerMajor;
    return f.format(whole);
  }

  String _withSymbol(String number, Currency c) {
    if (!showSymbol) return number;
    // German style puts the symbol after the number.
    if (locale.startsWith('de')) return '$number ${c.symbol}';
    return '${c.symbol}$number';
  }

  /// Formats with sign according to [signStyle]. Set [explicitPlus] to
  /// prefix positive amounts with `+` (used for income rows).
  String format(Money m, {bool explicitPlus = false, bool? cents}) {
    final body = _withSymbol(formatNumber(m, cents: cents), m.currency);
    if (m.isNegative) {
      return switch (signStyle) {
        SignStyle.leadingMinus => '$minus$body',
        SignStyle.parentheses => '($body)',
        SignStyle.trailingMinus => '$body $minus',
      };
    }
    if (explicitPlus && m.isPositive) return '+$body';
    return body;
  }

  /// Splits into whole and fraction parts for hero amounts where the cents
  /// are set in a lighter step, e.g. (`€24,118`, `.40`).
  (String whole, String fraction) formatHero(Money m) {
    final c = m.currency;
    final symbols = NumberFormat.decimalPattern(locale).symbols;
    final abs = m.minor.abs();
    final whole = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 0,
    ).format(abs ~/ c.minorPerMajor);
    final frac = (abs % c.minorPerMajor).toString().padLeft(c.minorDigits, '0');
    final sign = m.isNegative ? minus : '';
    if (locale.startsWith('de')) {
      return ('$sign$whole', '${symbols.DECIMAL_SEP}$frac ${c.symbol}');
    }
    return ('$sign${c.symbol}$whole', '${symbols.DECIMAL_SEP}$frac');
  }
}
