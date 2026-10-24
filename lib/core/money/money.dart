import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

/// Currency metadata. v1 only uses EUR, but every amount carries a code so
/// multi-currency can be added later without a data migration.
@immutable
class Currency {
  const Currency._(this.code, this.symbol, this.minorDigits);

  factory Currency.of(String code) => _known[code] ?? Currency._(code, code, 2);

  final String code;
  final String symbol;

  /// Number of minor-unit digits (2 for EUR: 1 EUR = 100 cents).
  final int minorDigits;

  static const eur = Currency._('EUR', '€', 2);

  static const _known = {'EUR': eur};

  int get minorPerMajor {
    var f = 1;
    for (var i = 0; i < minorDigits; i++) {
      f *= 10;
    }
    return f;
  }

  @override
  bool operator ==(Object other) => other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}

/// An amount of money stored as integer minor units (cents).
///
/// Never use `double` for money: all arithmetic here is exact. Use
/// [Money.fromDecimal]/[toDecimal] when percentages or interest are involved.
@immutable
class Money implements Comparable<Money> {
  const Money(this.minor, [this.currency = Currency.eur]);

  const Money.zero([this.currency = Currency.eur]) : minor = 0;

  /// Creates money from a decimal major-unit value, rounding half away from
  /// zero to the nearest minor unit.
  factory Money.fromDecimal(Decimal value, [Currency currency = Currency.eur]) {
    final scaled = value * Decimal.fromInt(currency.minorPerMajor);
    return Money(_roundHalfAwayFromZero(scaled), currency);
  }

  /// Parses a plain machine-format string like `-12.5` or `1234.56`.
  /// For user input with locale formats use the import/number parsers.
  factory Money.parse(String value, [Currency currency = Currency.eur]) =>
      Money.fromDecimal(Decimal.parse(value.trim()), currency);

  /// Sum of [values] (zero when empty).
  factory Money.sum(
    Iterable<Money> values, [
    Currency currency = Currency.eur,
  ]) => values.fold(Money.zero(currency), (a, b) => a + b);

  final int minor;
  final Currency currency;

  bool get isZero => minor == 0;
  bool get isNegative => minor < 0;
  bool get isPositive => minor > 0;

  Money get abs => Money(minor.abs(), currency);

  Decimal toDecimal() =>
      (Decimal.fromInt(minor) / Decimal.fromInt(currency.minorPerMajor))
          .toDecimal(scaleOnInfinitePrecision: currency.minorDigits);

  Money operator +(Money other) {
    _check(other);
    return Money(minor + other.minor, currency);
  }

  Money operator -(Money other) {
    _check(other);
    return Money(minor - other.minor, currency);
  }

  Money operator -() => Money(-minor, currency);

  /// Multiplies by an exact factor (e.g. a percentage) with half-away-from-zero
  /// rounding.
  Money times(Decimal factor) =>
      Money(_roundHalfAwayFromZero(Decimal.fromInt(minor) * factor), currency);

  /// Multiplies by an integer count.
  Money timesInt(int n) => Money(minor * n, currency);

  /// Splits into [parts] amounts that sum exactly to this amount; the
  /// remainder cents go to the first parts.
  List<Money> allocate(int parts) {
    assert(parts > 0, 'parts must be positive');
    final base = minor ~/ parts;
    var rest = minor - base * parts;
    final step = rest.sign;
    return List.generate(parts, (i) {
      if (rest != 0) {
        rest -= step;
        return Money(base + step, currency);
      }
      return Money(base, currency);
    });
  }

  /// Ratio of this to [other] as a double for display (progress bars only).
  double ratioTo(Money other) => other.minor == 0 ? 0 : minor / other.minor;

  bool operator <(Money other) => compareTo(other) < 0;
  bool operator <=(Money other) => compareTo(other) <= 0;
  bool operator >(Money other) => compareTo(other) > 0;
  bool operator >=(Money other) => compareTo(other) >= 0;

  static Money min(Money a, Money b) => a <= b ? a : b;
  static Money max(Money a, Money b) => a >= b ? a : b;

  @override
  int compareTo(Money other) {
    _check(other);
    return minor.compareTo(other.minor);
  }

  void _check(Money other) {
    if (other.currency != currency) {
      throw ArgumentError(
        'Currency mismatch: ${currency.code} vs ${other.currency.code}',
      );
    }
  }

  static int _roundHalfAwayFromZero(Decimal d) {
    final r = d.abs().round();
    final i = r.toBigInt().toInt();
    return d < Decimal.zero ? -i : i;
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  /// Machine-readable representation, e.g. `-12.50`.
  String toPlainString() {
    final neg = minor < 0;
    final a = minor.abs();
    final major = a ~/ currency.minorPerMajor;
    final rest = a % currency.minorPerMajor;
    final frac = currency.minorDigits == 0
        ? ''
        : '.${rest.toString().padLeft(currency.minorDigits, '0')}';
    return '${neg ? '-' : ''}$major$frac';
  }

  @override
  String toString() => '${toPlainString()} ${currency.code}';
}
