// Merges per-feature ARB fragments into the gen-l10n input files and runs
// `flutter gen-l10n`.
//
//   dart run tool/l10n.dart          # merge + generate
//   dart run tool/l10n.dart --check  # also fail if a DE key is missing
//
// Fragments live in lib/l10n/parts/<feature>_<locale>.arb. Keys must be
// prefixed with the feature name in camelCase (e.g. `txnListTitle`) so
// fragments never collide. Each `<feature>_en.arb` is the template and may
// carry `@key` metadata; other locales only need the plain keys.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final parts = Directory('lib/l10n/parts');
  final byLocale = <String, Map<String, Object?>>{};
  final files =
      parts
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.arb'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final name = f.uri.pathSegments.last.replaceAll('.arb', '');
    final locale = name.substring(name.lastIndexOf('_') + 1);
    final Map<String, Object?> json;
    try {
      json = (jsonDecode(f.readAsStringSync()) as Map).cast();
    } on FormatException catch (e) {
      stderr.writeln('Invalid JSON in ${f.path}: $e');
      exit(1);
    }
    final target = byLocale.putIfAbsent(locale, () => {'@@locale': locale});
    for (final e in json.entries) {
      if (e.key.startsWith('@@')) continue;
      if (target.containsKey(e.key)) {
        stderr.writeln('Duplicate key ${e.key} in ${f.path}');
        exit(1);
      }
      target[e.key] = e.value;
    }
  }
  final en = byLocale['en'] ?? {};
  var missing = 0;
  for (final entry in byLocale.entries) {
    if (entry.key == 'en') continue;
    for (final k in en.keys.where((k) => !k.startsWith('@'))) {
      if (!entry.value.containsKey(k)) {
        missing++;
        if (args.contains('--check')) {
          stderr.writeln('Missing ${entry.key} translation: $k');
        }
      }
    }
  }
  const encoder = JsonEncoder.withIndent('  ');
  for (final entry in byLocale.entries) {
    File('lib/l10n/app_${entry.key}.arb')
        .writeAsStringSync('${encoder.convert(entry.value)}\n');
  }
  if (args.contains('--check') && missing > 0) exit(1);
  final r = Process.runSync('flutter', ['gen-l10n'], runInShell: true);
  stdout.write(r.stdout);
  stderr.write(r.stderr);
  exit(r.exitCode);
}
