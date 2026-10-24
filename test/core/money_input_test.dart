import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/money/money_input.dart';

void main() {
  test('parses common formats', () {
    final cases = <String, int?>{
      '12': 1200,
      '12,5': 1250,
      '12.50': 1250,
      '1.234,56': 123456,
      '1,234.56': 123456,
      '1.234': 123400,
      '1 234,56 €': 123456,
      '€1,234': 123400,
      '-12,50': -1250,
      '−12,50': -1250,
      '(12,50)': -1250,
      '12,50-': -1250,
      '0,125': 13,
      ',5': 50,
      '1.234.567': 123456700,
      'abc': null,
      '': null,
      '12+3': null,
    };
    cases.forEach((input, expected) {
      expect(parseAmountInput(input), expected, reason: input);
    });
  });

  test('formats for input', () {
    expect(formatAmountInput(123456), '1234,56');
    expect(formatAmountInput(-5, decimalSeparator: '.'), '-0.05');
  });
}
