import 'package:meta/meta.dart';

/// Why an amount expression could not be evaluated.
enum CalcError {
  /// Nothing (or only whitespace) was entered.
  empty,

  /// Not a valid expression, e.g. `12++`, `(3`, `1,2,3.4.5`.
  syntax,

  /// Division by zero.
  divisionByZero,

  /// The result does not fit into the supported range.
  tooLarge,
}

/// Result of [AmountCalculator.evaluate]: either [minor] units or an [error].
@immutable
class CalcResult {
  const CalcResult.ok(int this.minor) : error = null;

  const CalcResult.error(CalcError this.error) : minor = null;

  final int? minor;
  final CalcError? error;

  bool get isOk => error == null;

  @override
  bool operator ==(Object other) =>
      other is CalcResult && other.minor == minor && other.error == error;

  @override
  int get hashCode => Object.hash(minor, error);

  @override
  String toString() => isOk ? 'CalcResult.ok($minor)' : 'CalcResult.$error';
}

/// Evaluates the quick-add keypad's calculator expressions such as
/// `12.50+3.20`, `3×4,99` or `(10+5)÷3` into minor units (cents).
///
/// * Operators: `+`, `-`/`−`, `*`/`×`/`x`, `/`/`÷`/`:`, parentheses and
///   unary minus; `×`/`÷` bind tighter than `+`/`−`.
/// * Arithmetic is exact (big rational numbers); only the final result is
///   rounded half away from zero to the cent.
/// * `decimalSeparator` is the locale's separator (`,` for German, `.` for
///   English). The other separator is accepted too: in a number containing
///   both, the last one is the decimal separator; on its own it is a
///   grouping separator when followed by exactly three digits (`1.234` in
///   German = 1234) and a decimal separator otherwise (`12.5`).
abstract final class AmountCalculator {
  /// Largest accepted absolute result in minor units (10^15 cents).
  static final _limit = BigInt.from(10).pow(15);

  /// Evaluates [input]. With [lenient] (live preview while typing) trailing
  /// operators are ignored and open parentheses are closed implicitly.
  static CalcResult evaluate(
    String input, {
    String decimalSeparator = '.',
    bool lenient = false,
  }) {
    final List<_Token> tokens;
    try {
      tokens = _tokenize(input, decimalSeparator);
    } on FormatException {
      return const CalcResult.error(CalcError.syntax);
    }
    if (lenient) {
      while (tokens.isNotEmpty &&
          tokens.last.kind == _Kind.op &&
          tokens.last.op != ')') {
        tokens.removeLast();
      }
      var depth = 0;
      for (final t in tokens) {
        if (t.op == '(') depth++;
        if (t.op == ')') depth--;
      }
      for (var i = 0; i < depth; i++) {
        tokens.add(const _Token.op(')'));
      }
    }
    if (tokens.isEmpty) return const CalcResult.error(CalcError.empty);
    final parser = _Parser(tokens);
    final _Frac value;
    try {
      value = parser.parse();
    } on _DivByZero {
      return const CalcResult.error(CalcError.divisionByZero);
    } on FormatException {
      return const CalcResult.error(CalcError.syntax);
    }
    final minor = value.toMinorRounded();
    if (minor.abs() > _limit) return const CalcResult.error(CalcError.tooLarge);
    return CalcResult.ok(minor.toInt());
  }

  /// Convenience: the result in minor units, or null when invalid.
  static int? tryEvaluate(String input, {String decimalSeparator = '.'}) =>
      evaluate(input, decimalSeparator: decimalSeparator).minor;

  /// Whether [input] contains an arithmetic operator (not just a leading
  /// sign), i.e. whether a "= result" preview is useful.
  static bool hasOperator(String input) {
    final s = input.trim();
    for (var i = 1; i < s.length; i++) {
      if (_opChars.containsKey(s[i]) && s[i] != '(' && s[i] != ')') {
        return true;
      }
    }
    return s.contains('(');
  }

  /// Normalises operator glyphs to the keypad's display characters
  /// (`*` → `×`, `/` → `÷`, `-` → `−`).
  static String displayOperator(String op) => switch (_opChars[op]) {
    '*' => '×',
    '/' => '÷',
    '-' => '−',
    final String o => o,
    null => op,
  };

  static const _opChars = <String, String>{
    '+': '+',
    '-': '-',
    '−': '-',
    '–': '-',
    '*': '*',
    '×': '*',
    'x': '*',
    'X': '*',
    '·': '*',
    '/': '/',
    '÷': '/',
    ':': '/',
    '(': '(',
    ')': ')',
  };

  static List<_Token> _tokenize(String input, String decimalSeparator) {
    final tokens = <_Token>[];
    final number = StringBuffer();
    void flush() {
      if (number.isEmpty) return;
      tokens.add(
        _Token.number(_parseNumber(number.toString(), decimalSeparator)),
      );
      number.clear();
    }

    for (final ch in input.split('')) {
      if (_isDigit(ch) || ch == '.' || ch == ',') {
        number.write(ch);
      } else if (_opChars.containsKey(ch)) {
        flush();
        tokens.add(_Token.op(_opChars[ch]!));
      } else if (ch.trim().isEmpty || ch == '€' || ch == "'") {
        // Whitespace, currency symbol and Swiss grouping are ignored; they
        // also end a number ("1 2" is a syntax error, not 12).
        flush();
      } else {
        throw const FormatException('unexpected character');
      }
    }
    flush();
    return tokens;
  }

  static bool _isDigit(String ch) {
    final c = ch.codeUnitAt(0);
    return c >= 0x30 && c <= 0x39;
  }

