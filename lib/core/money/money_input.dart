/// Parses a user-typed amount into minor units (cents).
///
/// Accepts both `1.234,56` (German) and `1,234.56` (English) styles, plain
/// `12,5` / `12.5`, optional currency symbol, spaces, a leading `-`/`−` or
/// parentheses for negatives. When only one separator occurs, it is a
/// decimal separator if followed by 1–2 digits, otherwise a grouping
/// separator (`1.234` = 1234, `1,5` = 1.50).
///
/// Returns null when the text is not a number.
int? parseAmountInput(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  var negative = false;
  if (s.startsWith('(') && s.endsWith(')')) {
    negative = true;
    s = s.substring(1, s.length - 1);
  }
  s = s
      .replaceAll('€', '')
      .replaceAll('EUR', '')
      .replaceAll(RegExp(r'[\s  ]'), '')
      .replaceAll("'", '');
  if (s.startsWith('-') || s.startsWith('−')) {
    negative = !negative;
    s = s.substring(1);
  } else if (s.startsWith('+')) {
    s = s.substring(1);
  }
  if (s.endsWith('-') || s.endsWith('−')) {
    negative = !negative;
    s = s.substring(0, s.length - 1);
  }
  if (s.isEmpty || !RegExp(r'^[0-9.,]+$').hasMatch(s)) return null;

  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  String intPart;
  String fracPart;
  if (lastComma >= 0 && lastDot >= 0) {
    final dec = lastComma > lastDot ? ',' : '.';
    final i = s.lastIndexOf(dec);
    intPart = s.substring(0, i).replaceAll(RegExp('[.,]'), '');
    fracPart = s.substring(i + 1);
  } else if (lastComma >= 0 || lastDot >= 0) {
    final sep = lastComma >= 0 ? ',' : '.';
    final parts = s.split(sep);
    final tail = parts.last;
    // One separator followed by exactly three digits reads as grouping
    // ("1.234" = 1234) unless the integer part is 0 ("0,125").
    final grouping =
        parts.length > 2 || (tail.length == 3 && parts.first != '0');
    if (grouping) {
      intPart = parts.join();
      fracPart = '';
    } else {
      intPart = parts.first;
      fracPart = tail;
    }
  } else {
    intPart = s;
    fracPart = '';
  }
  if (intPart.isEmpty) intPart = '0';
  if (fracPart.length > 2) {
    // Round half away from zero on the third decimal.
    final round = int.parse(fracPart[2]) >= 5;
    fracPart = fracPart.substring(0, 2);
    final v = int.parse(intPart) * 100 + int.parse(fracPart) + (round ? 1 : 0);
    return negative ? -v : v;
  }
  final v = int.parse(intPart) * 100 + int.parse(fracPart.padRight(2, '0'));
  return negative ? -v : v;
}

/// Formats minor units for an input field (no symbol, no grouping), e.g.
/// `1234,50`.
String formatAmountInput(int minor, {String decimalSeparator = ','}) {
  final neg = minor < 0;
  final a = minor.abs();
  final s =
      '${a ~/ 100}$decimalSeparator${(a % 100).toString().padLeft(2, '0')}';
  return neg ? '-$s' : s;
}
