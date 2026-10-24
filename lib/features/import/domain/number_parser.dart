import 'package:decimal/decimal.dart';
import 'package:personal_finance/core/money/money.dart';
import 'package:personal_finance/features/import/domain/raw_sheet.dart';

/// Number notations for amounts (PLAN.md §2.5 step 5).
enum NumberFormatKind {
  /// Detect per column.
  auto,

  /// German: `1.234,56`.
  de,

  /// English: `1,234.56`.
  en,

  /// Space grouping: `1 234,56` (also `1 234.56`).
  space,
}

final _currency = RegExp(
  r'(€|\$|£|¥|\bEUR\b|\bUSD\b|\bGBP\b|\bCHF\b|\bFr\.|\bEuro\b)',
  caseSensitive: false,
);
final _spaces = RegExp('[\\s\u00a0\u202f\u2009]');
final _deRe = RegExp(r'^(?:\d{1,3}(?:\.\d{3})+|\d+)?(?:,\d+)?$');
final _enRe = RegExp(r'^(?:\d{1,3}(?:,\d{3})+|\d+)?(?:\.\d+)?$');
final _spaceRe = RegExp(r'^(?:\d{1,3}(?: \d{3})+|\d+)?(?:[.,]\d+)?$');
final _suffixSign = RegExp(r'\s*(S|H|CR|DR|Cr|Dr|Soll|Haben)$');

/// Converts a plain decimal string (`-12.345`) to minor units, rounding half
/// away from zero.
int? decimalToMinor(String number) {
  final t = number.trim();
  final m = _simpleDecimal.firstMatch(t);
  if (m != null && m.group(2)!.length <= 15) {
    final whole = int.parse(m.group(2)!);
    final cents = int.parse((m.group(3) ?? '').padRight(2, '0'));
    final v = whole * 100 + cents;
    return m.group(1) == '-' ? -v : v;
  }
  final d = Decimal.tryParse(t);
  return d == null ? null : Money.fromDecimal(d).minor;
}

/// Parses an amount written as text in notation [kind] (not auto) into
/// signed minor units. Understands a leading `+`, `-`, `−` or `–`, a
/// trailing minus (`12,50-`), parentheses for negatives (`(12,50)`),
/// currency symbols and codes, and `S`/`H` or `DR`/`CR` suffixes.
int? parseAmountText(String input, NumberFormatKind kind) {
  var s = input.trim();
  if (s.isEmpty) return null;
  // Fast path for plain numbers ("-1.234,56").
  if (_plain.hasMatch(s)) return _parseCore(s, kind);
  var negative = false;
  final suffix = _suffixSign.firstMatch(s);
  if (suffix != null && suffix.start > 0) {
    final t = suffix.group(1)!.toLowerCase();
    if (t == 's' || t == 'dr' || t == 'soll') negative = true;
    s = s.substring(0, suffix.start);
  }
  s = s.replaceAll(_currency, '').trim();
  if (s.startsWith('(') && s.endsWith(')')) {
    negative = !negative;
    s = s.substring(1, s.length - 1).trim();
  }
  s = s.replaceAll(_currency, '').trim();
  if (s.isEmpty) return null;
  final first = s[0];
  if (first == '-' || first == '−' || first == '–') {
    negative = !negative;
    s = s.substring(1).trim();
  } else if (first == '+') {
    s = s.substring(1).trim();
  }
  if (s.isNotEmpty) {
    final last = s[s.length - 1];
    if (last == '-' || last == '−') {
      negative = !negative;
      s = s.substring(0, s.length - 1).trim();
    }
  }
  s = s.replaceAll(_currency, '').replaceAll("'", '').replaceAll('’', '');
  if (s.isEmpty) return null;
  final v = _parseCore(s, kind);
  if (v == null) return null;
  return negative ? -v : v;
}

final _simpleDecimal = RegExp(r'^([-+]?)(\d+)(?:\.(\d{0,2}))?$');
final _plain = RegExp(r'^-?[0-9][0-9.,]*$');

