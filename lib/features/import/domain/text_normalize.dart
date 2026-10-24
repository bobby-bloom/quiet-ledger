import 'dart:math' as math;

import 'package:meta/meta.dart';

const _fold = {
  'ä': 'ae',
  'ö': 'oe',
  'ü': 'ue',
  'ß': 'ss',
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'å': 'a',
  'æ': 'ae',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ø': 'o',
  'œ': 'oe',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ý': 'y',
  'ÿ': 'y',
};

/// Lower-cases and folds diacritics (`Müller` → `mueller`).
String foldText(String s) {
  final lower = s.toLowerCase();
  final sb = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    sb.write(_fold[ch] ?? ch);
  }
  return sb.toString();
}

/// Folded text with everything but letters and digits removed: the form
/// used to compare header names (`Betrag (€)` → `betrag`).
String headerKey(String s) => foldText(s).replaceAll(RegExp('[^a-z0-9]'), '');

/// Folded text with punctuation removed and whitespace collapsed: the form
/// used for duplicate hashes and fuzzy matching (`REWE  Markt GmbH.` →
/// `rewe markt gmbh`).
String normaliseText(String? s) {
  if (s == null) return '';
  return foldText(s)
      .replaceAll(RegExp('[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

/// Levenshtein edit distance.
int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  var cur = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = math.min(
        math.min(cur[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + cost,
      );
    }
    final t = prev;
    prev = cur;
    cur = t;
  }
  return prev[b.length];
}

Set<String> _trigrams(String s) {
  final p = '  $s ';
  return {for (var i = 0; i + 3 <= p.length; i++) p.substring(i, i + 3)};
}

/// Similarity in [0, 1] of two labels: the better of normalised
/// Levenshtein and trigram Dice, with a bonus when one contains the other.
double similarity(String a, String b) {
  final x = normaliseText(a);
  final y = normaliseText(b);
  if (x.isEmpty || y.isEmpty) return 0;
  if (x == y) return 1;
  final lev = 1 - levenshtein(x, y) / math.max(x.length, y.length);
  final ta = _trigrams(x);
  final tb = _trigrams(y);
  final common = ta.intersection(tb).length;
  final dice = 2 * common / (ta.length + tb.length);
  var score = math.max(lev, dice);
  if (x.length >= 3 && y.length >= 3 && (x.contains(y) || y.contains(x))) {
    score = math.max(score, 0.8);
  }
  return score;
}

/// A fuzzy match candidate.
@immutable
class FuzzyMatch<T> {
  const FuzzyMatch(this.value, this.label, this.score);

  final T value;
  final String label;
  final double score;
}

/// The [limit] best candidates for [query] with a score ≥ [threshold],
/// best first.
List<FuzzyMatch<T>> fuzzyMatches<T>(
  String query,
  Iterable<(T, String)> candidates, {
  double threshold = 0.55,
  int limit = 3,
}) {
  final out = <FuzzyMatch<T>>[
    for (final (v, label) in candidates)
      if (similarity(query, label) case final s when s >= threshold)
        FuzzyMatch(v, label, s),
  ]..sort((a, b) => b.score.compareTo(a.score));
  return out.length > limit ? out.sublist(0, limit) : out;
}
