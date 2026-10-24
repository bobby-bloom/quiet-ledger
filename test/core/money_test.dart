import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/money/money.dart';
import 'package:personal_finance/core/money/money_format.dart';

void main() {
  group('Money', () {
    test('arithmetic is exact', () {
      expect(const Money(10) + const Money(20), const Money(30));
      expect(const Money(10) - const Money(25), const Money(-15));
      expect(-const Money(5), const Money(-5));
    });

    test('parse and toPlainString round-trip', () {
      expect(Money.parse('12.5').minor, 1250);
      expect(Money.parse('-0.01').minor, -1);
      expect(const Money(-123456).toPlainString(), '-1234.56');
      expect(const Money(5).toPlainString(), '0.05');
    });

    test('times rounds half away from zero', () {
      expect(const Money(1000).times(Decimal.parse('0.0125')).minor, 13);
      expect(const Money(-1000).times(Decimal.parse('0.0125')).minor, -13);
      expect(const Money(3).times(Decimal.parse('0.5')).minor, 2);
    });

    test('allocate distributes remainder', () {
      final parts = const Money(100).allocate(3);
      expect(parts.map((m) => m.minor), [34, 33, 33]);
      expect(Money.sum(parts), const Money(100));
      final neg = const Money(-100).allocate(3);
      expect(neg.map((m) => m.minor), [-34, -33, -33]);
    });

    test('currency mismatch throws', () {
      expect(
        () => const Money(1) + Money(1, Currency.of('USD')),
        throwsArgumentError,
      );
    });
  });

  group('MoneyFormatter', () {
    test('en_US', () {
      final f = MoneyFormatter(locale: 'en_US');
      expect(f.format(const Money(2411840)), '€24,118.40');
      expect(f.format(const Money(-1999)), '−€19.99');
      expect(f.format(const Money(12000), explicitPlus: true), '+€120.00');
    });

    test('de_DE with sign styles', () {
      expect(
        MoneyFormatter(locale: 'de_DE').format(const Money(-123456)),
        '−1.234,56 €',
      );
      expect(
        MoneyFormatter(
          locale: 'de_DE',
          signStyle: SignStyle.parentheses,
        ).format(const Money(-1250)),
        '(12,50 €)',
      );
      expect(
        MoneyFormatter(
          locale: 'de_DE',
          signStyle: SignStyle.trailingMinus,
        ).format(const Money(-1250)),
        '12,50 € −',
      );
    });

    test('without cents rounds', () {
      final f = MoneyFormatter(locale: 'en_US', showCents: false);
      expect(f.format(const Money(1050)), '€11');
      expect(f.format(const Money(1049)), '€10');
    });

    test('hero split', () {
      final (whole, frac) = MoneyFormatter(locale: 'en_US')
          .formatHero(const Money(2411840));
      expect(whole, '€24,118');
      expect(frac, '.40');
    });
  });
}