  static _Frac _parseNumber(String raw, String decimalSeparator) {
    final dec = decimalSeparator == ',' ? ',' : '.';
    final other = dec == ',' ? '.' : ',';
    final hasDec = raw.contains(dec);
    final hasOther = raw.contains(other);
    String intPart;
    String fracPart;
    if (hasDec && hasOther) {
      // The separator that occurs last is the decimal one.
      final last = raw.lastIndexOf(dec) > raw.lastIndexOf(other) ? dec : other;
      final group = last == dec ? other : dec;
      if (last.allMatches(raw).length != 1) {
        throw const FormatException('two decimal separators');
      }
      final i = raw.indexOf(last);
      intPart = raw.substring(0, i).replaceAll(group, '');
      fracPart = raw.substring(i + 1);
      if (fracPart.contains(group)) {
        throw const FormatException('grouping after decimal');
      }
    } else if (hasDec) {
      final parts = raw.split(dec);
      if (parts.length != 2) {
        throw const FormatException('two decimal separators');
      }
      intPart = parts[0];
      fracPart = parts[1];
    } else if (hasOther) {
      final parts = raw.split(other);
      final grouping =
          parts.length > 2 ||
          (parts[1].length == 3 && parts[0].isNotEmpty && parts[0] != '0');
      if (grouping) {
        if (parts.skip(1).any((p) => p.length != 3) || parts[0].isEmpty) {
          throw const FormatException('bad grouping');
        }
        intPart = parts.join();
        fracPart = '';
      } else {
        intPart = parts[0];
        fracPart = parts[1];
      }
    } else {
      intPart = raw;
      fracPart = '';
    }
    if (intPart.isEmpty && fracPart.isEmpty) {
      throw const FormatException('lonely separator');
    }
    final digits = '${intPart.isEmpty ? '0' : intPart}$fracPart';
    return _Frac(BigInt.parse(digits), BigInt.from(10).pow(fracPart.length));
  }
}

enum _Kind { number, op }

class _Token {
  const _Token.number(_Frac this.value) : kind = _Kind.number, op = null;
  const _Token.op(String this.op) : kind = _Kind.op, value = null;

  final _Kind kind;
  final _Frac? value;
  final String? op;
}

class _DivByZero implements Exception {
  const _DivByZero();
}

/// Recursive-descent parser:
/// `expr := term (('+'|'-') term)*`,
/// `term := unary (('*'|'/') unary)*`,
/// `unary := ('+'|'-') unary | number | '(' expr ')'`.
class _Parser {
  _Parser(this.tokens);

  final List<_Token> tokens;
  var _pos = 0;

  _Frac parse() {
    final v = _expr();
    if (_pos != tokens.length) throw const FormatException('trailing input');
    return v;
  }

  _Token? get _peek => _pos < tokens.length ? tokens[_pos] : null;

  bool _acceptOp(String op) {
    final t = _peek;
    if (t != null && t.op == op) {
      _pos++;
      return true;
    }
    return false;
  }

  _Frac _expr() {
    var v = _term();
    while (true) {
      if (_acceptOp('+')) {
        v = v + _term();
      } else if (_acceptOp('-')) {
        v = v - _term();
      } else {
        return v;
      }
    }
  }

  _Frac _term() {
    var v = _unary();
    while (true) {
      if (_acceptOp('*')) {
        v = v * _unary();
      } else if (_acceptOp('/')) {
        final d = _unary();
        if (d.isZero) throw const _DivByZero();
        v = v / d;
      } else {
        return v;
      }
    }
  }

  _Frac _unary() {
    if (_acceptOp('-')) return -_unary();
    if (_acceptOp('+')) return _unary();
    if (_acceptOp('(')) {
      final v = _expr();
      if (!_acceptOp(')')) throw const FormatException('missing )');
      return v;
    }
    final t = _peek;
    if (t == null || t.kind != _Kind.number) {
      throw const FormatException('number expected');
    }
    _pos++;
    return t.value!;
  }
}

/// Exact fraction of two big integers (denominator always positive).
@immutable
class _Frac {
  factory _Frac(BigInt numerator, BigInt denominator) {
    var n = numerator;
    var d = denominator;
    if (d.isNegative) {
      n = -n;
      d = -d;
    }
    final g = n.gcd(d);
    if (g > BigInt.one) {
      n = n ~/ g;
      d = d ~/ g;
    }
    return _Frac._(n, d);
  }

  const _Frac._(this.n, this.d);

  final BigInt n;
  final BigInt d;

  bool get isZero => n == BigInt.zero;

  _Frac operator +(_Frac o) => _Frac(n * o.d + o.n * d, d * o.d);
  _Frac operator -(_Frac o) => _Frac(n * o.d - o.n * d, d * o.d);
  _Frac operator *(_Frac o) => _Frac(n * o.n, d * o.d);
  _Frac operator /(_Frac o) => _Frac(n * o.d, d * o.n);
  _Frac operator -() => _Frac._(-n, d);

  /// Value × 100, rounded half away from zero.
  BigInt toMinorRounded() {
    final scaled = n * BigInt.from(100);
    final abs = scaled.abs();
    var q = abs ~/ d;
    final rem = abs - q * d;
    if (rem * BigInt.two >= d) q += BigInt.one;
    return scaled.isNegative ? -q : q;
  }

  @override
  bool operator ==(Object other) =>
      other is _Frac && other.n == n && other.d == d;

  @override
  int get hashCode => Object.hash(n, d);
}