/// Parses unsigned digits with separators in notation [kind]; a leading
/// "-" is accepted (fast path).
int? _parseCore(String input, NumberFormatKind kind) {
  var s = input;
  var negative = false;
  if (s.startsWith('-')) {
    negative = true;
    s = s.substring(1);
  }

  String intPart;
  String frac;
  switch (kind) {
    case NumberFormatKind.de:
      s = s.replaceAll(_spaces, '');
      if (!_deRe.hasMatch(s)) return null;
      final i = s.indexOf(',');
      intPart = (i < 0 ? s : s.substring(0, i)).replaceAll('.', '');
      frac = i < 0 ? '' : s.substring(i + 1);
    case NumberFormatKind.en:
    case NumberFormatKind.auto:
      s = s.replaceAll(_spaces, '');
      if (!_enRe.hasMatch(s)) return null;
      final i = s.indexOf('.');
      intPart = (i < 0 ? s : s.substring(0, i)).replaceAll(',', '');
      frac = i < 0 ? '' : s.substring(i + 1);
    case NumberFormatKind.space:
      s = s.replaceAll(_spaces, ' ').trim();
      if (!_spaceRe.hasMatch(s)) return null;
      final i = s.lastIndexOf(RegExp('[.,]'));
      intPart = (i < 0 ? s : s.substring(0, i)).replaceAll(' ', '');
      frac = i < 0 ? '' : s.substring(i + 1);
  }
  if (intPart.isEmpty && frac.isEmpty) return null;
  if (frac.length <= 2 && intPart.length <= 15) {
    // Exact without rounding: integer arithmetic.
    final whole = intPart.isEmpty ? 0 : int.parse(intPart);
    final cents = frac.isEmpty ? 0 : int.parse(frac.padRight(2, '0'));
    final v = whole * 100 + cents;
    return negative ? -v : v;
  }
  final minor = decimalToMinor(
    '${intPart.isEmpty ? '0' : intPart}.${frac.isEmpty ? '0' : frac}',
  );
  if (minor == null) return null;
  return negative ? -minor : minor;
}

/// Parses an amount cell: numbers as they are, text in notation [kind]
/// ([NumberFormatKind.auto] reads text as English).
int? parseAmountCell(RawCell cell, NumberFormatKind kind) =>
    switch (cell.kind) {
      RawKind.number => decimalToMinor(cell.number!),
      RawKind.text => parseAmountText(cell.text!, kind),
      RawKind.empty || RawKind.date || RawKind.boolean || RawKind.error => null,
    };

/// Picks the notation of a column of amounts written as text. Strong
/// evidence (both separators, or one separator followed by 1–2 digits)
/// decides; otherwise [fallback].
NumberFormatKind detectNumberFormat(
  Iterable<String> samples, {
  NumberFormatKind fallback = NumberFormatKind.de,
}) {
  var de = 0;
  var en = 0;
  var space = 0;
  var weakDe = 0;
  var weakEn = 0;
  for (final raw in samples) {
    final s = raw
        .replaceAll(_currency, '')
        .replaceAll(RegExp(r'[()+\-−–\s]+$|^[()+\-−–\s]+'), '')
        .replaceAll(_suffixSign, '')
        .trim();
    if (s.isEmpty || !RegExp(r'\d').hasMatch(s)) continue;
    final normSpace = s.replaceAll(_spaces, ' ');
    if (RegExp(r'\d \d{3}').hasMatch(normSpace)) {
      space++;
      continue;
    }
    final comma = s.lastIndexOf(',');
    final dot = s.lastIndexOf('.');
    if (comma >= 0 && dot >= 0) {
      comma > dot ? de++ : en++;
    } else if (comma >= 0) {
      final tail = s.length - comma - 1;
      if (tail == 1 || tail == 2) {
        de++;
      } else if (tail == 3) {
        weakEn++;
      } else {
        de++;
      }
    } else if (dot >= 0) {
      final tail = s.length - dot - 1;
      if (tail == 1 || tail == 2) {
        en++;
      } else if (tail == 3) {
        weakDe++;
      } else {
        en++;
      }
    }
  }
  // "1 234,56" also reads "12,00"; any space grouping decides.
  if (space > 0 && en == 0) return NumberFormatKind.space;
  if (de > en) return NumberFormatKind.de;
  if (en > de) return NumberFormatKind.en;
  if (weakDe > weakEn) return NumberFormatKind.de;
  if (weakEn > weakDe) return NumberFormatKind.en;
  return fallback;
}
