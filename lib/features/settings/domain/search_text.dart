/// Text normalisation and matching for the settings search (pure Dart).
library;

const _fold = {
  'ä': 'a',
  'ö': 'o',
  'ü': 'u',
  'ß': 'ss',
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ç': 'c',
  'ñ': 'n',
  '−': '-',
  '–': '-',
  '&': ' ',
  '/': ' ',
};

/// Lower-cases [s], folds umlauts/accents (ä → a, ß → ss) and collapses
/// whitespace, so "Schriftgröße" matches "schriftgrosse" and "größe".
String foldSearchText(String s) {
  final b = StringBuffer();
  for (final rune in s.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    b.write(_fold[ch] ?? ch);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// One searchable item.
class SearchDoc<T> {
  const SearchDoc({
    required this.value,
    required this.title,
    this.secondary = const [],
  });

  final T value;

  /// Primary text (the setting label).
  final String title;

  /// Description, keywords, section name, option labels.
  final List<String> secondary;
}

/// Returns the docs whose texts contain every query token, best matches
/// first: title prefix, then title word prefix, then title contains, then
/// secondary matches. Stable within a rank.
List<T> rankSearch<T>(String query, Iterable<SearchDoc<T>> docs) {
  final tokens = foldSearchText(query)
      .split(' ')
      .where((t) => t.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return const [];
  final scored = <(int, int, T)>[];
  var i = 0;
  for (final d in docs) {
    final title = foldSearchText(d.title);
    final rest = d.secondary.map(foldSearchText).join(' | ');
    var score = 0;
    var ok = true;
    for (final t in tokens) {
      if (title.startsWith(t)) {
        score += 40;
      } else if (title.contains(' $t') || title.contains('($t')) {
        score += 30;
      } else if (title.contains(t)) {
        score += 20;
      } else if (rest.contains(t)) {
        score += 10;
      } else {
        ok = false;
        break;
      }
    }
    if (ok) scored.add((score, i, d.value));
    i++;
  }
  scored.sort((a, b) {
    final c = b.$1.compareTo(a.$1);
    return c != 0 ? c : a.$2.compareTo(b.$2);
  });
  return [for (final s in scored) s.$3];
}
