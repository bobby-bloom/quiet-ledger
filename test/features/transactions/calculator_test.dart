import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/transactions/domain/calc_input.dart';
import 'package:personal_finance/features/transactions/domain/calculator.dart';

void main() {
  int? en(String s) => AmountCalculator.tryEvaluate(s);
  int? de(String s) => AmountCalculator.tryEvaluate(s, decimalSeparator: ',');
  CalcError? err(String s, {String sep = '.'}) =>
      AmountCalculator.evaluate(s, decimalSeparator: sep).error;

  group('AmountCalculator', () {
    test('plain numbers', () {
      expect(en('24.80'), 2480);
      expect(en('24'), 2400);
      expect(en('.5'), 50);
      expect(en('12.'), 1200);
      expect(en('€ 7.5'), 750);
    });

    test('addition and subtraction', () {
      expect(en('12.50+3.20'), 1570);
      expect(en('10-2.5'), 750);
      expect(en('10−2.5'), 750);
      expect(en('1+2+3'), 600);
    });

    test('precedence: × and ÷ before + and −', () {
      expect(en('2+3×4'), 1400);
      expect(en('2+3*4'), 1400);
      expect(en('10-6/2'), 700);
      expect(en('10-6÷2'), 700);
      expect(en('(2+3)×4'), 2000);
      expect(en('2×(3+4)×0.5'), 700);
    });

    test('unary minus', () {
      expect(en('-5'), -500);
      expect(en('3×-2'), -600);
      expect(en('-(2+3)'), -500);
    });

    test('exact arithmetic, rounding only at the end', () {
      // 10 / 3 = 3.333… → 3.33; × 3 again stays exact (10.00).
      expect(en('10/3'), 333);
      expect(en('10/3*3'), 1000);
      // 0.1 + 0.2 is exactly 0.30 (no binary float error).
      expect(en('0.1+0.2'), 30);
      // Half away from zero on the third decimal.
      expect(en('0.125'), 13);
      expect(en('-0.125'), -13);
      expect(en('1/8'), 13);
      expect(en('0.124'), 12);
      expect(en('2/3'), 67);
    });

    test('German separators', () {
      expect(de('12,50+3,20'), 1570);
      expect(de('24,8'), 2480);
      // A lone dot followed by three digits is grouping in German.
      expect(de('1.234'), 123400);
      expect(de('1.234,56'), 123456);
      // …otherwise the dot is still accepted as decimal separator.
      expect(de('12.5'), 1250);
      expect(de('3×4,99'), 1497);
    });

    test('English separators', () {
      expect(en('1,234.56'), 123456);
      expect(en('1,234'), 123400);
      expect(en('12,5'), 1250);
      expect(en('1,234,567'), 123456700);
    });

    test('invalid input', () {
      expect(err(''), CalcError.empty);
      expect(err('   '), CalcError.empty);
      expect(err('12++'), CalcError.syntax);
      expect(err('(3'), CalcError.syntax);
      expect(err('3)'), CalcError.syntax);
      expect(err('1.2.3'), CalcError.syntax);
      expect(err('12.5.6', sep: ','), CalcError.syntax);
      expect(err('1,2,3', sep: ','), CalcError.syntax);
      expect(err('abc'), CalcError.syntax);
      expect(err('5/0'), CalcError.divisionByZero);
      expect(err('5/(2-2)'), CalcError.divisionByZero);
      expect(err('9999999999999999'), CalcError.tooLarge);
    });

    test('lenient mode for the live preview', () {
      final r = AmountCalculator.evaluate('12+', lenient: true);
      expect(r, const CalcResult.ok(1200));
      expect(AmountCalculator.evaluate('(2+3', lenient: true).minor, 500);
      expect(AmountCalculator.evaluate('12+').error, CalcError.syntax);
    });

    test('hasOperator', () {
      expect(AmountCalculator.hasOperator('12'), isFalse);
      expect(AmountCalculator.hasOperator('-12'), isFalse);
      expect(AmountCalculator.hasOperator('12+3'), isTrue);
      expect(AmountCalculator.hasOperator('2×3'), isTrue);
    });
  });

  group('CalcInput', () {
    String type(String keys, {String sep = ','}) {
      var e = '';
      for (final k in keys.split(' ')) {
        e = CalcInput.apply(e, k, decimalSeparator: sep);
      }
      return e;
    }

    test('digits, separator and max two decimals', () {
      expect(type('1 2 sep 5 0 7'), '12,50');
      expect(type('sep 5'), '0,5');
      expect(type('1 sep sep 2'), '1,2');
    });

    test('no leading zeros', () {
      expect(type('0 0 5'), '5');
      expect(type('0 sep 5'), '0,5');
    });

    test('operators replace each other and are ignored at start', () {
      expect(type('+ 1 2 + × 3'), '12×3');
      expect(type('1 2 + − 3'), '12−3');
      expect(type('− 5'), '−5');
    });

    test('backspace, clear and equals', () {
      expect(type('1 2 3 back'), '12');
      expect(type('1 2 clear'), '');
      expect(type('1 2 sep 5 + 3 sep 2 ='), '15,70');
      expect(type('1 0 + 5 ='), '15');
      expect(type('1 0 ='), '10');
    });

    test('result of the typed expression', () {
      final e = type('1 2 sep 5 + 3 sep 2');
      expect(AmountCalculator.tryEvaluate(e, decimalSeparator: ','), 1570);
    });

    test('physical keyboard mapping', () {
      expect(CalcInput.keyForCharacter('7'), '7');
      expect(CalcInput.keyForCharacter('.'), CalcKey.separator);
      expect(CalcInput.keyForCharacter(','), CalcKey.separator);
      expect(CalcInput.keyForCharacter('*'), CalcKey.times);
      expect(CalcInput.keyForCharacter('/'), CalcKey.divide);
      expect(CalcInput.keyForCharacter('-'), CalcKey.minus);
      expect(CalcInput.keyForCharacter('a'), isNull);
    });

    test('fromMinor drops zero cents', () {
      expect(CalcInput.fromMinor(2480, decimalSeparator: ','), '24,80');
      expect(CalcInput.fromMinor(-1500, decimalSeparator: '.'), '15');
      expect(CalcInput.fromMinor(0, decimalSeparator: '.'), '');
    });
  });
}
