import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:personal_finance/features/import/domain/text_normalize.dart';

/// Duplicate hash of a transaction (PLAN.md §2.5 step 10): date, signed
/// amount and normalised payee/note. 32 hex characters.
String dedupeHash({
  required DateTime date,
  required int amountMinor,
  String? payee,
  String? note,
}) {
  final d =
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  final key = '$d|$amountMinor|${normaliseText(payee)}|${normaliseText(note)}';
  return sha256.convert(utf8.encode(key)).toString().substring(0, 32);
}

/// Separator between the two legs' hashes / row refs of an imported
/// transfer: `<outgoing>|<incoming>`. Both legs store the combined value;
/// each leg owns the part matching its sign (outgoing = first).
const transferHashSeparator = '|';

/// Combined hash stored on both legs of a merged transfer.
String transferHash(String outgoing, String incoming) =>
    '$outgoing$transferHashSeparator$incoming';

/// The hash that belongs to one stored leg: plain hashes as they are; for
/// a combined transfer hash the outgoing part for the negative leg and the
/// incoming part for the positive leg.
String legHash(String stored, int amountMinor) {
  final i = stored.indexOf(transferHashSeparator);
  if (i < 0) return stored;
  return amountMinor < 0 ? stored.substring(0, i) : stored.substring(i + 1);
}

/// A multiset of hashes: each stored transaction can absorb one incoming
/// duplicate, so two identical coffees on one day are matched one-to-one.
class HashCounter {
  HashCounter([Map<String, int>? counts]) : _counts = {...?counts};

  final Map<String, int> _counts;

  void add(String hash, [int n = 1]) =>
      _counts[hash] = (_counts[hash] ?? 0) + n;

  bool contains(String hash) => (_counts[hash] ?? 0) > 0;

  /// Removes one occurrence; returns whether there was one.
  bool take(String hash) {
    final n = _counts[hash] ?? 0;
    if (n <= 0) return false;
    _counts[hash] = n - 1;
    return true;
  }

  Map<String, int> toMap() => Map.unmodifiable(_counts);
}
