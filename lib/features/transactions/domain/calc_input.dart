import 'package:personal_finance/core/money/money_input.dart';
import 'package:personal_finance/features/transactions/domain/calculator.dart';

/// Keys of the calculator keypad (and their physical-keyboard equivalents).
abstract final class CalcKey {
  static const separator = 'sep';
  static const plus = '+';
  static const minus = '−';
  static const times = '×';
  static const divide = '÷';
  static const open = '(';
  static const close = ')';
  static const backspace = 'back';
  static const clear = 'clear';
  static const equals = '=';

  static const operators = {plus, minus, times, divide};
}

/// Applies keypad presses to the expression string shown in quick add.
/// The expression uses the display glyphs (`+ − × ÷`) and the locale's
/// decimal separator; [AmountCalculator] evaluates it.
abstract final class CalcInput {
  static const maxLength = 48;

  /// Returns [expr] after pressing [key] (a digit `0`–`9` or a [CalcKey]).
  static String apply(
    String expr,
    String key, {
    required String decimalSeparator,
  }) {
    switch (key) {
      case CalcKey.clear:
        return '';
      case CalcKey.backspace:
        return expr.isEmpty ? expr : expr.substring(0, expr.length - 1);
      case CalcKey.equals:
        if (!AmountCalculator.hasOperator(expr)) return expr;
        final r = AmountCalculator.evaluate(
          expr,
          decimalSeparator: decimalSeparator,
          lenient: true,
        );
        if (!r.isOk) return expr;
        return _format(r.minor!, decimalSeparator);
    }
    if (expr.length >= maxLength) return expr;
    final token = _currentNumber(expr);
    final last = expr.isEmpty ? '' : expr[expr.length - 1];

    if (key == CalcKey.separator) {
      if (token.contains(decimalSeparator)) return expr;
      if (last == CalcKey.close) return expr;
      return token.isEmpty
          ? '${expr}0$decimalSeparator'
          : '$expr$decimalSeparator';
    }
    if (CalcKey.operators.contains(key)) {
      if (expr.isEmpty) return key == CalcKey.minus ? key : expr;
      if (last == CalcKey.open) {
        return key == CalcKey.minus ? '$expr$key' : expr;
      }
      if (CalcKey.operators.contains(last)) {
        // Replace the previous operator ("12+" then "×" → "12×").
        final trimmed = expr.substring(0, expr.length - 1);
        if (trimmed.isEmpty) return key == CalcKey.minus ? key : '';
        return '$trimmed$key';
      }
      if (last == decimalSeparator) {
        return '${expr.substring(0, expr.length - 1)}$key';
      }
      return '$expr$key';
    }
    if (key == CalcKey.open) {
      if (expr.isEmpty || CalcKey.operators.contains(last) || last == '(') {
        return '$expr(';
      }
      return expr;
    }
    if (key == CalcKey.close) {
      final open = '('.allMatches(expr).length;
      final closed = ')'.allMatches(expr).length;
      if (open <= closed || token.isEmpty && last != ')') return expr;
      if (last == decimalSeparator) return expr;
      return '$expr)';
    }
    if (key.length == 1 &&
        key.codeUnitAt(0) >= 0x30 &&
        key.codeUnitAt(0) <= 0x39) {
      if (last == CalcKey.close) return expr;
      // At most two decimals per number.
      final sep = token.indexOf(decimalSeparator);
      if (sep >= 0 && token.length - sep - 1 >= 2) return expr;
      // No leading zeros ("0" then "5" → "5").
      if (token == '0') return '${expr.substring(0, expr.length - 1)}$key';
      return '$expr$key';
    }
    return expr;
  }

  /// Maps a typed character to a key, or null when it is not accepted.
  /// Both `.` and `,` type the locale's decimal separator.
  static String? keyForCharacter(String ch) {
    if (ch.length != 1) return null;
    final c = ch.codeUnitAt(0);
    if (c >= 0x30 && c <= 0x39) return ch;
    return switch (ch) {
      '.' || ',' => CalcKey.separator,
      '+' => CalcKey.plus,
      '-' || '−' => CalcKey.minus,
      '*' || 'x' || 'X' || '×' => CalcKey.times,
      '/' || ':' || '÷' => CalcKey.divide,
      '(' => CalcKey.open,
      ')' => CalcKey.close,
      '=' => CalcKey.equals,
      _ => null,
    };
  }

  /// Expression for an existing amount (edit mode), e.g. `24,80`.
  static String fromMinor(int minor, {required String decimalSeparator}) {
    if (minor == 0) return '';
    return _format(minor.abs(), decimalSeparator);
  }

  static String _format(int minor, String sep) {
    final s = formatAmountInput(minor, decimalSeparator: sep);
    // Drop ",00" for whole amounts so the user can keep typing.
    final zero = '${sep}00';
    final v = s.endsWith(zero) ? s.substring(0, s.length - 3) : s;
    return v.replaceFirst('-', CalcKey.minus);
  }

  /// The number being typed at the end of [expr].
  static String _currentNumber(String expr) {
    var i = expr.length;
    while (i > 0) {
      final ch = expr[i - 1];
      final c = ch.codeUnitAt(0);
      if ((c >= 0x30 && c <= 0x39) || ch == '.' || ch == ',') {
        i--;
      } else {
        break;
      }
    }
    return expr.substring(i);
  }
}
